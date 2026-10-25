# Proxmox VE Ansible Host Configuration

## What the Playbook Does

[`pve-config.yaml`](pve-config.yaml):
1. **Updates Repositories to No-Subscription (DEB822)**: Disables the enterprise repositories in `/etc/apt/sources.list.d/pve-enterprise.sources` and `/etc/apt/sources.list.d/ceph.sources`, and configures community no-subscription `.sources` files for Proxmox VE (`pve-no-subscription.sources`) and Ceph (`ceph-no-subscription.sources`), followed by an APT cache update.
2. **Installs Local User SSH Key**: Detects and installs the local user's public SSH key (`~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`) into the root user's `authorized_keys`.
3. **Creates the Terraform Role (`TerraformProv`)**: Sets up the role with the least-privilege permissions documented in [`docs/proxmox-setup.md`](../../docs/proxmox-setup.md).
4. **Creates the Terraform Service User (`terraform@pve`)**: Creates the dedicated service user in the `pve` authentication realm.
5. **Assigns Permissions (ACL)**: Binds `TerraformProv` to `terraform@pve` recursively at root path (`/`).

## Usage

```bash
# If using password authentication for the initial run
ansible-playbook -i inventory.[prod|test].ini pve-config.yaml --ask-pass

# Once SSH keys are in place
ansible-playbook -i inventory.ini pve-config.yaml
```
