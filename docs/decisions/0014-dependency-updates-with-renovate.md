# ADR-0014: Dependency updates with Renovate

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

**Renovate** proposes every version bump as a pull request: container images, OpenTofu providers, Ansible collections, and GitHub Actions.

## Context

Every release is deployed automatically ([ADR-0004](0004-pull-based-deployment.md)), so a version bump merged to `main` reaches the server without further action. Something has to propose those bumps, and each one has to be reviewable. The previous repository already used Renovate.

## Consequences

- Updates arrive as reviewable PRs, never as silent drift on the server.
- Which commit type Renovate uses decides whether an update creates a release at all, and of what kind. Still open ([open questions](../open-questions.md)).
