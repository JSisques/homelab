# Blog

Personal blog — [github.com/JSisques/blog](https://github.com/JSisques/blog).
A static Astro site, built into a Docker image and pushed to `jsisques/blog`
on Docker Hub (and mirrored to `ghcr.io/jsisques/blog`) by that repo's
release-train CI. This Application just pulls and runs the latest published
image — the cluster never builds the site itself.

No persistent state, no secrets.

## Access

- Personal: `https://blog.jsisques.net`, via the Cloudflare Tunnel
  (`services/cloudflared/config.yml`) forwarding to the k3s-server node on
  `NodePort 30083`, see `service.yaml`.

There is no LAN `IP:port` route: `tier: personal` in
`config/services.yaml` means the only intended entry point is the tunnel,
same reasoning as the `public` tier used by sisqueslabs-landing/daysoff,
just under the `jsisques.net` domain instead of `sisqueslabs.com`.

## Why NodePort instead of an Ingress

See `kubernetes/applications/sisqueslabs-landing/README.md#why-nodeport-instead-of-an-ingress`
— same reasoning, no in-cluster ingress controller yet.

## Deployment

Managed entirely by Argo CD — see
`kubernetes/argocd/applications/blog.yaml`. No manual `kubectl apply`
should be required; push to `main` and Argo CD reconciles.

To roll out a new image build: the `latest` tag is what's pinned here, so a
new push to `blog`'s `main` branch is picked up on the next pod restart.
Force one with:

```bash
kubectl rollout restart deployment/blog -n blog
```
