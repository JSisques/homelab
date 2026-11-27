# ADR-0028: `bpg/proxmox` provider pinned to an exact version, and Debian 13 in every LXC

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

| Topic | Decision |
|-------|----------|
| OpenTofu provider | **`bpg/proxmox`**, pinned to an **exact version** (`version = "= X.Y.Z"`), with `.terraform.lock.hcl` committed |
| LXC base OS | **Debian 13 "Trixie"**, the same Debian release as the Proxmox VE host |

Version bumps of the provider arrive as Renovate pull requests ([ADR-0014](0014-dependency-updates-with-renovate.md)), pass `tofu validate` in CI ([ADR-0023](0023-ci-checks.md)), and the plan guard refuses any bump that would recreate a container ([ADR-0024](0024-plan-guard-before-apply.md)).

## Context

Checked on 2026-11-27:

| Fact | Source |
|------|--------|
| The latest Proxmox VE is 9.2 (2026-05-21), built on Debian 13.5 "Trixie", with LXC 7.0 | [Proxmox press release](https://www.proxmox.com/en/about/press-releases/proxmox-virtual-environment-9-2) |
| `bpg/proxmox` supports Proxmox VE 9.x (recommended) and OpenTofu 1.6+. Latest release found: `v0.110.0`, 2026-06-18 | [bpg README](https://github.com/bpg/terraform-provider-proxmox), [v0.110.0](https://newreleases.io/project/github/bpg/terraform-provider-proxmox/release/v0.110.0) |
| `bpg/proxmox` is still `0.x`, and `v0.109.0` shipped a breaking change in a minor version | [v0.109.0](https://newreleases.io/project/github/bpg/terraform-provider-proxmox/release/v0.109.0) |
| `Telmate/proxmox` supported Proxmox VE 9 only in `3.0.2-rc` pre-releases from 2025; no stable 2026 release was found | [Proxmox forum](https://forum.proxmox.com/threads/proxmox-9-terraform-provider-missing-vm-monitor-permission-but-it-doesnt-exist.170212/) |

## Reasoning

- **Same Debian as the host:** an LXC has no kernel of its own; it runs on the host's kernel. Debian 13 is built and tested for the kernel generation Proxmox VE 9 ships. It also means one operating system for the platform base role, one set of apt repositories, and one end-of-support date to watch.
- **Exact pin:** `~> 0.110` would accept any later `0.x`, and in this provider a minor version can break. An exact pin lets no new version in without a reviewed pull request.

## Consequences

- Every provider update is a pull request, so Renovate opens one for each release (several per month).
- Moving to the next Debian release happens together with the next Proxmox VE major version.
- The exact provider version is chosen when the OpenTofu foundation is implemented, as the latest release on that day.

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| `Telmate/proxmox` | Proxmox VE 9 support only in pre-releases |
| `~>` version constraint | Accepts breaking minor versions of a `0.x` provider |
| Debian 12 in the LXC containers | A second Debian release to maintain, older than the host it runs on |
| Ubuntu or Alpine | A second operating system family for the base role |
