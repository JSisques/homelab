# Strimzi

This directory contains the configuration required to install and manage the Strimzi Kafka Operator.

Strimzi provides Kubernetes-native resources for managing Kafka clusters, topics, users, authentication, and authorization.

## Purpose

Strimzi acts as the control plane for Kafka.

```text
Kubernetes
    │
    ▼
Strimzi Operator
    │
    ├── Kafka
    ├── KafkaNodePool
    ├── KafkaTopic
    └── KafkaUser
```

Instead of manually managing Kafka using CLI commands, Kafka resources are declared in Git and reconciled by Strimzi.

## Installation

The operator is installed using Helm through the Kustomize configuration in this directory.

```text
strimzi/
└── kustomization.yaml
```

The Strimzi version should be pinned rather than using an unversioned or floating release.

## GitOps

Strimzi itself is infrastructure and should be installed before the Kafka custom resources.

The deployment order is:

```text
Strimzi Operator
       │
       ▼
Kafka CR
       │
       ▼
KafkaNodePool
       │
       ├── KafkaTopic
       └── KafkaUser
```

Argo CD is responsible for reconciling the desired state.

## Upgrading Strimzi

Strimzi upgrades should be performed deliberately.

Before upgrading:

1. Check Strimzi compatibility with the current Kafka version.
2. Review the release notes.
3. Update the pinned Helm chart version.
4. Test the change in the homelab.
5. Commit the upgrade.
6. Allow Argo CD to reconcile the change.

Do not automatically upgrade the operator without reviewing compatibility.

## Troubleshooting

Check the operator:

```bash
kubectl get pods -n kafka
```

Check operator logs:

```bash
kubectl logs -n kafka deployment/strimzi-cluster-operator
```

Check Kafka custom resources:

```bash
kubectl get kafka -n kafka
```

Inspect the Kafka resource:

```bash
kubectl describe kafka homelab -n kafka
```
