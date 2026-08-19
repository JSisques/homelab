#!/usr/bin/env python3
"""Sync Uptime Kuma monitors from config/services.yaml.

Unlike scripts/generation/*.sh, this isn't a pure local file transform —
Uptime Kuma has no config file of its own (everything lives in its
internal SQLite database, editable only via its UI or Socket.IO API), so
"generating" its config means pushing state into a live instance over
that API. Safe to run repeatedly: monitors are matched by name and
updated in place rather than duplicated, and only monitors this script
itself created (tagged via a fixed description) are ever pruned.

Requires the `uptime-kuma-api` package (`pip install uptime-kuma-api`)
and `yq` (https://github.com/kislyuk/yq), already required by every
script in scripts/generation/.
"""

import argparse
import json
import subprocess
import sys
from urllib.parse import urlparse

try:
    from uptime_kuma_api import MonitorType, UptimeKumaApi
except ImportError:
    sys.exit(
        "Error: uptime-kuma-api is required but was not found.\n"
        "Install it: pip install uptime-kuma-api"
    )

MANAGED_MARKER = (
    "Managed by config/services.yaml via scripts/sync-uptime-kuma.py "
    "— edits here are overwritten on the next deploy."
)


def load_services(services_yaml_path):
    result = subprocess.run(
        ["yq", "-c", ".", services_yaml_path],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)["services"]


def build_desired_monitors(services):
    """One entry per service with uptime.enabled == true, keyed by name."""
    desired = {}
    for key, service in services.items():
        if not service.get("uptime", {}).get("enabled"):
            continue

        url = service.get("url")
        if not url:
            sys.exit(f'Error: service "{key}" has uptime.enabled but no url')

        name = service.get("name", key)
        parsed = urlparse(url)
        is_tcp = service.get("blackbox", {}).get("module") == "tcp_connect"

        if is_tcp:
            desired[name] = {
                "type": MonitorType.PORT,
                "name": name,
                "hostname": parsed.hostname,
                "port": parsed.port,
                "description": MANAGED_MARKER,
            }
        else:
            desired[name] = {
                "type": MonitorType.HTTP,
                "name": name,
                "url": url,
                "description": MANAGED_MARKER,
            }
    return desired


def sync(api, desired):
    existing = {m["name"]: m for m in api.get_monitors()}
    created = updated = deleted = unchanged = 0

    for name, spec in desired.items():
        current = existing.get(name)
        if current is None:
            api.add_monitor(**spec)
            created += 1
            print(f"  + created: {name}")
            continue

        # Compare only the fields we manage — leave interval, retries,
        # notifications, etc. alone if a human tweaked them by hand.
        changed = any(
            str(current.get(field)) != str(value)
            for field, value in spec.items()
            if field != "description"
        )
        if changed:
            api.edit_monitor(current["id"], **spec)
            updated += 1
            print(f"  ~ updated: {name}")
        else:
            unchanged += 1

    # Prune monitors this script created that no longer have a matching
    # service — never touch a monitor without our marker, so a
    # hand-created monitor is always left alone.
    for name, current in existing.items():
        if name in desired:
            continue
        if current.get("description") != MANAGED_MARKER:
            continue
        api.delete_monitor(current["id"])
        deleted += 1
        print(f"  - deleted: {name}")

    print(
        f"Uptime Kuma sync complete: {created} created, {updated} updated, "
        f"{deleted} deleted, {unchanged} unchanged"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--services-yaml", required=True)
    parser.add_argument("--url", required=True, help="Uptime Kuma base URL")
    parser.add_argument("--username", required=True)
    parser.add_argument("--password", required=True)
    args = parser.parse_args()

    services = load_services(args.services_yaml)
    desired = build_desired_monitors(services)

    with UptimeKumaApi(args.url, timeout=30) as api:
        api.login(args.username, args.password)
        sync(api, desired)


if __name__ == "__main__":
    main()
