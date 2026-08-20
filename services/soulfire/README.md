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

One Docker named volume, `soulfire-data` → `/soulfire/data`: SoulFire's own config, instance definitions (bot address, protocol version, account settings), and generated data. Not backed up — if lost, the only cost is re-creating a test instance through the web UI, nothing operationally important lives here.

## Networking

Reached directly by LAN/VPN `IP:port`, no reverse proxy:

```text
http://192.168.0.219:38765
```

Same trust model as every other `tier: internal` service — no auth in front of it beyond being on the LAN or WireGuard. The web UI's own admin account (created on first visit) is the only login.

Traffic to the SoulFire UI itself is plain HTTP (fine on the LAN/VPN); this is unrelated to the Minecraft protocol traffic SoulFire's bots generate when pointed at `192.168.0.217:25565`.

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

Then open `http://localhost:38765`.

## Source of Truth

Terraform manages the LXC (existence, CPU, memory, disk, network). Ansible manages host configuration and Docker Compose deployment. No NAS mount, no secrets.
