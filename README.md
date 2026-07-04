# Homelab Manifests

Kubernetes and Helm manifests for a self-hosted homelab, deployed via GitOps with ArgoCD.

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url>
cd homelab-manifests

# 2. Copy and configure the environment template
cp .env.example .env
# Edit .env with your values: INFRA_ENV, INFRA_DOMAIN, INFRA_LB_IP, etc.

# 3. Bootstrap the cluster (requires existing K8s cluster)
./tooling/bootstrap

# 4. ArgoCD will pick up all apps automatically
#    Production: apps/prod/  (11 apps)
#    Test:       apps/test/  (5 apps)
```

### Prerequisites

- **Kubernetes** cluster (v1.29+)
- **Helm** 3.x
- **kubectl**
- **envsubst** (for variable substitution in manifests)
- **yq** (for secrets file parsing)

## Project Layout

```
.
├── apps/                      # ArgoCD ApplicationSet definitions
│   ├── prod/                  # Production environment
│   └── test/                  # Test environment
├── charts/                    # Local Helm charts (base-app templates)
├── monitoring/                # Observability stack
├── network/                   # Networking (CNI, cert-manager, envoy)
├── sec/                       # Security tools
├── data/                      # Data services (PostgreSQL, LLM proxy)
├── media/                     # Media server apps
├── p2p/                       # P2P apps
├── vault/                     # HashiCorp Vault
├── external-secrets/          # External Secrets Operator
├── devops-tools/              # ArgoCD deployment
├── longhorn-system/           # Block storage
├── tooling/                   # Bootstrap orchestrator
└── .github/workflows/         # CI: validate Kubernetes manifests
```

## Architecture

### GitOps with ArgoCD

All workloads are deployed and managed by ArgoCD ApplicationSets. Apps are organized into two environments:

| Environment | Apps | Description |
|---|---|---|
| `prod` | 11 | Full stack: media, monitoring, security, networking, data, devops |
| `test` | 5 | Subset for testing: devops-tools, network, vault, longhorn, external-secrets |

Each ApplicationSet uses `CreateNamespace=true` and `ServerSideApply=true` for self-healing and namespace management. Sync-waves are ordered: ArgoCD → Vault (-4) → ESO (-3) → other apps (0).

### Bootstrap Flow

The cluster is bootstrapped in 5 sequential steps via `tooling/bootstrap`:

1. **CRDs** — Install cluster-wide CRDs (gateway-api, cert-manager, ESO, etc.)
2. **CNI (Cilium)** — Deploy Cilium with load-balancer pool and HA VIP
3. **Storage (Longhorn)** — Deploy Longhorn with PVCs, control-plane-tolerated
4. **Vault** — Initialize, unseal, configure auth, load secrets (requires `vault/tooling/bootstrap <secrets.yaml>`)
5. **External Secrets Operator** — Install ESO for secret injection into apps

### Configuration

All manifests use `envsubst` for variable substitution. The template file is:

| Variable | Description | Required |
|---|---|---|
| `INFRA_ENV` | Environment: `test` or `prod` | Yes |
| `INFRA_DOMAIN` | Domain for ingress and services | Yes |
| `INFRA_LB_IP` | Load balancer IP (Cilium) | Yes |
| `INFRA_HA_VIP` | HA Virtual IP | Yes |
| `VAULT_ADMIN_PASSWORD` | Vault admin password | Yes (prod) |

Template a copy of `.env.example` with your actual values before deploying:

```bash
cp .env.example .env
# Edit .env with your cluster-specific values
```

### Vault Setup

Vault bootstrap requires a secrets file at `vault/tooling/bootstrap <secrets.yaml>` containing:

- `cluster.secrets.vault.unsealer[]` — Unseal keys (filled automatically from `vault operator init`)
- `cluster.secrets.vault.vault.rootToken` — Initial root token (filled automatically)

## CI/CD

GitHub Actions workflow validates all Kubernetes manifests on every PR and push to `main`:

```bash
# CI pipeline:
# 1. Render all manifests through kustomize + envsubst
# 2. Validate YAML structure and Kubernetes resource specs
# 3. Slack notification on successful merge
```

## Notes

> Vault bootstrap is a one-time operation that initializes the Vault server, unseals it with keys from your secrets file, and configures auth engines and policies. After bootstrap, subsequent deploys use the existing vault deployment.

> All namespaces enforce `pod-security.kubernetes.io/audit: restricted` (audit-version: latest).

> Renovate auto-merges minor and patch Kubernetes manifest updates in `renovate.json`.
