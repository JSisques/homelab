# Grafana

Grafana is the visualization and observability platform for the homelab.

It provides dashboards for Prometheus metrics and other observability data sources.

## Responsibilities

Grafana provides:

- Metrics visualization
- Infrastructure dashboards
- Kubernetes dashboards
- Application dashboards
- Homelab monitoring
- Alert visualization
- Prometheus integration

Grafana is not responsible for collecting metrics.

Prometheus is responsible for metrics collection, while Grafana is responsible for visualization.

## Directory Structure

```text
services/grafana/
├── README.md
├── compose.yml
└── config/
    └── provisioning/
        ├── datasources/
        │   └── prometheus.yaml
        └── dashboards/
            └── dashboards.yaml
```

Additional dashboards can be stored in:

```text
services/grafana/
└── config/
    └── dashboards/
        ├── homelab-test.json
        ├── proxmox.json
        ├── kubernetes.json
        └── services.json
```

## Docker Compose

Grafana is deployed using:

```text
services/grafana/compose.yml
```

The container exposes port:

```text
3000
```

Grafana stores persistent application data in a Docker volume:

```text
grafana-data
```

This prevents Grafana configuration and internal data from being lost when the container is recreated.

## Provisioning

Grafana provisioning allows data sources and dashboards to be configured automatically.

The provisioning directory is mounted into the container:

```text
./config/provisioning
        │
        ▼
/etc/grafana/provisioning
```

This allows Grafana to be configured entirely from Git.

## Prometheus

Prometheus is the primary metrics data source.

The expected architecture is:

```text
Proxmox
   │
   ├── Node Exporter
   │
   ▼
Prometheus
   │
   ▼
Grafana
```

For Kubernetes:

```text
K3s
 │
 ├── kube-state-metrics
 ├── node-exporter
 └── application metrics
          │
          ▼
      Prometheus
          │
          ▼
        Grafana
```

Grafana should use the internal Prometheus address rather than the public reverse-proxy URL.

## Datasource Provisioning

The Prometheus datasource should be provisioned automatically.

Example:

```text
services/grafana/config/provisioning/datasources/prometheus.yaml
```

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

The exact hostname depends on the deployment architecture.

If Prometheus runs in another LXC, use its internal homelab address instead, for example:

```text
http://192.168.0.24:9090
```

## Dashboards

Dashboards should be version-controlled whenever possible.

Example:

```text
services/grafana/config/dashboards/
├── homelab-test.json
├── proxmox.json
├── kubernetes.json
└── services.json
```

This makes dashboards reproducible.

A fresh Grafana installation should be able to recreate the dashboards from the repository.

## Test Dashboard

The initial test dashboard can be used to verify the complete monitoring pipeline:

```text
Exporter
   │
   ▼
Prometheus
   │
   ▼
Grafana
   │
   ▼
Test Dashboard
```

The dashboard should contain simple metrics such as:

- CPU usage
- Memory usage
- Disk usage
- Network traffic
- Prometheus target status

## Networking

Grafana is exposed through the homelab reverse proxy:

```text
https://grafana.home.arpa
```

Traffic flows through:

```text
Client
  │
  ▼
Reverse Proxy
  │
  ▼
Grafana LXC
  │
  ▼
Docker
  │
  ▼
Grafana
```

The internal Grafana port is:

```text
3000
```

## Monitoring Grafana

Grafana itself should be monitored using Uptime Kuma.

```text
Grafana
   │
   ▼
Uptime Kuma
   │
   ▼
Availability monitoring
```

Prometheus can additionally monitor Grafana metrics if required.

## Deployment

The deployment process is:

```text
Terraform
    │
    ▼
Grafana LXC
    │
    ▼
Ansible
    │
    ├── Install Docker
    ├── Create application directories
    ├── Copy compose.yml
    ├── Copy provisioning configuration
    └── Start Docker Compose
             │
             ▼
          Grafana
```

Terraform is responsible only for creating the LXC.

Ansible is responsible for configuring the host and deploying Grafana.

The Grafana application configuration is stored in:

```text
services/grafana/
```

## Local Development

Grafana can be started locally with:

```bash
cd services/grafana
docker compose up -d
```

Stop it with:

```bash
docker compose down
```

Follow the logs with:

```bash
docker compose logs -f grafana
```

## Configuration Changes

Configuration should preferably be changed in Git.

For example:

```text
Edit provisioning
       │
       ▼
git commit
       │
       ▼
git push
       │
       ▼
Deployment pipeline
       │
       ▼
Ansible
       │
       ▼
Grafana LXC
```

Manual changes made directly inside the Grafana container should be avoided when the same configuration can be represented in the repository.

## Source of Truth

The repository is the source of truth for:

- Docker Compose configuration
- Datasource provisioning
- Dashboard provisioning
- Version-controlled dashboards

Terraform is the source of truth for:

- LXC existence
- CPU
- Memory
- Disk
- Network

Ansible is the source of truth for:

- Host configuration
- Docker installation
- Application deployment

## Architecture

```text
                         Git Repository
                              │
              ┌───────────────┴───────────────┐
              │                               │
       Terraform config                 Grafana config
              │                               │
              ▼                               ▼
        Grafana LXC                    services/grafana/
              │                               │
              └───────────────┬───────────────┘
                              ▼
                           Ansible
                              │
                              ▼
                         Docker Compose
                              │
                              ▼
                           Grafana
                              │
                              ▼
                         Prometheus
```

The goal is for Grafana to be completely reproducible from the repository.
