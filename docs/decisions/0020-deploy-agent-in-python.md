# ADR-0020: Deploy agent in Python, run by a systemd timer

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

The deploy agent ([ADR-0004](0004-pull-based-deployment.md)) is **a script of our own, written in Python, run by a systemd timer** in the `control` LXC. It calls `tofu` and `ansible-playbook` directly. It is tested with pytest.

## Context

The agent's responsibilities were already decided in other ADRs. `ansible-pull` was the alternative.

| Responsibility | Source | Covered by `ansible-pull` |
|----------------|--------|---------------------------|
| Find the latest GitHub **release** | ADR-0004 | No: it clones a branch or ref |
| Compare its major with `DEPLOY_MAX_MAJOR` | ADR-0008 | No |
| Remember failed versions and skip them | ADR-0009 | No |
| Run OpenTofu | ADR-0007 | No |
| Run Ansible | ADR-0004 | **Yes** |
| Health check after deploying | ADR-0009 | No |
| Write deploy metrics | ADR-0005 | No |

`ansible-pull` would need a wrapper script for six of seven responsibilities. At that point the wrapper is the agent.

## Reasoning for Python

| Reason | Detail |
|--------|--------|
| No new dependency | Ansible already needs Python on the machine it runs from |
| Fit for the job | Semver comparison, GitHub API JSON, and metric files are simpler than in Bash with `jq` |
| Testable | It decides what is deployed in the house, so it must have tests |

## Consequences

- One more component to maintain, with its own tests and CI checks.
- The agent's polling interval and health check window are still open ([open questions](../open-questions.md)).
