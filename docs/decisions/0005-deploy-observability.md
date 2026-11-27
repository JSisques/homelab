# ADR-0005: Deployment observability and dead man's switch

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

1. The deploy agent writes its results as metrics through the Grafana Alloy agent on its LXC: deployed version, last success timestamp, last exit code, and any pending version.
2. **Prometheus, not the agent**, alerts on a failed deploy, on a stale agent metric, and on drift between the deployed version and the latest GitHub release.
3. An **external dead man's switch** receives outbound heartbeats from the homelab and alerts when they stop.
4. Every alert reaches the owner through the existing channel: Alertmanager → Telegram.

## Context

With pull-based deployment ([ADR-0004](0004-pull-based-deployment.md)), a failed deploy produces no red mark in GitHub. It fails inside the house, possibly at 3 a.m.

## Reasoning

| Question | Answer |
|----------|--------|
| Who compares deployed vs. desired version? | Something other than the agent. The watcher cannot be the watched: a dead agent compares nothing. |
| How is a dead agent detected? | Its metric stops updating. Silence becomes a signal. |
| What if the monitoring LXC is down? | Nothing inside the homelab survives a power cut, so the last watcher lives outside it. |
| Should the external watcher probe the homelab? | No. That needs something reachable from the internet. The homelab sends heartbeats out instead, **only while everything is healthy**, so silence covers every failure at once. |

## Consequences

- One alert channel for everything.
- `monitoring` must exist before any other domain ([ADR-0012](0012-rollout-order.md)).
- Depends on one external service for the heartbeat. Provider pending ([open questions](../open-questions.md)).
