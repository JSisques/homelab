# Sisques Labs Landing

Public landing page for Sisques Labs —
[github.com/sisques-labs/sisques-labs-landing](https://github.com/sisques-labs/sisques-labs-landing).
A static Astro site, built into a Docker image and pushed to
`sisqueslabs/sisques-labs-landing` on Docker Hub (and mirrored to
`ghcr.io/sisques-labs/sisques-labs-landing`) by that repo's release-train CI.
This Application just pulls and runs the latest published image — the
cluster never builds the site itself.

No persistent state, no secrets.

## Access

- Public: `https://landing.sisqueslabs.com`, via the Cloudflare Tunnel
  (`services/cloudflared/config.yml`) forwarding to the k3s-server node on
  `NodePort 30080`, see `service.yaml`.

There is no LAN `IP:port` route: `tier: public` in
`config/services.yaml` means the only intended entry point is the tunnel,
same as Gardenia.

## Why NodePort instead of an Ingress

There's no ingress controller deployed in-cluster yet (see
`kubernetes/argocd/README.md`'s "Future Improvements"). Until one exists,
every Kubernetes-hosted public/personal service is exposed the same way as
LXC-hosted ones: a fixed port the Cloudflare Tunnel LXC can reach directly
on the LAN. Revisit this (Traefik or similar, in-cluster) once more than a
couple of services need it.

## Deployment

Managed entirely by Argo CD — see
`kubernetes/argocd/applications/sisqueslabs-landing.yaml`. No manual
`kubectl apply` should be required; push to `main` and Argo CD reconciles.

To roll out a new image build: the `latest` tag is what's pinned here, so a
new push to `sisques-labs-landing`'s `main` branch is picked up on the next
pod restart. Force one with:

```bash
kubectl rollout restart deployment/sisqueslabs-landing -n sisqueslabs-landing
```
