# Homelab Manifests

Kubernetes/Helm manifests for a homelab, deployed via ArgoCD (GitOps).

## Environments

### Kubernetes workloads — ArgoCD ApplicationSets in `apps/`

- `apps/prod/` — production (11 apps: longhorn, network, monitoring, vault, sec, devops-tools, external-secrets, media, p2p, data)
- `apps/test/` — test (5 apps: devops-tools, network, vault, longhorn, external-secrets)

Each ApplicationSet references a subdirectory under its environment folder. Add a new app by adding an entry to `generators.list.elements`.

### Infrastructure — Terraform in `infra/environments/`

- `infra/environments/prod/` — 3-node HA cluster (talos-01/02/03 @ `.50-.52`, VIP @ `.80`) on a **dedicated bare-metal Proxmox VE host**
- `infra/environments/test/` — **single-VM** cluster (talos-test-01 @ `.60`, VMID 201, 100 GB data disk) running on a **Proxmox VE instance deployed as a VM on this machine** (nested virtualization)
- `infra/tooling/create-test-pve-vm` — helper script to launch the local test Proxmox VE VM via libvirt/KVM with `--cpu host-passthrough`

Both environments share the same modules under `infra/modules/`. The test environment sets `cluster_vip` to the node's own IP (no L2 VIP election needed for one node) and uses `cpu_type = "kvm64"` (or `"host"`).

## Full Bootstrap

One-shot cluster bootstrap from scratch (no existing cluster required):

```bash
tooling/bootstrap
```

This installs CRDs → CNI (Cilium) → Storage (Longhorn) → Vault → External Secrets Operator → ArgoCD.

Vault bootstrap requires a secrets file (`vault/tooling/bootstrap <secrets.yaml>`) containing `cluster.secrets.vault.unsealer[]` and `cluster.secrets.vault.vault.rootToken`.

## Variable Substitution

Manifests use `envsubst` for: `INFRA_DOMAIN`, `INFRA_LB_IP`, `INFRA_HA_VIP`, `INFRA_ENV`.
Template a copy of `.env.example` with actual values before deploying.

## Manifest Rendering

Most manifests are rendered via `kubectl kustomize --enable-helm` piped into `kubectl apply --server-side --force-conflicts`.
Never apply manifests directly — always go through kustomize first.

## Key Conventions

- All namespaces enforce `pod-security.kubernetes.io/audit: restricted` (audit-version: latest)
- ArgoCD sync-waves: ESO `-3`, Vault `-4`, others default `0`
- ArgoCD uses `CreateNamespace=true` and `ServerSideApply=true`
- Renovate auto-meres minor/patch Helm chart updates (`renovate.json`)
- CI validates all YAML manifests on PR/push

## Directory Ownership

| Directory | Purpose |
|---|---|
| `apps/` | ArgoCD ApplicationSet definitions |
| `infra/environments/prod/` | Terraform: 3-node prod cluster (bare-metal PVE host) |
| `infra/environments/test/` | Terraform: single-VM test cluster (nested PVE VM on this host) |
| `infra/modules/` | Shared Terraform modules (pve-config, talos-image, talos-vm, talos-cluster) |
| `infra/tooling/` | Local helper scripts (create-test-pve-vm) |
| `manifests/` | All Kubernetes/Helm manifests |
| `manifests/charts/` | Local Helm charts (base-app) |
| `manifests/crds/` | Cluster CRDs (remote sources via kustomize) |
