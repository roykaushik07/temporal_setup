# Temporal HELM Chart

Production-ready HELM chart for deploying Temporal to Kubernetes/EKS.

## Overview

This HELM chart deploys:
- Temporal Server (workflow engine)
- Temporal UI (web interface)
- Connects to external PostgreSQL (AWS RDS)
- Uses custom Docker images from Nexus

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PostgreSQL 12+ (AWS RDS or external)
- Custom Docker images in Nexus registry
- Database schemas already set up (see below)

## Quick Start

### 1. Prepare Database

Your AWS RDS PostgreSQL should have these databases created:
- `temporal` (main database)
- `temporal_visibility` (search/query database)

**Note:** Schema setup must be done manually before first deployment (see "Database Schema Setup" section).

### 2. Create Kubernetes Secret for Database Credentials

```bash
kubectl create secret generic temporal-db-credentials \
  --from-literal=username=temporal \
  --from-literal=password='your-rds-password'
```

### 3. Create Kubernetes Secret for Nexus Registry

```bash
kubectl create secret docker-registry nexus-registry-secret \
  --docker-server=your-nexus-url \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email@company.com
```

### 4. Create values-production.yaml

```yaml
# values-production.yaml
global:
  imagePullSecrets:
  - name: nexus-registry-secret

server:
  image:
    repository: your-nexus-url/temporal-server
    tag: "1.24.2"
  replicas: 3

ui:
  image:
    repository: your-nexus-url/temporal-ui
    tag: "2.30.0"
  replicas: 2
  ingress:
    enabled: true
    className: "nginx"
    hosts:
    - host: temporal-ui.your-company.com
      paths:
      - path: /
        pathType: Prefix

database:
  external:
    enabled: true
    host: "your-rds-endpoint.us-east-1.rds.amazonaws.com"
    port: 5432
    defaultDatabase: temporal
    visibilityDatabase: temporal_visibility
    user: temporal
    existingSecret: temporal-db-credentials
    ssl:
      enabled: true
      mode: require
```

### 5. Install the Chart

```bash
helm install temporal ./temporal-helm \
  -f values-production.yaml \
  --namespace temporal \
  --create-namespace
```

### 6. Verify Deployment

```bash
# Check pods
kubectl get pods -n temporal

# Check services
kubectl get svc -n temporal

# View logs
kubectl logs -n temporal deployment/temporal-server -f
```

## Database Schema Setup

**IMPORTANT:** You must set up database schemas BEFORE deploying Temporal.

### Option 1: Manual Setup (Recommended for Production)

```bash
# 1. Download schema files from Temporal GitHub
wget https://github.com/temporalio/temporal/archive/refs/tags/v1.24.2.tar.gz
tar -xzf v1.24.2.tar.gz

# 2. Use temporal-sql-tool (from your binaries)
# Setup default schema
./temporal-sql-tool \
  --plugin postgres12 \
  --ep your-rds-endpoint.amazonaws.com \
  --port 5432 \
  --user temporal \
  --password 'your-password' \
  --database temporal \
  setup-schema -v 0.0

# Update to latest version
./temporal-sql-tool \
  --plugin postgres12 \
  --ep your-rds-endpoint.amazonaws.com \
  --port 5432 \
  --user temporal \
  --password 'your-password' \
  --database temporal \
  update-schema -d temporal-1.24.2/schema/postgresql/v12/temporal/versioned

# Setup visibility schema
./temporal-sql-tool \
  --plugin postgres12 \
  --ep your-rds-endpoint.amazonaws.com \
  --port 5432 \
  --user temporal \
  --password 'your-password' \
  --database temporal_visibility \
  setup-schema -v 0.0

# Update visibility schema
./temporal-sql-tool \
  --plugin postgres12 \
  --ep your-rds-endpoint.amazonaws.com \
  --port 5432 \
  --user temporal \
  --password 'your-password' \
  --database temporal_visibility \
  update-schema -d temporal-1.24.2/schema/postgresql/v12/visibility/versioned
```

### Option 2: Kubernetes Job (Future Enhancement)

A schema-setup init job will be added in a future version.

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `server.image.repository` | Temporal server image | `your-nexus-url/temporal-server` |
| `server.image.tag` | Image tag | `1.24.2` |
| `server.replicas` | Number of server pods | `3` |
| `ui.enabled` | Enable UI deployment | `true` |
| `database.external.host` | RDS endpoint | `""` |
| `database.external.existingSecret` | K8s secret with credentials | `""` |

See `values.yaml` for all available parameters.

## Accessing Temporal UI

### Via Port Forward (Testing)

```bash
kubectl port-forward -n temporal svc/temporal-ui 8080:8080
```

Then open: http://localhost:8080

### Via Ingress (Production)

Configure ingress in `values-production.yaml`:

```yaml
ui:
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
    - host: temporal-ui.your-company.com
      paths:
      - path: /
        pathType: Prefix
    tls:
    - secretName: temporal-ui-tls
      hosts:
      - temporal-ui.your-company.com
```

## Security & Access Control

Temporal supports two types of access control (both **optional** and **disabled by default**):

### Type 1: UI Access Control

Control who can access the Temporal Web UI:

- **Basic Authentication** - Simple username/password at Ingress level
- **OAuth/OIDC** - Corporate SSO (Okta, Azure AD, Google)
- **LDAP/Active Directory** - Direct LDAP integration

Example (Basic Auth):
```yaml
security:
  ui:
    authentication:
      enabled: true
      basicAuth:
        enabled: true
        existingSecret: "temporal-ui-basic-auth"
```

### Type 2: Server Access Control

Control which workers can connect to Temporal server:

- **Namespace Isolation** - Logical separation (recommended for starting)
- **Mutual TLS (mTLS)** - Certificate-based authentication

Example (Namespace Isolation):
```yaml
security:
  server:
    authentication:
      enabled: false
      namespaceIsolation:
        enabled: true  # Always available, zero overhead
```

**For detailed security setup instructions, see [docs/SECURITY.md](docs/SECURITY.md)**

## Connecting Workers

Your Python workers (or other language SDKs) connect to Temporal server:

### From Inside Kubernetes

```python
client = await Client.connect(
    "temporal-server.temporal.svc.cluster.local:7233",
    namespace="default"  # Specify namespace for isolation
)
```

### From Outside Kubernetes

Use port-forward or LoadBalancer service:

```python
client = await Client.connect(
    "temporal.your-company.com:7233",
    namespace="default"
)
```

## Upgrading

### Upgrade Temporal Version

1. **Update schemas** (if needed - check release notes)
2. **Update image tags** in values-production.yaml
3. **Upgrade helm release:**

```bash
helm upgrade temporal ./temporal-helm \
  -f values-production.yaml \
  --namespace temporal
```

### Rollback

```bash
helm rollback temporal -n temporal
```

## Scaling

### Scale Server Pods

```bash
kubectl scale deployment/temporal-server --replicas=5 -n temporal
```

Or update `values-production.yaml`:

```yaml
server:
  replicas: 5
```

Then:

```bash
helm upgrade temporal ./temporal-helm -f values-production.yaml -n temporal
```

## Monitoring

### Prometheus Metrics

Temporal server exposes metrics on port 9090:

```yaml
# Future: ServiceMonitor for Prometheus Operator
advanced:
  monitoring:
    enabled: true
    prometheus:
      enabled: true
      serviceMonitor:
        enabled: true
```

Access metrics:

```bash
kubectl port-forward -n temporal svc/temporal-server 9090:9090
curl http://localhost:9090/metrics
```

## Troubleshooting

### Pods Won't Start

```bash
# Check pod status
kubectl get pods -n temporal

# View logs
kubectl logs -n temporal <pod-name>

# Describe pod for events
kubectl describe pod -n temporal <pod-name>
```

### Common Issues

**1. ImagePullBackOff**
- Check Nexus credentials secret exists
- Verify image repository URL
- Ensure images exist in Nexus

**2. Database Connection Errors**
- Verify RDS endpoint in values.yaml
- Check database credentials secret
- Ensure RDS security group allows K8s cluster access
- Verify databases (temporal, temporal_visibility) exist

**3. Schema Version Errors**
- Run schema setup (see "Database Schema Setup" section)
- Check schema version matches Temporal version

### Get Support

```bash
# View all resources
kubectl get all -n temporal

# View config maps
kubectl get configmap -n temporal
kubectl describe configmap temporal-server-config -n temporal

# View secrets
kubectl get secrets -n temporal
```

## Uninstalling

```bash
helm uninstall temporal -n temporal
```

**Note:** This does NOT delete:
- Database data in RDS
- Kubernetes secrets
- PersistentVolumeClaims (if any)

## Features

### Implemented
- ✅ Custom Docker images from Nexus
- ✅ External PostgreSQL (AWS RDS)
- ✅ Temporal Server deployment
- ✅ Temporal UI deployment
- ✅ Ingress support for UI
- ✅ **Security & Access Control:**
  - ✅ UI Authentication (Basic Auth, OAuth/OIDC, LDAP)
  - ✅ Server Authentication (Namespace Isolation, mTLS)
- ✅ Configurable resources and replicas
- ✅ Health checks (liveness/readiness probes)
- ✅ High availability configurations

### Future Enhancements

Planned features (not yet implemented):
- [ ] Schema setup init job
- [ ] Prometheus ServiceMonitor integration
- [ ] Grafana dashboard templates
- [ ] Worker deployment template
- [ ] Multi-region support
- [ ] Auto-scaling (HPA) configurations

## Architecture

```
┌─────────────────────┐
│   Ingress/ALB       │
│  (temporal-ui.com)  │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│   Temporal UI       │
│   (Deployment)      │
│   Replicas: 2       │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│  Temporal Server    │
│   (Deployment)      │
│   Replicas: 3       │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│   AWS RDS           │
│   PostgreSQL 15     │
│   (External)        │
└─────────────────────┘
```

## Contributing

This is an internal HELM chart. For modifications:
1. Update templates
2. Test with `helm lint`
3. Test deployment to dev cluster
4. Update documentation

## Resources

- [Temporal Documentation](https://docs.temporal.io/)
- [Temporal Server Configuration](https://docs.temporal.io/references/configuration)
- [HELM Documentation](https://helm.sh/docs/)
