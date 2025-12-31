# Ansible

## Setup

1. Create `group_vars/all.yml` from example:
   ```bash
   cp group_vars/all.yml.example group_vars/all.yml
   ```

2. Create vault password file:
   ```bash
   echo 'your-vault-password' > .vault_pass
   chmod 600 .vault_pass
   ```

## Vault

**Create a new vault file:**
```bash
ansible-vault create inventory/group_vars/k3s_cluster/vault.yml
```

**Edit existing vault:**
```bash
ansible-vault edit inventory/group_vars/k3s_cluster/vault.yml
```

**Encrypt an existing file:**
```bash
ansible-vault encrypt path/to/file.yml
```

**View vault contents:**
```bash
ansible-vault view inventory/group_vars/k3s_cluster/vault.yml
```

## Playbooks

```bash
ansible-playbook playbooks/k3s-install.yml
ansible-playbook playbooks/k3s-kubeconfig.yml
ansible-playbook playbooks/docker.yml --limit worker1
ansible-playbook playbooks/pelican.yml --limit worker1
```

### Adding a worker node

```bash
ansible-playbook playbooks/k3s-install.yml --limit worker1
```

The k3s token must be set in `inventory/group_vars/k3s_cluster/vault.yml`:
```yaml
k3s_token: "your-k3s-node-token"
```
