# SonarQube

SonarQube (Community Build) is the homelab's static code analysis server — it runs quality/security scans on pull requests for this repo and other personal repos, and reports the results back to GitHub.

## Responsibilities

- Runs code analysis submitted by `sonar-scanner` (invoked from CI, see `.github/workflows/ci.yaml`).
- Stores analysis history, quality gates, and project configuration in its own PostgreSQL database.
- Serves a web UI for browsing results and issuing analysis tokens.

SonarQube is deployed as a Docker Compose application inside a dedicated LXC container, same as `n8n` and `jellyfin`.

## Directory Structure

```text
services/sonarqube/
├── README.md
├── compose.yaml
└── .env.example
```

## Architecture

```text
                  sonarqube LXC
                        │
                 Docker Compose
                        │
              ┌─────────┴─────────┐
              │                   │
              ▼                   ▼
          SonarQube           PostgreSQL
              │                   │
              ▼                   ▼
      Analysis results,     Persistent data
      quality gates
```

## Networking

SonarQube is exposed two ways, same pattern as `jellyfin`:

- **LAN**: `https://sonarqube.home.arpa` through Traefik — for browsing results locally. No auth in front of it beyond being on the LAN/WireGuard; SonarQube enforces its own login.
- **Remote**: `https://sonarqube.jsisques.net` through the existing Cloudflare Tunnel (`services/cloudflared/config.yml`) — this is the path GitHub Actions (and any other personal repo's CI) uses to reach it. This is the personal-apps ingress (`jsisques.net`), not the public `sisqueslabs.com` one.

The internal application port is `9000` in both cases.

### Why no Cloudflare Access in front of it

Every other `personal`-tier service in this homelab relies on the app's own login instead of an extra Access layer, and SonarQube does force login by default (no anonymous access). Cloudflare Access could still be added later to protect the browser UI specifically, but it wasn't wired up here: Access enforces itself via extra HTTP headers a client must send on every request, and it's not confirmed whether `sonar-scanner`/`SonarSource/sonarqube-scan-action` support injecting those — getting it wrong would silently break every CI run. If you want that extra layer, set it up manually in the Cloudflare dashboard for `sonarqube.jsisques.net` and verify CI still authenticates before relying on it.

## Persistence

| Path                         | Backing                              | Contents                                  |
| ----------------------------- | -------------------------------------| ------------------------------------------ |
| `/opt/sonarqube/data`         | Docker named volume `sonarqube-data` | Elasticsearch index, analysis state       |
| `/opt/sonarqube/extensions`   | Docker named volume `sonarqube-extensions` | Installed plugins                   |
| `/opt/sonarqube/logs`         | Docker named volume `sonarqube-logs` | Application logs                          |
| `/var/lib/postgresql/data`    | Docker named volume `postgres-data`  | Projects, quality gates, users, tokens    |

`sonarqube-data` and `postgres-data` are the two that matter for backups — `sonarqube-extensions`/`sonarqube-logs` are regenerable.

## Database

PostgreSQL is required by SonarQube (the bundled H2 database is for evaluation only, not production use). Configuration is supplied through environment variables — see `.env.example` for the template. Secrets must never be committed to Git.

## Kernel requirements (Elasticsearch)

SonarQube bundles Elasticsearch, which needs:

- `vm.max_map_count >= 524288` — a host-wide kernel setting, **not** namespaced per-container, so it can't be set via Compose `sysctls:`. It's applied on the LXC host by `ansible/roles/sonarqube/tasks/main.yaml` (`ansible.posix.sysctl`).
- Raised `nofile`/`nproc` limits — these *are* process-scoped, so they're set directly on the `sonarqube` service in `compose.yaml` via `ulimits:`.

If the LXC ever becomes unprivileged in a way that blocks setting `vm.max_map_count` from inside it, the fallback is setting it on the Proxmox host itself (`/etc/sysctl.d/`) — LXC containers share the host kernel, so a host-level sysctl covers every container on it.

## CI Integration

`.github/workflows/ci.yaml` runs `SonarSource/sonarqube-scan-action` against `SONAR_HOST_URL` (`https://sonarqube.jsisques.net`) using a `SONAR_TOKEN` repo secret. The token is a project-scoped analysis token generated from the SonarQube UI after first login — it isn't something Terraform/Ansible can provision, since it only exists once the server is running for the first time.

## Resource sizing

2 vCPU / 4GB RAM, 20GB disk — SonarQube + its bundled Elasticsearch are the heavier pieces (JVM baseline plus index memory), with Postgres alongside in the same compose stack. Revisit (`config/hosts.yaml`) if analysis runs start queueing or feel slow under load from multiple repos.

## Deployment

Terraform creates the LXC:

```text
terraform/proxmox/lxc.tf
```

The LXC is configured by Ansible:

```text
ansible/
├── playbooks/
│   └── sonarqube.yaml
└── roles/
    └── sonarqube/
```

```bash
make deploy-sonarqube
```

## Local Development

```bash
cd services/sonarqube

cp .env.example .env

docker compose up -d
```

Then open `http://localhost:9000` (default credentials `admin`/`admin`, SonarQube forces a password change on first login).

## Monitoring

Community Build has no native Prometheus `/metrics` endpoint (that's an Enterprise-tier feature), so it's probed by `blackbox_exporter` for up/down + latency instead (see `config/services.yaml`, `services/blackbox-exporter/README.md`) and added to Uptime Kuma as an HTTP monitor on port `9000`.

## Source of Truth

Terraform manages the LXC (existence, CPU, memory, disk, network). Ansible manages host configuration, the `vm.max_map_count` kernel setting, and Docker Compose deployment. This directory manages the Compose definition and application configuration.
