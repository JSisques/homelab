# ADR-0001: One deployment path, no Kubernetes

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

Every service is deployed the same way: **Proxmox LXC → Ansible → Docker Compose**. Kubernetes, k3s, Argo CD, Rancher, Kafka, and the Raspberry Pi workers are removed.

## Context

The previous repository (`homelab-old`) had two orchestrators competing:

- Ansible with Docker Compose, running nearly every real service (Jellyfin, n8n, AdGuard, Traefik...).
- k3s with Argo CD, running three small applications plus Rancher and Kafka.

Adding a service meant first choosing which of the two paths to use. The owner concluded Kubernetes brought nothing to this homelab.

## Consequences

- One way to add, change, and remove a service.
- No cluster to operate, upgrade, or back up.
- Workloads that would need Kubernetes features (scheduling across nodes, self-healing across hosts) are out of scope.

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| Move everything to Kubernetes | A single server gains nothing from a cluster scheduler, and adds a whole platform to maintain |
| Keep both paths | The root cause of the previous mess |
