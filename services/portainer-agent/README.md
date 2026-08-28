# Portainer Agent

Lets the central [Portainer](../portainer/README.md) server manage this host's Docker containers, without exposing the raw Docker socket over the network.

Deployed on every LXC/VM that runs Docker Compose, as a baseline dependency alongside `node-exporter`/`promtail` — see [`ansible/roles/portainer-agent/README.md`](../../ansible/roles/portainer-agent/README.md) for the full host list and the manual "add environment" step required once per host.

Not a cataloged service: no `config/services.yaml` entry, no Homepage tile, no Prometheus target.

## Deployment

Deployed by the `portainer-agent` Ansible role — see [`ansible/roles/portainer-agent/README.md`](../../ansible/roles/portainer-agent/README.md).
