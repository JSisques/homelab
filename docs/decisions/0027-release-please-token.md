# ADR-0027: release-please uses a fine-grained token, and only `main` can be deployed

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

release-please authenticates with **`RELEASE_PLEASE_TOKEN`**, a repository Actions secret holding a fine-grained personal access token:

| Property | Value |
|----------|-------|
| Repository access | `JSisques/homelab` only |
| Permissions | Read and write on `contents`, `pull requests`, and `issues` |
| Expiration | None (accepted risk, see below) |

Four measures limit what a leaked token can do:

| Measure | What it prevents |
|---------|------------------|
| `main` protection: pull request required, required checks, **no admin bypass** | A direct push to `main`, even with the token, since the token acts as the owner |
| The agent checks that the release tag's commit is an ancestor of `origin/main` before deploying (`git merge-base --is-ancestor`) | A release on a loose branch, or one created by hand |
| Only the release-please workflow references the secret, and it runs only on push to `main` | Another workflow exposing it |
| No workflow uses `pull_request_target`, enforced by a CI check | A fork pull request running with the token |

## Context

Events created with `GITHUB_TOKEN` do not start workflows. Release pull requests opened with it would get no CI, and branch protection would block their merge. The owner created the fine-grained token on 2026-11-27.

## Consequences

- **Whoever holds the token can deploy to the homelab.** With write access to `contents` and `pull requests`, they can open a pull request, let CI pass, and merge it themselves. release-please needs both permissions, so any token it uses has this power. Requiring one approval does not help: a sole owner cannot approve their own pull requests.
- **The token never expires,** so a leak has no end date. The owner accepted this to avoid release-please stopping on an expiry date. Possible improvement: set an expiry (for example, one year) and record its rotation.
- The owner can no longer push to `main` directly. Every change, including documentation, goes through a pull request.
- A GitHub Actions secret cannot be read from the web interface; only a running workflow that requests it can.

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| `GITHUB_TOKEN` | Release pull requests get no CI |
| GitHub App | Its tokens are short-lived, but the private key that mints them is a permanent secret with the same power, and it is one more thing to create and maintain |
| Branch protection with admin bypass | The token itself could push to `main` |
