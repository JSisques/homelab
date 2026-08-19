# Scripts

This directory contains utility scripts used to bootstrap, validate, generate, and operate the homelab.

Scripts should provide convenience and orchestration around the main infrastructure tools rather than replacing them.

Terraform, Ansible, Kubernetes, Helm, and Argo CD remain responsible for their respective domains.

## Structure

```text
scripts/
├── README.md
│
├── bootstrap/
│   └── bootstrap.sh        # not implemented yet
│
├── validation/
│   └── validate.sh
│
├── generation/
│   ├── README.md
│   ├── generate-homepage.sh
│   ├── generate-prometheus.sh
│   ├── generate-traefik.sh
│   ├── generate-cloudflared.sh
│   ├── generate-inventory.sh
│   └── generate-terraform-vars.sh
│
└── sync-uptime-kuma.py    # pushes config/services.yaml into a live Uptime Kuma over its API — not a local
                            # file transform like generation/, since Uptime Kuma has no config file of its own
                            # (see ansible/roles/uptime-kuma-sync/)
```

`utils/` (a `wait-for-service.sh` / `health-check.sh` pair) doesn't exist yet — it's a placeholder for future deploy tooling, not a current gap.

## Bootstrap

Bootstrap scripts are responsible for preparing a new homelab environment.

```bash
./scripts/bootstrap/bootstrap.sh
```

The long-term goal is to make the initial setup reproducible from a clean environment.

```text
Proxmox
   │
   ▼
Terraform
   │
   ▼
VMs / LXCs
   │
   ▼
Ansible
   │
   ▼
K3s / Docker / Services
   │
   ▼
Argo CD
```

## Validation

Validation scripts check the repository before changes are deployed.

```bash
./scripts/validation/validate.sh
```

Validation may include:

* YAML syntax
* Kubernetes manifests
* Kustomize
* Helm
* Terraform
* Ansible
* Docker Compose
* Secret detection

Validation should run locally and in CI.

## Configuration Generation

Some services require configuration formats that are different from the central homelab service model.

Generation scripts convert the central configuration into service-specific configuration.

```text
config/services.yaml
        │
        ├──────────────┐
        │              │
        ▼              ▼
 Homepage         Uptime Kuma
 config             monitors
 (generate-        (sync-uptime-kuma.py,
  homepage.sh)       ansible/roles/uptime-kuma-sync/)
```

Homepage's config is a static file `generate-homepage.sh` writes to disk (`services/homepage/config/services.yaml`), deployed like any other checked-in config. Uptime Kuma has no config file at all — everything lives in its own SQLite database — so `sync-uptime-kuma.py` pushes state into a *running* instance over its API instead of writing a file; see `ansible/roles/uptime-kuma-sync/` for why that makes it an Ansible-run script rather than a `make generate` step.

The generated configuration should be deterministic and reproducible.

Generated files should only be committed when there is a clear reason to do so.

## Utilities

The `utils/` directory contains small reusable scripts for common operational tasks.

Examples include:

* Waiting for services to become available
* Performing health checks
* Waiting for Kubernetes resources
* Checking network connectivity

Utilities should remain small and focused.

## Design Principles

### Keep Scripts Small

Scripts should solve one problem or orchestrate a well-defined workflow.

### Prefer Existing Tools

Do not reimplement functionality already provided by Terraform, Ansible, Kubernetes, Helm, or Argo CD.

### Idempotency

Scripts that modify infrastructure should be safe to execute multiple times.

### Fail Fast

Scripts should return a non-zero exit code when an operation fails.

### CI Compatible

Scripts should work both locally and inside GitHub Actions.

### No Secrets

Scripts must not contain credentials or other sensitive information.

Secrets should be provided through the repository's secret management system.

## Relationship With Other Components

```text
                     Git
                      │
                      ▼
                   Scripts
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
      Terraform     Ansible    Generators
          │           │           │
          ▼           ▼           ▼
      Proxmox       Hosts      Services
                      │
                      ▼
                     K3s
                      │
                      ▼
                   Argo CD
                      │
                      ▼
                 Applications
```

Scripts are orchestration and tooling around the infrastructure. They are not intended to become another infrastructure management layer.
