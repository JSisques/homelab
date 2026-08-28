# Portainer

Central Docker management UI for the homelab — container status, logs, and restarts across every LXC/VM that runs Docker Compose, without SSHing into each one.

Runs on the shared `monitoring` LXC alongside Prometheus, Grafana, Loki, Alertmanager, and blackbox_exporter (see [`ansible/roles/monitoring/README.md`](../../ansible/roles/monitoring/README.md)), on the shared `monitoring` Docker network.

## How it fits together

Portainer doesn't reach into remote hosts' Docker sockets directly. Each Docker LXC/VM (including this one) runs a `portainer-agent` container ([`../portainer-agent/README.md`](../portainer-agent/README.md), deployed by [`ansible/roles/portainer-agent/`](../../ansible/roles/portainer-agent/README.md)), and Portainer connects out to it on port `9002` — standard agent mode, not Edge Agent, since every host is on the same flat LAN and already reachable by IP.

Portainer itself is not part of the Ansible/Git-described desired state — it's an operational convenience layer on top. Configuration changes still belong in `config/` + the relevant Ansible role/Compose file, not made by hand through the Portainer UI.

## Adding an environment

New Docker LXC/VMs register themselves automatically: `portainer-agent`'s role calls Portainer's REST API to add the environment once `portainer_api_token` is configured (an Access Token, created once by hand from the UI — see [`ansible/roles/portainer-agent/README.md`](../../ansible/roles/portainer-agent/README.md) for that one-off setup). Without the token, add it manually: **Environments → Add environment → Docker → Agent**, that host's LAN address (`config/hosts.yaml`) and port `9002`.

## Deployment

Deployed by the `monitoring` Ansible role — see [`ansible/roles/monitoring/README.md`](../../ansible/roles/monitoring/README.md).
