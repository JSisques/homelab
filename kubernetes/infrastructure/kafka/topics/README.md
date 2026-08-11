# Kafka Topics

This directory contains the declarative definitions of Kafka topics used by the homelab.

Topics are managed through Strimzi `KafkaTopic` resources.

## Why Topics Are Managed as Code

Kafka topics should not normally be created manually.

Instead:

```text
Git
 │
 ▼
KafkaTopic
 │
 ▼
Strimzi
 │
 ▼
Kafka Topic
```

This makes topic configuration:

* Version controlled
* Reviewable
* Reproducible
* Auditable
* Automatically deployed

## Structure

```text
topics/
├── README.md
├── events.yaml
├── commands.yaml
└── audit-events.yaml
```

## Topic Naming

Topic names should describe the business or infrastructure event being transported.

Examples:

```text
events
commands
audit-events
```

For applications, prefer explicit names:

```text
gardenia.events
gardenia.commands
identity.events
billing.events
```

Avoid generic names such as:

```text
test
data
messages
stuff
```

unless they have a clear purpose.

## Partitions

Partitions should be chosen according to expected throughput and consumer parallelism.

Example:

```yaml
spec:
  partitions: 3
```

Increasing partitions later is possible, but partition count should be considered carefully because it affects ordering and consumer architecture.

## Replication

Homelab topics should normally use a replication factor of three when the Kafka cluster has three brokers.

```yaml
spec:
  replicas: 3
```

This allows Kafka to tolerate a broker failure while maintaining availability.

## Retention

Retention should be explicitly configured where appropriate.

Example:

```yaml
config:
  retention.ms: 604800000
```

This keeps messages for seven days.

Long-lived event streams should use retention appropriate to their purpose and available storage.

## Creating a Topic

Create a new YAML file:

```text
topics/gardenia-events.yaml
```

Example:

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: gardenia.events
  namespace: kafka
  labels:
    strimzi.io/cluster: homelab
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 604800000
    cleanup.policy: delete
```

Commit and push the change.

Argo CD will reconcile the resource and Strimzi will create the topic.

## Operational Rules

* Do not create topics manually unless troubleshooting
* Do not enable automatic topic creation
* Use explicit replication
* Configure retention intentionally
* Avoid unnecessary partition counts
* Document topics with important business meaning
* Treat topic deletion as a potentially destructive operation

## Troubleshooting

List topics:

```bash
kubectl get kafkatopics -n kafka
```

Inspect a topic:

```bash
kubectl describe kafkatopic gardenia.events -n kafka
```

Check Kafka resources:

```bash
kubectl get kafka -n kafka
```
