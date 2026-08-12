#!/usr/bin/env bash
# Shared helpers for scripts/generation/*.sh. Source this file, don't run
# it directly:
#
#   source "${ROOT_DIR}/scripts/generation/lib.sh"

# Resolves every host in config/hosts.yaml to a full IPv4 address (or the
# literal string "TBD" for unconfirmed hosts) against the `network:`
# block's prefixes, and prints a single compact JSON object mapping host
# key to resolved address, e.g. {"monitoring": "192.168.1.20", ...}.
#
# Resolution order per host — see config/README.md:
#   1. address: TBD           -> "TBD"
#   2. address: <literal IP>  -> used as-is (an explicit override)
#   3. octet: <n>             -> network.<network // "lan">.prefix + "." + octet
#
# This is the single place that understands config/hosts.yaml's address
# schema — every generator resolves addresses through this, instead of
# each re-deriving `.value.address` on its own, so a network prefix
# change (config/hosts.yaml's `network:` block) only has to work here.
resolve_addresses() {
    local hosts_source="$1"

    # shellcheck disable=SC2016 # single quotes are intentional: this is a jq filter, not a shell expansion
    yq -c '
      (.network) as $net
      | .hosts
      | to_entries
      | map({
          key: .key,
          value: (
            .value as $h
            | if $h.address == "TBD" then "TBD"
              elif $h.address != null then $h.address
              elif $h.octet != null then
                ($net[$h.network // "lan"].prefix + "." + ($h.octet | tostring))
              else "TBD"
              end
          )
        })
      | from_entries
    ' "${hosts_source}"
}
