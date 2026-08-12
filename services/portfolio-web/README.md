# Portfolio Web

My personal developer portfolio — [github.com/JSisques/portfolio-web](https://github.com/JSisques/portfolio-web).
A static Astro site (i18n `es`/`en`, project content sourced from Markdown),
built into a Docker image and pushed to `ghcr.io/jsisques/portfolio-web` by
that repo's CI on every push to its main branch. This service just pulls and
runs the latest published image — the LXC never builds the site itself.

## Access

- LAN: `https://portfolio-web.home.arpa` (via Traefik, see `config/services.yaml`)
- Public: `https://portfolio.jsisques.net` (via the Cloudflare Tunnel, see
  `services/cloudflared/config.yml`)

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/portfolio-web.yaml
```

No persistent state, no secrets — redeploying just pulls the latest image tag.
To roll out a new build, re-run the playbook (or `docker compose pull &&
docker compose up -d` on the host directly).
