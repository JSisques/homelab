# Argo CD

Argo CD is the GitOps control plane for the homelab Kubernetes cluster.

It continuously monitors the Git repository and reconciles the Kubernetes cluster with the desired state defined in Git.

The goal is to avoid manually deploying and configuring Kubernetes workloads.

## Architecture

```text id="q0p2s7"
                         GitHub
                            │
                         git push
                            │
                            ▼
                         Argo CD
                            │
                    ┌───────┼────────┐
                    │       │        │
                    ▼       ▼        ▼
                  Kafka  Monitoring  Apps
                    │       │        │
                    ▼       ▼        ▼
                   K3s    K3s       K3s
```

Git is the source of truth.

If the Kubernetes cluster differs from the desired state in Git, Argo CD attempts to reconcile it.

## Directory Structure

```text id="j1j8i6"
argocd/
├── README.md
│
├── applications/
│   ├── kafka.yaml
│   ├── monitoring.yaml
│   ├── homepage.yaml
│   ├── uptime-kuma.yaml
│   └── ...
│
└── projects/
    └── homelab.yaml
```

As the platform grows, additional Argo CD configuration can be added here.

## Applications

Each Argo CD `Application` defines how a specific component is deployed.

Example:

```yaml id="g9pfu8"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kafka
  namespace: argocd
spec:
  project: homelab

  source:
    repoURL: https://github.com/YOUR_USERNAME/homelab.git
    targetRevision: main
    path: kubernetes/infrastructure/kafka

  destination:
    server: https://kubernetes.default.svc
    namespace: kafka

  syncPolicy:
    automated:
      prune: true
      selfHeal: true

    syncOptions:
      - CreateNamespace=true
```

This creates the following relationship:

```text id="xq3cgr"
Argo CD Application
        │
        ▼
Git repository
        │
        ▼
kubernetes/infrastructure/kafka/
        │
        ▼
Kubernetes resources
```

## Automated Synchronization

Applications should normally use automated synchronization.

```yaml id="m8j2q0"
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

### Self Heal

If someone manually changes a Kubernetes resource, Argo CD detects the difference and restores the desired state from Git.

```text id="2e8f3m"
Git
 │
 ▼
Desired State
 │
 ▼
Argo CD
 │
 ▼
Kubernetes
```

### Prune

If a resource is removed from Git, Argo CD can remove the corresponding Kubernetes resource.

This means that deleting infrastructure from Git can be destructive.

Changes to critical resources should therefore be reviewed carefully.

## Projects

Argo CD Projects can be used to group applications and restrict what they are allowed to deploy.

The homelab uses a dedicated project:

```text id="4m7c8w"
homelab
```

This can eventually enforce:

- Allowed repositories
- Allowed namespaces
- Allowed Kubernetes resource types
- Application boundaries
- Deployment permissions

## Application Categories

Applications should be organized according to their role.

### Infrastructure

```text id="7q1qgk"
kubernetes/infrastructure/
├── kafka/
├── monitoring/
├── traefik/
├── cert-manager/
└── ...
```

### Applications

```text id="jjx0hs"
kubernetes/applications/
├── gardenia/
├── identity-service/
├── rag/
└── ...
```

The distinction is useful because infrastructure components provide services consumed by applications.

```text id="b3l6bq"
Infrastructure
     │
     ├── Kafka
     ├── PostgreSQL
     ├── Redis
     ├── Monitoring
     └── Traefik
             │
             ▼
       Applications
             │
             ├── Gardenia
             ├── Identity Service
             └── RAG Platform
```

## Deployment Flow

The normal workflow is:

```text id="4jbdw6"
Developer
   │
   │ edit YAML
   ▼
Git
   │
   │ push
   ▼
GitHub
   │
   ▼
Argo CD
   │
   │ detect change
   ▼
Kubernetes
   │
   ▼
Desired state reached
```

No manual `kubectl apply` should normally be required.

## Sync Status

Useful commands:

```bash id="rj0a4k"
kubectl get applications -n argocd
```

Inspect an application:

```bash id="w6g2d8"
kubectl get application kafka -n argocd -o yaml
```

Check application status:

```bash id="o0m7k8"
kubectl describe application kafka -n argocd
```

## Rollbacks

Because the desired state is stored in Git, the primary rollback mechanism is a Git revert.

```text id="b8r5q1"
Bad commit
    │
    ▼
Git revert
    │
    ▼
Argo CD
    │
    ▼
Previous desired state
```

This keeps infrastructure changes auditable and reproducible.

## Secrets

Secrets should not be committed as plaintext Kubernetes manifests.

Argo CD should eventually integrate with the homelab's secret management strategy.

Potential approaches include:

- SOPS
- External Secrets
- Sealed Secrets
- Vault

The preferred approach should allow encrypted secrets to remain version controlled without exposing their plaintext values.

## Monitoring Argo CD

Argo CD itself should be monitored by the homelab observability stack.

Important metrics include:

- Application sync status
- Application health
- Reconciliation errors
- Repository errors
- Sync failures
- Controller health

The desired architecture is:

```text id="1a0j4y"
Argo CD
   │
   ▼
Prometheus
   │
   ▼
Grafana
```

## Operational Principles

- Git is the source of truth
- Avoid manual Kubernetes changes
- Use automated synchronization where appropriate
- Review destructive changes carefully
- Pin versions of important dependencies
- Keep infrastructure and applications separated
- Keep secrets out of plaintext Git
- Prefer Git reverts for rollbacks
- Every deployed service should have an explicit Argo CD Application

## Future Improvements

The Argo CD setup is expected to evolve toward an application hierarchy.

For example:

```text id="x7l9k2"
                    Root Application
                          │
              ┌───────────┼───────────┐
              │           │           │
        Infrastructure  Platform   Applications
              │           │           │
          ┌───┼───┐       │       ┌───┼────┐
          │   │   │       │       │   │    │
        Kafka DNS  TLS   Monitoring Gardenia RAG
```

This allows new services to be added to Git and automatically become part of the homelab's desired state.

## Related Documentation

- [`../infrastructure/`](../infrastructure/)
- [`../infrastructure/kafka/`](../infrastructure/kafka/)
- [`../applications/`](../applications/)
- [`../../config/services.yaml`](../../config/services.yaml)
