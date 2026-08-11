# Kafka Users

This directory contains Kafka users managed through Strimzi `KafkaUser` resources.

Users provide application-level authentication and authorization.

## Architecture

```text
Application
    │
    │ SASL / SCRAM
    ▼
KafkaUser
    │
    ▼
Kafka
```

Strimzi generates the Kubernetes Secret containing the user's credentials.

Applications consume those credentials through Kubernetes Secrets or an external secret management system.

## Structure

```text
users/
├── README.md
└── applications.yaml
```

As the number of applications grows, users should normally be separated:

```text
users/
├── gardenia.yaml
├── identity-service.yaml
├── billing.yaml
└── monitoring.yaml
```

## Authentication

The default authentication mechanism is SCRAM-SHA-512.

Example:

```yaml
authentication:
  type: scram-sha-512
```

Applications should never share credentials unnecessarily.

## Authorization

Kafka ACLs should follow the principle of least privilege.

For example, an application that only consumes events should not receive write permissions.

```yaml
authorization:
  type: simple
  acls:
    - resource:
        type: topic
        name: events
        patternType: literal
      operations:
        - Read
```

An application that produces events may receive:

```yaml
operations:
  - Write
```

Avoid granting broad permissions such as unrestricted access to every topic unless there is a specific operational reason.

## Application Users

Each significant application should have its own Kafka identity.

Example:

```text
gardenia
identity-service
billing
notification-service
```

This provides:

- Better security
- Easier credential rotation
- Clear ownership
- Better auditing
- More precise ACLs

## Secrets

Kafka credentials must never be committed to Git in plaintext.

Strimzi generates a Kubernetes Secret automatically.

Example:

```bash
kubectl get secret -n kafka
```

For workloads outside Kubernetes, credentials should be distributed using an appropriate secret management mechanism rather than copying passwords into source code.

Potential future integrations include:

- External Secrets
- SOPS
- Vault
- Ansible Vault

## Creating a User

Create a dedicated `KafkaUser`:

```yaml
apiVersion: kafka.strimzi.io/v1
kind: KafkaUser
metadata:
  name: gardenia
  namespace: kafka
  labels:
    strimzi.io/cluster: homelab
spec:
  authentication:
    type: scram-sha-512
```

Then define only the ACLs required by the application.

## Operational Rules

- One identity per application
- Use least-privilege ACLs
- Never commit plaintext credentials
- Do not share credentials between unrelated applications
- Rotate credentials when required
- Review permissions when topics change

## Troubleshooting

List users:

```bash
kubectl get kafkausers -n kafka
```

Inspect a user:

```bash
kubectl describe kafkauser gardenia -n kafka
```

List generated secrets:

```bash
kubectl get secrets -n kafka
```

Check the user status:

```bash
kubectl get kafkauser gardenia -n kafka -o yaml
```
