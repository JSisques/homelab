# Agent notes

This repo is homelab-as-code. Git describes the desired state; Terraform, Ansible, and Argo CD apply it. The public docs live under `website/` (Astro/Starlight).

Communicate with the human in Spanish. Code, comments, documentation, commit messages, and this file stay in English.

## Source of truth

`config/` is the only place shared homelab facts are written. Everything else is either implementation or generated output.

| File | Owns |
| ---- | ---- |
| `config/hosts.yaml` | Networks, machines, addresses (`octet` / `address`), Proxmox node name (`node:` on the hypervisor), VMID (`octet`, or `vmid:` override), LXC/VM sizing, `role` |
| `config/services.yaml` | The service catalog: name, `category`, `tier`, URL, Homepage, Traefik, Prometheus, blackbox, Uptime Kuma |

A service does not exist until it has an entry in `config/services.yaml`. A machine does not exist until it has an entry in `config/hosts.yaml`. Do not invent IPs, hostnames, ports, tiers, or URLs in Ansible, Terraform, Compose, Kubernetes, or docs — change `config/` and regenerate.

Keep the two files separate: hosts are infrastructure, services are the catalog. Do not merge them. Do not add a third catalog.

Details and field schemas: `config/README.md`.

### Address resolution

Hosts resolve in this order (see `scripts/generation/lib.sh`):

1. `address: TBD` — unconfirmed; generators skip it.
2. `address: <literal IP>` — override only when the IP is not `prefix.octet`.
3. `octet: <n>` — `network.<network // "lan">.prefix` + `.` + octet.

Change the LAN subnet by editing `network.lan.prefix` / `gateway`, not by hunting IPs.

A host `role` value must match a `services.yaml` key when that role is a service (e.g. `grafana` on the `monitoring` host). Roles that are not services (`k3s`, `server`, `worker`, `hypervisor`, `storage`) stay host-only.

### Tiers

`tier` in `config/services.yaml` decides the domain and exposure:

| Tier | Domain | Exposure |
| ---- | ------ | -------- |
| `internal` | none | LAN only, plain `IP:port` in `url`, linked from Homepage. Never through Traefik or Cloudflare. |
| `personal` | `*.jsisques.net` | `Cloudflared → Traefik → backend`. Needs a `traefik: {enabled: true, port: <n>}` block; `services/cloudflared/config.yml` is generated, not hand-edited. |
| `public` | `*.sisqueslabs.com` | Same as `personal`, different domain. |

Default to `internal`. A service that's `internal` day-to-day but also needs a remote-access alias (e.g. Jellyfin) adds an `external:` block instead of changing its own tier — see `config/README.md#external`.

## Generated files — never edit

After any `config/` change, run `make generate` then `make validate`.

| Generator | Output |
| --------- | ------ |
| `generate-inventory.sh` | `ansible/inventory/hosts.yml` |
| `generate-terraform-vars.sh` | `terraform/proxmox/hosts.auto.tfvars.json` |
| `generate-homepage.sh` | `services/homepage/config/services.yaml` |
| `generate-prometheus.sh` | `services/prometheus/prometheus.yml` |
| `generate-blackbox.sh` | `services/prometheus/blackbox-targets.yml` |
| `generate-traefik.sh` | `services/traefik/dynamic/routes.yml` |
| `generate-cloudflared.sh` | `services/cloudflared/config.yml` |

Do not hand-edit those outputs. Hand-authored files next to them (e.g. `services/prometheus/alerts.yml`, Compose files, Ansible roles) are fine.

## Adding a service

1. Add the catalog entry in `config/services.yaml` (stable hyphenated key, `tier`, Homepage/Traefik/monitoring/blackbox as needed).
2. If it needs a machine: add or update `config/hosts.yaml` (`type`/`octet`/`cpu`/`memory`/`disk`/`role`). The Proxmox VMID defaults to `octet`; set `vmid:` only when they differ. Kubernetes workloads that share `k3s-server` get a `role` on that host so generators can resolve a LAN address — they do not get their own LXC.
3. Implement it in exactly one place:
   - Docker on an LXC/VM → `services/<name>/` + `ansible/roles/<name>/` + playbook.
   - Kubernetes → `kubernetes/applications/<name>/` (or `kubernetes/infrastructure/`) + Argo CD `Application`.
4. `make generate` and `make validate`.
5. Deploy with `make apply-<host>` / `make deploy-<service>` (see `make services`), not by SSHing in and clicking through UIs.

Identifiers are lowercase with hyphens (`uptime-kuma`, `adguard-home-1`). Keep them stable; generators and roles key off them.

## Layers

```text
config/  →  make generate  →  Terraform / Ansible / service configs
                               Kubernetes is GitOps via Argo CD
```

- **Terraform** (`terraform/proxmox/`) — LXCs and VMs exist. No per-service HCL; `for_each` over generated maps. Does not configure the OS.
- **Ansible** (`ansible/`) — OS, Docker, Node Exporter, Promtail, and Compose deploy. Inventory is generated. Every service role depends on the baseline (`common`, `docker`, `node-exporter`, `promtail`).
- **Kubernetes** (`kubernetes/`) — only k3s workloads (Argo CD). Not for LXC services.
- **`services/`** — Compose and app config that Ansible copies as-is. One directory per deployed stack.

Do not duplicate a Compose file inside an Ansible role. Do not put LXC services into Kubernetes "just because".

## Secrets

Never commit passwords, tokens, private keys, or cloud credentials. Reference them (`secretRef`, env vars consumed by the Makefile extra-vars) and keep values outside Git. See each role's README for the required env vars (`N8N_POSTGRES_PASSWORD`, `CLOUDFLARED_CREDS_JSON`, …).

## Workflow

```text
edit config/ (and implementation) → make generate → make validate → commit → push
```

CI validates. `deploy.yaml` applies Terraform/Ansible on a self-hosted runner (manual dispatch). Prefer `make deploy-<service>` over a full-fleet `make deploy` when changing one stack.

Do not apply Terraform/Ansible against live infrastructure unless the human asked for it. The README still treats most of this as defined-in-Git, not yet applied.
