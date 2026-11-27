# Repository configuration

How the GitHub repository `JSisques/homelab` is configured, and what is still pending.

## Applied settings

Applied on 2026-11-27 with the `github-repo-setup` skill and verified through the GitHub API.

| Setting | Value |
|---------|-------|
| Visibility | Public |
| Description | `Infrastructure as code for my homelab: one Proxmox server, rebuilt from this repository alone.` |
| Topics | `ansible`, `docker-compose`, `gitops`, `homelab`, `infrastructure-as-code`, `lxc`, `opentofu`, `proxmox`, `release-please`, `self-hosted` |
| Default branch | `main` |
| `allow_squash_merge` | `true` |
| `allow_merge_commit` | `false` |
| `allow_rebase_merge` | `false` |
| `delete_branch_on_merge` | `true` |
| `squash_merge_commit_title` | `PR_TITLE` |
| `squash_merge_commit_message` | `PR_BODY` |
| Local branch | Renamed from `master` to `main` before the first commit |

The repository was made public so branch protection is available on the free plan; private repositories return `HTTP 403: Upgrade to GitHub Pro or make this repository public`.

### Commands used

```bash
gh api -X PATCH repos/JSisques/homelab \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY

gh repo edit JSisques/homelab --visibility public --accept-visibility-change-consequences

gh api -X PATCH repos/JSisques/homelab \
  -f "description=Infrastructure as code for my homelab: one Proxmox server, rebuilt from this repository alone."

gh repo edit JSisques/homelab --add-topic \
  homelab,infrastructure-as-code,proxmox,ansible,docker-compose,gitops,self-hosted,release-please,lxc,opentofu

git branch -m master main
git config branch.main.merge refs/heads/main
```

## Labels and milestones

Work is planned as atomic issues: one issue is one unit of behavior, delivered with its tests and documentation in one pull request.

| Label | Meaning |
|-------|---------|
| `platform` | `platform/` domain: Proxmox host, LXC base, base of every LXC |
| `control` | `control/` domain: deploy agent and its LXC |
| `decision` | A design decision to take and record as an ADR |

| Milestone | Contents |
|-----------|----------|
| `platform` | Release 1, part 1: the ground every domain stands on, plus the repository baseline |
| `control` | Release 1, part 2: the deploy agent, its LXC, release-please and the bootstrap |

Milestones group work by domain; they are not versions ([ADR-0013](decisions/0013-first-version-and-pre-1-0-behaviour.md)). Each later domain gets its own label and milestone when its work is planned.

```bash
gh label create platform --color 1D76DB --description "platform/ domain: host, LXC base, every-LXC base"
gh label create control --color 5319E7 --description "control/ domain: deploy agent and its LXC"
gh label create decision --color FBCA04 --description "A design decision to take and record as an ADR"
gh api repos/JSisques/homelab/milestones -f title=platform -f "description=..."
gh api repos/JSisques/homelab/milestones -f title=control -f "description=..."
```

## Pending: branch protection

Blocked until two things exist:

1. ~~The `main` branch on GitHub.~~ Done: first push on 2026-11-27 (`d18f418`).
2. A first CI run, which provides the real check names. Check names are never invented. On 2026-11-27, `main` had 0 check runs.

Then:

```bash
# List the check names from the latest commit on main
gh api repos/JSisques/homelab/commits/main/check-runs --jq '.check_runs[].name'
```

Require them with `strict: true`, a pull request before merging (0 approvals), **admin enforcement with no bypass**, and no push restrictions. Admin enforcement is required because `RELEASE_PLEASE_TOKEN` acts as the owner: with a bypass, the token could push straight to `main` ([ADR-0027](decisions/0027-release-please-token.md)).

## Secrets

| Secret | Used by | Details |
|--------|---------|---------|
| `RELEASE_PLEASE_TOKEN` | release-please workflow only, on push to `main` | Fine-grained token, this repository only, no expiration ([ADR-0027](decisions/0027-release-please-token.md)) |

## Public repository rules

Everything pushed here is public and stays in history, even after deletion.

- Secrets never enter the repository. Only `.env.example` with empty values ([ADR-0006](decisions/0006-secrets-management.md)).
- gitleaks runs in CI as a safety net.
- Self-hosted GitHub runners are not used: on a public repository, a pull request from a fork can run code on them ([ADR-0004](decisions/0004-pull-based-deployment.md)).
