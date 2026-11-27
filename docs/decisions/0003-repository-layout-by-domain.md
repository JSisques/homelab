# ADR-0003: Repository layout by domain

- **Status:** Accepted (folder name `platform` proposed)
- **Date:** 2026-11-27

## Decision

The repository root is organised **by domain** (`network/`, `monitoring/`, `media/`...), not by tool (`ansible/`, `opentofu/`). Everything a domain needs lives in its folder: its LXC definitions, Ansible configuration, Compose files, and alert rules.

A separate `platform/` folder holds **only what is installed inside every machine** (common base, Docker, Grafana Alloy) and the base that creates an empty LXC.

## Context

In the previous repository, `stirling-pdf` lived in five places across three root folders:

```
ansible/playbooks/stirling-pdf.yaml
ansible/roles/stirling-pdf/
services/stirling-pdf/
config/hosts.yaml
config/services.yaml
```

Removing it safely meant remembering all five.

## Reasoning

The test: **can a service be removed by deleting one folder, without leaving anything behind?** Only the domain layout passes.

For the shared folder, "used in several places" was rejected as the rule: Traefik and Prometheus are used by everything and still belong to `network` and `monitoring`. The difference is that Docker is **installed in every LXC**, while Traefik **runs in one** and is reached over the network.

## Consequences

- A domain is added, reviewed, and removed as one unit.
- Tool-level conventions (Ansible roles, OpenTofu modules) have to be configured to read from domain folders.
- `platform/` stays small by rule, not by discipline.

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| Layout by tool | One service spread across many folders |
| `shared/` | Becomes the place for anything undecided |
| `config/` | Means everything in infrastructure, and meant the IP inventory in the old repository |
