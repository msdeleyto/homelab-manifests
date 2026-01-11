# Copilot Instructions for k8s-homelab

## Architecture Overview

This is a Kubernetes homelab GitOps repository managed by ArgoCD. Infrastructure is organized into domain-specific directories, each containing Kustomize + Helm configurations.

**Layer structure (deploy order matters):**
1. `vault/` → HashiCorp Vault for secrets management
2. `storage/` → NFS storage class provisioner
3. `network/` → MetalLB, Traefik ingress, cert-manager
4. `devops-tools/` → ArgoCD, Renovate, GitHub Actions runners
5. `monitoring/` → Grafana, Prometheus, Loki, Tempo, Alloy
6. `media/` → Application workloads (Jellyfin, CWA)
7. `sec/` → Security tools (Falco, kube-bench)

## Key Patterns

### Kustomize + Helm Hybrid
All components use Kustomize with inline Helm charts. Pattern in [monitoring/grafana/kustomization.yaml](monitoring/grafana/kustomization.yaml):
```yaml
helmCharts:
- name: grafana
  repo: https://grafana.github.io/helm-charts
  version: 10.5.4
  valuesFile: values.yaml
```
Local charts (e.g., `media/jellyfin/`) use `helmGlobals.chartHome: ../` to reference the parent Chart.yaml.

### Vault Secret Placeholders
Secrets use placeholder syntax: `<path:secret/data/namespace/app#key>`
- ArgoCD Vault Plugin replaces these at deploy time
- Bootstrap scripts use `sed` to replace during initial setup
- Example in [media/jellyfin/values.yaml](media/jellyfin/values.yaml): `domain: <path:secret/data/infra#domain>`

### Traefik IngressRoutes
All services use Traefik CRD `IngressRoute` instead of standard Ingress. Template pattern in [media/jellyfin/templates/ingressroute.yaml](media/jellyfin/templates/ingressroute.yaml):
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
spec:
  entryPoints: [websecure]
  routes:
  - match: Host(`app.{{ .Values.domain }}`)
```

## Bootstrap Workflow

Initial cluster setup requires running bootstrap scripts in order (see [.env.example](../.env.example) for required variables):
1. `storage/tooling/bootstrap` → NFS storage class
2. `network/tooling/bootstrap` → Traefik, cert-manager, MetalLB
3. `vault/tooling/bootstrap` → Deploy Vault, then unseal and run `vault/tooling/configure`
4. `vault/tooling/load-secrets <secrets.yaml>` → Load secrets into Vault
5. `devops-tools/tooling/bootstrap` → ArgoCD

After bootstrap, ArgoCD syncs from [devops-tools/argocd/application.yaml](devops-tools/argocd/application.yaml) which points to an external `argocd-config` repo using the **App of Apps** pattern.

## Adding New Applications

1. Create directory under appropriate domain (e.g., `media/myapp/`)
2. Add `Chart.yaml` (for local charts) or use remote Helm repo
3. Create `kustomization.yaml` with `helmCharts` definition
4. Add `values.yaml` with Vault placeholders for secrets
5. Create `templates/` with: `deployment.yaml`, `service.yaml`, `ingressroute.yaml`
6. Add secrets to Vault under `secret/data/<namespace>/<app>`

## Conventions

- **Namespaces** match directory names: `monitoring/`, `media/`, `network/`, `devops-tools/`
- **Storage**: Use `storageClassName: nfs-sc` for persistent volumes
- **Node selection**: Use `nodeSelector.size: m` or similar for workload placement
- **Image tags**: Prefer explicit versions, Renovate auto-updates via `renovate.json`
