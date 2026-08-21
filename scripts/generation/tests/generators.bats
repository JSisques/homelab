#!/usr/bin/env bats
# Snapshot tests for scripts/generation/generate-*.sh: run each generator
# against a small fixture config/ in an isolated sandbox and diff its
# output against a committed expected file. Catches logic regressions
# that CI's plain "regenerate and diff against the real repo" check
# cannot: that check only proves the committed output matches what the
# generator produces today, not that today's output is correct.
#
# Regenerate a snapshot deliberately (after confirming the new output is
# right) with, e.g.:
#   ./scripts/generation/generate-homepage.sh   # against a sandbox
#   cp <sandbox output> scripts/generation/tests/fixtures/expected/<name>

load helpers

setup() {
    ROOT_DIR="$(repo_root)"
    EXPECTED="${ROOT_DIR}/scripts/generation/tests/fixtures/expected"
    make_sandbox
}

teardown() {
    clean_sandbox
}

@test "generate-homepage.sh matches the expected snapshot" {
    "${SANDBOX}/scripts/generation/generate-homepage.sh"
    diff "${EXPECTED}/homepage-services.yaml" "${SANDBOX}/services/homepage/config/services.yaml"
}

@test "generate-prometheus.sh matches the expected snapshot" {
    "${SANDBOX}/scripts/generation/generate-prometheus.sh"
    diff "${EXPECTED}/prometheus.yml" "${SANDBOX}/services/prometheus/prometheus.yml"
}

@test "generate-blackbox.sh matches the expected snapshot" {
    "${SANDBOX}/scripts/generation/generate-blackbox.sh"
    diff "${EXPECTED}/blackbox-targets.yml" "${SANDBOX}/services/prometheus/blackbox-targets.yml"
}

@test "generate-traefik.sh matches the expected snapshot" {
    "${SANDBOX}/scripts/generation/generate-traefik.sh"
    diff "${EXPECTED}/routes.yml" "${SANDBOX}/services/traefik/dynamic/routes.yml"
}

@test "generate-cloudflared.sh matches the expected snapshot" {
    "${SANDBOX}/scripts/generation/generate-cloudflared.sh"
    diff "${EXPECTED}/cloudflared-config.yml" "${SANDBOX}/services/cloudflared/config.yml"
}

@test "generate-inventory.sh matches the expected snapshot and skips TBD hosts" {
    run "${SANDBOX}/scripts/generation/generate-inventory.sh"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"skipping hosts without a confirmed address"* ]]
    [[ "${output}" == *"unconfirmed"* ]]
    diff "${EXPECTED}/inventory-hosts.yml" "${SANDBOX}/ansible/inventory/hosts.yml"
}

@test "generate-terraform-vars.sh matches the expected snapshot" {
    "${SANDBOX}/scripts/generation/generate-terraform-vars.sh"
    diff "${EXPECTED}/terraform-vars.json" "${SANDBOX}/terraform/proxmox/hosts.auto.tfvars.json"
}
