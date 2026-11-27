# Repository configuration

How the GitHub repository `JSisques/homelab` is configured, and what is still pending.

## Applied settings

Applied on 2026-11-27 with the `github-repo-setup` skill and verified through the GitHub API.

| Setting | Value |
|---------|-------|
| Visibility | Public |
| Description | `Infrastructure as code for my homelab: one Proxmox server, rebuilt from this repository alone.` |
| Topics | `ansible`, `docker-compose`, `gitops`, `homelab`, `infrastructure-as-code`, `lxc`, `proxmox`, `release-please`, `self-hosted` |
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
  homelab,infrastructure-as-code,proxmox,ansible,docker-compose,gitops,self-hosted,release-please,lxc

git branch -m master main
git config branch.main.merge refs/heads/main
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

Require them with `strict: true`, no required reviews, no admin enforcement, and no push restrictions.

## Public repository rules

Everything pushed here is public and stays in history, even after deletion.

- Secrets never enter the repository. Only `.env.example` with empty values ([ADR-0006](decisions/0006-secrets-management.md)).
- gitleaks runs in CI as a safety net.
- Self-hosted GitHub runners are not used: on a public repository, a pull request from a fork can run code on them ([ADR-0004](decisions/0004-pull-based-deployment.md)).
