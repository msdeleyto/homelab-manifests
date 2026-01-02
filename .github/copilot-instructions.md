# Copilot Instructions: k8s-homelab

## Architecture Overview

This is a **GitOps-managed Kubernetes homelab** using ArgoCD for continuous delivery. Each top-level directory maps to a Kubernetes **namespace**. After bootstrapping critical infrastructure, ArgoCD monitors this repo and automatically syncs changes to the cluster.

**Critical bootstrap order:**
1. `storage/` (NFS provisioner)
2. `network/` (MetalLB, Traefik, Cert-Manager)
3. `vault/` (secrets management)
4. `devops-tools/` (ArgoCD)

Bootstrap scripts are located in `<namespace>/tooling/bootstrap`.

## Project Structure Patterns

### Helm Chart Pattern
Services use **local Helm charts** (not external repos). Each service has:
- `Chart.yaml` - minimal metadata (name, version, description)
- `kustomization.yaml` - references the local chart with `helmGlobals.chartHome: ../`
- `values.yaml` - configuration values
- `templates/` - Kubernetes manifests with Helm templating

**Example:** [media/jellyfin/](media/jellyfin/)

### Mixed Helm Pattern
Some services combine **external + local Helm charts** in one kustomization:
- External chart for the base application (e.g., Traefik from official repo)
- Local chart for custom resources (e.g., IngressRoutes, ServiceAccounts)

**Example:** [network/traefik/kustomization.yaml](network/traefik/kustomization.yaml)

### Pure Kustomize Pattern  
Simple services use direct Kustomize with external Helm charts:

**Example:** [devops-tools/argocd/kustomization.yaml](devops-tools/argocd/kustomization.yaml)

## Secrets Management (Critical!)

All secrets use **Vault secret path placeholders** in the format: `<path:secret/data/category#key>`

Examples:
```yaml
domain: <path:secret/data/infra#domain>
adminPassword: <path:secret/data/monitoring/grafana#admin_password>
nfs: <path:secret/data/infra#nfs>
```

**Two secret workflows:**

1. **Bootstrap scripts** replace placeholders with environment variables via `sed`:
   ```bash
   sed -i "s|<path:secret/data/infra#domain>|${DOMAIN}|" values.yaml
   ```

2. **ArgoCD-managed** services use [Vault Plugin](https://argocd-vault-plugin.readthedocs.io/) to inject secrets at sync time.

**Never commit real secrets to the repo.** Use the `vault/tooling/load-secrets` script to populate Vault.

## Deployment Commands

Deploy manifests using `kubectl kustomize` with the `--enable-helm` flag:

```bash
# Apply a service
kubectl kustomize media/jellyfin --enable-helm | kubectl apply -f -

# Bootstrap network infrastructure
./network/tooling/bootstrap
```

**Note:** Standard `kubectl apply -k` does NOT support Helm charts. Always use the explicit kustomize command.

## Common Patterns

### Storage
All PVCs use `storageClassName: nfs-sc` (NFS provisioner deployed in storage namespace).

### Ingress
Services expose via Traefik **IngressRoutes** (not standard Ingress resources):
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
spec:
  entryPoints: [websecure]
  routes:
  - match: Host(`service.{{ .Values.domain }}`)
```

TLS certificates are automatically provisioned via Cert-Manager with Let's Encrypt.

### Node Scheduling
Services specify node selectors based on cluster node labels (e.g., `size: m` for medium nodes).

## Automation

- **Renovate:** Automatically updates Helm chart versions and container images
- **ArgoCD:** Auto-syncs Git changes to cluster (automated prune/self-heal enabled)
- **Vault Unsealer:** CronJob in `vault/unsealer/` automatically unseals Vault after restarts
