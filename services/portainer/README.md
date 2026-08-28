# Portainer

Central Docker management UI for the homelab — container status, logs, and restarts across every LXC/VM that runs Docker Compose, without SSHing into each one.

Runs on the shared `monitoring` LXC alongside Prometheus, Grafana, Loki, Alertmanager, and blackbox_exporter (see [`ansible/roles/monitoring/README.md`](../../ansible/roles/monitoring/README.md)), on the shared `monitoring` Docker network.

## How it fits together

Portainer doesn't reach into remote hosts' Docker sockets directly. Each Docker LXC/VM (including this one) runs a `portainer-agent` container ([`../portainer-agent/README.md`](../portainer-agent/README.md), deployed by [`ansible/roles/portainer-agent/`](../../ansible/roles/portainer-agent/README.md)), and Portainer connects out to it on port `9001` — standard agent mode, not Edge Agent, since every host is on the same flat LAN and already reachable by IP.

Portainer itself is not part of the Ansible/Git-described desired state — it's an operational convenience layer on top. Configuration changes still belong in `config/` + the relevant Ansible role/Compose file, not made by hand through the Portainer UI.

## Adding an environment

After deploying a new Docker LXC/VM (which brings up its `portainer-agent` automatically as a baseline dependency), add it in the Portainer UI once: **Environments → Add environment → Docker → Agent**, pointing at that host's LAN address (`config/hosts.yaml`) and port `9001`.

## Deployment

Deployed by the `monitoring` Ansible role — see [`ansible/roles/monitoring/README.md`](../../ansible/roles/monitoring/README.md).
