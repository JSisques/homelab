# Proxmox Backup Server Ansible Role

Installs [Proxmox Backup Server](https://www.proxmox.com/en/proxmox-backup-server) on a dedicated VM and points its datastore at an NFS export on the NAS.

Unlike every other role in this repo, PBS is **not** a Docker Compose service — it's installed as a native Debian package from Proxmox's own APT repository, so this role has no `docker` dependency (see `meta/main.yml`: only `common` + `node-exporter`).

## Topology note

Proxmox officially recommends running PBS on separate hardware from the Proxmox VE host(s) it backs up — a backup that lives on the same box it protects is a weaker guarantee. This repo runs it as a VM on the same node for now (a homelab trade-off, not best practice), but the actual backup **data** lives on the NAS over NFS, not on local disk. If this VM is lost, a fresh PBS install pointed at the same NFS export recovers the datastore and its catalog.

## Responsibilities

- Add the `pbs-no-subscription` APT repository and install `proxmox-backup-server`.
- Mount the NAS NFS export (`pbs_nas_export`, **adjust the default to your real export path**) at `pbs_mount_path`.
- Register that mount as a PBS datastore (`pbs_datastore_name`), idempotently — checks `proxmox-backup-manager datastore list` first.

## What this role does NOT automate

PBS's web UI (`https://<pbs-ip>:8007`) is still needed once for:

1. Setting a PBS user/API token for Proxmox VE to authenticate with.
2. Adding this PBS instance as a **Storage** backend in Proxmox VE (*Datacenter → Storage → Add → Proxmox Backup Server*), using its IP, the datastore name above, and that token.
3. Creating the actual backup job (which guests, schedule, retention/prune policy).

These are one-time, credential-bearing steps that don't belong in Git any more than the Cloudflare Tunnel's credentials do — see `services/cloudflared/README.md` for the same reasoning applied there.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/pbs.yaml
```
