# ADR-0011: Greenfield start and bootstrap

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

**Greenfield:** the old homelab is shut down and Proxmox is wiped. No resource is imported and no data is migrated. The owner accepts losing all data inside the old LXC containers, including n8n workflows, the engram database, and the *arr application state. A final cold backup to the NAS before wiping is optional.

**Bootstrap** is the only manual step, and it is a versioned script run once from a laptop:

```
1. Restore the .env from the locked note
2. scripts/bootstrap.sh → OpenTofu creates ONLY the control LXC (same code, same remote state)
3. The script installs the deploy agent → the agent manages everything else
```

## Context

The deploy agent creates every LXC, but it lives in one. On an empty Proxmox, something else has to create the first one.

## Reasoning

The bootstrap uses **the same OpenTofu code and state** as the agent, not ad-hoc `pct create` commands. Otherwise the control LXC would exist without OpenTofu knowing about it: drift from day one, and a second place to edit when it changes.

## Consequences

- Changing the control LXC (for example, more memory) is a normal release.
- **A change that forces recreating the control LXC cannot be applied by the agent on itself**, because it would delete itself mid-deploy. It is a breaking change ([ADR-0008](0008-release-versioning.md)) applied through the bootstrap.
