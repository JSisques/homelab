# ADR-0023: CI checks

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

| Check | Protects |
|-------|----------|
| **PR title follows Conventional Commits** | The version release-please computes |
| gitleaks | Against secrets committed to a public repository ([ADR-0006](0006-secrets-management.md)) |
| ruff + pytest | The deploy agent ([ADR-0020](0020-deploy-agent-in-python.md)) |
| `tofu fmt -check` + `tofu validate` | OpenTofu code |
| ansible-lint | Ansible code |
| shellcheck | The bootstrap script |
| actionlint | The GitHub Actions workflows |
| Documentation link check | Links between documents |

Two rules:

1. **Each check is added in the same pull request as the first code it checks.** No check exists before its code.
2. **Required checks have no path filters.** A required check that does not run because a pull request does not touch its paths stays pending and blocks the merge.

## Context

Branch protection needs real check names from a first CI run ([repository.md](../repository.md)).

## Reasoning

Squash merges use the pull request title as the commit message (`squash_merge_commit_title = PR_TITLE`), and release-please computes versions from commit messages ([ADR-0008](0008-release-versioning.md)). A title it cannot parse produces no release; an accidental `feat!:` produces a major version. Validating the title is therefore the check that protects the version.

## Consequences

- Branch protection is configured, and extended, as each check first runs on `main`.
- Every check runs on every pull request, including documentation-only ones.
