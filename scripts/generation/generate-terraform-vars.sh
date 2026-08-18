#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SOURCE="${ROOT_DIR}/config/hosts.yaml"
SERVICES_SOURCE="${ROOT_DIR}/config/services.yaml"
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

if [[ ! -f "${SERVICES_SOURCE}" ]]; then
    echo "Error: services configuration not found:"
    echo "  ${SERVICES_SOURCE}"
    exit 1
fi

source "${ROOT_DIR}/scripts/generation/lib.sh"

mkdir -p "${OUTPUT_DIR}"

echo "Generating Terraform variables..."

RESOLVED="$(resolve_addresses "${SOURCE}")"

# Maps each services.yaml key to its lowercased `category` (e.g.
# "grafana" -> "monitoring"), so a host's Proxmox tags can be derived from
# the generic categories of the services its roles match, instead of
# duplicating per-service names as tags.
# shellcheck disable=SC2016 # single quotes are intentional: this is a jq filter, not a shell expansion
CATEGORIES="$(yq -c '
  .services
  | to_entries
  | map({key: .key, value: (.value.category | ascii_downcase)})
  | from_entries
' "${SERVICES_SOURCE}")"

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
#
# A host's tags are the generic categories (from config/services.yaml,
# via $categories) of the services matched by its `role` list — not the
# role/service names themselves, and not `type` (lxc/vm is already visible
# on the resource itself). Roles with no matching service (e.g. "server",
# "worker") are dropped; a host left with no category at all falls back to
# "infrastructure" so it's never untagged.
# shellcheck disable=SC2016 # single quotes are intentional: this is a jq filter, not a shell expansion
yq --argjson resolved "${RESOLVED}" --argjson categories "${CATEGORIES}" '
  def host_tags: (
    [(.value.role // [])[] | $categories[.] // empty]
    | unique
    | sort
  ) as $cats | (if ($cats | length) == 0 then ["infrastructure"] else $cats end);

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
              vm_id: (.value.vmid // .value.octet),
              cores: .value.cpu,
              memory: .value.memory,
              disk: .value.disk,
              tags: (. | host_tags)
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
              vm_id: (.value.vmid // .value.octet),
              cpu: .value.cpu,
              memory: .value.memory,
              disk: .value.disk,
              ip: $resolved[.key],
              tags: (. | host_tags)
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
