# engram

[Engram](https://github.com/Gentleman-Programming/engram) gives AI coding agents (Claude Code, OpenCode, Codex, Cursor, ...) persistent memory. Each agent normally keeps its own local SQLite database; this LXC runs **Engram Cloud** (`engram cloud serve`), the self-hosted server mode that lets multiple agents/machines replicate memory into one shared, project-scoped store with a browser dashboard.

Local SQLite on every agent's own machine stays authoritative — this server is optional replication + visibility, not the only copy of the data.

## Responsibilities

The Engram Cloud runtime provides:

- `GET /health` liveness endpoint
- `POST /sync/push` / `GET /sync/pull` — chunk-based project sync
- `POST /sync/mutations/push` / `GET /sync/mutations/pull` — mutation sync
- `GET /dashboard/*` — browser visibility into replicated projects

It is deployed as a Docker Compose stack inside a dedicated LXC, same pattern as `n8n`: the app plus its own PostgreSQL, no shared database.

## Directory Structure

```text
services/engram/
├── README.md
├── compose.yml
└── .env.example
```

## Architecture

```text
                    engram LXC
                        │
                 Docker Compose
                        │
              ┌─────────┴─────────┐
              │                   │
              ▼                   ▼
            engram             PostgreSQL
        (cloud serve)
              │
              ▼
    agents on the LAN/WireGuard
    (engram sync --cloud --project ...)
```

## Docker Compose

The service is defined in:

```text
services/engram/compose.yml
```

`engram` listens internally and externally on:

```text
18080
```

PostgreSQL listens internally on `5432` and is never published outside the Docker network.

## Image

There is no build-from-source step here — Engram publishes an official multi-arch image at `ghcr.io/gentleman-programming/engram`, and the project's own docs say not to build from source for a deployment like this one. `ENGRAM_IMAGE_TAG` pins an explicit release tag (currently `v2.0.0-rc.8` — Engram Cloud has not shipped a non-RC `v2.x` tag yet; see the [Release Policy](https://github.com/Gentleman-Programming/engram/blob/main/docs/RELEASE-POLICY.md)). Never track `:latest` here — bump `ENGRAM_IMAGE_TAG` deliberately.

## Persistence

PostgreSQL stores every replicated chunk/mutation and the dashboard read model. The following Docker volume is used:

```text
postgres-data
```

mounted at `/var/lib/postgresql/data`. It must be included in the homelab backup strategy (see [`docs/storage.md`](../../docs/storage.md)) — losing it loses every agent's replicated memory (though each agent's own local SQLite database is unaffected, since it stays authoritative).

## Credentials

Authenticated mode requires four secrets, none of which may be committed to Git:

- `POSTGRES_PASSWORD`
- `ENGRAM_CLOUD_TOKEN` — bearer token `/sync/*` clients use
- `ENGRAM_CLOUD_ADMIN` — separate token for `/dashboard` admin surfaces; must differ from `ENGRAM_CLOUD_TOKEN`
- `ENGRAM_JWT_SECRET` — must be an explicit, non-default 32+ byte secret

`ENGRAM_CLOUD_ALLOWED_PROJECTS` is not secret but is required server-side even in this mode; it is set to `*` (any project name) here.

Use `.env.example` as the local-development template only. In the homelab deployment, real values come from Ansible Vault / CI secrets via the `engram` Ansible role (`ansible/roles/engram/`).

## Networking

engram is reached directly by its LAN `IP:port`, no reverse proxy in front of it:

```text
http://192.168.0.221:18080
```

`tier: internal` — this holds agents' persistent memory (code context, decisions, credentials an agent may have recorded), so it stays LAN/WireGuard-only, never given a public Cloudflare Tunnel route. It runs in authenticated mode (not `ENGRAM_CLOUD_INSECURE_NO_AUTH=1`, which upstream documents as local/dev smoke only) even though it never leaves the LAN, since the data it holds is sensitive.

## Monitoring

- **Uptime Kuma**: an HTTP monitor targets `http://192.168.0.221:18080` (root), not `GET /health` — root isn't a mapped route (only `/health`, `/sync/*`, `/dashboard/*` are), so this is a known false-negative-risk check, same caveat as `cookidoo-mcp`/`obsidian`. This is also why `config/services.yaml` doesn't set a `blackbox:` block here (`generate-blackbox.sh` always probes the bare host:port with no path).
- No native `/metrics` endpoint to scrape.

## Client setup (on each agent's machine)

```bash
engram cloud config --server http://192.168.0.221:18080
export ENGRAM_CLOUD_TOKEN=<the bearer token configured above>
engram cloud enroll <project>
engram sync --cloud --project <project>
```

### With Gentle-AI

[Gentle-AI](https://github.com/Gentleman-Programming/gentle-ai) (the installer that configures Claude Code/Cursor/OpenCode/etc.) only wires up Engram's local MCP integration — it has no Cloud step of its own. Cloud config lives in `~/.engram/cloud.json`, managed by the `engram` CLI directly, independent of whichever tool installed it. So after Gentle-AI has installed `engram` on a machine, point it at this server with the same commands above:

```bash
engram cloud config --server http://192.168.0.221:18080
export ENGRAM_CLOUD_TOKEN=<the bearer token configured above>   # put this in the shell profile, not a one-off export, so it survives new sessions
engram cloud enroll <project>   # repeat per repo you want replicated here
```

`gentle-ai doctor` reports Engram reachability, so it picks up the Cloud server once configured this way — nothing to change in Gentle-AI itself.

### Always-on replication (autosync)

The commands above sync explicitly, on demand (`engram sync --cloud --project <project>`). For a project to replicate automatically in the background, every time the agent runs, enable [Cloud Autosync](https://github.com/Gentleman-Programming/engram/blob/main/DOCS.md#cloud-autosync) instead — it still only covers projects already enrolled with `engram cloud enroll`, it does not replicate everything on the machine.

Set three environment variables wherever `engram mcp` (or `engram serve`) actually runs:

```bash
ENGRAM_CLOUD_AUTOSYNC=1   # exact string "1" -- anything else is treated as disabled
ENGRAM_CLOUD_TOKEN=<the bearer token configured above>
ENGRAM_CLOUD_SERVER=http://192.168.0.221:18080
```

**Where to put these matters:**

- **Shell profile** (`~/.zshrc` / `~/.bash_profile`), then restart the agent/terminal — recommended. `engram mcp` inherits its parent shell's environment, so this applies to every project without touching any per-agent config file, and survives `engram setup <agent>` / Gentle-AI / plugin re-runs.
- **The agent's MCP config file directly** — only safe for a config file Claude Code actually reads. Upstream's own docs say `engram setup claude-code` writes the MCP registration to `~/.claude/mcp/engram.json`, but verified on this fleet's Claude Code version, that path is **not** auto-discovered at all (`claude mcp get engram` returns not-found even with the file in place after a full restart) — the plugin's session-start hook re-runs `engram setup claude-code --mcp-only` and keeps rewriting that dead file, so tools silently stop loading after an update with no error. The registration that actually works: `claude mcp add engram -s user -- <path-to-engram-binary> mcp --tools=agent`, which writes to `~/.claude.json` (`mcpServers`, user scope) — the location Claude Code really reads, and `claude mcp add ... --env KEY=VALUE` can set the three autosync variables right there instead of (or in addition to) the shell profile. If `mcp__engram__*` tools ever go missing again after a plugin/Engram update, re-run that `claude mcp add` command and restart — don't assume the plugin's own migration hook fixed it.

If either `ENGRAM_CLOUD_TOKEN` or `ENGRAM_CLOUD_SERVER` is missing, autosync logs an `[autosync] ERROR` and disables itself gracefully — the agent still starts.

## Updates

Bump `ENGRAM_IMAGE_TAG` in the deployed `.env` (via the Ansible role's `engram_image_tag` variable) after reading the target release's notes, then re-run `make deploy-engram`. Follow upstream's [Release Policy](https://github.com/Gentleman-Programming/engram/blob/main/docs/RELEASE-POLICY.md) before moving off an RC once a stable `v2.x` exists.

## Deployment

Terraform creates the LXC:

```text
terraform/proxmox/lxc.tf
```

(sized via `config/hosts.yaml` → `scripts/generation/generate-terraform-vars.sh`).

The LXC is configured by Ansible:

```text
ansible/
├── playbooks/
│   └── engram.yaml
└── roles/
    └── engram/
```

The deployment flow is:

```text
Terraform
    │
    ▼
LXC engram
    │
    ▼
Ansible
    │
    ├── Install Docker
    ├── Create application directory
    ├── Configure secrets (Vault)
    ├── Copy compose.yml
    └── Start Compose
             │
             ├── engram (cloud serve)
             └── PostgreSQL
```

## Local Development

```bash
cd services/engram

cp .env.example .env   # then fill in real secrets

docker compose up -d
```

View logs:

```bash
docker compose logs -f engram
```

Stop the stack:

```bash
docker compose down
```

## Security

This server replicates whatever agents choose to save as memory — which can include code context, architectural decisions, and occasionally credentials an agent recorded before realizing it shouldn't have. Treat it like any other credential store: `tier: internal` only, authenticated mode always on, `ENGRAM_CLOUD_TOKEN` and `ENGRAM_CLOUD_ADMIN` kept as separate secrets.

## Source of Truth

Terraform manages: LXC existence, CPU, memory, disk, network (sized from `config/hosts.yaml`).

Ansible manages: host configuration, Docker, Docker Compose deployment, secret injection.

This directory manages: Docker Compose configuration, non-secret application configuration, service documentation.
