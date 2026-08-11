# Cloudflared

`cloudflared` runs a locally-managed [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) that terminates all inbound traffic for the homelab's two external domains and forwards it to internal services. No inbound ports are opened on the home network — the tunnel is an outbound-only connection from this container to Cloudflare's edge.

## Responsibilities

- Terminate public/personal traffic for `sisqueslabs.com` and `jsisques.net`
- Route each hostname to the correct internal target (LXC, VM, or K3s ingress) per `config.yml`
- Refuse anything not explicitly listed (default `http_status:404` catch-all)

Services on `*.home.arpa` are never routed through the tunnel — they stay LAN/VPN-only. See the [Domains](../../README.md#domains-and-network-access) table and `config/README.md`'s `tier` field.

## Directory Structure

```text
services/cloudflared/
├── README.md
├── compose.yaml
└── config.yml
```

`config.yml` contains the ingress rules (hostname → internal target). It is safe to commit — it contains no secrets, only routing.

## One-Time Setup (manual, outside Git)

Creating the tunnel and issuing its credentials requires an authenticated Cloudflare account and cannot be automated from CI:

1. `cloudflared tunnel login` — authorizes the CLI against your Cloudflare account.
2. `cloudflared tunnel create homelab` — creates the tunnel and writes a credentials JSON file locally. Note the tunnel ID it prints.
3. Replace `REPLACE_WITH_TUNNEL_ID` in `config.yml` with the real tunnel ID.
4. For each hostname in `config.yml`, add a DNS CNAME record (in the Cloudflare dashboard or via `cloudflared tunnel route dns homelab <hostname>`) pointing to `<tunnel-id>.cfargotunnel.com`, for both the `sisqueslabs.com` and `jsisques.net` zones.
5. Keep the credentials JSON file out of Git. Provide its contents to Ansible as the `cloudflared_credentials_json` variable (via Ansible Vault or a CI secret) — see `ansible/roles/cloudflared/README.md`.

## Adding a Service

To expose a new service publicly:

1. Set `tier: public` (sisqueslabs.com) or `tier: personal` (jsisques.net) on it in `config/services.yaml`.
2. Add an `ingress` entry in `config.yml` mapping its hostname to its internal address.
3. Add the matching DNS CNAME record (step 4 above).
4. Commit and deploy.

Anything on `tier: internal` must **not** get an entry here.

## Local Development

Local testing requires real tunnel credentials and is normally not necessary; validate `config.yml` syntax instead:

```bash
cd services/cloudflared
docker compose config --quiet
```

## Deployment

Terraform creates the `cloudflared` LXC (`terraform/proxmox/lxc.tf`). Ansible deploys this Compose file and injects the credentials (see `ansible/roles/cloudflared/`).
