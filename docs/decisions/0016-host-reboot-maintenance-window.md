# ADR-0016: Host reboot maintenance window

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

Host updates are installed but do not reboot when they are installed. The host reboots **only in a fixed maintenance window, Saturday at 04:00 local time**, and only when:

1. an update requires a reboot, and
2. no deploy is running.

The "reboot required" state is exposed as a metric. If the host fails to come back, the heartbeats stop and the external dead man's switch alerts ([ADR-0005](0005-deploy-observability.md)).

## Context

Kernel updates on the Proxmox host need a reboot, and a host reboot restarts every LXC, including the deploy agent's.

## Reasoning

| Option | Problem |
|--------|---------|
| The agent reboots while applying the update | It kills itself mid-deploy, at any time of day, while services are in use |
| Always by hand, after an alert | Safe, but a manual step, and repeated alerts end up ignored |
| **Fixed window, only when needed** | Automatic, at a time when nobody uses the homelab, and failures are already detected |

## Consequences

- Host security updates can wait up to a week for their reboot.
- **During the reboot the LAN has no DNS**: both AdGuard replicas live on the same host. Their redundancy covers LXC failures, not host failures. To address in the `network` domain.
