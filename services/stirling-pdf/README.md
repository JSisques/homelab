# Stirling PDF

[Stirling PDF](https://www.stirlingpdf.com/) is a self-hosted, all-in-one PDF toolbox — merge, split, convert, OCR, watermark, compress, and dozens of other PDF operations through a web UI, no upload to a third-party site.

## Responsibilities

- Serves a web UI for PDF manipulation (merge/split/convert/OCR/watermark/etc.) and the underlying API those tools call.
- Stateless per request: you upload a file, it processes it in the container, you download the result — there's no persistent document library, so unlike Jellyfin/Minecraft/RustFS/Obsidian, this service needs **no NAS mount**.

Stirling PDF is deployed as a Docker Compose application inside a dedicated LXC container, same as `it-tools`.

## Directory Structure

```text
services/stirling-pdf/
├── README.md
└── compose.yaml
```

No `.env.example` — there are no secrets in this deployment (built-in login is disabled, see below).

## Image variant

Uses `stirlingtools/stirling-pdf:latest` — the standard tag ("all PDF features", balanced size), not `-fat` (extra fonts/higher-quality format conversion, heavier) or `-ultra-lite` (core PDF ops only, no OCR/format conversion, for constrained hardware). Switching is a one-line tag change in `compose.yaml` if `-fat`'s conversion quality or `-ultra-lite`'s smaller footprint ever becomes worth it — see [the image variants doc](https://docs.stirlingpdf.com/Installation/Docker%20Install/) — but would also mean revisiting `cpu`/`memory`/`disk` in `config/hosts.yaml`.

## Login: disabled

Stirling PDF ships with its own login system enabled by default (a seeded `admin`/`stirling` account you're expected to change on first login). This deployment turns it off (`SECURITY_ENABLELOGIN=false`, alongside `DISABLE_ADDITIONAL_FEATURES=true` — matches [Stirling PDF's own documented no-login example](https://github.com/Stirling-Tools/Stirling-PDF/blob/main/docker/compose/docker-compose.yml)), same trust model as `it-tools`/`jellyfin`/`obsidian`/every other `tier: internal` service here: the LAN/WireGuard boundary is the auth, not a per-app login screen.

## Persistence

Four Docker named volumes — no NAS mount, nothing here is the primary copy of anything you'd mind losing:

| Path                  | Volume                    | Contents                                          |
| ---------------------- | -------------------------- | -------------------------------------------------- |
| `/configs`             | `stirling-pdf-config`      | App settings + its embedded database               |
| `/usr/share/tessdata`  | `stirling-pdf-tessdata`    | Tesseract OCR language data                        |
| `/logs`                | `stirling-pdf-logs`        | Application logs                                   |
| `/pipeline`            | `stirling-pdf-pipeline`    | Saved automation pipelines (if you build any)       |

## Networking

Reached directly by LAN `IP:port`, no reverse proxy:

```text
http://192.168.0.218:8080
```

Same trust model as every other `tier: internal` service — no auth in front of it beyond being on the LAN or WireGuard (see "Login" above for why that's also true inside the app itself).

## Resource sizing

2 vCPU / 2GB RAM, 6GB disk — the standard image, no NAS mount to size around, so this is mostly OS + Docker + the image itself. Revisit if OCR-heavy batches or large-file conversions start feeling slow.

## Deployment

Terraform creates the LXC:

```text
terraform/proxmox/lxc.tf
```

The LXC is configured by Ansible:

```text
ansible/
├── playbooks/
│   └── stirling-pdf.yaml
└── roles/
    └── stirling-pdf/
```

```bash
make deploy-stirling-pdf
```

## Local Development

```bash
cd services/stirling-pdf
docker compose up -d
```

Then open `http://localhost:8080`.

## Monitoring

Stirling PDF has no native Prometheus `/metrics` endpoint exposed by default, so it's probed by `blackbox_exporter` for up/down + latency instead (see `config/services.yaml`, `services/blackbox-exporter/README.md`) and added to Uptime Kuma as an HTTP monitor on port `8080`.

## Source of Truth

Terraform manages the LXC (existence, CPU, memory, disk, network). Ansible manages host configuration and Docker Compose deployment — there's no NAS mount to set up first, unlike most of this repo's other Docker services.
