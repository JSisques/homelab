#!/bin/sh
# Polls SCAN_DIR for files that are new and have stopped growing (i.e. not
# mid-download), then scans each one against the clamd daemon at
# CLAMD_HOST:CLAMD_PORT over TCP. Runs independently of qBittorrent/Sonarr/
# Radarr/pyLoad/MeTube, so it covers every download path into
# /mnt/nas/downloads, not just torrents.
#
# This does not quarantine or delete infected files — Sonarr/Radarr import
# on their own schedule and don't know about this scanner. It only records
# hits in INFECTED_LOG so they can be found and removed by hand.
set -eu

: "${CLAMD_HOST:=clamav}"
: "${CLAMD_PORT:=3310}"
: "${SCAN_DIR:=/scan}"
: "${STATE_DIR:=/state}"
: "${POLL_INTERVAL:=60}"
: "${STABLE_WAIT:=10}"

mkdir -p "$STATE_DIR"
SCANNED_LIST="$STATE_DIR/scanned.list"
INFECTED_LOG="$STATE_DIR/infected.log"
touch "$SCANNED_LIST" "$INFECTED_LOG"

CLAMD_CONF="$STATE_DIR/clamd-remote.conf"
cat > "$CLAMD_CONF" <<EOF
TCPSocket $CLAMD_PORT
TCPAddr $CLAMD_HOST
EOF

echo "[clamav-scan-watch] watching $SCAN_DIR, reporting to $CLAMD_HOST:$CLAMD_PORT every ${POLL_INTERVAL}s"

while true; do
  find "$SCAN_DIR" -type f 2>/dev/null | while IFS= read -r file; do
    grep -qxF "$file" "$SCANNED_LIST" && continue

    size1=$(stat -c%s "$file" 2>/dev/null || echo -1)
    sleep "$STABLE_WAIT"
    size2=$(stat -c%s "$file" 2>/dev/null || echo -2)
    if [ "$size1" != "$size2" ] || [ "$size1" -le 0 ]; then
      continue # still being written, or vanished
    fi

    echo "[clamav-scan-watch] scanning: $file"
    if clamdscan --config-file="$CLAMD_CONF" --no-summary --quiet "$file"; then
      echo "$file" >> "$SCANNED_LIST"
    else
      rc=$?
      if [ "$rc" -eq 1 ]; then
        echo "$(date +%Y-%m-%dT%H:%M:%S%z) INFECTED: $file" | tee -a "$INFECTED_LOG"
        echo "$file" >> "$SCANNED_LIST"
      else
        echo "[clamav-scan-watch] scan error (exit $rc) on $file, will retry next pass"
      fi
    fi
  done
  sleep "$POLL_INTERVAL"
done
