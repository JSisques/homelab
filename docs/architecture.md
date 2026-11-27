# Architecture

One Proxmox server runs a small number of LXC containers. OpenTofu creates them, Ansible configures them, and Docker Compose runs the services inside them. An agent inside the LAN applies every release automatically.

## Layers

| Layer | Tool | Responsibility |
|-------|------|----------------|
| Hypervisor | Proxmox | Runs the LXC containers and VMs |
| Provisioning | OpenTofu | Creates LXC containers and VMs ([ADR-0007](decisions/0007-encrypted-remote-state.md)) |
| Configuration | Ansible | Installs the platform and deploys each domain |
| Runtime | Docker Compose | Runs the services, with CPU and memory limits per container |

Kubernetes is intentionally absent ([ADR-0001](decisions/0001-single-deployment-path.md)).

## Life of a change

```
1. Commit through a PR, squash-merged to main
2. release-please opens a release PR → merge it → tag vX.Y.Z
3. The deploy agent, inside the LAN, polls GitHub and sees the new tag
     ├─ major > DEPLOY_MAX_MAJOR → stop, alert, wait for manual steps
     └─ otherwise → OpenTofu + Ansible → health check for a few minutes
          ├─ healthy → publish the deployed version as a metric
          └─ failing → mark the version as failed, do not retry, alert
4. To undo a change: git revert → new patch release → back to step 2
```

| Step | Decision |
|------|----------|
| Deployment model | Pull ([ADR-0004](decisions/0004-pull-based-deployment.md)) |
| Versioning and the major gate | [ADR-0008](decisions/0008-release-versioning.md) |
| Undoing a change | Roll forward ([ADR-0009](decisions/0009-roll-forward.md)) |

## Knowing that it works

The agent cannot be its own watcher, and nothing inside the house can report a power cut. Three layers cover each other ([ADR-0005](decisions/0005-deploy-observability.md)):

| Failure | Detected by |
|---------|-------------|
| A deploy fails | The agent's metrics, scraped by Prometheus |
| The agent stops running | Prometheus: the agent's metric goes stale |
| The deployed version differs from the latest release | Prometheus: drift alert |
| The whole homelab is down (power, internet, Proxmox) | External dead man's switch: heartbeats stop arriving |

All alerts reach the phone through Alertmanager → Telegram.

## Rebuilding from nothing

What describes the infrastructure never lives inside it.

| Asset | Lives in | Recovery |
|-------|----------|----------|
| Code and configuration | GitHub | `git clone` |
| Secrets (`.env`) | Control LXC, NAS copy, encrypted offsite copy | [ADR-0006](decisions/0006-secrets-management.md) |
| OpenTofu state | External versioned bucket, encrypted client-side | [ADR-0007](decisions/0007-encrypted-remote-state.md) |

Recovery:

1. Boot the server from a Proxmox ISO with an embedded `answer.toml`; it installs unattended ([ADR-0015](decisions/0015-automated-proxmox-host.md)).
2. Ansible configures the host: repositories, NAS mount, network bridge, iGPU.
3. The bootstrap script creates only the control LXC; the agent does the rest ([ADR-0011](decisions/0011-greenfield-bootstrap.md)).

## Host maintenance

Host updates reboot only in a fixed window, Saturday at 04:00, when needed and with no deploy running ([ADR-0016](decisions/0016-host-reboot-maintenance-window.md)). Host network changes are breaking changes and are applied by hand with console access.

## Access

Everything is reached through VPN. Nothing is published to the internet today ([ADR-0010](decisions/0010-vpn-only-access.md)).
