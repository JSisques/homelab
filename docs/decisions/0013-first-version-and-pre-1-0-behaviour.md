# ADR-0013: First version and pre-1.0 behaviour

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

- The first release is **`v0.1.0`**.
- release-please keeps its **default pre-1.0 behaviour** (`bump-minor-pre-major: false`): the first breaking change bumps straight to `v1.0.0`.
- **The version measures compatibility, not milestones.** `v1.0.0` arrives with the first change that needs manual action outside the repository ([ADR-0008](0008-release-versioning.md)), however many domains exist at that point.
- The agent starts with `DEPLOY_MAX_MAJOR=0`.

## Context

Under semver, `0.x` versions are allowed to break between minor releases. release-please offers two behaviours for breaking changes before `1.0.0` (checked in its documentation on 2026-11-27):

| `bump-minor-pre-major` | `feat!:` on `v0.1.0` gives | Major-version gate |
|------------------------|----------------------------|--------------------|
| `false` (default) | `v1.0.0` | Works: the agent stops at major `1` |
| `true` | `v0.2.0` | **Blind**: major stays `0`, the agent applies it alone |

While the homelab is being built, breaking changes are frequent, so the second option would apply them automatically.

## Consequences

- The gate protects from the first release.
- `v1.0.0` may arrive early, for example with an IP plan change during the `monitoring` release. Accepted by the owner.
- Marking a release as "official" is not done with the version number. If ever needed, it uses something else, such as a GitHub milestone.

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| `bump-minor-pre-major: true` | Leaves the major-version gate blind for the whole `0.x` series |
| Start at `v1.0.0` | No reason; the owner chose `v0.1.0` |
