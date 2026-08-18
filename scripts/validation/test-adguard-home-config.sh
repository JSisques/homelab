#!/usr/bin/env bash
# Assert the AdGuard Home seed template binds the UI on :80 and rewrites
# *.home.arpa to Traefik's address (injected by Ansible, not hardcoded).

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
    "adguard_home_password_bcrypt" \
    "adguard_home_rewrite_domain" \
    "adguard_home_rewrite_answer" \
    "rewrites:"; do
    if ! grep -q -F "${needle}" "${TEMPLATE}"; then
        echo "FAIL: template missing ${needle}"
        exit 1
    fi
done

if grep -q '192.168.0.204' "${TEMPLATE}"; then
    echo "FAIL: Traefik address is hardcoded; use adguard_home_rewrite_answer"
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
    adguard_home_rewrite_domain="*.home.arpa",
    adguard_home_rewrite_answer="192.168.0.204",
)

if "*.home.arpa" not in rendered or "192.168.0.204" not in rendered:
    print("FAIL: rendered config missing *.home.arpa rewrite to Traefik")
    sys.exit(1)
if "0.0.0.0:80" not in rendered:
    print("FAIL: UI is not bound to :80")
    sys.exit(1)

print("ok: AdGuard Home seed config rewrites *.home.arpa to Traefik")
PY
