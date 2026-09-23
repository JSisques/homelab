# sonarqube

Deploys the `services/sonarqube/` Docker Compose stack (SonarQube Community Build + Postgres) to the dedicated `sonarqube` VM, after tuning the guest kernel parameters SonarQube's bundled Elasticsearch requires.

## Guest Kernel Tuning

SonarQube bundles an embedded Elasticsearch, which needs `vm.max_map_count>=524288` — a kernel parameter that is not namespaced, so it cannot be set from inside an LXC (this is exactly why this service gets a dedicated VM instead — see `services/sonarqube/README.md`). Two `ansible.posix.sysctl` tasks run before Compose starts, both persisted to `/etc/sysctl.d/99-sonarqube.conf` (survives a reboot):

- `vm.max_map_count = 524288`
- `fs.file-max = 131072`

Both apply only inside the `sonarqube` VM's own kernel namespace — the Proxmox host's own sysctl values are never touched.

## Required Variables

| Variable | Default | Description |
|----------|---------|--------------|
| `sonarqube_app_dir` | `/opt/sonarqube` | Deploy directory on the guest |
| `sonarqube_postgres_db` | `sonar` | Postgres database name |
| `sonarqube_postgres_user` | `sonar` | Postgres user |
| `sonarqube_jdbc_password` | `""` (must be overridden) | Used as both `POSTGRES_PASSWORD` and `SONAR_JDBC_PASSWORD`. Provide via Ansible Vault / CI secrets — never commit a real value. |

The role hard-fails (`ansible.builtin.assert`) before templating `.env` or starting Compose if `sonarqube_jdbc_password` is empty or the literal `changeme`.

## Deployment Flow

```text
assert secret set
       │
       ▼
sysctl vm.max_map_count / fs.file-max
       │
       ▼
create /opt/sonarqube
       │
       ▼
template .env (mode 0600)
       │
       ▼
copy compose.yml
       │
       ▼
docker compose up
       │
       ▼
prune dangling images
```

Run via `make deploy-sonarqube` (see `ansible/playbooks/sonarqube.yaml`, wired into `ansible/playbooks/site.yaml`).

## First-Login Hardening

After the first successful deploy, log in with the default `admin`/`admin` credential and rotate it immediately — this role does not (and cannot) do this for you. See `services/sonarqube/README.md#first-login-hardening`.

## Baseline Dependencies

Like every Docker Compose role in this repo, `meta/main.yml` depends on `common`, `node-exporter`, `promtail`, `docker`, and `portainer-agent`, so this host gets monitoring, logging, and Portainer management for free.
