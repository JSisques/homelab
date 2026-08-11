#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SOURCE="${ROOT_DIR}/config/services.yaml"
OUTPUT_DIR="${ROOT_DIR}/services/prometheus"
OUTPUT="${OUTPUT_DIR}/prometheus.yml"

if ! command -v yq >/dev/null 2>&1; then
    echo "Error: yq is required but was not found."
    echo "Install yq: https://github.com/mikefarah/yq"
    exit 1
fi

if [[ ! -f "${SOURCE}" ]]; then
    echo "Error: services configuration not found:"
    echo "  ${SOURCE}"
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "Generating Prometheus configuration..."

cat > "${OUTPUT}" <<'EOF'
# This file is generated.
# Do not edit manually.
# Source: config/services.yaml

global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
EOF

yq -r '
  .services
  | to_entries[]
  | select(.value.monitoring.enabled == true)
  | select(.value.monitoring.type == "prometheus")
  | (.value.monitoring.endpoint | sub("^https?://"; "") | sub("/metrics$"; "") | sub("/pve$"; "")) as $target
  | "  - job_name: \"\(.key)\"\n    static_configs:\n      - targets:\n          - \"\($target)\""
' "${SOURCE}" >> "${OUTPUT}"

echo ""
echo "Prometheus configuration generated:"
echo "  ${OUTPUT}"
