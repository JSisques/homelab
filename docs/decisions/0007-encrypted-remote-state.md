# ADR-0007: Encrypted remote infrastructure state

- **Status:** Accepted for the requirements. Tool and provider proposed
- **Date:** 2026-11-27

## Decision

The infrastructure state file must be:

1. **Outside the homelab**, in another physical place and outside the LAN.
2. **Written automatically** on every apply, through a remote backend.
3. **Encrypted before it leaves the house.**
4. **Versioned**, so a corrupted state can be restored.

**Proposed:** OpenTofu instead of Terraform, with the S3 backend (`use_lockfile = true`) on a versioned bucket (AWS S3 or Backblaze B2), and client-side state encryption (`pbkdf2` key provider + `aes_gcm` method). The passphrase is passed through `TF_ENCRYPTION` and stored in the `.env`.

## Context

In the previous repository, `terraform.tfstate` lived on the owner's laptop. It was lost once, and Terraform recreated every LXC as duplicates. The state also contains secrets in plain text.

## Reasoning

| Option | Problem |
|--------|---------|
| Copy by hand, like the `.env` | The state changes on every deploy. A manual copy is always stale, and a stale state is almost as dangerous as none |
| Store it in `rustfs`, the homelab's own S3 | Circular dependency: OpenTofu needs the state to create the `rustfs` LXC. After a disaster, it can never be rebuilt |
| Terraform with server-side encryption | The state travels unencrypted and the bucket provider holds the keys |
| Cloudflare R2 | No object versioning (checked 2026-11-27) |

The general rule: **what describes the infrastructure never lives inside it.**

## Consequences

- Recovery needs only the repository and the `.env`; the passphrase in the `.env` opens the state.
- OpenTofu is a fork of Terraform with the same language and providers. Terraform-only features are not available.
- Losing the passphrase makes the state unreadable. It is covered by the `.env` copies ([ADR-0006](0006-secrets-management.md)).
