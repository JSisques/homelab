# AdGuard Home Ansible Role

Deploys [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) on a dedicated LXC container using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`). This role installs Docker (via the `docker` role) and deploys the application.

Used twice, unmodified, against two independent LXCs — `adguard-home-1` (primary) and `adguard-home-2` (secondary) — for DNS redundancy: each gets its own conf directory and is unaware of the other. Keeping later UI changes in sync is handled by `ansible/roles/adguard-home-sync/`, not this role.

## Responsibilities

- Create the application directory (`adguard_home_app_dir`, default `/opt/adguard-home`)
- Seed `conf/AdGuardHome.yaml` **once** (`force: false`) so the first-run wizard is skipped: admin user, UI on `:80`, and a DNS rewrite of `*.home.arpa` to Traefik's LAN address from the generated inventory
- Deploy `services/adguard-home/compose.yaml` (bind-mounts `./conf` into the container)
- Start the stack with `community.docker.docker_compose_v2`

AdGuard Home rewrites its YAML at runtime. After the first seed, this role does not overwrite it — further filter/client changes belong in the UI (and then `adguard-home-sync`).

## Variables

| Variable | Default | Notes |
| --- | --- | --- |
| `adguard_home_username` / `adguard_home_password` | empty | Required on the first seed. Playbooks map these from `adguard_sync_origin_*` (primary) and `adguard_sync_replica_*` (secondary). |
| `adguard_home_rewrite_domain` | `*.home.arpa` | Internal-tier wildcard |
| `adguard_home_rewrite_answer` | `hostvars['traefik'].ansible_host` | Traefik's LAN IP from `config/hosts.yaml` |

## Deployment

```bash
set -a && source .env && set +a
make deploy-adguard-home-1
make deploy-adguard-home-2
```

(`make deploy-adguard-home-1` passes `ADGUARD_SYNC_ORIGIN_*` / `ADGUARD_SYNC_REPLICA_*` from the environment — see the root `Makefile`.)

If a previous deploy already created an empty named volume and left the wizard running, delete `/opt/adguard-home/conf/AdGuardHome.yaml` on the host (or the leftover Docker volume) and re-run so the seed can be written.
