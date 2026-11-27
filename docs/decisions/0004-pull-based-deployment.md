# ADR-0004: Pull-based deployment

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

A **deploy agent** runs in the `control` LXC, inside the LAN. It polls GitHub for new release tags and applies them locally with OpenTofu and Ansible. **GitHub never connects to the homelab, and GitHub Actions has no deploy step.** The release tag itself is the signal.

## Context

The server sits behind the home router. GitHub is on the internet. Something has to run OpenTofu and Ansible when a release is published.

## Reasoning

| Option | What it exposes | Verdict |
|--------|-----------------|---------|
| GitHub-hosted runner + SSH into the LAN | An open port or tunnel, and an SSH key with access to the whole homelab stored in GitHub | Rejected |
| Self-hosted runner in the LAN | Runs workflow code. GitHub recommends self-hosted runners only for private repositories, because fork pull requests can run code on them. This repository is public | Rejected |
| Agent inside the LAN that pulls | Nothing: no inbound ports, no LAN credentials outside the LAN | **Chosen** |

A webhook from GitHub to the agent was also rejected. It adds no information the agent does not get by polling, only lower latency, and it needs an endpoint reachable from the internet.

## Consequences

- Deploys start within one polling interval, not instantly.
- A failed deploy happens silently inside the house unless the agent reports it ([ADR-0005](0005-deploy-observability.md)).
- SSH keys to the other LXC containers never leave the LAN.
