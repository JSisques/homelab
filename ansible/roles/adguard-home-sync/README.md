# AdGuard Home Sync Ansible Role

Deploys [AdGuardHome-Sync](https://github.com/bakito/adguardhome-sync) on the `adguard-home-2` LXC, using Docker Compose.

Terraform doesn't create a dedicated LXC for this — it runs alongside AdGuard Home itself on `adguard-home-2` (see `ansible/playbooks/adguard-home-sync.yaml`, also targeting `hosts: adguard-home-2`), the same "several roles share one LXC" pattern used by the `monitoring` role for Prometheus/Grafana/Loki/Alertmanager.

## Responsibilities

- Render `config.yaml` (origin/replica URLs + credentials) from Ansible variables — see `defaults/main.yaml` for the full list, all of which must be overridden with real secrets before deploying for real.
- The origin URL is resolved automatically from the generated inventory (`hostvars['adguard-home-1']['ansible_host']`) — no hardcoded IP. The admin API is on port 80 (the seeded config skips the wizard's port 3000).
- Deploy `services/adguard-home-sync/compose.yaml` and start it.

## Requirements

`adguard-home-1` and `adguard-home-2` must already be deployed with the seeded admin credentials (same `ADGUARD_SYNC_*` values this role uses) — see `ansible/roles/adguard-home/README.md`.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/adguard-home-sync.yaml \
  -e "adguard_sync_origin_username=..." \
  -e "adguard_sync_origin_password=..." \
  -e "adguard_sync_replica_username=..." \
  -e "adguard_sync_replica_password=..."
```

(`make deploy-adguard-home-sync` passes these from the matching `ADGUARD_SYNC_*` environment variables instead — see the root `Makefile`.)
