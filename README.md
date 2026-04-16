# homelab-manifests

> GitOps-managed Kubernetes manifests for a self-hosted homelab cluster

This repository contains all Kubernetes manifests for a homelab cluster managed with ArgoCD, Kustomize, and Helm. It covers the full stack — from CNI and storage through secrets management, ingress, authentication, monitoring, and self-hosted applications. ArgoCD watches `main` and reconciles every component automatically.

## Table of contents

- [Architecture](#architecture)
- [Repository layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Bootstrap](#bootstrap)
- [Secret management](#secret-management)
- [Networking and ingress](#networking-and-ingress)
- [Authentication](#authentication)
- [Adding a new app](#adding-a-new-app)
- [Validating manifests](#validating-manifests)
- [Renovate](#renovate)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GitHub (this repo)                   │
│   main branch ──► ArgoCD (watches homelab-apps for apps)    │
└────────────────────────────┬────────────────────────────────┘
                             │ GitOps sync
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                     │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐    │
│  │  Cilium  │  │ Longhorn │  │  Vault   │  │    ESO    │    │
│  │  (CNI)   │  │(storage) │  │(secrets) │  │(k8s→Vault)│    │
│  └──────────┘  └──────────┘  └──────────┘  └───────────┘    │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Envoy Gateway (cluster-gateway)  ◄── HTTPRoutes     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌────────┐ ┌──────────┐ ┌────────────┐ ┌──────────────┐    │
│  │ media/ │ │   p2p/   │ │monitoring/ │ │    sec/      │    │
│  └────────┘ └──────────┘ └────────────┘ └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Secrets flow:** Vault KV v2 → External Secrets Operator → Kubernetes `Secret`

**Ingress flow:** Client → Cilium L2 LB → Envoy `cluster-gateway` → `HTTPRoute` → Service

**Auth flow (protected routes):** Envoy `SecurityPolicy` → `oauth2-proxy` → Keycloak

## Repository layout

```
homelab-manifests/
├── devops-tools/        # ArgoCD, ARC runners, Renovate
├── external-secrets/    # External Secrets Operator + ClusterSecretStore
├── longhorn-system/     # Longhorn distributed storage
├── media/               # Jellyfin, Hometube, CWA, Yubal (local Helm charts)
├── monitoring/          # Prometheus, Grafana, Loki, Tempo, Alloy, Kiali, CrowdSec
├── network/             # Cilium (CNI), Istio (ambient), Envoy Gateway, cert-manager
├── p2p/                 # qBittorrent, Jackett, Slskd, Shelfmark (local Helm charts)
├── sec/                 # Keycloak, OAuth2 Proxy, Falco, Kube-bench
├── tooling/             # Cluster-wide bootstrap script
└── vault/               # HashiCorp Vault + tooling scripts
```

Each deployable component follows this layout:

```
<namespace>/<app>/
├── kustomization.yaml     # Kustomize root; declares helmCharts and resources
├── values.yaml            # Helm values
├── httproute.yaml         # HTTPRoute for ingress (if exposed)
└── external-secrets.yaml  # ExternalSecret pulling from Vault (if needed)
```

## Prerequisites

| Tool | Minimum version | Purpose |
|------|-----------------|---------|
| `kubectl` | 1.29 | Cluster interaction |
| `helm` | 3.x | Chart rendering during bootstrap |
| `yq` | 4.x | YAML processing in bootstrap scripts |
| `envsubst` | any | Variable substitution during local validation |

The cluster itself runs on **k3s** (Rancher). Istio CNI paths are hardcoded to k3s defaults (`/var/lib/rancher/k3s/...`).

## Bootstrap

Bootstrap brings up the five foundational components in order before ArgoCD takes over. Run the top-level script from the repo root:

```bash
cp .env.example .env
# fill in .env values, then:
source .env
./tooling/bootstrap <secrets.yaml> <secret-files.yaml>
```

The script runs these steps in sequence:

| Step | Component | Script |
|------|-----------|--------|
| 1/5 | Cilium (CNI) | `network/tooling/bootstrap` |
| 2/5 | Longhorn (storage) | `longhorn-system/tooling/bootstrap` |
| 3/5 | Vault (secrets backend) | `vault/tooling/bootstrap <secrets.yaml> <secret-files.yaml>` |
| 4/5 | External Secrets Operator | `external-secrets/tooling/bootstrap` |
| 5/5 | ArgoCD | `devops-tools/tooling/bootstrap` |

Once ArgoCD is running it picks up [`homelab-apps`](https://github.com/msdeleyto/homelab-apps) and reconciles all remaining components.

### Secrets file format

`secrets.yaml` uses the following structure (under `.cluster.secrets`):

```yaml
cluster:
  secrets:
    vault:
      unsealer:
        key1: <unseal-key-1>
        key2: <unseal-key-2>
        key3: <unseal-key-3>
      vault:
        rootToken: <root-token>
    <namespace>:
      <app>:
        key: value
```

The bootstrap script initialises Vault on first run, writes the generated unseal keys and root token back into `secrets.yaml`, and loads all secrets under `.cluster.secrets` into Vault KV v2.

To reload secrets later without a full bootstrap:

```bash
./vault/tooling/load-secrets "$(yq '.cluster.secrets' secrets.yaml)"
```

## Secret management

Secrets are stored in **Vault KV v2** at `secret/<namespace>/<app>` and surfaced into the cluster via the **External Secrets Operator**.

The `ClusterSecretStore` named `vault-backend` (in `external-secrets/external-secrets/secret-store.yaml`) authenticates to Vault using the `eso-reader` Kubernetes auth role bound to the `external-secrets` service account.

Every `ExternalSecret` in this repo references `vault-backend` with `refreshPolicy: OnChange`.

Example path mapping:

| Vault path | Kubernetes namespace |
|------------|----------------------|
| `secret/sec/keycloak` | `sec` |
| `secret/monitoring/grafana` | `monitoring` |
| `secret/infra` | flat key-value store for infra-wide values |

## Networking and ingress

- **Cilium** handles CNI and provides L2 load balancing for the gateway IP (`INFRA_LB_IP`).
- **Envoy Gateway** provides the `cluster-gateway` `Gateway` resource in the `network` namespace (`gatewayClassName: envoy-gateway-class`, `sectionName: https`). The `EnvoyProxy` config and `GatewayClass` are defined in `network/envoy/`.
- All ingress uses **HTTPRoute** (Gateway API v1) attached to `cluster-gateway` in namespace `network`.

Hostnames follow the pattern `<service>.${INFRA_DOMAIN}` (e.g. `argocd.example.com`).

Routes requiring authentication have a corresponding `SecurityPolicy` in `network/envoy/security-policies.yaml` that points to `oauth2-proxy` in the `sec` namespace.

## Authentication

Protected services are gated by **OAuth2 Proxy** (`sec/oauth2-proxy`), backed by **Keycloak** (`sec/keycloak`).

- Keycloak is provisioned with a `cluster` realm via an `ExternalSecret` that templates a full realm JSON `ConfigMap`.
- The `oauth2-proxy` OIDC client is configured in that realm.
- A `ReferenceGrant` in `sec/oauth2-proxy/ref-grant.yaml` allows cross-namespace `SecurityPolicy` references from any namespace that attaches a policy to the `oauth2-proxy` service.

## Adding a new app

1. Create `<namespace>/<app>/` following the component structure above.
2. Add an `HTTPRoute` for ingress if the service should be externally reachable.
3. Add an `ExternalSecret` if the app needs secrets from Vault (store the values at `secret/<namespace>/<app>`).
4. Register the app in [`homelab-apps`](https://github.com/msdeleyto/homelab-apps) by adding `- name: <app>` to the relevant `ApplicationSet` list under `prod/` and/or `test/`.

ArgoCD will pick it up on the next sync.

## Validating manifests

Manifests are validated in CI on every pull request and push to `main` via the reusable workflow at `home-kops/actions/.github/workflows/validate-k8s-manifests.yaml`.

To render and validate locally:

```bash
source .env   # sets INFRA_ENV, INFRA_DOMAIN, INFRA_LB_IP, INFRA_HA_VIP, etc.
kubectl kustomize --enable-helm <component-dir> \
  | envsubst '${INFRA_DOMAIN} ${INFRA_ENV} ${INFRA_LB_IP} ${INFRA_HA_VIP}'
```

### Environment variables

| Variable | Description | Example |
|----------|-------------|---------|
| `INFRA_ENV` | Deployment environment | `prod` or `test` |
| `INFRA_DOMAIN` | Base domain for all hostnames | `example.com` |
| `INFRA_LB_IP` | IP assigned to the Cilium L2 load balancer | `192.168.1.100` |
| `INFRA_HA_VIP` | Virtual IP for HA control-plane | `192.168.1.50` |
| `INFRA_LETS_ENCRYPT_EMAIL` | Email for cert-manager ACME registration | `admin@example.com` |
| `VAULT_ADMIN_PASSWORD` | Password for the Vault `admin` userpass account | — |

See [`.env.example`](./.env.example) for the full list.

## Renovate

[`renovate.json`](./renovate.json) is configured to auto-merge minor and patch updates for stable (non-`0.x`) packages. Major version bumps require manual review.

Renovate runs as a self-hosted bot via the `devops-tools/renovate` component. Merge results are posted to Slack via the `notify-result` job in the CI workflow.
