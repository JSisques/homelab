# Open questions

Undecided topics, ordered by the release that needs them. When one is resolved, remove it from here and link the ADR that answers it.

**Needed by** refers to the rollout order in [ADR-0012](decisions/0012-rollout-order.md): release 1 is `control` + `platform`, release 2 is `monitoring`.

## Pending confirmation of a recommendation

| Topic | Recommendation | Needed by | Where |
|-------|----------------|-----------|-------|
| OpenTofu instead of Terraform | OpenTofu, for client-side state encryption | Release 1 | [ADR-0007](decisions/0007-encrypted-remote-state.md) |
| Name of the shared folder | `platform/` | Release 1 | [domains.md](domains.md) |
| Domains beyond monitoring, tools, and media | See the catalog | Each domain's release | [domains.md](domains.md) |
| One VPN or two | Two: admin VPN in `network`, friends VPN in `games` | `network` / `games` | [ADR-0010](decisions/0010-vpn-only-access.md) |

## Not discussed yet

| Topic | What needs deciding | Needed by |
|-------|---------------------|-----------|
| Proxmox host | Whether installing Proxmox and configuring the host (network bridges, NAS mount, iGPU passthrough) is done by hand or lives in the repository. Today the design assumes Proxmox already exists, which is exactly the kind of knowledge that has to be remembered | Release 1 |
| State bucket provider | AWS S3 or Backblaze B2; both support versioning. Cloudflare R2 does not | Release 1 |
| Deploy agent implementation | systemd timer + `ansible-pull`, or a custom script | Release 1 |
| IP addressing plan | How the LXC containers are addressed, starting with `control` | Release 1 |
| CI checks | Which checks run (gitleaks is agreed). Needed for the release-please workflow and for branch protection ([repository.md](repository.md)) | Release 1 |
| First version | Start at `v0.1.0` or `v1.0.0`. Under semver, a `0.x` minor bump counts as breaking, which changes how `DEPLOY_MAX_MAJOR` gates releases ([ADR-0008](decisions/0008-release-versioning.md)) | Release 1 |
| Agent polling interval | How often the agent checks GitHub for releases | Release 1 |
| Health check window | How long the agent watches services after a deploy | Release 1 |
| Dead man's switch provider | Healthchecks.io was suggested | Release 2 |
| Service data backups | Code, secrets, and state are covered, but not the data services generate from now on (n8n workflows, the engram database, Jellyfin metadata). What is backed up, where, and the role of PBS | First domain with persistent data |
| Image and dependency updates | Who bumps container image versions and tool versions (the old repository used Renovate), and which commit type each update gets, given that every release is deployed automatically | First domain with a service |
| Portainer | Keep it, or drop it because clicking changes into containers creates drift from Git | Release 2 |
| Order of the remaining domains | After `control`, `platform`, and `monitoring` ([ADR-0012](decisions/0012-rollout-order.md)) | Release 3 |
