# Architecture

One Proxmox server runs a small number of LXC containers. OpenTofu creates them, Ansible configures them, and Docker Compose runs the services inside them. An agent inside the LAN applies every release automatically.

## Overview

```mermaid
flowchart LR
  subgraph internet["Internet"]
    GH["GitHub<br/>code and releases"]
    S3["AWS S3<br/>encrypted OpenTofu state"]
    DMS["Dead man's switch"]
    TG["Telegram"]
  end

  subgraph home["Home LAN"]
    subgraph pve["Proxmox host"]
      CTRL["control LXC<br/>deploy agent + .env"]
      MON["monitoring LXC<br/>Prometheus, Alertmanager, Grafana"]
      DOM["domain LXCs<br/>network, media, tools..."]
    end
    NAS["NAS"]
  end

  CTRL -- "polls releases" --> GH
  CTRL -- "reads and writes state" --> S3
  CTRL -- "OpenTofu + Ansible" --> pve
  MON -- "scrapes metrics" --> CTRL
  MON -- "scrapes metrics" --> DOM
  MON -- "alerts" --> TG
  MON -- "heartbeat, sender not decided" --> DMS
  DMS -- "alerts on silence" --> TG
  pve -- "mounts" --> NAS
```

Every arrow between the house and the internet starts inside the house. Nothing on the internet opens a connection to the homelab ([ADR-0004](decisions/0004-pull-based-deployment.md)).

## Layers

| Layer | Tool | Responsibility |
|-------|------|----------------|
| Hypervisor | Proxmox | Runs the LXC containers and VMs, installed unattended ([ADR-0015](decisions/0015-automated-proxmox-host.md)) |
| Provisioning | OpenTofu | Creates LXC containers and VMs ([ADR-0007](decisions/0007-encrypted-remote-state.md)) |
| Configuration | Ansible | Configures the host, installs the platform, and deploys each domain |
| Runtime | Docker Compose | Runs the services, with CPU and memory limits per container |

Kubernetes is intentionally absent ([ADR-0001](decisions/0001-single-deployment-path.md)).

## Life of a change

```mermaid
flowchart TD
  A["PR squash-merged to main"] --> B["release-please opens a release PR"]
  B --> C["Merge the release PR<br/>tag vX.Y.Z"]
  C --> D["Agent polls GitHub<br/>and sees the new tag"]
  D --> E{"Major greater than<br/>DEPLOY_MAX_MAJOR?"}
  E -- "yes" --> F["Stop and alert"]
  F --> G["Owner performs the manual steps<br/>from the release notes<br/>and raises DEPLOY_MAX_MAJOR"]
  G --> D
  E -- "no" --> H{"Version marked<br/>as failed?"}
  H -- "yes" --> I["Skip it"]
  H -- "no" --> J["OpenTofu + Ansible"]
  J --> K{"Services healthy<br/>after a few minutes?"}
  K -- "yes" --> L["Publish the deployed<br/>version as a metric"]
  K -- "no" --> M["Mark the version as failed<br/>do not retry, alert"]
  M --> N["Owner: git revert or fix"]
  N --> A
```

| Step | Decision |
|------|----------|
| Deployment model | Pull ([ADR-0004](decisions/0004-pull-based-deployment.md)), by a Python agent on a systemd timer ([ADR-0020](decisions/0020-deploy-agent-in-python.md)) |
| Versioning and the major gate | [ADR-0008](decisions/0008-release-versioning.md), [ADR-0013](decisions/0013-first-version-and-pre-1-0-behaviour.md) |
| Undoing a change | Roll forward ([ADR-0009](decisions/0009-roll-forward.md)) |
| Proposing updates | Renovate ([ADR-0014](decisions/0014-dependency-updates-with-renovate.md)) |

## Knowing that it works

The agent cannot be its own watcher, and nothing inside the house can report a power cut ([ADR-0005](decisions/0005-deploy-observability.md)).

```mermaid
flowchart LR
  AG["Deploy agent"] -- "deploy metrics" --> PR["Prometheus"]
  GH["Latest GitHub release"] -- "compared with<br/>the deployed version" --> PR
  PR -- "deploy failed<br/>agent stale<br/>version drift" --> AM["Alertmanager"]
  AM --> TG["Telegram"]
  HL["Homelab"] -- "heartbeat,<br/>only while healthy" --> DMS["Dead man's switch<br/>outside the homelab"]
  DMS -- "heartbeats stopped" --> TG
```

| Failure | Detected by |
|---------|-------------|
| A deploy fails | The agent's metrics, scraped by Prometheus |
| The agent stops running | Prometheus: the agent's metric goes stale |
| The deployed version differs from the latest release | Prometheus: drift alert |
| The whole homelab is down (power, internet, Proxmox) | External dead man's switch: heartbeats stop arriving |

## Rebuilding from nothing

What describes the infrastructure never lives inside it.

| Asset | Lives in | Recovery |
|-------|----------|----------|
| Code and configuration | GitHub | `git clone` |
| Secrets (`.env`) | Control LXC, NAS copy, encrypted offsite copy | [ADR-0006](decisions/0006-secrets-management.md) |
| OpenTofu state | AWS S3, versioned and encrypted client-side | [ADR-0007](decisions/0007-encrypted-remote-state.md), [ADR-0018](decisions/0018-state-bucket-on-aws-s3.md) |

```mermaid
flowchart TD
  ENV[".env restored<br/>from the locked note"]
  STATE["OpenTofu state<br/>in AWS S3"]
  A["Empty server"] --> B["Boot the Proxmox ISO<br/>with the embedded answer.toml"]
  B --> C["Unattended installation"]
  C --> D["Ansible configures the host<br/>repositories, NAS, bridge, iGPU"]
  D --> E["bootstrap.sh<br/>OpenTofu creates only the control LXC"]
  E --> F["Install the deploy agent"]
  F --> G["The agent applies the latest release"]
  ENV -.-> B
  ENV -.-> D
  ENV -.-> E
  STATE -.-> E
```

Details: [ADR-0011](decisions/0011-greenfield-bootstrap.md), [ADR-0015](decisions/0015-automated-proxmox-host.md).

## Host maintenance

Host updates reboot only in a fixed window, Saturday at 04:00, when needed and with no deploy running ([ADR-0016](decisions/0016-host-reboot-maintenance-window.md)). Host network changes are breaking changes and are applied by hand with console access.

## Access

Everything is reached through VPN. Nothing is published to the internet today ([ADR-0010](decisions/0010-vpn-only-access.md)).

```mermaid
flowchart LR
  OWNER["Owner"] -- "admin VPN" --> WG["wireguard<br/>network domain"]
  WG --> ALL["Every domain"]
  FRIENDS["Friends"] -- "friends VPN<br/>proposed" --> WGF["wireguard-friends<br/>games domain"]
  WGF -- "server-side firewall" --> GAMES["games LXCs only"]
```
