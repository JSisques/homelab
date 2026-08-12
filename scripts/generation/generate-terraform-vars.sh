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

source "${ROOT_DIR}/scripts/generation/lib.sh"

mkdir -p "${OUTPUT_DIR}"

echo "Generating Terraform variables..."

RESOLVED="$(resolve_addresses "${SOURCE}")"

# shellcheck disable=SC2016 # single quotes are intentional: this is a jq filter, not a shell expansion
SKIPPED="$(yq -r --argjson resolved "${RESOLVED}" '
  .hosts | to_entries[]
  | select(.value.type == "lxc" or .value.type == "vm")
  | select($resolved[.key] == "TBD")
  | .key
' "${SOURCE}")"
if [[ -n "${SKIPPED}" ]]; then
    echo "Warning: skipping hosts without a confirmed address (address: TBD):"
    while IFS= read -r host; do
        echo "  - ${host}"
    done <<<"${SKIPPED}"
fi

# gateway/network_bridge/network_mask come from the network.lan block in
# config/hosts.yaml — terraform.tfvars no longer sets gateway/
# network_bridge by hand, see terraform/proxmox/terraform.tfvars.example.
# shellcheck disable=SC2016 # single quotes are intentional: this is a jq filter, not a shell expansion
yq --argjson resolved "${RESOLVED}" '
  .hosts as $hosts
  | .network as $net
  | {
      lxc_network: (
        $hosts
        | to_entries
        | map(select(.value.type == "lxc" and $resolved[.key] != "TBD"))
        | map({
            (.key): {
              ip: $resolved[.key],
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
        | map(select(.value.type == "vm" and $resolved[.key] != "TBD"))
        | map({
            (.key): {
              proxmox_node: (.value.proxmox_node // "pve"),
              cpu: .value.cpu,
              memory: .value.memory,
              disk: .value.disk,
              ip: $resolved[.key]
            }
          })
        | (if length == 0 then {} else add end)
      ),
      gateway: $net.lan.gateway,
      network_bridge: $net.lan.bridge,
      network_mask: $net.lan.mask
    }
' "${SOURCE}" > "${OUTPUT}"

echo ""
echo "Terraform variables generated:"
echo "  ${OUTPUT}"
echo ""
echo "This file is auto-loaded by Terraform (*.auto.tfvars.json) — no -var-file needed."
