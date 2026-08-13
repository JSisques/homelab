# cookidoo-mcp

[cookidoo-mcp](https://github.com/sisques-labs/cookidoo-mcp) is an [MCP](https://modelcontextprotocol.io) server that exposes a Cookidoo account (recipes, shopping list, meal planner, collections) to AI agents and MCP clients over Streamable HTTP.

## Responsibilities

cookidoo-mcp provides:

- Cookidoo account info and active subscription
- Recipe search and details
- Shopping list management (ingredients, additional items, mark as bought)
- Meal-planner calendar
- Custom recipes and collections (managed/custom)

It is deployed as a single Docker Compose container inside a dedicated LXC, following the same pattern as `it-tools` and `uptime-kuma` rather than `n8n` — it has no database, it is a single stateless-transport container with one small volume for session persistence.

## Directory Structure

```text
services/cookidoo-mcp/
├── README.md
├── compose.yml
└── .env.example
```

## Architecture

```text
                  cookidoo-mcp LXC
                        │
                 Docker Compose
                        │
                        ▼
                  cookidoo-mcp
                        │
                        ▼
              Cookidoo (cookidoo.es)
```

## Docker Compose

The service is defined in:

```text
services/cookidoo-mcp/compose.yml
```

cookidoo-mcp listens internally on:

```text
3000
```

The MCP endpoint is `POST /api/mcp` (Streamable HTTP, stateless — a fresh `McpServer` per request; `GET`/`DELETE` on that path return `405`). A liveness probe is exposed at `GET /api/health`.

## Persistence

By default the Cookidoo login session lives only in memory, so a container restart forces a fresh OAuth2 login. `COOKIDOO_COOKIE_FILE` is set to `/data/session.json`, backed by the `cookidoo-mcp-data` Docker volume, so restarts reuse the existing session (an expired one self-heals on the next `401`).

The session file holds session cookies — treat it like a credential. It is backed up as part of the LXC's Proxmox Backup Server backup (see [`docs/storage.md`](../../docs/storage.md)), the same way `obsidian-config` and `jellyfin-config` are.

## Credentials

`COOKIDOO_EMAIL` and `COOKIDOO_PASSWORD` are the only required configuration. They must never be committed to Git — use `.env.example` as the template for local development only.

In the homelab deployment, these come from Ansible Vault / CI secrets via the `cookidoo-mcp` Ansible role (`ansible/roles/cookidoo-mcp/`), not from a checked-in `.env`.

## Networking

cookidoo-mcp is exposed through the homelab reverse proxy:

```text
https://cookidoo-mcp.home.arpa
```

Traffic flows through:

```text
Client (MCP agent)
      │
      ▼
Reverse Proxy
      │
      ▼
cookidoo-mcp LXC
      │
      ▼
Docker
      │
      ▼
cookidoo-mcp
```

`tier: internal` — the server holds real Cookidoo credentials, so it is reachable only over LAN/WireGuard under `*.home.arpa`, never given a public Cloudflare Tunnel route.

## Monitoring

- **Uptime Kuma**: an HTTP monitor should target `GET https://cookidoo-mcp.home.arpa/api/health`, not `/` — the root path has no route and returns `404`, so a plain "is `/` 2xx" check would be a false negative. This is also why `config/services.yaml` doesn't set a `blackbox:` block for this service (`generate-blackbox.sh` always probes the bare host:port with no path).
- **OpenTelemetry**: traces, metrics, and logs are pushed via OTLP to the homelab's OTel Collector (`services/otel-collector/`, on the `monitoring` LXC at `192.168.0.209:4318`) — see `OTEL_EXPORTER_OTLP_ENDPOINT` in `compose.yml`. There is no native `/metrics` endpoint to scrape directly.

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
│   └── cookidoo-mcp.yaml
└── roles/
    └── cookidoo-mcp/
```

The deployment flow is:

```text
Terraform
    │
    ▼
LXC cookidoo-mcp
    │
    ▼
Ansible
    │
    ├── Install Docker
    ├── Create application directory
    ├── Configure Cookidoo credentials (Vault)
    ├── Copy compose.yml
    └── Start Compose
             │
             ▼
       cookidoo-mcp
```

## Local Development

```bash
cd services/cookidoo-mcp

cp .env.example .env   # then fill in your Cookidoo credentials

docker compose up -d
```

View logs:

```bash
docker compose logs -f cookidoo-mcp
```

Stop the stack:

```bash
docker compose down
```

## Security

cookidoo-mcp holds real Cookidoo account credentials and can mutate the account's shopping list, meal planner, and custom recipes/collections. It must stay `tier: internal` — reachable only via LAN/VPN, never exposed through the Cloudflare Tunnel.

## Source of Truth

Terraform manages: LXC existence, CPU, memory, disk, network (sized from `config/hosts.yaml`).

Ansible manages: host configuration, Docker, Docker Compose deployment, Cookidoo credential injection.

This directory manages: Docker Compose configuration, non-secret application configuration, service documentation.
