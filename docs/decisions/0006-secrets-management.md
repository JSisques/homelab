# ADR-0006: Secrets management

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

| Location | Contents |
|----------|----------|
| Repository (public) | `.env.example` with every key and empty values. gitleaks runs in CI |
| `control` LXC | The real `.env`, gitignored. The only copy the agent reads |
| NAS | A copy, in a separate physical failure domain |
| Apple Notes locked note | An encrypted offsite copy |

## Context

The previous repository had no defined place for secrets: Telegram bot token, Cloudflare tokens, WireGuard keys, database passwords. This repository is public.

## Reasoning

| Threat | Covered by |
|--------|------------|
| Secret committed by mistake | gitleaks in CI |
| `control` LXC disk dies | NAS copy |
| Fire, flood, or theft takes NAS and server together | Offsite copy |
| Offsite copy read by the storage provider | Must be encrypted. A plain file in a cloud drive is rejected |

The Apple Passwords app was checked and rejected: it only has a notes field per password entry, with no secure notes or attachments. Apple Notes locked notes are encrypted with a key derived from a passphrase (PBKDF2 + SHA-256), attachments included, and sync through iCloud.

Losing the `.env` means regenerating every token, key, and password by hand.

## Consequences

- The `.env` changes rarely, so copying it by hand is acceptable. State that changes on every deploy is handled differently ([ADR-0007](0007-encrypted-remote-state.md)).
- After any `.env` change, both copies must be updated by hand.
