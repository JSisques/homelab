# ADR-0018: State bucket on AWS S3

- **Status:** Accepted
- **Date:** 2026-11-27
- **Extends:** [ADR-0007](0007-encrypted-remote-state.md), resolving its bucket provider

## Decision

The OpenTofu state lives in an **AWS S3 bucket** with object versioning enabled, using the S3 backend with `use_lockfile = true`.

## Context

ADR-0007 required the state to be offsite, written automatically, encrypted client-side, and versioned, and proposed AWS S3 or Backblaze B2.

Two writers can apply changes: the deploy agent, and the owner's laptop (bootstrap, and host network changes applied by hand, [ADR-0015](0015-automated-proxmox-host.md)). Without locking, two simultaneous applies can corrupt the state.

## Reasoning

`use_lockfile` locks the state with S3 conditional writes (`If-None-Match`), available since OpenTofu 1.10.

| Provider | Versioning | Conditional writes |
|----------|------------|--------------------|
| AWS S3 | Yes | Yes (AWS documentation) |
| Backblaze B2 | Yes | Could not be confirmed on 2026-11-27 |
| Cloudflare R2 | No | Rejected in ADR-0007 |

AWS S3 is the only option confirmed to meet every requirement. The state is a few kilobytes, so the cost is negligible.

## Consequences

- Requires an AWS account with a payment card.
- The AWS credentials go in the `.env` ([ADR-0006](0006-secrets-management.md)). They should only grant access to this bucket.
