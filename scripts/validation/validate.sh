#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}" || exit 1

FAILED=0

section() {
    echo ""
    echo "== $1 =="
}

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "skip: '$1' not installed, skipping this section"
        return 1
    fi
    return 0
}

section "AdGuard Home seed config"
./scripts/validation/test-adguard-home-config.sh || FAILED=1

section "YAML (yamllint)"
if require yamllint; then
    yamllint . || FAILED=1
fi

section "Shell scripts (shellcheck)"
if require shellcheck; then
    find scripts -type f -name "*.sh" -print0 | xargs -0 -r shellcheck || FAILED=1
fi

section "Terraform"
if require terraform; then
    (cd terraform/proxmox && terraform fmt -check -recursive) || FAILED=1
    (cd terraform/proxmox && terraform init -backend=false -input=false >/dev/null && terraform validate) || FAILED=1
fi

section "Ansible (ansible-lint)"
if require ansible-lint; then
    (cd ansible && ansible-lint .) || FAILED=1
fi

section "Docker Compose"
if require docker; then
    while IFS= read -r file; do
        echo "Validating ${file}"
        docker compose -f "${file}" config --quiet || FAILED=1
    done < <(find services \( -name "compose.yml" -o -name "compose.yaml" -o -name "docker-compose.yml" \))
fi

section "Generated files up to date"
if require yq; then
    chmod +x scripts/generation/*.sh
    ./scripts/generation/generate-homepage.sh >/dev/null
    ./scripts/generation/generate-prometheus.sh >/dev/null
    ./scripts/generation/generate-inventory.sh >/dev/null
    ./scripts/generation/generate-terraform-vars.sh >/dev/null

    if ! git diff --exit-code -- \
        services/homepage/config/services.yaml \
        services/prometheus/prometheus.yml \
        ansible/inventory/hosts.yml \
        terraform/proxmox/hosts.auto.tfvars.json; then
        echo "Generated files are out of date with config/. Review the diff above, then commit it."
        FAILED=1
    fi
fi

if [[ "${FAILED}" -ne 0 ]]; then
    echo ""
    echo "Validation FAILED."
    exit 1
fi

echo ""
echo "All validations passed."
