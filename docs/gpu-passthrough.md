# AMD GPU Passthrough Implementation

This document describes the implementation of AMD GPU passthrough from Proxmox VE hosts to Talos VMs in the Kubernetes cluster.

## Overview

The implementation enables passing an AMD integrated GPU (iGPU) from the Proxmox VE host to a specific Talos node. The node is labeled with both NFD-compatible PCI labels and `gpu.amd.com/*` capability labels for Kubernetes workload scheduling.

## Kubernetes Labels

GPU nodes receive the following labels (set both declaratively via Talos `kubelet.nodeLabels` and enforced post-bootstrap via `kubectl`):

| Label | Value | Purpose |
|---|---|---|
| `feature.node.kubernetes.io/pci-0300_1002.present` | `true` | NFD-compatible — indicates an AMD VGA controller is present |
| `feature.node.kubernetes.io/pci-0300_1002.vendor` | `1002` | NFD-compatible — PCI vendor ID for AMD |
| `gpu.amd.com/present` | `true` | GPU is available on this node |
| `gpu.amd.com/vaapi` | `true` | VA-API hardware acceleration is available via `/dev/dri` |
| `amdgpu` | `true` | Backward-compatible label for existing workloads |

Workloads can select GPU nodes using any of these labels. Prefer `gpu.amd.com/present` or the NFD labels for new workloads.

## Components

### 1. Ansible Playbook (`infra/ansible/pve-config.yaml`)

The Ansible playbook now includes GPU passthrough configuration:

- **IOMMU kernel parameters**: Enables AMD IOMMU and binds GPU PCI devices to vfio-pci driver
- **vfio module loading**: Ensures vfio modules load before amdgpu/snd_hda_intel
- **PCI resource mapping**: Creates a PVE PCI resource mapping for the GPU
- **Terraform permissions**: Grants the terraform user permission to use PCI mappings

**Variables** (set in inventory files):
```yaml
gpu_passthrough_enabled: true
gpu_pci_ids: ["1002:164c", "1002:1637"]  # Vendor:Device IDs
gpu_mapping_name: "amdgpu"
gpu_pci_addresses: ["0000:04:00.0", "0000:04:00.1"]  # PCI addresses
```

**Inventory files**:
- `infra/ansible/inventory.prod.ini` - Production host (AMD Lucienne iGPU on Ryzen 7 5700U)
- `infra/ansible/inventory.test.ini` - Test host (AMD Barcelo iGPU on Ryzen 7 7730U)

### 2. Terraform VM Module (`infra/terraform/modules/talos-vm`)

Updated to support optional GPU passthrough per node:

- **New variable**: `gpu_mapping` (optional string) in the nodes configuration
- **Conditional machine type**: Uses `q35` when GPU is attached, `pc` otherwise
- **Dynamic hostpci block**: Attaches GPU via PVE PCI resource mapping when configured

### 3. Terraform Cluster Module (`infra/terraform/modules/talos-cluster`)

Automatically applies Kubernetes labels to GPU-equipped nodes via Talos machine configuration:

- **Declarative labels**: GPU-specific `kubelet.nodeLabels` patch is merged into the machine configuration for nodes with `gpu_mapping` set. Labels are applied by the kubelet at node registration and survive reboots.
- **No post-bootstrap kubectl**: Labels are part of the machine config, eliminating the need for kubeconfig management and post-hoc label application.

## Usage

### 1. Configure Ansible Inventory

Edit the appropriate inventory file (`inventory.prod.ini` or `inventory.test.ini`) to set GPU passthrough variables:

```ini
gpu_passthrough_enabled=true
gpu_pci_ids=["1002:164c", "1002:1637"]
gpu_mapping_name="amdgpu"
gpu_pci_addresses=["0000:04:00.0", "0000:04:00.1"]
```

To find the correct PCI IDs and addresses for your GPU:
```bash
lspci -nn | grep -i vga
# Note the [vendor:device] ID and the PCI address (e.g., 04:00.0)

lspci -nn | grep -i audio | grep -i amd
# Note the HDMI audio function PCI address
```

### 2. Run Ansible Playbook

```bash
cd infra/ansible
ansible-playbook -i inventory.prod.ini pve-config.yaml
```

This will:
- Configure IOMMU kernel parameters
- Set up vfio-pci driver binding
- Create the PCI resource mapping in PVE
- Reboot the host to apply changes

After reboot, verify vfio-pci owns the GPU:
```bash
lspci -nnk -s 04:00.0  # Should show "Kernel driver in use: vfio-pci"
```

### 3. Configure Terraform Node

Edit the appropriate `terraform.tfvars` file to add `gpu_mapping` to the target node:

```hcl
nodes = {
  "talos01" = { ... },
  "talos02" = { ... },
  "talos03" = { 
    vmid = 103, 
    ip = "192.168.10.23/24", 
    controlplane = true, 
    cpu_cores = 4, 
    memory_mb = 8192, 
    os_disk_gb = 30, 
    data_disk_gb = 100, 
    mac_address = "AC:24:11:AA:BB:03",
    gpu_mapping = "amdgpu"  # <-- Add this line
  }
}
```

### 4. Apply Terraform Configuration

```bash
cd infra/terraform/environments/prod
terraform init
terraform plan
terraform apply
```

Terraform will:
- Recreate the VM with `q35` machine type (if needed)
- Attach the GPU via PCI resource mapping
- Apply the `amdgpu=true` label to the node

### 5. Verify GPU Access in Kubernetes

```bash
# Check GPU labels on nodes
kubectl get nodes --show-labels | grep -E 'gpu\.amd\.com|amdgpu|pci-0300_1002'

# Verify all expected labels are present on the GPU node
kubectl get node talos03 --show-labels

# Check GPU devices in the node status
kubectl get node talos03 -o json | jq '.status.allocatable'

# Test GPU access from a pod (mounts /dev/dri for VA-API)
kubectl run gpu-test \
  --image=rocm/rocm-terminal \
  --rm -it \
  --overrides='{"spec": {"nodeSelector": {"gpu.amd.com/present": "true"}}}' \
  -- /bin/bash
# Inside the pod:
ls -l /dev/dri/
vainfo  # if VA-API tools are available
```

## Limitations and Considerations

### AMD iGPU Reset Bug

AMD integrated GPUs (especially Renoir/Barcelo) may have the "AMD reset bug" where the GPU doesn't reset cleanly when a VM reboots. Symptoms:
- VM cannot reboot successfully
- Host requires reboot to recover GPU state

**Mitigations**:
- Avoid rebooting the VM; stop it fully before restarting
- Use `machine = "q35"` (already implemented)
- If the bug occurs, a host reboot is required

### Performance

- Integrated GPUs share system memory with the CPU
- Performance is limited compared to discrete GPUs
- Suitable for: light transcoding, display output, basic compute
- Not suitable for: heavy ML workloads, intensive rendering

### Single GPU per Host

- The GPU can only be passed to one VM at a time
- Cannot be shared between multiple VMs
- SR-IOV is not supported on consumer AMD iGPUs

## Troubleshooting

### GPU not showing as vfio-pci after Ansible run

1. Check kernel parameters:
   ```bash
   cat /proc/cmdline
   # Should include: amd_iommu=on iommu=pt vfio-pci.ids=...
   ```

2. Check if vfio modules loaded:
   ```bash
   lsmod | grep vfio
   ```

3. Check dmesg for IOMMU errors:
   ```bash
   dmesg | grep -i iommu
   ```

4. Reboot the host manually if needed

### Terraform fails to attach GPU

1. Verify PCI mapping exists:
   ```bash
   pvesh get /cluster/mapping/amdgpu
   ```

2. Check terraform user permissions:
   ```bash
   pveum acl list | grep terraform
   # Should show Mapping.Use or PVEVMAdmin
   ```

3. Verify GPU is bound to vfio-pci:
   ```bash
   lspci -nnk -s 04:00.0
   ```

### Kubernetes label not applied

1. Verify the node has `gpu_mapping` configured in `terraform.tfvars`

2. Check the Talos machine config:
   ```bash
   talosctl --nodes 192.168.10.23 get machineconfig -o yaml
   # Look for kubelet.nodeLabels section
   ```

3. If labels are missing, re-apply the Terraform configuration:
   ```bash
   cd infra/terraform/environments/prod
   terraform apply
   ```

4. Alternatively, apply labels manually (temporary fix):
   ```bash
   kubectl label node talos03 \
     feature.node.kubernetes.io/pci-0300_1002.present=true \
     feature.node.kubernetes.io/pci-0300_1002.vendor=1002 \
     gpu.amd.com/present=true \
     gpu.amd.com/vaapi=true \
     amdgpu=true \
     --overwrite
   ```

## Future Enhancements

- Support for discrete GPUs with better IOMMU isolation
- Automated GPU driver installation in Talos (via system extensions)
- GPU monitoring and metrics collection
- Multi-GPU support when discrete GPUs are added
