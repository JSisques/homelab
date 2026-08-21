# Configuration Generation

This directory contains scripts that generate service-specific configuration from the central homelab configuration.

The goal is to maintain a single source of truth for service metadata while avoiding duplicated configuration across different services.

## Structure

```text
generation/
├── README.md
├── lib.sh
├── generate-homepage.sh
├── generate-prometheus.sh
├── generate-blackbox.sh
├── generate-traefik.sh
├── generate-cloudflared.sh
├── generate-inventory.sh
├── generate-terraform-vars.sh
└── tests/               # bats tests, see "Testing" below
```

`generate-uptime-kuma.sh` doesn't exist yet — Uptime Kuma has no config-as-code format to generate into, see `services/uptime-kuma/README.md`.

## Source of Truth

The central service inventory is located at:

```text
config/services.yaml
```

This file contains metadata about the services running in the homelab.

Example:

```yaml
services:
  grafana:
    name: Grafana
    category: Monitoring
    tier: internal
    url: http://192.168.0.209:3000
    icon: grafana.png

    homepage:
      enabled: true
      description: Monitoring dashboards

    uptime:
      enabled: true

    monitoring:
      enabled: true
```

Individual services can opt into different integrations.

## Architecture

```text
                     config/services.yaml
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             ▼                ▼                ▼
      generate-          generate-        generate-
      homepage.sh       uptime-kuma.sh    prometheus.sh
             │                │                │
             ▼                ▼                ▼
         Homepage        Uptime Kuma       Prometheus
         config             config           config
```

The central configuration describes **what services exist**.

The generation scripts translate that information into the configuration format required by each individual service.

## Why Generate Configuration?

Without a central configuration, every service would need to be configured independently.

For example:

```text
Homepage
├── Grafana
├── Prometheus
└── Kafka

Uptime Kuma
├── Grafana
├── Prometheus
└── Kafka

Prometheus
├── Grafana
├── Kafka
└── ...
```

This creates duplicated information and makes changes error-prone.

Instead:

```text
services.yaml
     │
     ├── Homepage
     ├── Uptime Kuma
     └── Prometheus
```

A service only needs to be added or modified in the central inventory.

## Scripts

### Homepage

```bash
./scripts/generation/generate-homepage.sh
```

Generates the Homepage service configuration.

Output:

```text
services/homepage/config/services.yaml
```

### Prometheus

```bash
./scripts/generation/generate-prometheus.sh
```

Generates Prometheus configuration: one scrape job per service that exposes native metrics, plus a `node-exporter`/`promtail` job scraping every `type: lxc`/`type: vm` host, plus a static `blackbox` job (targets read at runtime from `services/prometheus/blackbox-targets.yml`, generated separately by `generate-blackbox.sh`).

Source: `config/services.yaml`, `config/hosts.yaml`. Output: `services/prometheus/prometheus.yml`.

### blackbox_exporter

```bash
./scripts/generation/generate-blackbox.sh
```

Generates the blackbox_exporter target list: one target per service with a `blackbox: {enabled: true, port: <n>, scheme: http|https, module: <name>}` block in `config/services.yaml`, grouped by `module` (e.g. `http_2xx`, `http_2xx_insecure`) since blackbox_exporter's `file_sd_config` needs one `labels:` block per group. The backend LAN address comes from `config/hosts.yaml`, resolved the same way as Traefik — host key first, then `role`. `pbs` and `k3s-server` have minimal `config/services.yaml` entries (no `homepage`/`traefik`/`uptime` blocks) that exist solely to carry a `blackbox:` block, since those service names match their `config/hosts.yaml` host keys directly.

Source: `config/services.yaml`, `config/hosts.yaml`. Output: `services/prometheus/blackbox-targets.yml`.

### Traefik

```bash
./scripts/generation/generate-traefik.sh
```

Generates Traefik's dynamic routing config: one router + backend pair per `personal`/`public` tier exposure with a `traefik: {enabled: true, port: <n>}` block — either a service's own top-level tier, or nested under its `external:` alias (a service that's internal day-to-day but also has a remote-access alias, e.g. Jellyfin — see `config/README.md#external`). `internal` services never get a router here; Traefik only fronts what Cloudflared forwards to it. The router's hostname comes from the exposure's `url:`; the backend LAN address comes from `config/hosts.yaml`, resolved by matching host key first, then by `role`.

Source: `config/services.yaml`, `config/hosts.yaml`. Output: `services/traefik/dynamic/routes.yml`.

### Cloudflared

```bash
./scripts/generation/generate-cloudflared.sh
```

Generates the Cloudflare Tunnel ingress list: one `hostname` entry per `personal`/`public` tier exposure (same set as Traefik's, above), every one pointing at Traefik's LAN address — never straight at the backend. Traefik does the actual per-service routing from the same catalog. The `tunnel:` ID (a one-time manual value from `cloudflared tunnel create`, see `services/cloudflared/README.md`) is preserved across regenerations if already set, since it isn't `config/`-owned data.

Source: `config/services.yaml`, `config/hosts.yaml`. Output: `services/cloudflared/config.yml`.

### Ansible Inventory

```bash
./scripts/generation/generate-inventory.sh
```

Generates the Ansible inventory: one group per host and one per `role` value (e.g. `k3s` groups every Raspberry Pi together), plus an `all.vars` block (`lan_cidr`, `lan_gateway`) carrying `config/hosts.yaml`'s `network.lan` block into Ansible — roles that need the LAN subnet (e.g. `wireguard`'s `ALLOWEDIPS`) read it from there instead of hardcoding it.

Source: `config/hosts.yaml`. Output: `ansible/inventory/hosts.yml`.

### Terraform Variables

```bash
./scripts/generation/generate-terraform-vars.sh
```

Generates the `lxc_network` and `vm_nodes` Terraform variables from every `type: lxc` / `type: vm` host, plus `gateway`/`network_bridge`/`network_mask` from `config/hosts.yaml`'s `network.lan` block — addresses, Proxmox VMID (`vmid` or `octet`), sizing (`cpu`/`memory`/`disk`), and network config live in `config/hosts.yaml` only, never duplicated by hand in `terraform.tfvars`.

Source: `config/hosts.yaml`. Output: `terraform/proxmox/hosts.auto.tfvars.json` (auto-loaded by Terraform, no `-var-file` needed).

Hosts with `address: TBD` are skipped (with a warning) by every generator that resolves addresses.

### Shared Address Resolution

```text
scripts/generation/lib.sh
```

Not a generator itself — a `resolve_addresses()` helper, sourced by every script above, that turns `config/hosts.yaml`'s per-host `octet`/`network`/`address` fields into a flat `{host: ip}` JSON map against the `network:` block's prefixes. This is the one place that understands the address schema; see `config/README.md` for the resolution rules and `config/hosts.yaml`'s header comment.

## Requirements

The generation scripts are written in POSIX-compatible shell/Bash and use [`yq`](https://github.com/kislyuk/yq) — the Python/jq wrapper, **not** mikefarah's Go `yq` — for YAML processing, since they rely on jq filter syntax (`to_entries`, `group_by`, `sub()`, ...).

Install it with:

```bash
pip install yq
```

GitHub Actions runners ship mikefarah's `yq` by default, which is not compatible with these scripts. CI installs the correct one explicitly before running them.

The scripts should fail with a clear error message if required dependencies are missing.

## Design Principles

### Single Source of Truth

Service metadata should live in:

```text
config/services.yaml
```

Do not duplicate basic service information in multiple configuration files.

### Deterministic Output

Running a generation script multiple times with the same input should produce the same output.

```text
same input
    +
same script
    =
same output
```

### Idempotency

Generation scripts must be safe to run repeatedly.

They should replace or update generated configuration instead of appending duplicate entries.

### No Secrets

Generated configuration must not contain plaintext credentials, passwords, API keys, or tokens.

Secrets should be handled separately using the homelab's secret management strategy.

### Keep Service-Specific Configuration Local

Not every configuration option belongs in `config/services.yaml`.

The central configuration should contain common service metadata and integration settings.

Complex or service-specific configuration should remain in the corresponding service directory.

For example:

```text
config/services.yaml
        │
        │ common metadata
        ▼
generate-homepage.sh
        │
        ▼
services/homepage/config/
        │
        ├── services.yaml
        ├── settings.yaml
        └── widgets.yaml
```

The generator should not attempt to become a replacement for Homepage's entire configuration system.

## Generated Files

Generated files should be clearly identifiable.

When possible, generated files should include a comment such as:

```yaml
# This file is generated.
# Do not edit manually.
# Source: config/services.yaml
```

Manual changes to generated files may be overwritten the next time the generator runs.

## Local Workflow

A typical workflow is:

```text
1. Edit config/services.yaml
          │
          ▼
2. Run generation scripts
          │
          ▼
3. Review generated files
          │
          ▼
4. Validate configuration
          │
          ▼
5. Commit changes
          │
          ▼
6. Deploy
```

For example:

```bash
./scripts/generation/generate-homepage.sh

git diff

./scripts/validation/validate.sh
```

## CI/CD

Generation scripts should eventually be executed by GitHub Actions.

A CI workflow can:

1. Validate the source configuration.
2. Run all generation scripts.
3. Check whether generated files are up to date.
4. Fail if generated files differ from the committed versions.

This prevents configuration drift between the central service inventory and generated service configuration.

## Adding a New Generator

When adding a new integration:

```text
scripts/generation/
└── generate-example.sh
```

The script should:

1. Read from `config/services.yaml`.
2. Validate required fields.
3. Generate deterministic output.
4. Never contain secrets.
5. Fail clearly when input is invalid.
6. Document its generated files.
7. Be added to the validation/CI workflow.

Example:

```bash
./scripts/generation/generate-example.sh
```

## Testing

`tests/` has [bats](https://github.com/bats-core/bats-core) tests:

- `lib.bats` — unit tests for `lib.sh`'s `resolve_addresses()` (the TBD /
  literal / octet+prefix resolution order), against the fixture
  `tests/fixtures/lib/hosts.yaml`.
- `generators.bats` — one snapshot test per `generate-*.sh`: runs the
  script in an isolated sandbox against `tests/fixtures/config/` and
  diffs the result against `tests/fixtures/expected/`.

Run them with:

```bash
bats scripts/generation/tests
```

They also run in CI (`.github/workflows/ci.yaml`, `generation-tests` job)
and as part of `scripts/validation/validate.sh` / `make validate`.

If you change a generator's output on purpose, regenerate its snapshot:
run the script against `tests/fixtures/config/` in a scratch directory,
confirm the new output is correct, then copy it over the matching file in
`tests/fixtures/expected/`.

## Important Rule

The generation layer is intentionally lightweight.

It should **transform configuration**, not manage infrastructure.

Infrastructure management belongs to:

```text
Terraform → Proxmox infrastructure
Ansible   → Host configuration
Kubernetes → Kubernetes workloads
Argo CD   → GitOps reconciliation
```

The generation scripts only connect the central homelab configuration with services that require generated configuration.
