# Homepage

[Homepage](https://gethomepage.dev/) is the dashboard for the homelab. It provides a centralized interface for accessing and monitoring the services running across the infrastructure.

## Responsibilities

Homepage provides:

- Centralized access to homelab services
- Service categorization
- Service links and descriptions
- Infrastructure shortcuts
- Integration with monitoring and infrastructure services
- Service status information where supported

Homepage is not responsible for service monitoring itself. Uptime Kuma and Prometheus provide monitoring and metrics.

## Directory Structure

```text
services/homepage/
├── README.md
├── compose.yml
└── config/
    ├── services.yaml
    ├── settings.yaml
    └── widgets.yaml
```

### `compose.yml`

Docker Compose definition used to run Homepage.

The Compose file is deployed to the Homepage LXC by Ansible.

### `config/`

Contains Homepage configuration.

```text
config/
├── services.yaml
├── settings.yaml
└── widgets.yaml
```

#### `services.yaml`

Defines the services displayed in Homepage.

The source of truth for service metadata is:

```text
config/services.yaml
```

The Homepage configuration is generated from that file by:

```text
scripts/generation/generate-homepage.sh
```

This avoids maintaining the same service information in multiple places.

#### `settings.yaml`

Contains Homepage application settings such as:

- Title
- Theme
- Layout
- Language
- Background
- Display preferences

#### `widgets.yaml`

Contains Homepage widgets and integrations.

## Deployment

Homepage runs in a dedicated LXC container managed by Terraform.

```text
Terraform
    │
    ▼
LXC homepage
    │
    ▼
Ansible
    │
    ├── Docker
    ├── Docker Compose
    └── Homepage configuration
            │
            ▼
        Homepage
```

The LXC infrastructure is defined in:

```text
terraform/proxmox/lxc.tf
```

The service deployment is handled by Ansible.

## Configuration Generation

Homepage service entries should not normally be edited manually.

The source of truth is:

```text
config/services.yaml
```

Run:

```bash
./scripts/generation/generate-homepage.sh
```

to generate:

```text
services/homepage/config/services.yaml
```

The generated file should be treated as an artifact of the source configuration.

## Networking

Homepage is exposed through the homelab reverse proxy:

```text
https://home.home.arpa
```

Traffic flows through:

```text
Client
  │
  ▼
Reverse Proxy
  │
  ▼
Homepage LXC
  │
  ▼
Docker container
```

The internal Docker port is:

```text
3000
```

The reverse proxy is responsible for TLS termination and external routing.

## Monitoring

Homepage itself is monitored by Uptime Kuma.

```text
Homepage
    │
    ▼
Uptime Kuma
    │
    ▼
Service availability
```

Homepage does not replace Prometheus.

Prometheus is responsible for infrastructure and application metrics where exporters or native metrics endpoints are available.

## Adding a Service

To add a service to Homepage:

1. Add the service to:

```text
config/services.yaml
```

2. Run:

```bash
./scripts/generation/generate-homepage.sh
```

3. Review the generated configuration.

4. Commit the changes.

5. Push to Git.

The deployment pipeline will synchronize the updated configuration with the homelab.

## Development

To run Homepage locally:

```bash
cd services/homepage
docker compose up -d
```

Homepage will be available at:

```text
http://localhost:3000
```

To stop it:

```bash
docker compose down
```

## Deployment Architecture

```text
                         Git Repository
                              │
                              ▼
                    config/services.yaml
                              │
                              ▼
              generate-homepage.sh
                              │
                              ▼
              services/homepage/config/
                              │
                              ▼
                         Ansible
                              │
                              ▼
                       LXC: homepage
                              │
                              ▼
                         Docker
                              │
                              ▼
                         Homepage
                              │
                              ▼
                    Reverse Proxy
                              │
                              ▼
                 https://home.home.arpa
```

## Source of Truth

The configuration hierarchy is:

```text
config/services.yaml
        │
        ▼
generate-homepage.sh
        │
        ▼
services/homepage/config/services.yaml
        │
        ▼
Homepage
```

Infrastructure is managed separately:

```text
Terraform → LXC
Ansible   → Host + application deployment
Homepage  → Service dashboard
```

This separation keeps infrastructure, deployment, and application configuration independently manageable.
