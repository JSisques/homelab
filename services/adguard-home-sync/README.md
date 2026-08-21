# AdGuard Home Sync

[AdGuardHome-Sync](https://github.com/bakito/adguardhome-sync) is a small tool that copies configuration — blocklists, filters, DNS rewrites, client rules — from one AdGuard Home instance (the "origin") to one or more others (the "replicas"), on a schedule.

## Responsibilities

- Keep `adguard-home-2` (the secondary DNS resolver) configured identically to `adguard-home-1` (the primary), without hand-editing both UIs every time a rule changes.
- Nothing else — it has no DNS or ad-blocking function of its own, and isn't a DNS server. If it stops running, both AdGuard instances keep resolving DNS; they just stop staying in sync.

## Directory Structure

```text
services/adguard-home-sync/
├── README.md
└── compose.yaml
```

`config.yaml` (the sync tool's own config, with the origin/replica URLs and credentials) is **not** in this directory — it's templated by `ansible/roles/adguard-home-sync/` from Ansible variables (secrets), the same pattern as `services/n8n/`'s `.env`.

## Configuration

Runs on the `adguard-home-2` LXC (see `ansible/playbooks/adguard-home-sync.yaml`), pulling from `adguard-home-1` over the LAN and pushing to its own local instance.

Both AdGuard Home instances must already be seeded by `ansible/roles/adguard-home` (same `ADGUARD_SYNC_*` credentials). Pass them in as:

```bash
export ADGUARD_SYNC_ORIGIN_USERNAME="..."   # adguard-home-1's admin user
export ADGUARD_SYNC_ORIGIN_PASSWORD="..."
export ADGUARD_SYNC_REPLICA_USERNAME="..."  # adguard-home-2's admin user
export ADGUARD_SYNC_REPLICA_PASSWORD="..."
```

then `make deploy-adguard-home-sync` (after both `make deploy-adguard-home-1` and `make deploy-adguard-home-2` have run at least once).

Sync interval defaults to every 10 minutes (`adguard_sync_cron`, see `ansible/roles/adguard-home-sync/defaults/main.yaml`).

**Note:** the rendered `config.yaml` schema follows the upstream project's config file format as of this writing — check `bakito/adguardhome-sync`'s own README against the pinned image tag before the first real deploy, in case the schema has moved on.

## Local Development

Not designed to be run standalone outside the two real AdGuard instances — there's nothing meaningful to sync against on a laptop.
