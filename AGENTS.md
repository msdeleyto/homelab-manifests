# Kubernetes Homelab Infrastructure

## Core Commands

**Bootstrap cluster infrastructure**
```bash
./tooling/bootstrap <vault_secrets_path>
```
Installs in order: CRDs → CNI → Storage (Longhorn) → Vault → ESO → ArgoCD

**Validate manifests**
GitHub Actions validates on PR/push to main. Changes to YAML/YML files trigger validation.

**Update versions**
Renovate bot creates automerged PRs for minor/patch updates. Major updates require manual review.

## Architecture

**Toolchain**: Kustomize manifests + Helm charts for multi-cluster management.

**API Management**: Kubernetes Gateway API + Envoy Gateway API for routing.

**Secrets**: Vault (admin) + External Secrets Operator (ESO) for dynamic secrets.

## Directory Structure

- `crds/`: Custom Resource Definitions (Gateway API, ArgoCD, ESO, Cert-Manager, Envoy)
- `network/`: Cilium CNI, Envoy proxy, Cert-manager
- `longhorn-system/`: Longhorn storage with NFS backup target
- `vault/`: Vault with unsealer for secret management
- `external-secrets/`: External Secrets Operator
- `devops-tools/`: ArgoCD for CI/CD
- `monitoring/`: Prometheus, Grafana, Loki, Tempo, Alloy, CrowdSec, TimescaleDB
- `sec/`: Falco, Keycloak, OAuth2-Proxy, Kubebench
- `p2p/`: Jackett, qbittorrent, slskd, shelfmark
- `media/`: Jellyfin, hometube, cwa, yubal

## Helm Charts

Each service has `Chart.yaml` (metadata) + `values.yaml` (config). Images pinned with SHA for stability.

## Environment

- `INFRA_ENV`: [test|prod]
- `INFRA_DOMAIN`: Cluster domain
- `VAULT_ADMIN_PASSWORD`: Vault admin password