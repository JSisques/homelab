# ADR-0012: Rollout order: one domain per release

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

Each release adds **one domain**, and it is verified before the next one starts.

```
1. control + platform   → the agent and the base of every LXC
2. monitoring           → the ability to see whether anything works
3. remaining domains    → each one once what it depends on exists
```

## Context

The previous repository was built quickly and without control. This one is built step by step.

## Reasoning

Every safety mechanism in [ADR-0005](0005-deploy-observability.md) (agent metrics, drift alerts, Telegram, the dead man's switch) runs through `monitoring`. Without it, every later release would be deployed blind.

**First build what lets you see, then what you want to see.** The same rule orders the remaining domains: a domain goes in once the domains it depends on exist.

## Consequences

- The homelab offers no user-facing services until the third release.
- The order of the remaining domains is still open ([open questions](../open-questions.md)).
