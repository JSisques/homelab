# Alertmanager

[Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) receives firing alerts from Prometheus (`services/prometheus/alerts.yml`) and routes them — currently to Telegram.

## Directory Structure

```text
services/alertmanager/
├── README.md
├── compose.yaml
└── alertmanager.yml.j2
```

`alertmanager.yml.j2` is **not** deployed as a static copy like other services' config — it's rendered by the `monitoring` Ansible role, because the Telegram receiver needs two secrets:

```yaml
monitoring_alertmanager_telegram_bot_token: ""  # from @BotFather
monitoring_alertmanager_telegram_chat_id: 0     # the chat/channel Telegram ID
```

Without them, Alertmanager still starts and Prometheus alerts still fire — they just land in a `null` receiver (nowhere) instead of Telegram. See `ansible/roles/monitoring/README.md` for how to provide the real values.

## Networking

Attaches to the shared external `monitoring` Docker network (see `services/loki/README.md`) so Prometheus can reach it at `http://alertmanager:9093`.

## Deployment

Deployed by the `monitoring` Ansible role alongside Prometheus, Grafana, and Loki onto the shared `monitoring` LXC.
