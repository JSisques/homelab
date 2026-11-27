# ADR-0017: `platform/` includes the Proxmox host

- **Status:** Accepted
- **Date:** 2026-11-27
- **Extends:** [ADR-0003](0003-repository-layout-by-domain.md) and [ADR-0015](0015-automated-proxmox-host.md)

## Decision

The shared folder is named **`platform/`**, and it holds the whole ground every domain stands on:

| Part | Contents |
|------|----------|
| Host | The `answer.toml` template and the Ansible configuration of the Proxmox host |
| LXC base | What creates an empty LXC |
| Inside every LXC | Common base, Docker, Grafana Alloy |

The rule from ADR-0003 is unchanged for everything else: what runs in one place and is reached over the network belongs to a domain.

## Context

ADR-0003 defined `platform/` as what is installed inside every machine, and left the name as a proposal. ADR-0015 automated the host but left its location open. The host is not inside an LXC, but it is the lowest layer of the same ground.

## Consequences

- Everything below the services lives in one folder.
- `platform/` grows by one well-defined part, not by exceptions.

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| `shared/` | Becomes the place for anything undecided |
| A separate `host/` root folder | Splits the ground into two places with no benefit |
