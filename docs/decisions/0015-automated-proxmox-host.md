# ADR-0015: Automated Proxmox host

- **Status:** Accepted
- **Date:** 2026-11-27
- **Extends:** [ADR-0011](0011-greenfield-bootstrap.md). The bootstrap now starts at installing Proxmox

## Decision

1. **Installation** uses the Proxmox automated installer: an `answer.toml` generated from the repository (with secrets from the `.env`) is embedded into the ISO with `proxmox-auto-install-assistant prepare-iso`. The only manual action is booting the server from the USB stick.
2. **Host configuration** is done by Ansible, in Git, instead of the community `post-pve-install` script:
   - Enterprise repository disabled, no-subscription repository enabled
   - Subscription notice removed
   - Package updates
   - NAS mount, with credentials from the `.env`
   - Network bridge and iGPU passthrough
3. **Host network changes are breaking changes** (`feat!:`, [ADR-0008](0008-release-versioning.md)). The agent does not apply them; the owner does, with console access.

## Context

The previous Proxmox was installed by hand, then configured with [`post-pve-install`](https://community-scripts.org/scripts/post-pve-install) and a manual NAS mount. The owner wants to rebuild after a disk failure with the fewest manual steps.

The automated installer exists since Proxmox VE 8.2 ([wiki](https://pve.proxmox.com/wiki/Automated_Installation)).

## Reasoning

| Problem | Why it matters |
|---------|----------------|
| `post-pve-install` is interactive | It asks questions; its own page recommends answering "yes" to all |
| `post-pve-install` is not ours | It changes when its repository changes. Its last change was on 2026-11-26. Running it again a year later guarantees nothing |
| The agent lives in an LXC attached to the host bridge | Reconfiguring the bridge cuts the agent's network mid-change. If the new configuration is wrong, neither the agent nor SSH can reach the host to fix it |

## Consequences

- From an empty disk to a configured host with no questions asked.
- The `answer.toml` contains the root password, so it is generated at build time and never committed.
- Where the host configuration lives in the repository is still open ([open questions](../open-questions.md)).
