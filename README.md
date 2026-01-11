# k8s-homelab

GitOps-managed Kubernetes homelab infrastructure using ArgoCD, Kustomize, and Helm.

## Repository Structure

```
├── storage/      # NFS storage class provisioner
├── network/      # MetalLB, Traefik, cert-manager
├── vault/        # HashiCorp Vault for secrets
├── devops-tools/ # ArgoCD, Renovate, GitHub runners
├── monitoring/   # Grafana, Prometheus, Loki, Tempo
├── media/        # Application workloads (Jellyfin, CWA)
└── sec/          # Security tools (Falco, kube-bench)
```

## Bootstrap

1. Copy and configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your values
   source .env
   ```

2. Run bootstrap scripts in order:
   ```bash
   ./storage/tooling/bootstrap
   ./network/tooling/bootstrap
   ./vault/tooling/bootstrap
   # Unseal Vault, then:
   ./vault/tooling/configure
   ./vault/tooling/load-secrets <secrets.yaml>
   ./devops-tools/tooling/bootstrap
   ```

After bootstrap, ArgoCD manages all deployments via the [App of Apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/) pattern from the `argocd-config` repository.

## Adding New Services

1. Create directory under appropriate domain:
   ```
   media/myapp/
   ├── Chart.yaml
   ├── kustomization.yaml
   ├── values.yaml
   └── templates/
       ├── deployment.yaml
       ├── service.yaml
       └── ingressroute.yaml
   ```

2. Add secrets to Vault:
   ```bash
   kubectl -n vault exec -it vault-0 -- vault kv put secret/media/myapp key=value
   ```

3. **Update `argocd-config` repo** to include the new application for deployment.

## Guidelines

| Aspect | Convention |
|--------|------------|
| **Config management** | Kustomize + Helm hybrid ([example](monitoring/grafana/kustomization.yaml)) |
| **Ingress** | Traefik `IngressRoute` CRD, not standard Ingress |
| **Secrets** | Vault placeholders: `<path:secret/data/namespace/app#key>` |
| **Storage** | `storageClassName: nfs-sc` |
| **Namespaces** | Match directory names (`media/`, `monitoring/`, etc.) |
| **Image tags** | Explicit versions; Renovate handles updates |

## Secrets Format

Secrets YAML for `load-secrets` script:
```yaml
infra:
  domain: home.example.com
  nfs: 192.168.1.100
media:
  jellyfin:
    api_key: xxx
```
