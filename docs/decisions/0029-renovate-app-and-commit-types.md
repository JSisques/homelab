# ADR-0029: Renovate runs as the hosted app, and its commit type follows what reaches the server

- **Status:** Accepted
- **Date:** 2026-11-27
- **Extends:** [ADR-0014](0014-dependency-updates-with-renovate.md), resolving its commit types

## Decision

Renovate runs as the **hosted Mend Renovate GitHub App**, installed by the owner. Its commit type depends on whether the update changes something running on the server:

| Update | Commit type | Result |
|--------|-------------|--------|
| Something that runs on the server, minor or patch: container images, the `bpg/proxmox` provider, Ansible collections | `fix(deps)` | Patch release, deployed automatically |
| Something that runs on the server, major | `feat(deps)!` | Major release, held by the agent's major-version gate ([ADR-0008](0008-release-versioning.md)) |
| Something that only runs in CI: GitHub Actions, linters | `chore(deps)` | No release, no deploy |

A major update is breaking by default because Renovate cannot know whether it needs manual steps. Before merging, the owner either:

- writes the manual steps in a `BREAKING CHANGE:` footer in the pull request body, which becomes the commit message (`squash_merge_commit_message = PR_BODY`) and the release notes; or
- retitles it to `fix(deps)` when it needs no manual step, so it deploys automatically.

## Context

The version computed by release-please belongs to the homelab, not to the dependency. An image update that fixes a vulnerability adds no capability to the homelab: it keeps doing what it did, so it is a fix. A major update such as Postgres 16 to 17 cannot start on the previous major's data without a manual dump and restore; deployed automatically, the service would go down and the health check would mark the version as failed.

The owner installed the app before this decision. On 2026-11-27 the repository had no Renovate pull request and no `renovate.json`, as expected: Renovate does not onboard a repository with no dependencies.

## Consequences

- An update of a running dependency reaches the server within one polling interval of its merge.
- CI-only updates accumulate on `main` without creating releases.
- Pull requests opened by the app run CI, because the app is its own identity, not `GITHUB_TOKEN` ([ADR-0027](0027-release-please-token.md)). No token of the owner's is stored for Renovate.
- Every major update needs the owner's attention before it is merged.
- Renovate's pull request titles must pass the PR title check ([ADR-0023](0023-ci-checks.md)).

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| Renovate as a workflow in this repository | Needs a token with write access to contents and pull requests, a second secret with the deploy power of `RELEASE_PLEASE_TOKEN` |
| `chore(deps)` for every update | Security fixes would wait for an unrelated release |
| `fix(deps)` for every update, majors included | A major that needs manual steps would be deployed automatically and break the service |
