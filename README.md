# homelab-manifests

> GitOps-managed Kubernetes manifests for a self-hosted homelab cluster

This repository contains the Kubernetes manifests and bootstrap scripts for a homelab cluster managed with ArgoCD, Kustomize, and Helm. It covers the cluster foundation, secret management, ingress, authentication, monitoring, and a set of self-hosted applications. ArgoCD is bootstrapped from this repo, then continuously reconciles the environment-specific app definitions from [`homelab-apps`](https://github.com/msdeleyto/homelab-apps).

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

```text
GitHub (this repo)
  -> bootstrap scripts install CRDs, Cilium, Longhorn, Vault, ESO, and ArgoCD
  -> ArgoCD Application `apps` points to homelab-apps.git at ./${INFRA_ENV}
  -> ArgoCD syncs the rest of the cluster continuously

Secrets flow:
  secrets.yaml / secret-files.yaml -> Vault KV v2 -> External Secrets Operator -> Kubernetes Secret

Ingress flow:
  Client -> Cilium L2 LB -> Envoy Gateway `cluster-gateway` -> HTTPRoute -> Service

Protected routes:
  Envoy SecurityPolicy -> oauth2-proxy -> Keycloak
```

## Repository layout

```text
homelab-manifests/
├── crds/               # Cluster CRDs applied before the rest of bootstrap
├── data/               # Data-layer components such as CloudNativePG
├── devops-tools/       # ArgoCD bootstrap manifests and tooling
├── external-secrets/   # External Secrets Operator + ClusterSecretStore
├── longhorn-system/    # Longhorn distributed storage
├── media/              # Jellyfin, Hometube, CWA, Yubal
├── monitoring/         # Alloy, CrowdSec, Grafana, Loki, Prometheus, Tempo, Timescale
├── network/            # Cilium, Envoy Gateway, cert-manager
├── p2p/                # qBittorrent, Jackett, Shelfmark, Slskd
├── sec/                # Keycloak, OAuth2 Proxy, Falco, kube-bench job
├── tooling/            # Top-level bootstrap entrypoint
└── vault/              # Vault manifests and secret-loading tooling
```

Most deployable components are Kustomize roots with a `kustomization.yaml` and, when needed, supporting files such as `values.yaml`, `httproute.yaml`, `external-secret*.yaml`, or chart `templates/` directories.

## Prerequisites

| Tool | Purpose |
|------|---------|
| `kubectl` | Apply manifests and interact with the cluster |
| `helm` | Install charts during bootstrap |
| `yq` | Parse versions and process secrets files |
| `envsubst` | Render manifests that use environment variables |

The cluster is assumed to be running on **k3s**. Some security tooling is explicitly wired to k3s host paths.

## Bootstrap

Bootstrap installs the base cluster services in order, then leaves ongoing reconciliation to ArgoCD.

```bash
cp .env.example .env
# fill in .env values, then:
source .env
./tooling/bootstrap <secrets.yaml> <secret-files.yaml>
```

The top-level script performs these steps:

| Order | Component | Script |
|------|-----------|--------|
| Pre-step | CRDs | `crds/tooling/bootstrap` |
| 1/5 | Cilium | `network/tooling/bootstrap` |
| 2/5 | Longhorn | `longhorn-system/tooling/bootstrap` |
| 3/5 | Vault | `vault/tooling/bootstrap <secrets.yaml> <secret-files.yaml>` |
| 4/5 | External Secrets Operator | `external-secrets/tooling/bootstrap` |
| 5/5 | ArgoCD | `devops-tools/tooling/bootstrap` |

Once ArgoCD is running, the `devops-tools/argocd/application.yaml` manifest points it at [`homelab-apps`](https://github.com/msdeleyto/homelab-apps) and syncs the environment path `./${INFRA_ENV}`.

### Secrets file formats

`secrets.yaml` is loaded into Vault from `.cluster.secrets`:

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
    infra:
      SOME_KEY: some-value
    <namespace>:
      <app>:
        key: value
```

`secret-files.yaml` maps file-backed secrets that should be written into Vault:

```yaml
<namespace>:
  <app>:
    <key>: /path/to/file
```

On first run, the Vault bootstrap script initializes Vault, writes the generated unseal keys and root token back into `secrets.yaml`, configures auth methods and policies, then loads both inline and file-backed secrets.

To reload secrets later without a full bootstrap:

```bash
./vault/tooling/load-secrets "$(yq '.cluster.secrets' secrets.yaml)"
./vault/tooling/load-secret-files "$(yq '.' secret-files.yaml)"
```

## Secret management

Secrets are stored in **Vault KV v2** under `secret/` and surfaced into the cluster through the **External Secrets Operator**.

- App secrets are written to `secret/<namespace>/<app>`.
- Infra-wide flat values are written to `secret/infra`.
- The `ClusterSecretStore` named `vault-backend` in `external-secrets/external-secrets/secret-store.yaml` uses Vault Kubernetes auth with the `eso-reader` role.

Example mappings:

| Vault path | Used by |
|------------|---------|
| `secret/sec/keycloak` | Keycloak |
| `secret/monitoring/grafana` | Grafana |
| `secret/infra` | Shared infrastructure values |

## Networking and ingress

- **Cilium** provides cluster networking and the L2 load balancer for `INFRA_LB_IP`.
- **Envoy Gateway** is installed in `network/envoy` and exposes the `cluster-gateway` `Gateway` in the `network` namespace.
- Ingress is defined with **Gateway API** `HTTPRoute` resources, either as standalone manifests or as templates inside local charts.
- **cert-manager** is configured in `network/certmanager` and renders issuers/certificates with `INFRA_LETS_ENCRYPT_EMAIL`.

Hostnames generally follow `<service>.${INFRA_DOMAIN}`.

Protected routes are attached to Envoy `SecurityPolicy` resources in `network/envoy/security-policies.yaml`, which delegate auth to `oauth2-proxy` in the `sec` namespace.

## Authentication

Protected services are gated by **OAuth2 Proxy** (`sec/oauth2-proxy`) backed by **Keycloak** (`sec/keycloak`).

- Keycloak is deployed with an attached PostgreSQL cluster manifest (`db-cluster.yaml`).
- `oauth2-proxy` is used as Envoy external auth for protected `HTTPRoute`s.
- `sec/oauth2-proxy/ref-grant.yaml` allows cross-namespace references from the namespaces that attach Envoy auth policies to the `oauth2-proxy` service.

## Adding a new app

1. Create or update the component directory in this repo.
2. Add a `kustomization.yaml` if the component is Kustomize-managed.
3. Add Helm `values.yaml` and/or local chart `templates/` when the app is chart-based.
4. Add ingress with an `HTTPRoute` if the service should be reachable externally.
5. Add an `ExternalSecret` if the app needs values from Vault.
6. Register the app in [`homelab-apps`](https://github.com/msdeleyto/homelab-apps) under the appropriate environment path so ArgoCD will reconcile it.

## Validating manifests

CI validation runs from `.github/workflows/validate_manifests.yaml` on pull requests and on pushes to `main`. It delegates manifest validation to the reusable workflow `msdeleyto/gh-actions/.github/workflows/validate-k8s-manifests.yaml`.

To render a component locally:

```bash
source .env
kubectl kustomize --enable-helm <component-dir> \
  | envsubst '${INFRA_DOMAIN} ${INFRA_ENV} ${INFRA_LB_IP} ${INFRA_HA_VIP} ${INFRA_LETS_ENCRYPT_EMAIL}'
```

### Environment variables

| Variable | Description |
|----------|-------------|
| `INFRA_ENV` | Environment name used by ArgoCD (`test`, `prod`, etc.) |
| `INFRA_DOMAIN` | Base domain for externally exposed services |
| `INFRA_LB_IP` | IP announced by the Cilium L2 load balancer |
| `INFRA_HA_VIP` | Control-plane virtual IP used by the Cilium config |
| `INFRA_LETS_ENCRYPT_EMAIL` | ACME email used by cert-manager |
| `VAULT_ADMIN_PASSWORD` | Password configured for the Vault `admin` userpass account |

Only a minimal starter set is included in [`.env.example`](./.env.example). Additional variables can be exported in your shell as needed for local rendering.

## Renovate

[`renovate.json`](./renovate.json) enables Kubernetes manifest scanning and auto-merges minor and patch updates for stable non-`0.x` dependencies. Platform automerge is enabled.
