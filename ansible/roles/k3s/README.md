# K3s Ansible Role

Installs [K3s](https://k3s.io/) as a **single-node server** (no agents/workers yet) and bootstraps Argo CD on top of it.

Like `pbs`, this is a native install (the official K3s install script), not Docker — K3s bundles its own containerd. `meta/main.yml` depends on `common`, `node-exporter`, and `promtail` only.

## Current topology

```text
k3s-server (VM, 192.168.0.31)
  │
  ├── K3s server (control plane + kubelet — schedulable, single node)
  └── Argo CD (namespace: argocd)
```

No workers yet — `config/hosts.yaml`'s two Raspberry Pis are tagged `role: [k3s, worker]` for exactly this future, but joining them as K3s agents is a separate, not-yet-built step. Until then, this is a single-node cluster: everything Kubernetes-related runs on `k3s-server` alone.

**Kafka is deliberately not deployed yet.** `kubernetes/infrastructure/kafka/node-pool.yaml` requests 3 replicas at 1-2 CPU / 2-4 GiB each — more than this single node should take on, and the Strimzi operator (`kubernetes/infrastructure/kafka/strimzi/`) isn't wired into the main kustomization that Argo CD's `kafka` Application points at. Bringing Kafka up needs both of those addressed, plus real cluster capacity (i.e. workers).

## Responsibilities

- Install K3s (`INSTALL_K3S_CHANNEL=stable` by default — see `k3s_channel`), server mode, world-readable kubeconfig (`--write-kubeconfig-mode 644`).
- Wait for the node to report `Ready`.
- Install Argo CD (official manifests, `argocd` namespace) and wait for `argocd-server` to roll out. It comes up **empty** — no `Application` resources are applied by this role. Apply them yourself when a given workload (Kafka, once it's ready; other infra) is actually meant to start reconciling:

  ```bash
  KUBECONFIG=~/.kube/homelab-k3s.yaml kubectl apply -f kubernetes/argocd/projects/
  KUBECONFIG=~/.kube/homelab-k3s.yaml kubectl apply -f kubernetes/argocd/applications/<name>.yaml
  ```

- Fetch `/etc/rancher/k3s/k3s.yaml` to the Ansible control machine at `k3s_kubeconfig_local_path` (default `~/.kube/homelab-k3s.yaml`, never committed), rewriting `https://127.0.0.1:6443` to the node's real address so it works from off-box.

## Accessing Argo CD

```bash
export KUBECONFIG=~/.kube/homelab-k3s.yaml

# initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# port-forward the UI (or add an ingress/route once one exists)
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Rotate/delete `argocd-initial-admin-secret` after the first login, per Argo CD's own recommendation.

## Deployment

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/k3s-server.yaml
```
