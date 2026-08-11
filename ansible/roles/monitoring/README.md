# Monitoring Ansible Role

Deploys the homelab's monitoring stack — Prometheus and Grafana — onto the shared `monitoring` LXC container, using Docker Compose.

Terraform creates the LXC (`terraform/proxmox/lxc.tf`, hostname `monitoring`). This role installs Docker (via the `docker` role) and deploys both applications side by side under `/opt/prometheus` and `/opt/grafana`.

## Responsibilities

- Deploy `services/prometheus/compose.yaml` and `services/prometheus/prometheus.yml` to `{{ monitoring_prometheus_app_dir }}` (default `/opt/prometheus`) and start it.
- Deploy `services/grafana/compose.yaml` and `services/grafana/config/` (dashboard/datasource provisioning) to `{{ monitoring_grafana_app_dir }}` (default `/opt/grafana`) and start it.

`services/prometheus/prometheus.yml` is generated from `config/services.yaml` by `scripts/generation/generate-prometheus.sh` and should not be edited by hand.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/monitoring.yaml
```

Service documentation: [`services/prometheus/README.md`](../../../services/prometheus/README.md), [`services/grafana/README.md`](../../../services/grafana/README.md).
