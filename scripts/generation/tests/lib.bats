#!/usr/bin/env bats
# Unit tests for scripts/generation/lib.sh's resolve_addresses(), the
# single place config/hosts.yaml's address resolution order (TBD ->
# literal -> octet+prefix -> TBD) is implemented. See
# config/README.md#address-resolution.

load helpers

setup() {
    ROOT_DIR="$(repo_root)"
    source "${ROOT_DIR}/scripts/generation/lib.sh"
    FIXTURE="${ROOT_DIR}/scripts/generation/tests/fixtures/lib/hosts.yaml"
}

resolved() {
    resolve_addresses "${FIXTURE}" | yq -r --arg k "$1" '.[$k]'
}

@test "address: TBD stays TBD" {
    [ "$(resolved tbd-host)" = "TBD" ]
}

@test "a literal address overrides octet" {
    [ "$(resolved literal-host)" = "10.0.0.5" ]
}

@test "octet resolves against the default (lan) network prefix" {
    [ "$(resolved lan-octet-host)" = "192.168.0.42" ]
}

@test "octet resolves against an explicit non-lan network prefix" {
    [ "$(resolved iot-octet-host)" = "192.168.50.7" ]
}

@test "a host with neither address nor octet falls back to TBD" {
    [ "$(resolved bare-host)" = "TBD" ]
}

@test "produces one JSON object covering every host" {
    local count
    count="$(resolve_addresses "${FIXTURE}" | yq -r 'keys | length')"
    [ "${count}" = "5" ]
}
