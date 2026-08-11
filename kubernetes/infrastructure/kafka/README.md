# Kafka

This directory contains the declarative configuration for the Kafka platform used by the homelab.

Kafka is deployed on the K3s cluster using [Strimzi](https://strimzi.io/) and is treated as a shared infrastructure service rather than an application-specific dependency.

The goal is to provide a single Kafka cluster that can be consumed by applications regardless of where they are deployed.

```text
                         Homelab Network
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
            K3s               LXC               VM
              │                 │                 │
              └─────────────────┼─────────────────┘
                                │
                         Kafka Cluster
                           (Strimzi)
```

## Responsibilities

This directory manages:

- Kafka cluster configuration
- Kafka node pools
- Kafka storage
- Kafka listeners
- Kafka topics
- Kafka users
- Kafka authentication
- Kafka authorization
- Kafka-related Kubernetes resources

The Strimzi operator itself is managed separately under [`strimzi/`](./strimzi/).

## Directory Structure

```text
kafka/
├── README.md
├── namespace.yaml
├── kustomization.yaml
├── cluster.yaml
├── node-pool.yaml
│
├── strimzi/
│   ├── README.md
│   └── kustomization.yaml
│
├── topics/
│   ├── README.md
│   ├── events.yaml
│   ├── commands.yaml
│   └── audit-events.yaml
│
└── users/
    ├── README.md
    └── applications.yaml
```

## Architecture

The initial cluster uses three Kafka nodes.

```text
K3s
└── Kafka
    ├── Node 0
    ├── Node 1
    └── Node 2
```

The nodes initially act as both Kafka brokers and KRaft controllers.

Kafka uses persistent storage so that broker data survives pod recreation.

## External Access

Kafka is intended to be a shared homelab service.

Applications do not need to run inside Kubernetes to consume Kafka.

The target architecture exposes Kafka through a stable homelab endpoint:

```text
kafka.home.example.com:9094
```

Applications can therefore connect regardless of whether they run on:

- Kubernetes
- LXC containers
- Virtual machines
- Raspberry Pi
- Other machines on the homelab network

Kubernetes-native applications may additionally use the internal Kafka listener.

## GitOps

Kafka resources are reconciled by Argo CD.

```text
Git
 │
 ▼
Argo CD
 │
 ▼
Kubernetes
 │
 ▼
Strimzi
 │
 ├── Kafka
 ├── KafkaNodePool
 ├── KafkaTopic
 └── KafkaUser
```

Changes should be made in Git rather than directly through the Kubernetes API or Kafka CLI whenever possible.

## Topics

Topics are managed declaratively using Strimzi `KafkaTopic` resources.

See [`topics/README.md`](./topics/README.md).

Example:

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: events
spec:
  partitions: 3
  replicas: 3
```

Creating or modifying a topic is therefore a Git change.

## Users

Kafka users are managed using Strimzi `KafkaUser` resources.

See [`users/README.md`](./users/README.md).

Authentication uses SCRAM-SHA-512 and permissions are defined explicitly through Kafka ACLs.

## Operational Principles

- Kafka is infrastructure, not an application
- Topics should be explicitly declared
- Automatic topic creation is disabled
- Applications should use dedicated Kafka users
- Credentials must not be committed in plaintext
- Kafka should not be exposed directly to the public Internet
- Persistent storage is required
- Production-like replication is preferred even in the homelab
- Changes should be made through GitOps

## Monitoring

Kafka is monitored by the homelab observability stack.

The target stack is:

```text
Kafka
 │
 ▼
Prometheus
 │
 ▼
Grafana
```

Important metrics include:

- Broker health
- Under-replicated partitions
- Offline partitions
- Consumer lag
- Request latency
- Throughput
- Controller health
- ISR changes
- Disk usage

## Related Components

- Strimzi: Kafka operator
- K3s: Kubernetes platform
- Argo CD: GitOps deployment
- Prometheus: Metrics
- Grafana: Dashboards
- Uptime Kuma: Availability monitoring

## Deployment

Kafka should normally be deployed through Argo CD.

For local development or troubleshooting, Kubernetes resources can be inspected with:

```bash
kubectl get kafka -n kafka
kubectl get kafkanodepool -n kafka
kubectl get kafkatopic -n kafka
kubectl get kafkauser -n kafka
```

Check Kafka pods:

```bash
kubectl get pods -n kafka
```

Check the Kafka cluster:

```bash
kubectl describe kafka homelab -n kafka
```
