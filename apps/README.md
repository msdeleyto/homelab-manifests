# ArgoCD ApplicationSets

ArgoCD ApplicationSet definitions for managing a Kubernetes homelab with GitOps, organized by environment.

## Structure

```
prod/                      # Production environment
├── default.yaml
├── devops-tools.yaml
├── external-secrets.yaml
├── media.yaml
├── monitoring.yaml
├── network.yaml
├── p2p.yaml
└── vault.yaml

test/                      # Test environment
├── default.yaml
├── devops-tools.yaml
├── network.yaml
└── vault.yaml
```

## Features

- Automated sync with self-healing and pruning
- Automatic namespace creation
- Server-side apply enabled

## Adding Applications

Edit the appropriate ApplicationSet and add to `generators.list.elements`:

```yaml
elements:
  - name: existing-app
  - name: new-app
```
