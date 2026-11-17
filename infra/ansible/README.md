# Proxmox VE Ansible Host Configuration

## What the Playbook Does

[`pve-config.yaml`](pve-config.yaml):
1. **Updates Repositories to No-Subscription (DEB822)**: Disables the enterprise repositories in `/etc/apt/sources.list.d/pve-enterprise.sources` and `/etc/apt/sources.list.d/ceph.sources`, and configures community no-subscription `.sources` files for Proxmox VE (`pve-no-subscription.sources`) and Ceph (`ceph-no-subscription.sources`), followed by an APT cache update.
2. **Hardens SSH**: Installs your local public SSH key (configured via `ssh_public_key_file` variable) into root's `authorized_keys` (exclusive — replaces any existing keys), and hardens `/etc/ssh/sshd_config` (disables password authentication, disables keyboard-interactive, enforces publickey-only auth, sets `PermitRootLogin prohibit-password`).
3. **Creates the Terraform Role (`TerraformProv`)**: Sets up the role with the least-privilege permissions needed for Day-1 terraform management (datastore, VM, pool, SDN, and system audit privileges). Creates the role if it doesn't exist, or updates its privileges if it does.
4. **Creates the Terraform Service User (`terraform@pve`)**: Creates the dedicated service user in the `pve` authentication realm.
5. **Assigns Permissions (ACL)**: Binds `TerraformProv` to `terraform@pve` recursively at root path (`/`).
6. **Generates API Token**: Generates the Terraform API token (`-privsep=0`).
7. **Installs Glances (host monitoring)**: Installs Glances with sensor support in a Python venv at `/opt/glances`, with a systemd service running the web UI (`glances -w`).

## Usage

```bash
# If using password authentication for the initial run
ansible-playbook -i inventory.[prod|test].ini pve-config.yaml --ask-pass

# Once SSH keys are in place
ansible-playbook -i inventory.[prod|test].ini pve-config.yaml
```
