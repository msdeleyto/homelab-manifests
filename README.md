# Homelab Manifests

GitOps-managed Kubernetes homelab services using ArgoCD, Kustomize, and Helm.

## Overview

This repository contains Kubernetes manifests for a homelab cluster, serving two purposes:

1. **GitOps Source** — ArgoCD monitors this repo via the App of Apps pattern
2. **Cluster Bootstrap** — Initial cluster setup via `tooling/bootstrap`

## Repository Structure
```
├── longhorn-system/ # Distributed block storage
├── network/ # Cilium, Istio, cert-manager
├── vault/ # HashiCorp Vault
├── external-secrets/ # External Secrets Operator
├── devops-tools/ # ArgoCD, Renovate, GitHub runners
├── monitoring/ # Grafana, Prometheus, Loki, Tempo, Alloy, CrowdSec
├── media/ # Application workloads
├── p2p/ # P2P applications
├── sec/ # Security tools (Falco, kube-bench)
└── tooling/ # Bootstrap orchestration
```

## Core Pillars

| Area | Components |
|------|------------|
| **GitOps / IaC** | ArgoCD, Kustomize + Helm hybrid, Renovate |
| **Secret Management** | HashiCorp Vault, External Secrets Operator |
| **Networking** | Cilium, Istio, cert-manager |
| **Storage** | Longhorn distributed storage |
| **Observability** | Grafana, Prometheus, Loki, Tempo, Alloy, Kiali |
| **Security** | Falco, kube-bench, CrowdSec |

## Bootstrap

```bash
# Cilium is replacing the CNI and kube-proxy on this setup, run on control plane before more control planes join the cluster
./network/tooling/bootstrap
```

```bash
# Ensure the environment variables listed in .env.example are available
./tooling/bootstrap <secrets.yaml> <secret-files.yaml>
```

Secrets Management
Manual secret updates via Vault:

```bash
./vault/tooling/load-secrets <secrets.yaml>
./vault/tooling/load-secret-files <secret-files.yaml>
```
