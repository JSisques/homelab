# n8n

n8n is the workflow automation platform for the homelab.

It is used to automate processes and integrate services, APIs, infrastructure and external systems.

## Responsibilities

n8n provides:

- Workflow automation
- API integrations
- Webhooks
- Scheduled jobs
- Infrastructure automation
- Service integrations
- Notifications
- Data processing

n8n is deployed as a Docker Compose application inside a dedicated LXC container.

## Directory Structure

```text
services/n8n/
├── README.md
├── compose.yml
└── .env.example
```

## Architecture

n8n uses PostgreSQL as its database.

```text
                     n8n LXC
                        │
                 Docker Compose
                        │
              ┌─────────┴─────────┐
              │                   │
              ▼                   ▼
             n8n              PostgreSQL
              │                   │
              ▼                   ▼
        n8n workflows        Persistent data
```

## Docker Compose

The service is defined in:

```text
services/n8n/compose.yml
```

The Compose stack contains:

- n8n
- PostgreSQL

n8n listens internally on:

```text
5678
```

PostgreSQL listens internally on:

```text
5432
```

PostgreSQL should not be exposed outside the Docker network.

## Persistence

n8n requires persistent storage.

The following Docker volumes are used:

```text
n8n-data
postgres-data
```

The n8n data directory is:

```text
/home/node/.n8n
```

PostgreSQL stores its data in:

```text
/var/lib/postgresql/data
```

The volumes must be included in the homelab backup strategy.

## Database

PostgreSQL is used instead of SQLite.

This provides a more production-oriented setup and makes the architecture easier to evolve if n8n later needs to scale.

The database configuration is supplied through environment variables.

Secrets must never be committed to Git.

Use:

```text
.env.example
```

as the template for local configuration.

## Networking

n8n is exposed through the homelab reverse proxy:

```text
https://n8n.home.arpa
```

Traffic flows through:

```text
Client
  │
  ▼
Reverse Proxy
  │
  ▼
n8n LXC
  │
  ▼
Docker
  │
  ▼
n8n
```

The internal application port is:

```text
5678
```

The reverse proxy is responsible for TLS termination.

## Webhooks

n8n workflows can expose webhooks through:

```text
https://n8n.home.arpa/
```

The `WEBHOOK_URL` environment variable must match the externally accessible URL.

This is important when workflows are triggered by external services.

## Timezone

The default timezone is:

```text
Europe/Madrid
```

Both:

```text
TZ
GENERIC_TIMEZONE
```

should use the same timezone.

This is especially important for scheduled workflows.

## Monitoring

n8n should be monitored by Uptime Kuma.

```text
n8n
 │
 ▼
Uptime Kuma
 │
 ▼
Availability monitoring
```

If application metrics are required, they can be integrated with Prometheus separately.

## Deployment

Terraform creates the LXC:

```text
terraform/proxmox/lxc.tf
```

The LXC is configured by Ansible:

```text
ansible/
├── playbooks/
│   └── n8n.yml
└── roles/
    └── n8n/
```

The deployment flow is:

```text
Terraform
    │
    ▼
LXC n8n
    │
    ▼
Ansible
    │
    ├── Install Docker
    ├── Install Docker Compose
    ├── Create application directories
    ├── Configure secrets
    ├── Copy compose.yml
    └── Start Compose
             │
             ▼
       ┌─────────────┐
       │     n8n     │
       └──────┬──────┘
              │
              ▼
          PostgreSQL
```

## Local Development

Start n8n locally:

```bash
cd services/n8n

cp .env.example .env

docker compose up -d
```

View logs:

```bash
docker compose logs -f n8n
```

Stop the stack:

```bash
docker compose down
```

## Configuration

Application configuration belongs in:

```text
services/n8n/compose.yml
```

Secrets belong outside Git.

The repository may contain:

```text
.env.example
```

but must never contain:

```text
.env
```

or real credentials.

## Backups

The following data must be backed up:

```text
n8n-data
postgres-data
```

A backup should be tested by restoring it to a separate environment.

Backing up only the Docker Compose file is not sufficient because workflows and credentials are stored in the persistent data.

## Security

n8n should not be directly exposed to the public Internet without additional security controls.

Recommended architecture:

```text
Internet
   │
   ▼
Cloudflare / VPN
   │
   ▼
Reverse Proxy
   │
   ▼
n8n
```

Webhook endpoints should be exposed only when required.

Credentials used by workflows must be managed as secrets and must not be committed to the repository.

## Source of Truth

Terraform manages:

- LXC existence
- CPU
- Memory
- Disk
- Network

Ansible manages:

- Host configuration
- Docker
- Docker Compose deployment
- Secrets injection

This directory manages:

- Docker Compose configuration
- n8n application configuration
- Service documentation

## Architecture

```text
                         Git Repository
                              │
              ┌───────────────┴───────────────┐
              │                               │
       Terraform config                  n8n service
              │                               │
              ▼                               ▼
          n8n LXC                       compose.yml
              │                               │
              └───────────────┬───────────────┘
                              ▼
                           Ansible
                              │
                              ▼
                         Docker Compose
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
                   n8n              PostgreSQL
                    │
                    ▼
              Reverse Proxy
                    │
                    ▼
             n8n.home.arpa
```

The goal is for the n8n deployment to be reproducible from the repository while keeping secrets and persistent application data outside Git.
