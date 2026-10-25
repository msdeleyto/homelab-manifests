# Proxmox VE Ansible Host Configuration

## What the Playbook Does

[`pve-config.yaml`](pve-config.yaml):
1. **Updates Repositories to No-Subscription (DEB822)**: Disables the enterprise repositories in `/etc/apt/sources.list.d/pve-enterprise.sources` and `/etc/apt/sources.list.d/ceph.sources`, and configures community no-subscription `.sources` files for Proxmox VE (`pve-no-subscription.sources`) and Ceph (`ceph-no-subscription.sources`), followed by an APT cache update.
2. **Installs Local User SSH Key & Hardens SSH**: Installs your local public SSH key (`~/.ssh/id_ed25519.pub`) into root's `authorized_keys`, and configures `/etc/ssh/sshd_config.d/hardening.conf` (disabling password authentication, disabling keyboard-interactive, setting `PermitRootLogin prohibit-password`, disabling X11 forwarding, and setting `MaxAuthTries 3`).
3. **Creates the Terraform Role (`TerraformProv`)**: Sets up the role with the least-privilege permissions needed for Day-1 Terraform management.
4. **Creates the Terraform Service User (`terraform@pve`)**: Creates the dedicated service user in the `pve` authentication realm.
5. **Assigns Permissions (ACL)**: Binds `TerraformProv` to `terraform@pve` recursively at root path (`/`).
6. **Generates API Token**: Generates the Terraform API token (`-privsep=0`).

## Usage

```bash
# If using password authentication for the initial run
ansible-playbook -i inventory.[prod|test].ini pve-config.yaml --ask-pass

# Once SSH keys are in place
ansible-playbook -i inventory.[prod|test].ini pve-config.yaml
```
