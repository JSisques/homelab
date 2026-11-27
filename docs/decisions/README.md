# Architecture Decision Records

Each file records one decision: what was decided, why, and what it costs.

| ADR | Decision | Status |
|-----|----------|--------|
| [0001](0001-single-deployment-path.md) | One deployment path, no Kubernetes | Accepted |
| [0002](0002-lxc-grouping-rule.md) | LXC grouping rule | Accepted |
| [0003](0003-repository-layout-by-domain.md) | Repository layout by domain | Accepted |
| [0004](0004-pull-based-deployment.md) | Pull-based deployment | Accepted |
| [0005](0005-deploy-observability.md) | Deployment observability and dead man's switch | Accepted |
| [0006](0006-secrets-management.md) | Secrets management | Accepted |
| [0007](0007-encrypted-remote-state.md) | Encrypted remote infrastructure state | Accepted |
| [0008](0008-release-versioning.md) | Release versioning and the major-version gate | Accepted |
| [0009](0009-roll-forward.md) | Roll forward instead of rollback | Accepted |
| [0010](0010-vpn-only-access.md) | VPN-only access | Accepted (VPN layout proposed) |
| [0011](0011-greenfield-bootstrap.md) | Greenfield start and bootstrap | Accepted |
| [0012](0012-rollout-order.md) | Rollout order: one domain per release | Accepted |
| [0013](0013-first-version-and-pre-1-0-behaviour.md) | First version and pre-1.0 behaviour | Accepted |
| [0014](0014-dependency-updates-with-renovate.md) | Dependency updates with Renovate | Accepted |
| [0015](0015-automated-proxmox-host.md) | Automated Proxmox host | Accepted |
| [0016](0016-host-reboot-maintenance-window.md) | Host reboot maintenance window | Accepted |
| [0017](0017-platform-includes-the-host.md) | `platform/` includes the Proxmox host | Accepted |
| [0018](0018-state-bucket-on-aws-s3.md) | State bucket on AWS S3 | Accepted |
| [0019](0019-diagrams-as-code-with-mermaid.md) | Diagrams as code with Mermaid | Accepted |
| [0020](0020-deploy-agent-in-python.md) | Deploy agent in Python, run by a systemd timer | Accepted |
| [0021](0021-agent-polling-and-health-check.md) | Agent polling interval and health check | Accepted |
| [0022](0022-ip-addressing-plan.md) | IP addressing plan | Accepted |

## Statuses

| Status | Meaning |
|--------|---------|
| Proposed | Recommended, not yet confirmed by the owner |
| Accepted | Confirmed. Never edited again |
| Superseded by ADR-NNNN | Replaced. Only this status line changes |

## Template

```markdown
# ADR-NNNN: <Decision as a statement>

- **Status:** Proposed | Accepted | Superseded by ADR-NNNN
- **Date:** YYYY-MM-DD

## Decision

<What was decided, in one paragraph or a short list.>

## Context

<The problem and the evidence that forced a decision.>

## Consequences

<What this makes easier, and what it costs.>

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
```
