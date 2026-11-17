# ArgoCD ApplicationSets

ArgoCD ApplicationSet definitions for managing a Kubernetes homelab with GitOps, organized by environment.

## Structure

Each environment directory (`prod/`, `test/`) contains one YAML file per application group. Each file defines either an `ApplicationSet` (for apps with multiple components) or an `Application` (for single resources like CRDs).

ApplicationSets use a list generator with `name` and `path` elements, where `path` points to the corresponding manifests directory under `manifests/`:

```yaml
generators:
  - list:
      elements:
        - name: component-a
          path: ./manifests/<group>/component-a
        - name: component-b
          path: ./manifests/<group>/component-b
```

## Features

- Automated sync with self-healing and pruning
- Automatic namespace creation (`CreateNamespace=true`)
- Server-side apply (`ServerSideApply=true`)
- Sync-waves for bootstrap ordering (CRDs first, then storage, then the rest)
- Per-namespace pod security standards via `managedNamespaceMetadata`

## Adding Applications

Edit the appropriate ApplicationSet YAML and add a new element to `generators.list.elements`:

```yaml
elements:
  - name: existing-app
    path: ./manifests/<group>/existing-app
  - name: new-app
    path: ./manifests/<group>/new-app
```

Make sure the corresponding manifests directory exists under `manifests/`.

## Adding a New Application Group

Create a new YAML file in the environment directory (e.g., `apps/prod/my-group.yaml`) following the existing ApplicationSet pattern. The file name becomes part of the ArgoCD application naming convention.
