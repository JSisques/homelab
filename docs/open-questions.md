# Open questions

Undecided topics, ordered by the release that needs them. When one is resolved, remove it from here and link the ADR that answers it.

**Needed by** refers to the rollout order in [ADR-0012](decisions/0012-rollout-order.md): release 1 is `control` + `platform`, release 2 is `monitoring`.

## Pending confirmation of a recommendation

| Topic | Recommendation | Needed by | Where |
|-------|----------------|-----------|-------|
| Domains beyond monitoring, tools, and media | See the catalog | Each domain's release | [domains.md](domains.md) |
| One VPN or two | Two: admin VPN in `network`, friends VPN in `games` | `network` / `games` | [ADR-0010](decisions/0010-vpn-only-access.md) |

## Not discussed yet

| Topic | What needs deciding | Needed by |
|-------|---------------------|-----------|
| IP addressing plan | How the LXC containers are addressed, starting with `control` | Release 1 |
| CI checks | Which checks run (gitleaks is agreed). Needed for the release-please workflow and for branch protection ([repository.md](repository.md)) | Release 1 |
| Dead man's switch provider | Healthchecks.io was suggested | Release 2 |
| Service data backups | Code, secrets, and state are covered, but not the data services generate from now on (n8n workflows, the engram database, Jellyfin metadata). What is backed up, where, and the role of PBS | First domain with persistent data |
| Renovate commit types | Which commit type each kind of update gets (patch, minor, major image bumps), given that it decides whether and how a release is created ([ADR-0014](decisions/0014-dependency-updates-with-renovate.md)) | First domain with a service |
| DNS during host reboots | Both AdGuard replicas live on the same host, so the LAN has no DNS while it reboots ([ADR-0016](decisions/0016-host-reboot-maintenance-window.md)) | `network` |
| Portainer | Keep it, or drop it because clicking changes into containers creates drift from Git | Release 2 |
| Order of the remaining domains | After `control`, `platform`, and `monitoring` ([ADR-0012](decisions/0012-rollout-order.md)) | Release 3 |
