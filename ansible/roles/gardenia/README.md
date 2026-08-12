# Gardenia Ansible Role

Prepares the k3s-server node for Gardenia's Postgres storage. Gardenia itself (gardenia-web, gardenia-api, Postgres) is **not** deployed by this role — it's a Kubernetes workload managed declaratively by Argo CD from `kubernetes/applications/gardenia/`, same as Kafka. See that directory's `README.md` for the full deployment story.

## Responsibilities

- Install NFS client utilities and mount the NAS export (`gardenia_postgres_nas_export`, **adjust the default to your real export path**) at `gardenia_postgres_mount_path`.

This mount is what `kubernetes/applications/gardenia/postgres/pv.yaml` (a `hostPath` PersistentVolume) points at — Kubernetes itself has no NFS CSI driver installed on this cluster, so the export is mounted at the OS level first, same pattern as `ansible/roles/obsidian/` and `ansible/roles/jellyfin/`.

## Prerequisites

Before deploying, create an NFS export on the NAS for Gardenia's Postgres data, following the same pattern as `ansible/roles/obsidian/`.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/gardenia.yaml
```

Run this before applying the Argo CD `gardenia` Application (or before letting Argo CD sync it), otherwise the Postgres pod's PV will fail to mount.

## Related Documentation

- `kubernetes/applications/gardenia/README.md` — the actual application deployment (Postgres, gardenia-api, gardenia-web, Ingress).
- `ansible/roles/k3s/README.md` — the cluster this role's mount feeds into.
- `ansible/roles/obsidian/`, `ansible/roles/jellyfin/` — same NFS-mount-from-NAS pattern, used as the model for this role.
