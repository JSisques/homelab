# SoulFire

[SoulFire](https://github.com/soulfiremc-com/SoulFire) is a Minecraft bot framework — it runs real client code (Fabric-based), so bots behave like real players at the protocol level rather than reimplementing the wire protocol. Used here to load-test the [Minecraft (PaperMC)](../minecraft/README.md) server: see `services/minecraft/README.md#load-testing` for the actual test procedure (offline-mode caveat, ramp-up plan, which metrics to watch).

## Not a 24/7 service

Unlike everything else in this repo, this LXC is meant to be **off most of the time** — start it in Proxmox only for a test session, stop it again afterwards. It has no Prometheus/blackbox/Uptime Kuma entry in `config/services.yaml` on purpose (see the comment there): an always-on monitor would just alert "down" between sessions.

## Directory Structure

```text
services/soulfire/
├── README.md
└── compose.yaml
```

## Persistence

One Docker named volume, `soulfire-data` → `/soulfire/data`: SoulFire's own config, instance definitions (bot address, protocol version, account settings), and generated data. Not backed up — if lost, the only cost is re-creating a test instance, nothing operationally important lives here.

## Client/server: there is no web dashboard at the port

`38765` is SoulFire's **backend** (gRPC-Web API) — opening `http://192.168.0.219:38765` in a browser just shows the auto-generated API docs, not a dashboard. To actually drive it you need a separate **client**:

1. **Generate an access token** — the console runs as the container's main process, so attach to it (needs `stdin_open`/`tty` in `compose.yaml`, already set):
   ```bash
   ssh root@192.168.0.219
   cd /opt/soulfire && docker compose attach soulfire
   ```
   At the prompt: `generate-token api`, copy the token it prints. Detach without stopping the container with `Ctrl+P, Ctrl+Q` (plain `Ctrl+C` would kill the process).
2. **Install the GUI client** on your own machine — not on this LXC — from the [SoulFireClient releases](https://github.com/soulfiremc-com/SoulFireClient/releases/latest) (macOS `.dmg`, Windows `.exe`, or Linux via Flathub).
3. Open it, enter **Server URL** `http://192.168.0.219:38765` and the **access token** from step 1.

Same trust model as every other `tier: internal` service otherwise — no auth in front of the backend beyond being on the LAN or WireGuard (the access token is the app-level auth on top of that).

Traffic between the client and this backend is plain HTTP (fine on the LAN/VPN); this is unrelated to the Minecraft protocol traffic SoulFire's bots generate when pointed at `192.168.0.217:25565`.

## Resource sizing

2 vCPU / 4GB RAM, 8GB disk (see `config/hosts.yaml` for the rationale) — sized for a few hundred bots per SoulFire's own guidance. Bump `memory` there if a test run needs more bots before the container OOMs.

## Deployment

Terraform creates the LXC:

```text
terraform/proxmox/lxc.tf
```

The LXC is configured by Ansible:

```text
ansible/
├── playbooks/
│   └── soulfire.yaml
└── roles/
    └── soulfire/
```

```bash
make deploy-soulfire
```

## Local Development

```bash
cd services/soulfire
docker compose up -d
```

Then point the GUI client (see above) at `http://localhost:38765`.

## Source of Truth

Terraform manages the LXC (existence, CPU, memory, disk, network). Ansible manages host configuration and Docker Compose deployment. No NAS mount, no secrets.
