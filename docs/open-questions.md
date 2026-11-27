# Open questions

Undecided topics. When one is resolved, remove it from here and link the ADR that answers it.

## Pending confirmation of a recommendation

| Topic | Recommendation | Where |
|-------|----------------|-------|
| OpenTofu instead of Terraform | OpenTofu, for client-side state encryption | [ADR-0007](decisions/0007-encrypted-remote-state.md) |
| Name of the shared folder | `platform/` | [domains.md](domains.md) |
| Domains beyond monitoring, tools, and media | See the catalog | [domains.md](domains.md) |
| One VPN or two | Two: admin VPN in `network`, friends VPN in `games` | [ADR-0010](decisions/0010-vpn-only-access.md) |

## Not discussed yet

| Topic | What needs deciding |
|-------|---------------------|
| Portainer | Keep it, or drop it because clicking changes into containers creates drift from Git |
| Order of the remaining domains | After `control`, `platform`, and `monitoring` ([ADR-0012](decisions/0012-rollout-order.md)) |
| CI checks | Which checks run (gitleaks is agreed). Needed before branch protection ([repository.md](repository.md)) |
| State bucket provider | AWS S3 or Backblaze B2; both support versioning. Cloudflare R2 does not |
| Deploy agent implementation | systemd timer + `ansible-pull`, or a custom script |
| Dead man's switch provider | Healthchecks.io was suggested |
| IP addressing plan | How the remaining LXC containers are addressed |
| Agent polling interval | How often the agent checks GitHub for releases |
| Health check window | How long the agent watches services after a deploy |
