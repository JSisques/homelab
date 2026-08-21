# uptime-kuma-sync Ansible Role

Pushes the monitor list into an already-deployed Uptime Kuma instance, generated from `config/services.yaml`'s existing `uptime: {enabled: true}` blocks — the same field every service already carries, previously read by nothing.

Unlike every other role in this repo, this one doesn't configure a host — it runs entirely on the **control machine** (`hosts: localhost` in `ansible/playbooks/uptime-kuma-sync.yaml`) and talks to Uptime Kuma over its Socket.IO API, because Uptime Kuma has no config file of its own: monitors, notifications, and everything else live in its internal SQLite database, editable only through its UI or that API.

## Responsibilities

- Assert `uptime_kuma_username`/`uptime_kuma_password` are set.
- Run `scripts/sync-uptime-kuma.py` against the live instance (`http://<uptime-kuma host>:3001`, resolved from `hostvars['uptime-kuma']`).

The script itself (not this role) does the actual work: for every service with `uptime.enabled: true`, create or update a matching monitor (`PORT` type if the service has a `blackbox: {module: tcp_connect}` block, `HTTP` type otherwise, using the service's own `url:`), matched and updated **by name** so re-running this doesn't create duplicates. Monitors it created (tagged with a fixed description) are pruned if their service's `uptime.enabled` later goes away or the service is removed from `config/services.yaml` — anything without that tag (created by hand through the UI) is never touched.

## Requirements

The **control machine** (not any LXC) needs:

- `yq` (already required by every `scripts/generation/*.sh` script)
- Python 3 with the [`uptime-kuma-api`](https://pypi.org/project/uptime-kuma-api/) package: `pip install uptime-kuma-api`

## Variables

```yaml
uptime_kuma_url: "http://{{ hostvars['uptime-kuma'].ansible_host }}:3001"

uptime_kuma_username: ""
uptime_kuma_password: ""
```

## Secrets

`uptime_kuma_username`/`uptime_kuma_password` must match the admin account Uptime Kuma's own first-run setup wizard already created — this role never seeds that account, only logs into it. Required — the role fails loudly via `ansible.builtin.assert` if either is empty, same approach as `cookidoo-mcp`/`cloudflared`/`rustfs`/`minecraft`.

Provide real values through Ansible Vault or `-e`/CI secrets.

## Deployment

Runs automatically at the end of `ansible/playbooks/site.yaml` — after every other service, since it wants their `config/hosts.yaml`/`config/services.yaml` state to already be current. Also runnable on its own:

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/uptime-kuma-sync.yaml \
  -e "uptime_kuma_username=$UPTIME_KUMA_USERNAME" \
  -e "uptime_kuma_password=$UPTIME_KUMA_PASSWORD"
```

or, from the repo root:

```bash
make deploy-uptime-kuma-sync
```

## Adding a monitor for a new service

Nothing role- or script-specific — just add (or confirm) `uptime: {enabled: true}` under the service in `config/services.yaml`, same step already required by `config/README.md` for any new service. The next `make deploy-uptime-kuma-sync` (or full `make deploy`) picks it up.

## Related

- `scripts/sync-uptime-kuma.py` — the actual sync logic.
- `ansible/roles/adguard-home-sync/` — a different kind of "sync a live app from config," worth comparing: that one runs as its own long-lived container polling on a cron schedule inside an LXC, because it's syncing two Kuma-external systems (two AdGuard instances) continuously. This one is a one-shot, deploy-time push from `config/services.yaml`, run from the control machine — monitors change only when the service catalog changes, not on a schedule.
