# Disaster Recovery

This runbook describes how to rebuild the homelab after a host, storage, cluster, or configuration failure. It is a starting point; recovery targets and backup locations must be recorded once the production setup is finalized.

## Recovery Objectives

Document these values for each critical service:

| Service                | RPO | RTO | Recovery source                              |
| ---------------------- | --- | --- | -------------------------------------------- |
| Proxmox infrastructure | TBD | TBD | Proxmox backup                               |
| K3s and Argo CD        | TBD | TBD | Git and cluster backup                       |
| Kafka                  | TBD | TBD | Persistent volume backup / topic replication |
| Prometheus             | TBD | TBD | `prometheus-data` backup                     |
| Grafana                | TBD | TBD | Provisioning files and database backup       |

RPO is the maximum acceptable data loss. RTO is the maximum acceptable restoration time.

## Recovery Order

```text
Backup access and credentials
             |
             v
Network, DNS, and Proxmox
             |
             v
VMs / LXCs and base operating systems
             |
             v
K3s control plane and nodes
             |
             v
Argo CD and infrastructure operators
             |
             v
Stateful services and persistent data
             |
             v
Applications, monitoring, and external access
```

## Rebuild Procedure

1. Confirm that the Git repository, Terraform state, encrypted secrets, and backups are reachable.
2. Recreate the Proxmox network and required storage using the infrastructure definitions.
3. Restore or provision the VMs and LXCs, then apply Ansible base configuration.
4. Install K3s and verify node readiness and cluster connectivity.
5. Install Argo CD and connect it to this repository.
6. Deploy Strimzi and the Kafka resources through Argo CD.
7. Restore persistent data before starting workloads that depend on it.
8. Deploy monitoring and standalone services, including the Prometheus data volume.
9. Re-enable DNS, ingress, and Cloudflare routes only after internal health checks pass.
10. Validate service-to-service connectivity, dashboards, alerts, and backups.

## Kafka Recovery

Kafka uses three broker/controller replicas and persistent claims. Do not delete claims during a rebuild unless the data has been intentionally discarded and a restore has been verified.

After restoration, verify:

```bash
kubectl get kafka,kafkanodepool,pvc -n kafka
kubectl get pods -n kafka
kubectl get kafkatopic,kafkauser -n kafka
```

Check broker health, replication, under-replicated partitions, topic availability, and application credentials before allowing producers and consumers to resume.

## Prometheus and Grafana Recovery

Restore the `prometheus-data` Docker volume before starting Prometheus when historical metrics matter. Grafana dashboards provisioned from `services/grafana/` can be recreated from Git, but dashboards or settings stored only in the Grafana database require a separate database backup.

## Validation Checklist

- All Proxmox hosts and required guests are reachable.
- K3s reports every expected node as `Ready`.
- Argo CD applications are `Synced` and `Healthy`.
- Persistent volume claims are bound and mounted.
- Kafka topics have the expected replication and no under-replicated partitions.
- Prometheus is scraping its targets.
- Grafana dashboards load and alerts reach their notification targets.
- DNS and ingress expose only approved services.
- A fresh backup and a restore test have been recorded.

## Recovery Testing

Perform a restore exercise periodically in an isolated environment. Record the date, versions, commands, missing prerequisites, restore duration, and follow-up changes in this repository or its operations log.
