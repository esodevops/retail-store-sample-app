# Kubernetes Manifests for Project Bedrock

## Platform manifests

- `namespace.yaml`: Creates the `retail-app` namespace.
- `clusterrolebinding-dev-view.yaml`: Grants Kubernetes `view` ClusterRole to IAM user `bedrock-dev-view`.
- `ingress.yaml`: Exposes the UI service via AWS ALB over HTTP by default (no placeholder values required).
- `ingress-tls.yaml`: Optional HTTPS ingress using ACM certificate and ALB SSL redirect.
- `aws-load-balancer-controller.yaml`: Defines the `alb` IngressClass used by `ingress.yaml`.
- `retail-managed-secrets.template.yaml`: Manual secret template if not using `scripts/sync-retail-secrets.sh`.

## Deploy order

```sh
cd terraform && terraform apply
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster
./scripts/sync-retail-secrets.sh
./helm/deploy-bedrock.sh
```

See [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) and [helm/README.md](../helm/README.md).
