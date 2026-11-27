# ADR-0008: Release versioning and the major-version gate

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

Releases are created by **release-please** from Conventional Commits.

| Commit | Version | Meaning in this homelab |
|--------|---------|-------------------------|
| `fix:` | patch | Corrects something; the agent applies it alone |
| `feat:` | minor | Adds something; the agent applies it alone |
| `feat!:` / `BREAKING CHANGE:` | major | **The agent cannot apply it alone** |

**A change is breaking when it needs manual action outside the repository** (router, phone, laptop, VPN clients) **or destroys data that cannot be recovered.** Example: changing the LAN subnet is breaking; adding `stirling-pdf` is not.

The agent applies a release only if its major version is `<= DEPLOY_MAX_MAJOR`, set in the `.env` of the `control` LXC. For a higher major, it stops and alerts. The owner then:

1. Reads the manual steps in the release notes, written in the `BREAKING CHANGE:` footer of the commit.
2. Performs them.
3. Raises `DEPLOY_MAX_MAJOR`. The next agent run applies the release.

## Context

Applying a subnet change automatically at 3 a.m. would move every LXC while clients still expect the old DNS, leaving the house without internet and without alerts, since Alertmanager moved too.

## Consequences

- Approval of a major release requires access to a file inside the LAN. Someone who compromises the GitHub account cannot force one.
- Every breaking commit must document its manual steps in the footer.
