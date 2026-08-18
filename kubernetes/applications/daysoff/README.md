# Days Off

Vacation bridge calculator —
[github.com/sisques-labs/daysoff](https://github.com/sisques-labs/daysoff).
A static Astro site, built into a Docker image and pushed to
`sisqueslabs/daysoff` on Docker Hub (and mirrored to
`ghcr.io/sisques-labs/daysoff`) by that repo's release-train CI. This
Application just pulls and runs the latest published image — the cluster
never builds the site itself.

No persistent state, no secrets.

## Access

- Public: `https://daysoff.sisqueslabs.com`, via the Cloudflare Tunnel
  (`services/cloudflared/config.yml`) forwarding to the k3s-server node on
  `NodePort 30081`, see `service.yaml`.

There is no LAN `IP:port` route: `tier: public` in
`config/services.yaml` means the only intended entry point is the tunnel,
same as Gardenia and sisqueslabs-landing.

## Why NodePort instead of an Ingress

See `kubernetes/applications/sisqueslabs-landing/README.md#why-nodeport-instead-of-an-ingress`
— same reasoning, no in-cluster ingress controller yet.

## Deployment

Managed entirely by Argo CD — see
`kubernetes/argocd/applications/daysoff.yaml`. No manual `kubectl apply`
should be required; push to `main` and Argo CD reconciles.

To roll out a new image build: the `latest` tag is what's pinned here, so a
new push to `daysoff`'s `main` branch is picked up on the next pod restart.
Force one with:

```bash
kubectl rollout restart deployment/daysoff -n daysoff
```
