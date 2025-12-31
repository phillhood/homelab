# Ansible

1. Create `group_vars/all.yml` from example:
   ```bash
   cp group_vars/all.yml.example group_vars/all.yml
   ```

2. Run playbooks:
   ```bash
   ansible-playbook playbooks/k3s-install.yml
   ansible-playbook playbooks/k3s-kubeconfig.yml
   ```
