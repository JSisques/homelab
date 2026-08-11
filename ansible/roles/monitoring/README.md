# Monitoring Ansible Role

Deploys the homelab's full observability stack — Prometheus, Grafana, Loki, Alertmanager, and blackbox_exporter — onto the shared `monitoring` LXC container, using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`, hostname `monitoring`). This role installs Docker (via the `docker` role) and deploys all five applications side by side, each in its own directory (`/opt/prometheus`, `/opt/grafana`, `/opt/loki`, `/opt/alertmanager`, `/opt/blackbox-exporter`).

## Responsibilities

- Create a shared external Docker network (`{{ monitoring_docker_network }}`, default `monitoring`) that all stacks attach to — each is still its own Compose project, but without this they'd land on separate per-project networks and couldn't resolve each other by container name (`http://prometheus:9090`, `http://loki:3100`, `http://alertmanager:9093`, `http://blackbox-exporter:9115`).
- Deploy `services/prometheus/{compose.yaml,prometheus.yml,alerts.yml,blackbox-targets.yml}` and start it.
- Deploy `services/grafana/{compose.yaml,config/}` and start it. Its datasources (`services/grafana/config/provisioning/datasources/`) point at Prometheus and Loki over that shared network.
- Deploy `services/loki/{compose.yaml,config.yml}` and start it.
- **Render** (not copy) `services/alertmanager/alertmanager.yml.j2` with the Telegram secrets below, then start Alertmanager.
- Deploy `services/blackbox-exporter/{compose.yaml,config.yml}` and start it — probes HTTP(S) services that have no native `/metrics` endpoint, see [`services/blackbox-exporter/README.md`](../../../services/blackbox-exporter/README.md).

`services/prometheus/prometheus.yml` is generated from `config/services.yaml` and `config/hosts.yaml` by `scripts/generation/generate-prometheus.sh` and should not be edited by hand. `services/prometheus/alerts.yml` and `services/prometheus/blackbox-targets.yml` are hand-authored and ARE meant to be edited directly.

## Alertmanager → Telegram

```yaml
monitoring_alertmanager_telegram_bot_token: ""  # token from @BotFather
monitoring_alertmanager_telegram_chat_id: 0     # numeric chat/channel id
```

Leave them unset and Alertmanager still starts — alerts fire but land in a `null` receiver instead of Telegram (a log line during the playbook run says so). Provide real values via Ansible Vault or CI secrets, the same way `n8n_postgres_password` and `cloudflared_credentials_json` are handled — never commit them.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/monitoring.yaml \
  -e "monitoring_alertmanager_telegram_bot_token=${TELEGRAM_BOT_TOKEN}" \
  -e "monitoring_alertmanager_telegram_chat_id=${TELEGRAM_CHAT_ID}"
```

Service documentation: [`services/prometheus/README.md`](../../../services/prometheus/README.md), [`services/grafana/README.md`](../../../services/grafana/README.md), [`services/loki/README.md`](../../../services/loki/README.md), [`services/alertmanager/README.md`](../../../services/alertmanager/README.md), [`services/blackbox-exporter/README.md`](../../../services/blackbox-exporter/README.md).
