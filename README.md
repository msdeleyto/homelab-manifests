# Homelab Manifests

Kubernetes and Helm manifests for a self-hosted homelab, deployed via GitOps with ArgoCD.

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url>
cd homelab-manifests

# 2. Copy and configure the environment template
cp .env.example .env
# Edit .env with your values: ENV, DOMAIN, Bitwarden credentials, etc.

# 3. Bootstrap the cluster (requires existing K8s cluster and Bitwarden token)
BITWARDEN_ACCESS_TOKEN=<your-token> ./manifests/tooling/bootstrap

# 4. ArgoCD takes over and deploys all apps from apps/<env>/ via GitOps
```

### Prerequisites

- **Kubernetes** cluster (v1.29+)
- **Helm** 3.x
- **kubectl** (includes `kustomize`)
- **envsubst** (for variable substitution in manifests)
- **yq** (for parsing YAML configuration)

## Project Layout

```
.
├── apps/                      # ArgoCD ApplicationSet definitions (per environment)
│   ├── prod/                  # Production environment
│   └── test/                  # Test environment
├── infra/                     # Infrastructure as code
│   ├── ansible/               # Proxmox VE host configuration playbook
│   └── terraform/             # Terraform modules and environments (Proxmox + Talos)
│       ├── environments/      # Per-environment Terraform configs (prod, test)
│       └── modules/           # Shared modules (talos-image, talos-vm, talos-cluster)
├── manifests/                 # All Kubernetes/Helm manifests
│   ├── charts/                # Local Helm charts (base-app)
│   ├── crds/                  # Cluster CRDs (remote sources via kustomize)
│   ├── tooling/               # Bootstrap orchestrator
│   └── <namespace>/           # Per-namespace directories
│       └── <app>/             # Per-app manifests (kustomize base + overlays)
└── .github/workflows/         # CI: validate manifests, Renovate, Slack notifications
```

## Architecture

### GitOps with ArgoCD

All workloads are deployed and managed by ArgoCD ApplicationSets. Apps are organized into environments under `apps/<env>/`, where each YAML file defines an ApplicationSet (or Application for CRDs) that references manifests under `manifests/`.

| Environment | Description |
|---|---|
| `prod` | Full platform: network, storage, devops, secrets, security |
| `test` | Same platform components for testing |

Each environment may also include workload-specific apps (media, P2P, data services, etc.) that depend on the platform layer.

Each ApplicationSet uses `CreateNamespace=true` and `ServerSideApply=true` for self-healing and namespace management. Sync-waves order bootstrap dependencies (CRDs → storage → everything else).

### Bootstrap Flow

The cluster is bootstrapped sequentially via `manifests/tooling/bootstrap`:

1. **CRDs** — Install cluster-wide Custom Resource Definitions (gateway API, certificates, external secrets, etc.)
2. **CNI (Container Network Interface)** — Deploy networking with load-balancer pool and HA VIP
3. **Certificate Management** — Install automated TLS certificate provisioning
4. **External Secrets Operator** — Install ESO with Bitwarden SDK server and configure Bitwarden access token
5. **ArgoCD** — Install ArgoCD which takes over deployment of all other applications via GitOps

Source your environment file and provide the Bitwarden token:

```bash
set -a && source .env && set +a
BITWARDEN_ACCESS_TOKEN=<your-token> ./manifests/tooling/bootstrap
```

### Configuration

All manifests use `envsubst` for variable substitution. Variables are defined in `.env`:

| Variable | Description |
|---|---|
| `ENV` | Environment: `prod` or `test` |
| `DOMAIN` | Domain for ingress and services |
| `BITWARDEN_ORG_ID` | Bitwarden organization ID |
| `BITWARDEN_PROJECT_ID` | Bitwarden project ID |
| `BITWARDEN_ACCESS_TOKEN` | Bitwarden SM machine account access token |

Template a copy of `.env.example` with your actual values before deploying:

```bash
cp .env.example .env
# Edit .env with your cluster-specific values
```

### Secrets Management

External Secrets Operator (ESO) integrates with Bitwarden Secrets Manager to inject secrets into applications. The Bitwarden SDK server runs in-cluster with TLS certificates managed by the certificate manager.

The bootstrap script creates the Bitwarden access token secret automatically. For manual setup:

```bash
kubectl create secret generic bitwarden-access-token \
  --namespace external-secrets \
  --from-literal=token=<your-bitwarden-sm-access-token>
```

## CI/CD

GitHub Actions workflows run on every PR and push to `main`:

- **Validate Kubernetes manifests** — renders all manifests through kustomize + envsubst and validates YAML structure
- **Renovate** — automated dependency updates (minor/patch auto-merge)
- **Slack notification** — on Renovate-triggered merges to `main`

## Notes

> All namespaces enforce `pod-security.kubernetes.io/audit: restricted` (audit-version: latest).

> Renovate auto-merges minor and patch updates per `renovate.json`.
