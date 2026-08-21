# Shared setup helpers for scripts/generation/tests/*.bats.
# `load helpers` (bats resolves the .bash suffix) makes these available in
# a test file's setup()/teardown().

repo_root() {
    cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd
}

# Copies scripts/generation/ and the generator fixtures into an isolated
# temp directory so each generate-*.sh resolves its own ROOT_DIR (derived
# from its own path) to the sandbox instead of the real repo — no risk of
# a test overwriting a real generated file.
make_sandbox() {
    local root
    root="$(repo_root)"

    SANDBOX="$(mktemp -d)"
    cp -r "${root}/scripts" "${SANDBOX}/scripts"
    mkdir -p "${SANDBOX}/config"
    cp "${root}/scripts/generation/tests/fixtures/config/hosts.yaml" "${SANDBOX}/config/hosts.yaml"
    cp "${root}/scripts/generation/tests/fixtures/config/services.yaml" "${SANDBOX}/config/services.yaml"
}

clean_sandbox() {
    [[ -n "${SANDBOX:-}" ]] && rm -rf "${SANDBOX}"
}
