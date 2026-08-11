# Configuration Generation

This directory contains scripts that generate service-specific configuration from the central homelab configuration.

The goal is to maintain a single source of truth for service metadata while avoiding duplicated configuration across different services.

## Structure

```text
generation/
├── README.md
├── generate-homepage.sh
├── generate-uptime-kuma.sh
└── generate-prometheus.sh
```

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
    url: https://grafana.home.arpa
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

### Uptime Kuma

```bash
./scripts/generation/generate-uptime-kuma.sh
```

Generates the configuration required to monitor services through Uptime Kuma.

### Prometheus

```bash
./scripts/generation/generate-prometheus.sh
```

Generates Prometheus configuration based on the services that expose metrics.

## Requirements

The generation scripts are written in POSIX-compatible shell/Bash and use `yq` for YAML processing.

Install `yq` before running the scripts.

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
