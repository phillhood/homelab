# Kubernetes

### bootstrap

```bash
./deploy.sh deploy
./deploy.sh deps
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