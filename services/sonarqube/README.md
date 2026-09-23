# sonarqube

[SonarQube Community Build](https://www.sonarsource.com/products/sonarqube/) — a self-hosted code-quality and static-analysis server. Runs on its own dedicated Proxmox VM (`config/hosts.yaml`, octet 223) rather than an LXC or the shared `k3s-server`, because it requires `vm.max_map_count=524288` — a host kernel parameter that isn't namespaced and can't be set from inside an LXC.

## Directory Structure

```text
services/sonarqube/
├── README.md
└── compose.yml
```

## Docker Compose

`services/sonarqube/compose.yml` defines two services:

- `sonarqube` — the application, `sonarqube:26.9.0.129388-community` (explicit tag, never `:community` or `:latest` — this is a third-party image, no `pull_policy: always`), listening on `9000`. `read_only: true` plus `tmpfs: [/tmp]` (upstream-recommended hardening), named volumes for `data`/`extensions`/`logs`/`temp`, and `ulimits: {nofile: 131072, nproc: 8192}` per [SonarQube's host requirements](https://docs.sonarsource.com/sonarqube-community-build/server-installation/pre-installation/linux).
- `db` — `postgres:17`, a dedicated sidecar (no shared fleet Postgres). `pg_isready` healthcheck; `sonarqube` waits for `condition: service_healthy` before starting.

## Required Environment Variables

Rendered into `.env` (mode `0600`) by the `sonarqube` Ansible role's `templates/env.j2`, from a single secret (`sonarqube_jdbc_password`, Makefile: `SONARQUBE_JDBC_PASSWORD`):

| Variable | Value |
|----------|-------|
| `POSTGRES_DB` | `sonar` |
| `POSTGRES_USER` | `sonar` |
| `POSTGRES_PASSWORD` | `sonarqube_jdbc_password` |
| `SONAR_JDBC_URL` | `jdbc:postgresql://db:5432/sonar` |
| `SONAR_JDBC_USERNAME` | `sonar` |
| `SONAR_JDBC_PASSWORD` | `sonarqube_jdbc_password` |

The role's `tasks/main.yaml` hard-fails (`ansible.builtin.assert`) before templating `.env` or starting Compose if `sonarqube_jdbc_password` is empty or still `changeme`.

## First-Login Hardening

SonarQube ships with a default `admin`/`admin` login. **Immediately after the first successful deploy**, log in at `http://192.168.0.223:9000` with `admin`/`admin` and rotate the password (Administration → Security → Users, or the forced first-login prompt). Leaving the default credentials in place on the LAN is the primary operational risk of this service — see the proposal's Risks table.

## Networking

`tier: internal` (`config/services.yaml`) — no domain, no Traefik/Cloudflare route, reached directly by LAN `IP:port`:

```text
http://192.168.0.223:9000
```

Health is checked via `GET /api/system/status` (`"status":"UP"`), probed by `blackbox_exporter`'s `http_status_up` module rather than a bare `http_2xx` — HTTP 200 alone does not mean the service has finished starting. See `services/blackbox-exporter/README.md`.

## Guest Kernel Tuning

The `sonarqube` Ansible role sets `vm.max_map_count=524288` and `fs.file-max>=131072` inside the VM before starting Compose (`/etc/sysctl.d/99-sonarqube.conf`, persisted across reboots). This only touches the guest — the Proxmox host's own kernel is never modified. See `ansible/roles/sonarqube/README.md`.

## Rollback

1. Revert the commit, then run `make generate`.
2. Destroy VM 223 (`terraform apply` after the revert, or `qm destroy 223` on the Proxmox host directly).
3. All application state (SonarQube data, Postgres) lives in the VM's own Docker volumes and is removed with the VM — no other stack is affected.

## Local Development

```bash
cd services/sonarqube
export POSTGRES_DB=sonar POSTGRES_USER=sonar POSTGRES_PASSWORD=change-me
export SONAR_JDBC_URL=jdbc:postgresql://db:5432/sonar SONAR_JDBC_USERNAME=sonar SONAR_JDBC_PASSWORD=change-me
docker compose up -d
```

## Source of Truth

Terraform manages: VM existence, CPU, memory, disk, network (sized from `config/hosts.yaml`).

Ansible manages: guest kernel tuning, Docker Compose deployment, secret injection.

This directory manages: Docker Compose configuration, non-secret application configuration, service documentation.
