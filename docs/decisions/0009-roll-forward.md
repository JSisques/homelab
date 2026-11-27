# ADR-0009: Roll forward instead of rollback

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

A broken release is undone **in Git, never on the server**: `git revert` (or a fix) → new patch release → the agent applies it like any other.

After each deploy, the agent checks service health for a few minutes. If services fail, it **marks the version as failed, does not retry it, and alerts**. It does not roll back on its own.

## Context

Automatic local rollback after a failed health check was considered.

## Reasoning

| Problem with local rollback | Effect |
|-----------------------------|--------|
| The agent obeys the latest GitHub release | It rolls back to `v1.2.0`, polls GitHub, sees `v1.3.0`, and deploys it again. An infinite loop |
| Many images migrate their database when a new version starts (Jellyfin, n8n, Postgres) | The previous image may no longer read the data. Rolling back blindly can break more than it fixes |

With roll forward, GitHub and the server agree again, the drift alert clears by itself, and history records what broke and why.

## Consequences

- Recovery time includes a commit, a release PR, and one polling interval.
- The agent needs to remember which versions failed.
