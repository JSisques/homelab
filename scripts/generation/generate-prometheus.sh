#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SERVICES_SOURCE="${ROOT_DIR}/config/services.yaml"
HOSTS_SOURCE="${ROOT_DIR}/config/hosts.yaml"
OUTPUT_DIR="${ROOT_DIR}/services/prometheus"
OUTPUT="${OUTPUT_DIR}/prometheus.yml"

if ! command -v yq >/dev/null 2>&1; then
    echo "Error: yq is required but was not found."
    echo "Install yq: https://github.com/kislyuk/yq"
    exit 1
fi

if [[ ! -f "${SERVICES_SOURCE}" ]]; then
    echo "Error: services configuration not found:"
    echo "  ${SERVICES_SOURCE}"
    exit 1
fi

if [[ ! -f "${HOSTS_SOURCE}" ]]; then
    echo "Error: hosts configuration not found:"
    echo "  ${HOSTS_SOURCE}"
    exit 1
fi

source "${ROOT_DIR}/scripts/generation/lib.sh"

mkdir -p "${OUTPUT_DIR}"

echo "Generating Prometheus configuration..."

cat > "${OUTPUT}" <<'EOF'
# This file is generated.
# Do not edit manually.
# Source: config/services.yaml, config/hosts.yaml

global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

rule_files:
  - /etc/prometheus/alerts.yml

scrape_configs:
EOF

# Per-service metrics, declared in config/services.yaml. Each target gets
# an explicit `instance` label set to the service key, overriding
# Prometheus's default of the raw "IP:port" — otherwise every dashboard
# and query has to translate IPs back to service names by hand.
# shellcheck disable=SC2016 # single quotes are intentional: this is a jq filter, not a shell expansion
yq -r '
  .services
  | to_entries[]
  | select(.value.monitoring.enabled == true)
  | select(.value.monitoring.type == "prometheus")
  | (.value.monitoring.endpoint | sub("^https?://"; "") | sub("/metrics$"; "") | sub("/pve$"; "")) as $target
  | "  - job_name: \"\(.key)\"\n    static_configs:\n      - targets:\n          - \"\($target)\"\n        labels:\n          instance: \"\(.key)\""
' "${SERVICES_SOURCE}" >> "${OUTPUT}"

# Host-level agents (node-exporter, promtail) run on every LXC/VM as a
# mandatory Ansible baseline (see ansible/README.md) regardless of which
# application is deployed there, so they're scraped from config/hosts.yaml
# directly rather than from a per-service monitoring block. Same
# `instance` labeling as above — one static_configs entry per host (rather
# than one entry sharing a target list) so each can carry its own label.
RESOLVED="$(resolve_addresses "${HOSTS_SOURCE}")"

# shellcheck disable=SC2016 # single quotes are intentional: this is a jq filter, not a shell expansion
HOST_ENTRIES="$(yq -r --argjson resolved "${RESOLVED}" '
  .hosts
  | to_entries[]
  | select(.value.type == "lxc" or .value.type == "vm")
  | select($resolved[.key] != "TBD")
  | "\(.key) \($resolved[.key])"
' "${HOSTS_SOURCE}")"

if [[ -n "${HOST_ENTRIES}" ]]; then
    {
        echo "  - job_name: \"node-exporter\""
        echo "    static_configs:"
        while IFS=' ' read -r name ip; do
            echo "      - targets:"
            echo "          - \"${ip}:9100\""
            echo "        labels:"
            echo "          instance: \"${name}\""
        done <<<"${HOST_ENTRIES}"

        echo "  - job_name: \"promtail\""
        echo "    static_configs:"
        while IFS=' ' read -r name ip; do
            echo "      - targets:"
            echo "          - \"${ip}:9080\""
            echo "        labels:"
            echo "          instance: \"${name}\""
        done <<<"${HOST_ENTRIES}"
    } >> "${OUTPUT}"
fi

# Services with no native /metrics endpoint (a static tools page, a DNS
# server with no Prometheus support, ...) still get basic up/down +
# latency via blackbox_exporter. Targets live in blackbox-targets.yml,
# generated separately by generate-blackbox.sh from each service's
# `blackbox:` block, so adding one doesn't require touching this script —
# see services/blackbox-exporter/README.md.
cat >> "${OUTPUT}" <<'EOF'
  - job_name: "blackbox"
    metrics_path: /probe
    file_sd_configs:
      - files:
          - /etc/prometheus/blackbox-targets.yml
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - source_labels: [module]
        target_label: __param_module
      - target_label: __address__
        replacement: blackbox-exporter:9115
EOF

echo ""
echo "Prometheus configuration generated:"
echo "  ${OUTPUT}"
