# Promtail Ansible Role

Installs [Promtail](https://grafana.com/docs/loki/latest/send-data/promtail/) as a native systemd service (Grafana's own APT repository — not Docker) and ships the host's systemd journal to Loki.

This is a **mandatory baseline** role, like `node-exporter` — see `ansible/README.md`. It's part of every service role's `meta/main.yml` dependencies, so every LXC and VM ships logs regardless of whether it runs Docker. That's also why it's a native package rather than a container: the `pbs` role has no `docker` dependency at all, and Promtail still needs to work there.

## Responsibilities

- Add Grafana's APT repository and install `promtail`.
- Render `/etc/promtail/config.yml` pointing at Loki (`promtail_loki_url`, resolved from the `monitoring` host's LAN address in the generated inventory — see `config/hosts.yaml`).
- Ship the systemd journal, labeled by host and unit.

## Variables

```yaml
promtail_loki_host: "{{ hostvars['monitoring'].ansible_host }}"
promtail_loki_url: "http://{{ promtail_loki_host }}:3100/loki/api/v1/push"
promtail_config_path: /etc/promtail/config.yml
```

`promtail_loki_url` tracks the `monitoring` host's address automatically — if Loki ever moves to a different host, update its `role` in `config/hosts.yaml` instead of overriding this variable by hand.
