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

Addresses, CPU, memory, and disk size are only ever set in `config/hosts.yaml` — never duplicated by hand in a `.tfvars` file. To add or resize an LXC/VM, edit `config/hosts.yaml` and re-run the generator; `hosts.auto.tfvars.json` is picked up by Terraform automatically (the `*.auto.tfvars.json` naming convention) with no `-var-file` flag needed. It's committed to Git like the repo's other generated artifacts (`ansible/inventory/hosts.yml`, `services/homepage/config/services.yaml`) — CI fails if it's out of date.

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

## Variables

Environment-specific values should be provided through Terraform variables.

Example:

```hcl
proxmox_endpoint = "https://proxmox.home.arpa:8006"
network_bridge   = "vmbr0"
gateway          = "192.168.1.1"
```

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
