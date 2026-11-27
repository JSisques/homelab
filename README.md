# homelab

Infrastructure as code for my homelab: one Proxmox server, rebuilt from this repository alone.

> **Status: design phase.** No infrastructure code exists yet. Everything below is the agreed design, recorded in [`docs/`](docs/README.md).

## What this repository guarantees

If the server dies, two things rebuild the whole homelab:

1. **This repository** — all code and configuration.
2. **The `.env` file** — all secrets, kept outside the repository (see [ADR-0006](docs/decisions/0006-secrets-management.md)).

Nothing else has to be remembered.

## Principles

| Principle | Meaning |
|-----------|---------|
| One deployment path | Proxmox + OpenTofu + Ansible + Docker Compose. No Kubernetes. |
| Folders by domain | A service lives in one place. Deleting a domain folder removes it entirely. |
| Pull, never push | Nothing from the internet enters the home network to deploy. |
| The release is the signal | Every release tag is applied automatically by an agent inside the LAN. |
| Roll forward | Fixes go through Git as a new release, never by hand on the server. |
| VPN by default | Nothing is published to the internet unless there is no alternative. |
| YAGNI | Nothing is built "just in case". |
| Everything is documented | A change without its documentation is not finished. See the [documentation policy](docs/README.md#documentation-policy). |

## How a change reaches the server

```
commit (PR, squash merge to main)
  → release-please opens the release PR → merge → tag vX.Y.Z
  → the deploy agent (inside the LAN) sees the new tag and applies it
  → health check → metrics → Prometheus → Telegram on failure
```

Full flow: [docs/architecture.md](docs/architecture.md).

## Documentation

Start at [`docs/README.md`](docs/README.md).
