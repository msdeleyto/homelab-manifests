# Homelab Manifests — Copilot Instructions

GitOps-managed Kubernetes homelab using ArgoCD, Kustomize + Helm, and Vault-backed secrets.

## Validation

Manifests are validated in CI via the reusable workflow `home-kops/actions/.github/workflows/validate-k8s-manifests.yaml`. To validate locally, render a component with:

```bash
kubectl kustomize --enable-helm <component-dir> | envsubst '${INFRA_DOMAIN} ${INFRA_ENV} ${INFRA_LB_IP} ${INFRA_HA_VIP}'
```

Required environment variables (see `.env.example`):
- `INFRA_ENV` — `test` or `prod`
- `INFRA_DOMAIN` — base domain (e.g. `example.com`)
- `INFRA_LB_IP`, `INFRA_HA_VIP` — network-specific IPs
- `INFRA_LETS_ENCRYPT_EMAIL`

## Architecture

### GitOps Flow
ArgoCD watches this repo's `main` branch. Each component path is registered as an ArgoCD `Application` (driven by `ApplicationSet` definitions in [`homelab-apps`](https://github.com/msdeleyto/homelab-apps)). All applications sync automatically with prune + selfHeal enabled.

### Bootstrap Order
The cluster is bootstrapped in this sequence (see `tooling/bootstrap`):
1. **Cilium** (CNI + kube-proxy replacement) — `network/tooling/bootstrap`
2. **Longhorn** (storage) — `longhorn-system/tooling/bootstrap`
3. **Vault** (secrets backend) — `vault/tooling/bootstrap <secrets.yaml> <secret-files.yaml>`
4. **External Secrets Operator** — `external-secrets/tooling/bootstrap`
5. **ArgoCD** — `devops-tools/tooling/bootstrap`

ArgoCD then takes over reconciliation for all remaining components.

### Secret Management
Secrets flow: **Vault KV v2 → External Secrets Operator → Kubernetes Secrets**

- The `ClusterSecretStore` named `vault-backend` (defined in `external-secrets/external-secrets/secret-store.yaml`) authenticates to Vault via Kubernetes service account using the `eso-reader` role.
- All `ExternalSecret` resources reference `vault-backend` and use `refreshPolicy: OnChange`.
- Vault KV paths follow the pattern `secret/<namespace>/<app>` (e.g. `/sec/keycloak`).
- Load secrets manually: `./vault/tooling/load-secrets <secrets.yaml>` (YAML structure: `namespace.app.key: value`).

### Networking
- **Cilium** handles CNI and L2 load balancing for the gateway IP.
- **Istio** provides the `cluster-gateway` Gateway in the `network` namespace (Gateway API, `gatewayClassName: istio`).
- **Envoy Gateway** provides an alternative `envoy-gateway-class` with an `EnvoyProxy` config and `SecurityPolicy` for auth enforcement.
- All ingress uses **HTTPRoute** (Gateway API v1), attaching to `cluster-gateway` in namespace `network`, `sectionName: https`.
- Hostnames follow the pattern `<service>.${INFRA_DOMAIN}`.
- Routes requiring auth have an Envoy `SecurityPolicy` in `network/envoy/security-policies.yaml` pointing to `oauth2-proxy` in `sec`.

### Authentication
OAuth2 Proxy (in `sec/oauth2-proxy`) sits in front of protected services, backed by **Keycloak** (in `sec/keycloak`). Keycloak is provisioned with a `cluster` realm, users, and the `oauth2-proxy` OIDC client via an `ExternalSecret` that templates a `ConfigMap` containing the full realm JSON.

`ReferenceGrant` in `sec/oauth2-proxy/ref-grant.yaml` allows cross-namespace `SecurityPolicy` references from multiple namespaces to the `oauth2-proxy` service.

## Key Conventions

### Component Structure
Every deployable component follows this layout:
```
<namespace>/<app>/
├── kustomization.yaml   # Kustomize root; declares helmCharts and resources
├── values.yaml          # Helm values (primary)
├── httproute.yaml       # HTTPRoute(s) for ingress (if exposed)
└── external-secrets.yaml  # ExternalSecret(s) pulling from Vault (if needed)
```

Additional values files (e.g. `jobs.yaml`, `alerting.yaml`, `dashboards/`) are referenced via `additionalValuesFiles` in the `helmCharts` entry.

### Kustomize + Helm Hybrid
All Helm charts are rendered inline via Kustomize's `helmCharts` field — **not** via ArgoCD's Helm support. This means `kubectl kustomize --enable-helm` is the canonical render path. Vendored chart tarballs are stored in `<component>/charts/` when local rendering is required.

### Custom Local Charts (media/ and p2p/)
`media/` and `p2p/` apps use **local custom Helm charts** co-located with the component (each has its own `Chart.yaml` + `templates/`). Their `kustomization.yaml` sets `helmGlobals.chartHome: ../` so Kustomize finds the chart by directory name.

### `envsubst` Variable Substitution
Raw `${VAR}` placeholders are used throughout YAML files (HTTPRoute hostnames, cert-manager issuers, Cilium values, etc.) and are substituted at apply time via `envsubst`. Only the variables listed in the explicit `envsubst '${VAR1} ${VAR2}'` call are substituted — this avoids clobbering unrelated `${}` expressions.

### Renovate Auto-merge
`renovate.json` is configured to auto-merge minor and patch updates for stable (non-`0.x`) packages. Major version bumps require manual review.

### Adding a New App
1. Create `<namespace>/<app>/` with `kustomization.yaml`, `values.yaml`, and any additional files following the component structure above.
2. Register it in [`homelab-apps`](https://github.com/msdeleyto/homelab-apps) by adding `- name: <app>` to the relevant `ApplicationSet` list under `prod/` and/or `test/`.
