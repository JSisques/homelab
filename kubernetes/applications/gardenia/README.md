# Gardenia

Gardenia's first Kubernetes deployment: `gardenia-web` + `gardenia-api` + Postgres, all in the `gardenia` namespace on the single-node k3s cluster (`k3s-server`, see `ansible/roles/k3s/`). This is the first application-level workload on that cluster — Kafka (`kubernetes/infrastructure/kafka/`) is infrastructure and still not applied.

## Architecture

```text
                        Internet
                           │
                  gardenia.sisqueslabs.com
                           │
                  Cloudflare Tunnel (services/cloudflared/)
                           │
                  http://gardenia.home.arpa:80
                           │
                       AdGuard Home
                  (DNS rewrite → k3s-server)
                           │
                           ▼
                  k3s built-in Traefik (ingressClassName: traefik)
                           │
                     Ingress (ingress.yaml)
                     path-routed by host
                    ┌──────┴──────┐
                    │             │
                 / → web     /api, /graphql → api
                    │             │
                    ▼             ▼
            gardenia-web    gardenia-api
             (Deployment)    (Deployment)
                                  │
                                  ▼
                           gardenia-postgres
                          (Deployment + PVC)
                                  │
                                  ▼
                    hostPath → /mnt/nas/gardenia-postgres
                          (NFS mount on k3s-server,
                           see ansible/roles/gardenia/)
```

`gardenia-web`'s browser bundle calls `NEXT_PUBLIC_API_URL=/api` and `NEXT_PUBLIC_GRAPHQL_URL=/graphql` (the image's build-time defaults — see `gardenia-web/Dockerfile`), so `gardenia-web` and `gardenia-api` must be reachable on the **same origin**. That's what `ingress.yaml` does: one host (`gardenia.home.arpa`), path-routed to two backend Services.

## Directory Structure

```text
kubernetes/applications/gardenia/
├── README.md
├── kustomization.yaml
├── namespace.yaml
├── ingress.yaml
├── postgres/
│   ├── pv.yaml               # hostPath PV, backed by the NFS mount below
│   ├── pvc.yaml
│   ├── secret.example.yaml   # template — copy to secret.yaml, apply manually
│   ├── deployment.yaml
│   └── service.yaml
├── api/
│   ├── configmap.yaml
│   ├── secret.example.yaml   # template — copy to secret.yaml, apply manually
│   ├── deployment.yaml
│   └── service.yaml
└── web/
    ├── deployment.yaml
    └── service.yaml
```

## Prerequisites (one-time, outside Git)

Nothing here is applied automatically yet — this directory describes the desired state, same as the rest of this repo (see root `README.md`'s "Project Status"). Before Argo CD can bring this up cleanly:

1. **NFS export on the NAS** for Postgres data, following the same pattern as `ansible/roles/obsidian/` (see `ansible/roles/gardenia/README.md` for the expected path).
2. **Mount it on k3s-server**:
   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts.yml playbooks/gardenia.yaml
   ```
   This creates `/mnt/nas/gardenia-postgres` on the node — `postgres/pv.yaml`'s `hostPath` depends on it existing first.
3. **Secrets** — copy each `secret.example.yaml` to `secret.yaml` (gitignored) with real values and apply manually:
   ```bash
   export KUBECONFIG=~/.kube/homelab-k3s.yaml
   kubectl apply -f kubernetes/applications/gardenia/postgres/secret.yaml
   kubectl apply -f kubernetes/applications/gardenia/api/secret.yaml
   ```
   `postgres/secret.yaml`'s `POSTGRES_PASSWORD` and `api/secret.yaml`'s `DATABASE_PASSWORD` must match — they're the same credential from two sides of the same connection. See each template's header comment for a `kubectl create secret` one-liner and how to generate `JWT_SECRET` / `OAUTH_TOKEN_ENC_KEY` / `OAUTH_STATE_SECRET`.
4. **DNS**: add an AdGuard Home rewrite for `gardenia.home.arpa` → `192.168.1.31` (k3s-server), the same manual step already used for the rest of `*.home.arpa` (see root `README.md`'s Domains section) — except this one points at the k3s node directly, not the Traefik LXC.
5. **GHCR image visibility**: `api/deployment.yaml` and `web/deployment.yaml` pull `ghcr.io/sisques-labs/gardenia-api` / `gardenia-web` with no `imagePullSecrets`. If those GHCR packages are private, either make them public or add a pull secret (`kubectl create secret docker-registry ghcr-pull-secret ...`) and reference it from both Deployments.

Then apply the Argo CD project + Application (see `ansible/roles/k3s/README.md` for the general flow):

```bash
export KUBECONFIG=~/.kube/homelab-k3s.yaml
kubectl apply -f kubernetes/argocd/projects/
kubectl apply -f kubernetes/argocd/applications/gardenia.yaml
```

## OAuth

Google/GitHub/Apple login are left unconfigured (`api/configmap.yaml` has no client id/secret) — email/password (JWT) only for this first deployment. `OAUTH_TOKEN_ENC_KEY` and `OAUTH_STATE_SECRET` are still required at boot regardless (see `gardenia-api/src/core/config/env.validation.ts`) and live in `api/secret.example.yaml`.

## Known gaps

- **MongoDB**: `gardenia-api/.env.example` lists `MONGO_URI`, but nothing in `gardenia-api/src` reads it — no MongoDB is deployed here.
- **Prometheus scraping**: `config/services.yaml`'s `gardenia` monitoring block (`http://gardenia:3000/metrics`) predates this deployment and isn't reachable from the `monitoring` LXC — that bare hostname only resolves inside the cluster's own DNS. Wiring real cross-network scraping (or pointing `gardenia-api` at the homelab's OTel Collector instead, like `docker-compose.yml`'s local dev stack does) is follow-up work, not part of this change.
- **Versions**: `api/deployment.yaml` and `web/deployment.yaml` pin specific release tags. Bump them by hand when a new version ships — Argo CD's `selfHeal` will not do this for you (by design, see `kubernetes/argocd/README.md`).
- **Node pinning**: `postgres/pv.yaml`'s `nodeAffinity` targets a node named `k3s-server` — verify that matches `kubectl get nodes` once the cluster actually exists.

## Related Documentation

- `kubernetes/argocd/README.md` — Argo CD conventions this Application follows.
- `ansible/roles/gardenia/README.md` — the NFS mount prerequisite.
- `ansible/roles/k3s/README.md` — the cluster itself.
- `services/cloudflared/config.yml` — the public ingress entry for `gardenia.sisqueslabs.com`.
