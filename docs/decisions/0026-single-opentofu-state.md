# ADR-0026: One OpenTofu root module and one state, on a bucket created by hand

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

- The whole homelab is **one OpenTofu root module with one state** in the S3 bucket of [ADR-0018](0018-state-bucket-on-aws-s3.md).
- The state bucket and its IAM user are **created by hand, once**, following the manual steps below. The IAM policy is versioned in the repository as JSON, so the manual step copies a file instead of clicking permissions.

## Context

Every LXC is created from one loop over all `*/lxc.yaml` files ([ADR-0025](0025-lxc-definitions-in-domain-inventories.md)). The bootstrap applies only the control LXC with the same code and state as the agent ([ADR-0011](0011-greenfield-bootstrap.md)). The bucket must exist before any state can be stored in it.

## Reasoning

| Concern | One state | One state per domain |
|---------|-----------|----------------------|
| Loop over every `lxc.yaml` | One loop | One root module, backend, and apply per domain |
| Plan guard ([ADR-0024](0024-plan-guard-before-apply.md)) | Sees the whole change in one plan | One plan per domain |
| Bootstrap | `tofu apply -target` on the control LXC | Has to know which state holds `control` |
| Dependencies (host network before LXC) | Normal references | `terraform_remote_state` and an apply order |
| Blast radius of a mistake | The whole homelab | One domain |

With about ten containers, the only advantage of splitting is a smaller blast radius, and the plan guard already refuses the worst case.

Creating the bucket with OpenTofu would need a second state, kept somewhere other than the bucket it creates, and the IAM user's access key would be stored in that state. The bucket survives every Proxmox wipe, so it is created once in the life of the homelab.

## Manual steps

Done once in the AWS account. Redone only if the bucket or the account is lost.

| Step | Setting |
|------|---------|
| Create the bucket | Block all public access, object versioning enabled |
| Create the IAM user | Attach the policy file versioned in the repository; it grants access to this bucket only |
| Create its access key | Store it in the `.env` ([ADR-0006](0006-secrets-management.md)) |

## Consequences

- One plan and one apply per release.
- A mistake in any domain can, in principle, touch every domain. The plan guard and the health check are the protection.
- Splitting later is possible with `tofu state mv` if the homelab grows enough to need it.
- The bucket is not reproducible from code; its settings are reproducible from this document and the policy file.

## Alternatives rejected

| Alternative | Why not |
|-------------|---------|
| One state per domain | Complexity in the agent, the bootstrap, and the plan guard for a blast radius the guard already limits |
| Bucket created by OpenTofu with a local state | A second state to keep safe, with an access key inside it |
| Bucket created by the bootstrap script | Mixes a once-in-a-lifetime account setup with a step repeated on every rebuild |
