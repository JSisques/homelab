# Obsidian

Obsidian is the homelab's "second brain" — a Markdown vault that AI agents (Claude, etc.) can read and write through MCP, rather than a note-taking app you open in a browser.

## Responsibilities

- Hosts a single Obsidian vault, headless (no GUI exposed).
- Exposes that vault to MCP clients over Streamable HTTP / SSE, so an agent can list, read, search, and edit notes.
- Keeps the vault's actual Markdown files on the NAS, not on the LXC's local disk.

Obsidian is deployed as a Docker Compose application inside a dedicated LXC container, same as `n8n` and `it-tools`.

## Directory Structure

```text
services/obsidian/
├── README.md
└── compose.yaml
```

No `.env.example` — there are no secrets in the default (no-OAuth, no git-sync) configuration this deploys with.

## Architecture

```text
                  obsidian LXC
                        │
                 Docker Compose
                        │
                        ▼
              ┌───────────────────┐
              │obsidian-remote     │
              │(shanehull)         │
              │                    │
              │ headless Obsidian  │
              │       +            │
              │ Local REST API     │
              │  plugin (internal, │
              │  127.0.0.1 only)   │
              │       +            │
              │ Go MCP bridge      │
              │  :4000 (HTTP/SSE)  │
              └─────────┬──────────┘
                        │
              /vaults (bind mount)
                        │
                        ▼
                 NFS export on NAS
              192.168.0.111:/export/obsidian
```

## What this container is

[`shanehull/obsidian-remote`](https://github.com/shanehull/obsidian-remote) runs a real (headless) Obsidian instance under Xvfb, with the community [Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api) plugin pre-installed and bound to `127.0.0.1` only, fronted by a small Go server that speaks MCP (Streamable HTTP on `/mcp`, SSE on `/sse`) and translates tool calls into REST API calls. There is no browser GUI exposed — everything happens through MCP tool calls (list/read/update/delete notes, search, manage frontmatter and tags).

There is no published image for this project, so `compose.yaml` builds it straight from its GitHub repository (`build: https://github.com/shanehull/obsidian-remote.git#v1.2.0`), pinned to a release tag rather than `main`, so a redeploy doesn't silently pick up upstream changes. Bumping the version is a one-line change to that tag.

## Vault persistence — why `TEST_MODE=true` is intentional

`shanehull/obsidian-remote` has two vault-sourcing modes, chosen by `TEST_MODE`:

- `TEST_MODE=false` expects `GIT_REPO_URL`/`GITHUB_PAT` and clones/pulls a vault from git on every boot. That means running a git host as a dependency, and it's the only path upstream actually downloads the Local REST API plugin's code on a **first** boot.
- `TEST_MODE=true` seeds a **new** vault directory — including the Local REST API plugin — the first time `/vaults` has no `.obsidian` directory, and does nothing on every boot after that.

This deployment has no git remote at all: the vault lives entirely on the NAS via the `/mnt/nas/obsidian:/vaults` bind mount in `compose.yaml`. `TEST_MODE=true` is what makes the very first boot self-bootstrap a working vault (with the REST API plugin actually installed) directly onto that NFS-backed path. Because persistence comes from the bind mount, not from the container, that "seed" is not disposable in this setup — it's the vault, permanently. Every boot after the first is a no-op for `init-vault.sh` (`.obsidian` already exists), so this is safe to leave as-is indefinitely.

## Persistence

Two volumes matter:

| Path      | Backing                              | Contents                                                   |
| --------- | ------------------------------------ | ------------------------------------------------------------ |
| `/vaults` | NFS export on the NAS (bind mount)   | The actual vault: Markdown notes, attachments, plugin config |
| `/config` | Docker named volume `obsidian-config`| Obsidian app state (vault ID, trust/open flags)               |

Only `/vaults` needs to be backed up — `/config` regenerates itself deterministically from `init-vault.sh` if lost.

### NAS prerequisite

Before deploying, create an NFS export on the NAS for this service, following the same pattern as `ansible/roles/pbs/`:

```text
192.168.0.111:/export/obsidian
```

The Ansible role (`ansible/roles/obsidian/`) mounts it at `/mnt/nas/obsidian` on the LXC and `compose.yaml` bind-mounts that into the container at `/vaults`.

## Networking

Obsidian's MCP endpoint is exposed through the homelab reverse proxy:

```text
https://obsidian.home.arpa/mcp   (Streamable HTTP)
https://obsidian.home.arpa/sse   (SSE)
```

Same trust model as `n8n`/`grafana`/other internal services: no auth in front of it beyond being on the LAN or WireGuard — see "Auth" below if that ever needs to change. The internal application port is `4000`; Traefik terminates TLS.

## Auth

`obsidian-remote` supports optional OAuth 2.0 (`OAUTH_ISSUER`, `OAUTH_JWKS_URL`, `OAUTH_AUDIENCE`, `OAUTH_CLIENT_SECRET`, `OAUTH_ALLOWED_EMAIL`) in front of the MCP endpoint. It's deliberately not configured here, matching every other `tier: internal` service in this repo — if this ever needs to be reachable from outside the LAN/VPN, add OAuth (or put it behind the Cloudflare Tunnel + Authelia/Authentik once that lands, see the repo root README's roadmap) rather than exposing it bare.

## Resource sizing

Headless Chromium/Electron is heavier than the other single-container services here (`it-tools`, `adguard-home`): 2 vCPU / 2GB RAM, 20GB disk (image layers from the `docker build` step, not vault data — that's all on the NAS). `shm_size: "1gb"` in `compose.yaml` avoids Chromium crashing on the default 64MB `/dev/shm`.

If the container fails to start on first deploy, the most likely cause is the unprivileged LXC's `nesting=true` feature not being enough for headless Chromium's sandbox — see `terraform/proxmox/lxc.tf`. That's a per-container Proxmox feature flag, not something this role can fix on its own.

## Deployment

Terraform creates the LXC:

```text
terraform/proxmox/lxc.tf
```

The LXC is configured by Ansible:

```text
ansible/
├── playbooks/
│   └── obsidian.yaml
└── roles/
    └── obsidian/
```

```bash
make deploy-obsidian
```

## Local Development

```bash
cd services/obsidian

mkdir -p /tmp/obsidian-vault   # stand-in for the NAS mount

docker compose up -d --build
```

The first boot builds the image from the pinned upstream tag (needs internet access) and seeds the vault — check `docker compose logs -f obsidian` for `Init complete. Headless Obsidian is ready.`.

## Monitoring

Obsidian should be monitored by Uptime Kuma as a **TCP** monitor on port `4000`, not an HTTP one — the MCP endpoint doesn't serve a plain `GET /` 200 response, so an HTTP monitor would flap. Not wired into `blackbox_exporter`/Prometheus for the same reason (see `config/services.yaml`, `services/blackbox-exporter/README.md`).

## Source of Truth

Terraform manages the LXC (existence, CPU, memory, disk, network). Ansible manages host configuration, the NFS mount, and Docker Compose deployment. This directory manages the Compose definition and application configuration.
