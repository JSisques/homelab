#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SOURCE="${ROOT_DIR}/config/hosts.yaml"
OUTPUT_DIR="${ROOT_DIR}/terraform/proxmox"
OUTPUT="${OUTPUT_DIR}/hosts.auto.tfvars.json"

if ! command -v yq >/dev/null 2>&1; then
    echo "Error: yq is required but was not found."
    echo "Install yq: https://github.com/kislyuk/yq"
    exit 1
fi

if [[ ! -f "${SOURCE}" ]]; then
    echo "Error: hosts configuration not found:"
    echo "  ${SOURCE}"
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "Generating Terraform variables..."

# shellcheck disable=SC2016 # single quotes are intentional: this is a jq filter, not a shell expansion
SKIPPED="$(yq -r '.hosts | to_entries[] | select(.value.type == "lxc" or .value.type == "vm") | select(.value.address == "TBD") | .key' "${SOURCE}")"
if [[ -n "${SKIPPED}" ]]; then
    echo "Warning: skipping hosts without a confirmed address (address: TBD):"
    while IFS= read -r host; do
        echo "  - ${host}"
    done <<<"${SKIPPED}"
fi

# shellcheck disable=SC2016 # single quotes are intentional: this is a jq filter, not a shell expansion
yq '
  .hosts as $hosts
  | {
      lxc_network: (
        $hosts
        | to_entries
        | map(select(.value.type == "lxc" and .value.address != "TBD"))
        | map({
            (.key): {
              ip: .value.address,
              cores: .value.cpu,
              memory: .value.memory,
              disk: .value.disk
            }
          })
        | (if length == 0 then {} else add end)
      ),
      vm_nodes: (
        $hosts
        | to_entries
        | map(select(.value.type == "vm" and .value.address != "TBD"))
        | map({
            (.key): {
              proxmox_node: (.value.proxmox_node // "pve"),
              cpu: .value.cpu,
              memory: .value.memory,
              disk: .value.disk,
              ip: .value.address
            }
          })
        | (if length == 0 then {} else add end)
      )
    }
' "${SOURCE}" > "${OUTPUT}"

echo ""
echo "Terraform variables generated:"
echo "  ${OUTPUT}"
echo ""
echo "This file is auto-loaded by Terraform (*.auto.tfvars.json) — no -var-file needed."
