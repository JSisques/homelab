# Portainer Agent Ansible Role

Deploys the [Portainer Agent](https://docs.portainer.io/admin/environments/add/docker/agent) container so the Portainer server (`ansible/roles/monitoring/`, see its README) can manage this host's Docker containers.

This is part of the **baseline dependency set** for every Docker LXC/VM — it's listed in the `meta/main.yml` of every service role that also depends on `docker` (the same set documented as `common, node-exporter, promtail, docker` in `AGENTS.md`). It is not a cataloged service: no `config/services.yaml` entry, no Homepage tile, no Prometheus target — same treatment as `node-exporter`/`promtail`.

Standard agent mode is used, not Edge Agent: every host is on the same flat LAN and already reachable by IP from the `monitoring` host, so the Portainer server dials the agent directly on port 9001. This avoids Edge Agent's per-host enrollment key entirely — no secrets, no manual bootstrap variable.

## Responsibilities

- Deploy `services/portainer-agent/compose.yaml` to `{{ portainer_agent_app_dir }}` (default `/opt/portainer-agent`) and start it.

## Manual step after first deploy

The agent alone doesn't register itself with the Portainer server — that only happens once an admin adds the environment from the UI:

1. Log into `http://192.168.0.209:9000` (see the `portainer` entry in `config/services.yaml`) and complete the first-run admin setup.
2. **Environments → Add environment → Docker → Agent**, using this host's LAN address from `config/hosts.yaml` and port `9001` (e.g. `192.168.0.205:9001` for `homepage`).

Repeat once per host. Portainer CE has no declarative environments-as-code path without scripting its REST API with an admin token, which is out of scope here.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/portainer-agent.yaml
```

Also runs automatically as part of every service playbook that depends on it (`make deploy-<service>`), since it's a `meta/main.yml` dependency.
