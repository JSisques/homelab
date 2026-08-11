# Homelab Storage

Storage is divided between infrastructure data, Kubernetes persistent volumes, and configuration stored in Git. Each stateful service must identify where its data lives and how it is backed up.

## Storage Classes

### Proxmox Storage

Proxmox provides the underlying storage for VM disks and LXC volumes. Terraform should declare disk size and attachment, while host-level storage policy determines the physical backend.

### Kubernetes Persistent Storage

The Kafka node pool uses the K3s `local-path` storage class:

- Three Kafka replicas.
- One 50 GiB persistent claim per node.
- `deleteClaim: false`, so deleting the Kafka resource does not intentionally delete its claims.

`local-path` storage is tied to node-local disks. It is not a replacement for replicated storage or an off-host backup. Node loss can still make data unavailable even when the claim remains.

### Docker Volumes

Prometheus uses the named Docker volume `prometheus-data` for `/prometheus`. The volume must be included in host backups; the Compose file alone does not contain the metric history.

## Data Classification

| Class         | Examples                                            | Recovery priority  |
| ------------- | --------------------------------------------------- | ------------------ |
| Configuration | Git manifests, Compose files, Ansible and Terraform | Highest            |
| Metrics       | Prometheus time series and Grafana dashboards       | Medium             |
| Event data    | Kafka topics and consumer state                     | High               |
| Secrets       | Credentials, keys, certificates                     | Highest, encrypted |
| Cache         | Temporary downloads and derived data                | Low                |

## Storage Rules

- Declare persistent storage in the owning manifest or Compose definition.
- Do not store credentials or tokens in Git.
- Keep capacity, retention, and deletion behavior explicit.
- Monitor free space, inode usage, claim status, and application-level health.
- Test restores, not only backups.
- Treat node-local storage as a failure domain.

## Capacity Planning

Before increasing replicas or retention, check:

1. Available Proxmox storage on the affected node.
2. Kubernetes node-local free space for `local-path` volumes.
3. Replication and retention overhead.
4. Backup destination capacity.
5. Restore time and network bandwidth.

Kafka topic retention and partition counts should be changed deliberately because they affect disk growth and recovery time.

## Backup Scope

Backups should cover:

- This Git repository and its history.
- Terraform state and its remote backend, if used.
- Proxmox VM and LXC backups.
- Kubernetes resource definitions and persistent volume data.
- The Prometheus Docker volume.
- Grafana provisioning and dashboards.
- Secret material in an encrypted backup format.

Configuration backups are not sufficient when a service contains important state outside Git.
