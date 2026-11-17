# Homelab Manifests

Kubernetes/Helm manifests for a homelab, deployed via ArgoCD (GitOps).

## Environments

### Kubernetes workloads — ArgoCD ApplicationSets in `apps/`

- `apps/prod/` — production (storage, network, monitoring, sec, devops-tools, external-secrets, media, p2p, data, crds)
- `apps/test/` — test (devops-tools, network, storage, external-secrets, data, sec, crds)

Each ApplicationSet references a subdirectory under `manifests/`. The `storage` ApplicationSet is a parent kustomization that deploys both Piraeus (LINSTOR/DRBD) and Local Path Provisioner into a single `storage` namespace.

### Infrastructure — Terraform in `infra/terraform/`

- `infra/terraform/environments/prod/` — 3-node HA cluster (talos-01/02/03 @ `.50-.52`, VIP @ `.80`) on a **dedicated bare-metal Proxmox VE host**
- `infra/terraform/environments/test/` — bare-metal Proxmox VE host (same architecture as prod)

Both environments share the same modules under `infra/terraform/modules/`.

### Host Configuration — Ansible in `infra/ansible/`

Ansible playbook (`pve-config.yaml`) to prepare Proxmox VE hosts: switch to no-subscription repos, harden SSH, create the Terraform service user/role/token, and install host-level monitoring (Glances).

## Full Bootstrap

One-shot cluster bootstrap from scratch (no existing cluster required):

```bash
BITWARDEN_ACCESS_TOKEN=<your-token> ./manifests/tooling/bootstrap
```

This installs CRDs → CNI (Cilium) → cert-manager → External Secrets Operator → ArgoCD. After bootstrap, ArgoCD takes over and deploys all other applications via GitOps.

ESO bootstrap requires a Bitwarden Secrets Manager machine account access token. Create one in your Bitwarden SM organization with access to the project containing your secrets.

## Variable Substitution

Manifests use `envsubst` for: `ENV`, `DOMAIN`, `BITWARDEN_ORG_ID`, `BITWARDEN_PROJECT_ID`, `BITWARDEN_ACCESS_TOKEN`.
Template a copy of `.env.example` with actual values before deploying.

## Manifest Rendering

Most manifests are rendered via `kubectl kustomize --enable-helm` piped into `kubectl apply --server-side --force-conflicts`.
Never apply manifests directly — always go through kustomize first.

## Key Conventions

- All namespaces enforce `pod-security.kubernetes.io/audit: restricted` (audit-version: latest)
- ArgoCD sync-waves: CRDs `-3`, storage `-2`, others default `0`
- ArgoCD uses `CreateNamespace=true` and `ServerSideApply=true`
- Renovate auto-merges minor/patch Helm chart updates (`renovate.json`)
- CI validates all YAML manifests on PR/push

## Directory Ownership

| Directory | Purpose |
|---|---|
| `apps/` | ArgoCD ApplicationSet definitions (per environment) |
| `infra/ansible/` | Ansible playbook for Proxmox VE host configuration |
| `infra/terraform/environments/prod/` | Terraform: 3-node prod cluster (bare-metal PVE host) |
| `infra/terraform/environments/test/` | Terraform: test cluster (bare-metal PVE host) |
| `infra/terraform/modules/` | Shared Terraform modules (talos-image, talos-vm, talos-cluster) |
| `manifests/` | All Kubernetes/Helm manifests |
| `manifests/charts/` | Local Helm charts (base-app) |
| `manifests/crds/` | Cluster CRDs (remote sources via kustomize) |
| `manifests/tooling/` | Bootstrap orchestrator script |
