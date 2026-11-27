# Open questions

Undecided topics, ordered by the release that needs them. When one is resolved, remove it from here and link the ADR that answers it.

**Needed by** refers to the rollout order in [ADR-0012](decisions/0012-rollout-order.md): release 1 is `control` + `platform`, release 2 is `monitoring`.

## Pending confirmation of a recommendation

| Topic | Recommendation | Needed by | Where |
|-------|----------------|-----------|-------|
| Domains beyond monitoring, tools, and media | See the catalog | Each domain's release | [domains.md](domains.md) |
| One VPN or two | Two: admin VPN in `network`, friends VPN in `games` | `network` / `games` | [ADR-0010](decisions/0010-vpn-only-access.md) |

## Needed to build release 1

None left. The six questions found while planning release 1 were answered by [ADR-0024](decisions/0024-plan-guard-before-apply.md) to [ADR-0029](decisions/0029-renovate-app-and-commit-types.md).

## Not discussed yet

| Topic | What needs deciding | Needed by |
|-------|---------------------|-----------|
| Dead man's switch provider | Healthchecks.io was suggested | Release 2 |
| Service data backups | Code, secrets, and state are covered, but not the data services generate from now on (n8n workflows, the engram database, Jellyfin metadata). What is backed up, where, and the role of PBS | First domain with persistent data |
| Internal domain and TLS | Which domain name services use on the LAN, and how Traefik gets certificates for it ([ADR-0022](decisions/0022-ip-addressing-plan.md)) | `network` |
| DNS during host reboots | Both AdGuard replicas live on the same host, so the LAN has no DNS while it reboots ([ADR-0016](decisions/0016-host-reboot-maintenance-window.md)) | `network` |
| Portainer | Keep it, or drop it because clicking changes into containers creates drift from Git | Release 2 |
| Order of the remaining domains | After `control`, `platform`, and `monitoring` ([ADR-0012](decisions/0012-rollout-order.md)) | Release 3 |
