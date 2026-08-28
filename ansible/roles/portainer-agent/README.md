# Portainer Agent Ansible Role

Deploys the [Portainer Agent](https://docs.portainer.io/admin/environments/add/docker/agent) container so the Portainer server (`ansible/roles/monitoring/`, see its README) can manage this host's Docker containers.

This is part of the **baseline dependency set** for every Docker LXC/VM — it's listed in the `meta/main.yml` of every service role that also depends on `docker` (the same set documented as `common, node-exporter, promtail, docker` in `AGENTS.md`). It is not a cataloged service: no `config/services.yaml` entry, no Homepage tile, no Prometheus target — same treatment as `node-exporter`/`promtail`.

Standard agent mode is used, not Edge Agent: every host is on the same flat LAN and already reachable by IP from the `monitoring` host, so the Portainer server dials the agent directly on port 9002. This avoids Edge Agent's per-host enrollment key entirely — connecting the agent itself needs no secret at all, only the auto-registration step below does.

The agent always self-signs its own TLS cert against its internal Docker IP (e.g. `172.19.0.2`), never the LAN address Portainer actually dials — this is true regardless of bridge vs. host networking, since the agent has no way to know which address it'll be reached at from outside. Registering it therefore requires `TLSSkipVerify`/`TLSSkipClientVerify`, not a networking change; the Portainer UI's own "Add environment" wizard sets these silently, which is why doing it there "just works" while a naive API call (without those flags) fails with `certificate is valid for 172.x.x.x, not <LAN IP>`.

## Responsibilities

- Deploy `services/portainer-agent/compose.yaml` to `{{ portainer_agent_app_dir }}` (default `/opt/portainer-agent`) and start it.
- If `portainer_api_token` is set, register this host as a Portainer environment via the server's REST API (`POST /api/endpoints`), idempotently — it first checks `GET /api/endpoints` for an existing entry named `{{ inventory_hostname }}` and skips creation if found, so re-running never creates duplicates.

## One-time manual step: the API token

Portainer needs a human-created admin account before anything else can talk to it, so this can't be fully hands-off from the very first deploy:

1. Log into `http://192.168.0.209:9000` (see the `portainer` entry in `config/services.yaml`) and complete the first-run admin setup.
2. Top-right user menu → **My account → Access Tokens** → create one.
3. Provide it as `portainer_api_token` via Ansible Vault or CI secrets (`PORTAINER_API_TOKEN` env var, wired through the Makefile's `ANSIBLE_EXTRA_VARS`) — never commit it.

That's it — from then on, every `make deploy-<service>` (or `make deploy-portainer-agent`) on a Docker host registers it automatically. Without the token, the role still deploys the agent container fine; it just logs a warning and leaves that host to be added by hand (**Environments → Add environment → Docker → Agent**, this host's LAN address from `config/hosts.yaml` and port `9002`).

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/portainer-agent.yaml
```

Also runs automatically as part of every service playbook that depends on it (`make deploy-<service>`), since it's a `meta/main.yml` dependency.
