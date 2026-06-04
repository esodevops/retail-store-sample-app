# Helm Deployment for Project Bedrock

The umbrella chart lives at `src/app/chart`. This folder contains Bedrock-specific values and deployment automation.

## Files

- `values-bedrock.yaml`: Managed RDS/DynamoDB overrides + in-cluster RabbitMQ/Redis.
- `values-bedrock.generated.yaml`: Created by `scripts/sync-retail-secrets.sh` with live RDS endpoints.
- `deploy-bedrock.sh`: Installs ALB controller and deploys the retail app.

## Deploy

```sh
./scripts/sync-retail-secrets.sh
./helm/deploy-bedrock.sh
```

## Direct command

```sh
helm dependency build src/app/chart
helm upgrade --install retail src/app/chart \
  --namespace retail-app \
  --create-namespace \
  -f src/app/chart/values.yaml \
  -f helm/values-bedrock.yaml \
  -f helm/values-bedrock.generated.yaml
```
