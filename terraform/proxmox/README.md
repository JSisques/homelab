# Proxmox Infrastructure

This directory contains the Terraform configuration for managing the homelab infrastructure running on Proxmox.

Terraform is responsible for defining and provisioning virtual machines, LXC containers, storage, and other Proxmox resources.

It does not configure the operating systems or deploy applications. Host configuration is handled by Ansible, while Kubernetes workloads are managed by Kubernetes and Argo CD.

## Responsibilities

Terraform manages:

- LXC containers
- Virtual machines
- Virtual disks
- Network interfaces
- Cloud-init configuration
- Proxmox resource allocation
- Infrastructure dependencies

The following tools are responsible for other layers:

```text
Terraform
    │
    ▼
Proxmox infrastructure
    │
    ├── VMs
    └── LXC containers
            │
            ▼
        Ansible
            │
            ▼
      Host configuration
            │
            ▼
        K3s / Docker
            │
            ▼
        Argo CD
            │
            ▼
    Kubernetes workloads
```

## Directory Structure

```text
terraform/proxmox/
├── README.md
├── versions.tf
├── provider.tf
├── variables.tf
├── locals.tf
├── network.tf
├── storage.tf
├── vms.tf
├── lxc.tf
├── outputs.tf
├── terraform.tfvars.example
└── hosts.auto.tfvars.json   # generated, see below — do not edit manually
```

## LXC Containers

LXC containers are defined generically in:

```text
lxc.tf
```

A single `resource "proxmox_virtual_environment_container" "lxc"` with `for_each = var.lxc_network` provisions every entry in that map — there's no per-service HCL to write or forget. `lxc_network` (and `k3s_nodes`, for VMs) come from `hosts.auto.tfvars.json`, which is **generated from `config/hosts.yaml`**:

```bash
./scripts/generation/generate-terraform-vars.sh
```

Addresses, Proxmox VMID (`octet` unless `vmid:` is set), CPU, memory, and disk size are only ever set in `config/hosts.yaml` — never duplicated by hand in a `.tfvars` file. To add or resize an LXC/VM, edit `config/hosts.yaml` and re-run the generator; `hosts.auto.tfvars.json` is picked up by Terraform automatically (the `*.auto.tfvars.json` naming convention) with no `-var-file` flag needed. It's committed to Git like the repo's other generated artifacts (`ansible/inventory/hosts.yml`, `services/homepage/config/services.yaml`) — CI fails if it's out of date.

Examples of services that already run in dedicated LXC containers include:

- Monitoring
- Homepage
- Uptime Kuma
- Docker workloads
- Infrastructure utilities

Terraform defines the infrastructure of these containers, such as:

- Container name
- Proxmox node
- CPU allocation
- Memory
- Disk
- Network configuration
- IP address
- Operating system template
- Tags (see below)

Application configuration should not be placed in Terraform.

For example:

```text
Terraform
    │
    ▼
LXC monitoring
    │
    ▼
Ansible
    │
    ├── Prometheus
    ├── Grafana
    └── Node Exporter
```

## Virtual Machines

Virtual machines are defined generically in `vms.tf`, the same way LXCs are: one `resource "proxmox_virtual_environment_vm" "vm"` with `for_each = var.vm_nodes`, generated from every `type: vm` host in `config/hosts.yaml` via `generate-terraform-vars.sh`.

Every VM is **cloned** from an existing Proxmox template (`clone { vm_id = var.vm_template_id }`) — Terraform doesn't install an OS, it clones one. Create that template once (a cloud-init-ready Debian/Ubuntu image converted to a template VM) and set its VM ID as `vm_template_id`.

`vm_nodes` currently provisions:

```text
Proxmox
│
├── pbs               (Proxmox Backup Server)
└── (K3s nodes, once config/hosts.yaml gets type: vm entries for them)
```

K3s nodes and PBS share the same generic VM mechanism — what differs is the Ansible role that configures each one afterwards.

## Tags

Every LXC container and VM gets Proxmox `tags` set automatically, so they can be filtered/grouped in the Proxmox UI by what they're for rather than by the already-obvious `lxc`/`vm` resource type. Tags are the generic `category` (from `config/services.yaml`, e.g. `monitoring`, `networking`, `downloads`, `media`, `automation`, `productivity`, `utilities`, `applications`, `infrastructure`) of the services matched by each host's `role` list in `config/hosts.yaml` — not the individual role/service names. `generate-terraform-vars.sh` resolves `role` -> `category` and writes the result into the `tags` field of `lxc_network`/`vm_nodes` in `hosts.auto.tfvars.json`; `lxc.tf`/`vms.tf` pass it straight through as `tags = each.value.tags`. A role with no matching `services.yaml` entry contributes no tag; a host left with no category at all falls back to `tags: ["infrastructure"]`. E.g. the `monitoring` LXC (`role: [prometheus, grafana, loki, alertmanager, otel-collector, tempo]`, all `category: Monitoring`) ends up tagged just `monitoring`. Add/rename a `role`, or change a service's `category`, and re-run `make terraform-vars` (or `make plan`/`make apply`, which do it automatically) to update the tags.

## Proxmox-side Setup (one-time, outside Terraform)

Terraform clones VMs and calls the Proxmox API — it does not create the template it clones from, nor the account it authenticates as. Both need to exist in Proxmox before the first `terraform apply`.

### VM template (`vm_template_id`)

`vms.tf` clones `var.vm_template_id` and relies on an `initialization` block (cloud-init) to set IP/user/SSH key, so the template must be built from a **cloud image**, not an installer ISO converted to a template (that path has no cloud-init drive and the `initialization` block has nothing to configure):

```bash
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
qm create 9000 --name debian-12-cloudinit --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 debian-12-generic-amd64.qcow2 local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

Use that VM ID as `vm_template_id`. This is unrelated to `debian_template` (the LXC `.tar.zst`, fetched via `pveam`).

### Service account and API token

Authenticate as a dedicated `terraform` user with a least-privilege role, not `root@pam`. Create, on the Proxmox side:

1. A user `terraform@pve`.
2. A role (e.g. `TerraformProvision`) with: `Datastore.AllocateSpace`, `Datastore.Audit`, `Pool.Allocate`, `SDN.Use`, `Sys.Audit`, `Sys.Console`, `Sys.Modify`, `Sys.PowerMgmt`, `VM.Allocate`, `VM.Audit`, `VM.Clone`, `VM.Config.CDROM`, `VM.Config.CPU`, `VM.Config.Cloudinit`, `VM.Config.Disk`, `VM.Config.HWType`, `VM.Config.Memory`, `VM.Config.Network`, `VM.Config.Options`, `VM.Migrate`, `VM.Monitor`, `VM.PowerMgmt`.
3. A group `terraform`, with that role assigned at path `/` (propagated).
4. The `terraform` user added to the `terraform` group.
5. An API token on that user (privilege separation off, so the token inherits the group's role).

The resulting `user@realm!tokenid=uuid` string is `proxmox_api_token` (`TF_VAR_proxmox_api_token`).

> **macOS/zsh warning:** typing `export TF_VAR_proxmox_api_token="user@realm!tokenid=uuid"` directly at an interactive zsh prompt triggers history expansion on the `!`, silently stripping it (and the following `-`) from the value. `terraform plan` then fails with a confusing "API token must be in the format ..." error even though what you typed was correct. Write the `export` to a file with a quoted heredoc (`<<'EOF'`) and `source` it instead — that path skips history expansion.

For the full click-by-click walkthrough, see the website guide [Preparar Proxmox para Terraform](../../website/src/content/docs/guides/preparar-proxmox.md).

## Variables

Environment-specific values should be provided through Terraform variables.

Example:

```hcl
proxmox_endpoint = "https://192.168.0.157:8006"
```

`network_bridge`, `gateway`, and `network_mask` are **not** set by hand — they come from `config/hosts.yaml`'s `network.lan` block (the same single source of truth as every host's address), written into `hosts.auto.tfvars.json` by `scripts/generation/generate-terraform-vars.sh` alongside `lxc_network`/`vm_nodes`. Change the LAN subnet by editing `config/hosts.yaml`, not `terraform.tfvars`.

Sensitive values must not be committed.

Use:

```text
terraform.tfvars
```

locally or environment variables / a secret management solution.

A safe example configuration can be committed as:

```text
terraform.tfvars.example
```

## Terraform State

Terraform state should not be committed to Git.

The following files should be ignored:

```text
terraform.tfstate
terraform.tfstate.*
.terraform/
*.tfvars
```

with the exception of explicitly safe example files such as:

```text
terraform.tfvars.example
```

For a homelab, local state can be used initially.

A remote state backend can be introduced later if required.

## Workflow

Initialize Terraform:

```bash
terraform init
```

Format the configuration:

```bash
terraform fmt -recursive
```

Validate the configuration:

```bash
terraform validate
```

Review changes:

```bash
terraform plan
```

Apply changes:

```bash
terraform apply
```

Destroy infrastructure:

```bash
terraform destroy
```

Destructive operations should always be reviewed carefully.

## Infrastructure Changes

The preferred workflow is:

```text
Edit Terraform
      │
      ▼
terraform fmt
      │
      ▼
terraform validate
      │
      ▼
terraform plan
      │
      ▼
Review
      │
      ▼
terraform apply
```

Infrastructure changes should be committed to Git after they have been verified.

## Design Principles

### Infrastructure as Code

All Proxmox infrastructure should be reproducible from Terraform.

### Declarative Configuration

Terraform describes the desired infrastructure state rather than a sequence of manual Proxmox operations.

### Separation of Concerns

Terraform creates infrastructure.

Ansible configures hosts.

Kubernetes manages Kubernetes workloads.

Argo CD reconciles Kubernetes with Git.

### No Application Configuration

Do not use Terraform to configure application internals.

For example, Terraform should create:

```text
LXC monitoring
```

but Ansible should install and configure:

```text
Prometheus
Grafana
Node Exporter
```

### Reproducibility

The goal is to make the infrastructure recoverable from the repository without relying on undocumented manual Proxmox configuration.
