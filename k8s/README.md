# Kubernetes

## Setup

1. Copy and configure values:
   ```bash
   cp values.yaml.example values.yaml
   ```

2. Deploy everything:
   ```bash
   ./deploy.sh
   ```

## Cheat Sheet

### bootstrap

```bash
./deploy.sh deploy    # Deploy all apps in order
./deploy.sh deps      # Update all Helm dependencies
```

### helm

```bash
helm upgrade --install <release> <app> -n <namespace> -f values.yaml
helm uninstall <release> -n <namespace>
```

```bash
helm list -A
helm status <release> -n <namespace>
helm get values <release> -n <namespace>
helm rollback <release> <revision> -n <namespace>
helm template <release> apps/<category>/<app> -f values.yaml
```

### kubectl

```bash
# Get
kubectl get pods -n <namespace>
kubectl get all -n <namespace>
kubectl describe pod <pod> -n <namespace>

# Logs
kubectl logs <pod> -n <namespace>
kubectl logs -f <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --previous

# Restart
kubectl rollout restart deployment/<name> -n <namespace>

# Delete
kubectl delete pod <pod> -n <namespace> --force --grace-period=0
```