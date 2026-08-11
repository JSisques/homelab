#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SOURCE="${ROOT_DIR}/config/services.yaml"
OUTPUT_DIR="${ROOT_DIR}/services/homepage/config"
OUTPUT="${OUTPUT_DIR}/services.yaml"

if ! command -v yq >/dev/null 2>&1; then
    echo "Error: yq is required but was not found."
    echo "Install yq from https://github.com/mikefarah/yq"
    exit 1
fi

if [[ ! -f "${SOURCE}" ]]; then
    echo "Error: services configuration not found:"
    echo "  ${SOURCE}"
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "Generating Homepage configuration..."

yq -y '
  .services
  | to_entries
  | map(select(.value.homepage.enabled == true))
  | group_by(.value.category)
  | map(
      .[0].value.category as $category
      | {
          ($category): (
            map({
              (.value.name): (
                {
                  href: .value.url,
                  icon: (.value.icon // null),
                  description: (.value.homepage.description // null)
                }
                | with_entries(select(.value != null))
              )
            })
            | add
          )
        }
    )
  | add
' "${SOURCE}" > "${OUTPUT}"

echo ""
echo "Homepage configuration generated:"
echo "  ${OUTPUT}"