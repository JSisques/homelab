# Documentation

Everything about this homelab is documented here. If it is not in `docs/`, it does not officially exist.

## Where to find what

| Document | Read it when you want to know |
|----------|-------------------------------|
| [architecture.md](architecture.md) | How the pieces fit together and how a change reaches the server |
| [domains.md](domains.md) | Which services exist, how they are grouped, and why |
| [repository.md](repository.md) | How this GitHub repository is configured |
| [open-questions.md](open-questions.md) | What is still undecided |
| [decisions/](decisions/README.md) | Why each decision was made (Architecture Decision Records) |

## Documentation policy

**Every change ships with its documentation in the same pull request.** A change without documentation is incomplete and must not be merged.

| When you... | Document it in |
|-------------|----------------|
| Make or change an architectural decision | A new ADR in [`decisions/`](decisions/README.md) |
| Add, change, or remove a domain or service | [`domains.md`](domains.md) and `docs/domains/<domain>.md` |
| Change how deployment, releases, or recovery work | [`architecture.md`](architecture.md) |
| Change GitHub settings, CI, or branch protection | [`repository.md`](repository.md) |
| Add a manual step of any kind | The document of the area it belongs to, as exact commands |
| Resolve an open question | Remove it from [`open-questions.md`](open-questions.md) and link the ADR that answers it |

### Rules

- **Accepted ADRs are never edited.** To change a decision, write a new ADR that supersedes the old one and update the old one's status line only.
- **Manual steps are written as commands**, never as descriptions. If a step cannot be scripted, its exact procedure is documented.
- **Recommendations are not decisions.** An ADR that was proposed but not explicitly confirmed stays `Proposed` until it is.
- **Partly proposed ADRs.** When the proposed part is confirmed, only the status line changes. When it is rejected, a new ADR supersedes it.
- **Documentation is in English.**
