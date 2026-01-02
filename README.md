# k8s-homelab

A production-grade GitOps-managed Kubernetes homelab using ArgoCD for continuous delivery and HashiCorp Vault for secrets management.

## Overview

This repository contains declarative Kubernetes manifests and Helm charts for deploying a complete homelab infrastructure. All services follow GitOps principles with ArgoCD continuously monitoring this repository and synchronizing the desired state to the cluster.

**Key Features:**
- 🔄 GitOps workflow with ArgoCD
- 🔐 Centralized secrets management with Vault
- 🌐 Automatic TLS certificates via Cert-Manager + Let's Encrypt
- 📊 Full observability stack (Prometheus, Grafana, Loki, Tempo)
- 🛡️ Security monitoring with Falco and CrowdSec
- 🤖 Automated dependency updates with Renovate

## Repository Structure

Each top-level directory represents a **Kubernetes namespace** containing related services:

```
k8s-homelab/
├── devops-tools/       # CI/CD infrastructure (ArgoCD, Renovate, GitHub Arc Runners)
├── media/              # Media management (Jellyfin, Calibre Web Automated)
├── monitoring/         # Observability (Prometheus, Grafana, Loki, Tempo, Alloy, CrowdSec)
├── network/            # Network infrastructure (Traefik, Cert-Manager, MetalLB)
├── sec/                # Security tooling (Falco, KubeBench)
├── storage/            # Storage solutions (NFS provisioner)
└── vault/              # Secrets management (HashiCorp Vault + auto-unsealer)
```

### Service Deployment Patterns

This repository uses three deployment patterns:

1. **Local Helm Chart Pattern** - Custom charts in `templates/` with local `Chart.yaml`
   - Example: [`media/jellyfin/`](media/jellyfin/)

2. **Mixed Helm Pattern** - External chart + local custom resources
   - Example: [`network/traefik/`](network/traefik/) (official Traefik chart + custom IngressRoutes)

3. **Pure Kustomize Pattern** - Direct Kustomize with external Helm charts
   - Example: [`devops-tools/argocd/`](devops-tools/argocd/)

All patterns use `kustomization.yaml` as the entry point. See [`.github/copilot-instructions.md`](.github/copilot-instructions.md) for detailed patterns.

## Bootstrap Process

Critical infrastructure must be deployed in order using bootstrap scripts before ArgoCD takes over:

### Prerequisites

- Kubernetes cluster running (k3s, k0s, or standard k8s)
- `kubectl` configured with cluster access
- `helm` CLI installed
- `yq` installed for secret management
- Environment variables set (see [Secrets Management](#secrets-management))

### Bootstrap Order

```bash
# 1. Storage layer (NFS provisioner)
export K8S_NFS="nfs-server-ip:/export/path"
./storage/tooling/bootstrap

# 2. Network infrastructure (MetalLB, Traefik, Cert-Manager)
export DOMAIN="example.com"
export NFS="nfs-server-ip:/export/path"
export CROWDSEC_TRAEFIK_BOUNCER_KEY="your-key"
export LETS_ENCRYPT_EMAIL="admin@example.com"
export CERT_MANAGER_API_TOKEN="cloudflare-api-token"
./network/tooling/bootstrap

# 3. Vault (secrets management)
./vault/tooling/bootstrap

# 4. Load secrets into Vault
./vault/tooling/load-secrets secrets.yaml
./vault/tooling/load-secret-files secret-files.yaml

# 5. DevOps tools (ArgoCD)
export ARGOCD_PASSWORD="bcrypt-hashed-password"
export ARGOCD_GH_ORG1_USERNAME="github-username"
export ARGOCD_GH_ORG1_PASSWORD="github-pat"
./devops-tools/tooling/bootstrap
```

After bootstrapping, ArgoCD automatically manages all subsequent deployments and updates.

## Secrets Management

This repository uses **HashiCorp Vault** for centralized secrets management. All secrets in manifests use placeholder format:

```yaml
domain: <path:secret/data/infra#domain>
adminPassword: <path:secret/data/monitoring/grafana#admin_password>
```

### Two Secret Workflows:

1. **Bootstrap Phase**: Scripts replace placeholders with environment variables:
   ```bash
   sed -i "s|<path:secret/data/infra#domain>|${DOMAIN}|" values.yaml
   ```

2. **ArgoCD Phase**: [Vault Plugin](https://argocd-vault-plugin.readthedocs.io/) injects secrets at sync time

### Loading Secrets

Create a `secrets.yaml` file (NOT committed to repo):

```yaml
infra:
  domain: example.com
  nfs: nfs-server-ip:/path
  k8s_nfs: nfs-server-ip:/k8s/path

monitoring:
  grafana:
    admin_password: secure-password

network:
  certmanager:
    letsEncryptEmail: admin@example.com
    apiToken: cloudflare-token
```

Load into Vault:

```bash
./vault/tooling/load-secrets secrets.yaml
```

For file-based secrets (private keys, certificates):

```bash
./vault/tooling/load-secret-files secret-files.yaml
```

**⚠️ Never commit real secrets to this repository!**

## Deployment Commands

Deploy services using `kubectl kustomize` with `--enable-helm` flag:

```bash
# Deploy a service
kubectl kustomize media/jellyfin --enable-helm | kubectl apply -f -

# Validate before applying
kubectl kustomize media/jellyfin --enable-helm | kubectl diff -f -

# Delete a service
kubectl kustomize media/jellyfin --enable-helm | kubectl delete -f -
```

**Note:** Standard `kubectl apply -k` does NOT support Helm charts. Always use explicit `kustomize` command.

## ArgoCD Management

After bootstrap, configure ArgoCD to monitor this repository:

1. Access ArgoCD UI: `https://argocd.<your-domain>`
2. Login with bootstrap credentials
3. Create Application pointing to this repository
4. Enable auto-sync, auto-prune, and self-heal

ArgoCD will automatically:
- Deploy new services added to the repository
- Update existing services on manifest changes
- Remove services deleted from the repository
- Inject Vault secrets at deployment time

## Technology Stack

| Category | Technologies |
|----------|-------------|
| **GitOps** | ArgoCD |
| **Package Management** | Helm 3, Kustomize |
| **Ingress** | Traefik v3 (IngressRoute CRDs) |
| **TLS Certificates** | Cert-Manager + Let's Encrypt |
| **Load Balancing** | MetalLB |
| **Storage** | NFS CSI Provisioner |
| **Secrets** | HashiCorp Vault |
| **Monitoring** | Prometheus, Grafana, Alloy |
| **Logging** | Loki |
| **Tracing** | Tempo |
| **Security** | Falco (runtime), CrowdSec (threat detection), KubeBench |
| **Automation** | Renovate (dependency updates) |

## Common Operations

### Adding a New Service

1. Create service directory under appropriate namespace:
   ```bash
   mkdir -p media/newservice
   ```

2. Create Helm chart structure:
   ```
   media/newservice/
   ├── Chart.yaml
   ├── kustomization.yaml
   ├── values.yaml
   └── templates/
       ├── deployment.yaml
       ├── service.yaml
       └── ingressroute.yaml
   ```

3. Use Vault placeholders for secrets in `values.yaml`

4. Commit and push - ArgoCD will deploy automatically

### Updating a Service

1. Modify manifests or values
2. Commit and push
3. ArgoCD syncs changes within minutes

### Viewing Logs

```bash
# Service logs
kubectl logs -n <namespace> <pod-name>

# ArgoCD sync logs
kubectl logs -n devops-tools -l app.kubernetes.io/name=argocd-server
```

## Storage Configuration

All persistent volumes use `storageClassName: nfs-sc` provided by the NFS provisioner in [`storage/nfs/`](storage/nfs/).

Example PVC:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  storageClassName: nfs-sc
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 10Gi
```

## Ingress Configuration

Services expose via Traefik **IngressRoutes** (not standard Ingress):

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: service
spec:
  entryPoints: [websecure]
  routes:
  - match: Host(`service.{{ .Values.domain }}`)
    kind: Rule
    services:
    - name: service
      port: 80
  tls:
    certResolver: letsencrypt
```

TLS certificates are automatically issued by Cert-Manager.

## Monitoring Access

- **Grafana**: `https://grafana.<your-domain>`
- **Prometheus**: `https://prometheus.<your-domain>`
- **ArgoCD**: `https://argocd.<your-domain>`

Default credentials are stored in Vault under respective namespaces.

## Troubleshooting

### ArgoCD Not Syncing

```bash
# Check ArgoCD application status
kubectl get applications -n devops-tools

# View sync errors
kubectl describe application <app-name> -n devops-tools
```

### Vault Sealed

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# Manually unseal (auto-unsealer CronJob should handle this)
kubectl exec -n vault vault-0 -- vault operator unseal
```

### Certificate Issues

```bash
# Check cert-manager logs
kubectl logs -n network -l app=cert-manager

# Check certificate status
kubectl get certificates -A
```

## Contributing

1. Create feature branch from `main`
2. Make changes following project patterns (see [`.github/copilot-instructions.md`](.github/copilot-instructions.md))
3. Test locally: `kubectl kustomize <path> --enable-helm | kubectl diff -f -`
4. Submit pull request
5. After merge, ArgoCD auto-deploys to cluster

**Important:**
- Never commit secrets
- Use Vault placeholders for sensitive data
- Follow existing Helm chart patterns
- Test with `kubectl diff` before merging

## License

This is a personal homelab project. Use at your own risk.

## Acknowledgments

Built with open-source tools from the Cloud Native Computing Foundation (CNCF) ecosystem.
