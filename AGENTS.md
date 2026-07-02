# Homelab Manifests

Kubernetes/Helm manifests for a homelab, deployed via ArgoCD (GitOps).

## Environments

Two environments, managed by ArgoCD ApplicationSets in `apps/`:

- `apps/prod/` — production (11 apps: longhorn, network, monitoring, vault, sec, devops-tools, external-secrets, media, p2p, data)
- `apps/test/` — test (5 apps: devops-tools, network, vault, longhorn, external-secrets)

Each ApplicationSet references a subdirectory under its environment folder. Add a new app by adding an entry to `generators.list.elements`.

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
| `charts/` | Local Helm charts (base-app) |
| `crds/` | Cluster CRDs (remote sources via kustomize) |
| `monitoring/` | Monitoring stack (alloy, grafana, loki, prometheus, tempo) |
| `vault/` | HashiCorp Vault deployment + auth/policies |
| `sec/` | Security tools (keycloak, oauth2-proxy, falco, kubebench) |
| `network/` | CNI (cilium), cert-manager, envoy gateway |
| `longhorn-system/` | Block storage |
| `data/` | Databases (CNPG) and AI infra (litellm) |
| `media/` | Media servers (cwa, hometube, jellyfin, yubal) |
| `p2p/` | P2P tools (jackett, qbittorrent, shelfmark, slskd) |
| `devops-tools/` | ArgoCD, tooling bootstrap |
| `tooling/` | Root-level bootstrap orchestrator |
| `external-secrets/` | External Secrets Operator |
