# ADR-0002: LXC grouping rule

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

> **Group** services in the same LXC when they share a functional domain.
>
> **Never group** when:
> 1. They are **replicas of the same service that exist for redundancy.** Replicas go in separate failure domains.
> 2. The service **accepts connections from the internet** or from people outside the household.
>
> **Always**, when grouping, set CPU and memory limits per container in Docker Compose.

## Context

The previous repository had 22 LXC containers and VMs, mostly one per service, each with its own fixed IP. Adding a service touched six places: the Terraform definition, the Ansible inventory, Traefik, Prometheus, blackbox, and Homepage. Seven generator scripts existed only to hide that cost.

Services like `it-tools`, `stirling-pdf`, `cookidoo-mcp`, and `homepage` were each a single stateless container with its own full operating system.

## Reasoning

| Concern | Conclusion |
|---------|------------|
| "If one fails, the others stay up" | A crashing container does not affect its neighbours. Only a failure of the LXC itself propagates. |
| Redundancy | Two AdGuard instances in one LXC become a single point of failure: a kernel update reboots both, and the LAN loses DNS. |
| Resource contention | Solved by per-container limits, not by separation. Separate LXCs on the same host still compete. |
| GPU passthrough | Does not force isolation: any LXC can receive the `/dev/dri` bind. |
| Compromise | A vulnerable plugin on an exposed service must not reach unrelated data in the same LXC. |

## Consequences

- Far fewer LXC containers, IPs, and operating systems to patch.
- Every new service first needs a domain, which forces a decision about what it is.
- An LXC failure takes down its whole group. Accepted for everything except redundant replicas.

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| One LXC per service | The previous mess |
| Everything in one LXC | Breaks redundancy and exposes everything to any compromise |
| Separate by resource usage | Per-container limits solve it without more machines |
