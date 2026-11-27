# ADR-0022: IP addressing plan

- **Status:** Accepted (VMID convention proposed)
- **Date:** 2026-11-27

## Decision

The LAN is `192.168.0.0/24`.

| Range | Owner | Contents |
|-------|-------|----------|
| `.1` | Router | Gateway |
| `.10` – `.199` | Router DHCP | Household devices |
| `.111` | NAS | Static, configured on the NAS itself. Inside the DHCP range |
| `.200` | Proxmox host | Static, set by the `answer.toml` ([ADR-0015](0015-automated-proxmox-host.md)) |
| `.201` – `.250` | This repository | LXC containers and VMs, assigned in one place in the code. `control` takes `.201` |

**IP addresses belong to LXC containers, never to services.** Services are reached by name through Traefik and the AdGuard DNS. A new service needs no IP address.

**Proposed:** keep the previous repository's convention that the Proxmox VMID equals the last octet (`.201` is CT `201`).

## Context

In the previous repository, every static address was inside the router's DHCP range (`.10` – `.250`): Proxmox `.157`, NAS `.111`, and LXC containers `.200` – `.221`. Nothing stopped the router from handing one of them to another device. Each service also had its own LXC and IP ([ADR-0002](0002-lxc-grouping-rule.md)).

## Manual steps

These are outside the repository and must be redone if the router or NAS is replaced.

| Device | Setting |
|--------|---------|
| Router | DHCP range from `192.168.0.10` to `192.168.0.199`. Configured by the owner on 2026-11-27 |
| Router | `192.168.0.111` must never be handed out (reservation or exclusion for the NAS) |
| NAS | Static address `192.168.0.111` |

## Consequences

- The homelab block (`.200` – `.250`) is outside DHCP, so its addresses cannot collide with household devices.
- **The NAS address is inside the DHCP range.** It is safe only while the router never hands out `.111`. The owner chose to keep it there; moving it to the homelab block was rejected.
- The internal domain name and TLS certificates for service names are still open, needed by the `network` release ([open questions](../open-questions.md)).

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| LXC containers in `.160` – `.199` | The owner preferred `.2xx`, already familiar from the previous repository, and it has more room |
| Move the NAS to the homelab block | Rejected by the owner |
| One IP per service | The previous mess |
