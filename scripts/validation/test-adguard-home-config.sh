#!/usr/bin/env bash
# Assert the AdGuard Home seed template binds the UI on :80 and stays a
# plain DNS/ad-blocking resolver — no domain rewrite. Internal services are
# plain LAN IP:port (see config/README.md#tier); there is no *.home.arpa
# (or any other) internal domain for AdGuard to rewrite.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="${ROOT_DIR}/ansible/roles/adguard-home/templates/AdGuardHome.yaml.j2"

if [[ ! -f "${TEMPLATE}" ]]; then
    echo "FAIL: missing ${TEMPLATE}"
    exit 1
fi

for needle in \
    "address: 0.0.0.0:80" \
    "adguard_home_username" \
    "adguard_home_password_bcrypt"; do
    if ! grep -q -F "${needle}" "${TEMPLATE}"; then
        echo "FAIL: template missing ${needle}"
        exit 1
    fi
done

if grep -q -E "rewrites:|home\.arpa|adguard_home_rewrite" "${TEMPLATE}"; then
    echo "FAIL: template still has a domain rewrite; internal services are plain LAN IP:port, AdGuard should not rewrite any domain"
    exit 1
fi

python3 - "${TEMPLATE}" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")

try:
    from jinja2 import Template
except ImportError:
    print("ok: template placeholders present (jinja2 not installed, skip render)")
    sys.exit(0)

rendered = Template(text).render(
    adguard_home_username="admin",
    adguard_home_password_bcrypt="$2b$10$examplehash",
)

if "0.0.0.0:80" not in rendered:
    print("FAIL: UI is not bound to :80")
    sys.exit(1)

print("ok: AdGuard Home seed config is a plain DNS/ad-blocking resolver, no domain rewrite")
PY
