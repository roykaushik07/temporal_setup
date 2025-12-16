# Temporal Setup - Local to EKS Migration

This repository contains everything needed to run Temporal workflow engine locally on macOS and deploy it to corporate EKS environment using custom-built Docker images.

## Project Overview

**Goal**: Set up Temporal locally for development, then migrate to production EKS with images hosted in corporate Nexus registry.

**Key Features**:
- Custom Docker images built from binaries (no Docker Hub dependency)
- Separate PostgreSQL for local dev, AWS RDS for production
- Production-ready HELM chart
- Python client examples
- Comprehensive documentation
- Tested with k3d locally

## Current Status: ✅ ALL PHASES COMPLETE

All 5 phases have been implemented and tested:
- ✅ **Phase 1**: Docker images built from binaries
- ✅ **Phase 2**: PostgreSQL running in Docker
- ✅ **Phase 3**: Docker Compose for local development
- ✅ **Phase 4**: HELM chart deployed to k3d
- ✅ **Phase 5**: Python client working with examples

**Ready for**: Corporate Nexus push → EKS deployment

---

## Quick Start

### Local Development (Docker Compose)

```bash
# 1. Start PostgreSQL
cd postgres
docker-compose up -d

# 2. Build images (one-time)
cd ../temporal-server
./download-binaries.sh
docker build -t temporal-server:1.24.2 -f Dockerfile .
docker build -t temporal-ui:2.30.0 -f Dockerfile.ui .

# 3. Setup database schemas (one-time)
cd ../temporal-compose
./setup-schema.sh

# 4. Start Temporal
docker-compose up -d

# 5. Access UI
open http://localhost:8080
```

### Kubernetes Testing (k3d)

```bash
# 1. Create k3d cluster
k3d cluster create temporal-test --api-port 6550 --servers 1 --agents 0

# 2. Load images
k3d image import temporal-server:1.24.2 -c temporal-test
k3d image import temporal-ui:2.30.0 -c temporal-test

# 3. Deploy HELM chart
cd temporal-helm
helm install temporal . -f values-local.yaml --namespace temporal --create-namespace

# 4. Access UI
kubectl port-forward -n temporal svc/temporal-ui 8081:8080
open http://localhost:8081
```

### Production Deployment (EKS)

```bash
# 1. Push images to Nexus
docker tag temporal-server:1.24.2 <nexus-url>/temporal-server:1.24.2
docker tag temporal-ui:2.30.0 <nexus-url>/temporal-ui:2.30.0
docker push <nexus-url>/temporal-server:1.24.2
docker push <nexus-url>/temporal-ui:2.30.0

# 2. Update values-production.yaml with your settings
# (Nexus URLs, RDS endpoint, ingress domain)

# 3. Deploy to EKS
helm install temporal ./temporal-helm \
  -f values-production.yaml \
  --namespace temporal \
  --create-namespace
```

---

## Project Structure

```
temporal/
├── README.md                          # This file
├── REVIEW.md                          # Comprehensive project review
├── .gitignore
│
├── postgres/                          # Phase 2 ✅
│   ├── docker-compose.yml
│   ├── init-scripts/
│   │   └── 01-create-databases.sh
│   └── README.md
│
├── temporal-server/                   # Phase 1 ✅
│   ├── Dockerfile                     # Temporal server image
│   ├── Dockerfile.ui                  # Temporal UI image
│   ├── download-binaries.sh           # Binary download script
│   ├── binaries/                      # Downloaded binaries (gitignored)
│   ├── config/
│   │   ├── development.yaml           # Server configuration
│   │   └── dynamicconfig/
│   ├── ui-config/
│   │   └── development.yaml           # UI configuration
│   └── README.md
│
├── temporal-compose/                  # Phase 3 ✅
│   ├── docker-compose.yml             # Local dev environment
│   ├── setup-schema.sh                # Database schema setup
│   └── README.md
│
├── temporal-helm/                     # Phase 4 ✅
│   ├── Chart.yaml
│   ├── values.yaml                    # Default values
│   ├── values-local.yaml              # k3d testing values
│   ├── values-production.yaml         # EKS deployment values
│   ├── templates/
│   │   ├── _helpers.tpl
│   │   ├── serviceaccount.yaml
│   │   ├── configmap.yaml
│   │   ├── ui-configmap.yaml
│   │   ├── server-deployment.yaml
│   │   ├── ui-deployment.yaml
│   │   ├── server-service.yaml
│   │   ├── ui-service.yaml
│   │   ├── ui-ingress.yaml
│   │   ├── secret.yaml
│   │   └── NOTES.txt
│   ├── README.md
│   └── LOCAL-TESTING.md
│
└── python-client/                     # Phase 5 ✅
    ├── requirements.txt
    ├── workflows/
    │   └── order_workflow.py
    ├── activities/
    │   └── order_activities.py
    ├── worker.py
    ├── start_workflow.py
    └── README.md
```

---

## Architecture

### Local Development
```
┌─────────────────┐
│  Temporal UI    │ :8080
│  (Docker)       │
└────────┬────────┘
         │
┌────────▼────────┐
│ Temporal Server │ :7233
│  (Docker)       │  All services in one container:
│                 │  - Frontend
│                 │  - History
│                 │  - Matching
│                 │  - Worker
└────────┬────────┘
         │
┌────────▼────────┐
│   PostgreSQL    │ :5432
│  (Docker)       │  - temporal
└─────────────────┘  - temporal_visibility
```

### Production (EKS)
```
┌──────────────────────┐
│   Ingress / ALB      │
│ temporal-ui.corp.com │
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│  Temporal UI         │
│  (K8s Deployment)    │
│  Replicas: 2         │
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│  Temporal Server     │
│  (K8s Deployment)    │  All services in one pod:
│  Replicas: 3         │  - Frontend
│                      │  - History
└──────────┬───────────┘  - Matching
           │              - Worker
┌──────────▼───────────┐
│   AWS RDS            │
│   PostgreSQL 15      │
│   Multi-AZ           │
└──────────────────────┘
```

---

## Key Design Decisions

1. **Alpine-based images** - Minimal (25MB), secure, corporate-approved
2. **Binary downloads** - No Docker Hub dependency (corporate requirement)
3. **Monolithic Temporal server** - All services in one pod (simpler than official microservices chart)
4. **Separate PostgreSQL** - Easy to swap local Docker ↔ AWS RDS
5. **No Elasticsearch** - Keep it simple, use PostgreSQL for visibility
6. **Init container pattern** - Secure password injection via envsubst
7. **ConfigMap checksums** - Auto-restart pods on config changes

---

## Technology Stack

- **Temporal**: v1.24.2 (workflow engine)
- **Temporal UI**: v2.30.0 (web interface)
- **Database**: PostgreSQL 15 (local Docker) / RDS (production)
- **Base Image**: Alpine Linux 3.19
- **Container Runtime**: Docker Desktop for Mac
- **Local K8s**: k3d v5.8.3
- **Orchestration**: Kubernetes (EKS)
- **Package Manager**: HELM 4.0.4
- **Client SDK**: Python temporalio v1.7.1

---

## Prerequisites

### Local Development
- macOS (tested on macOS Sequoia)
- Docker Desktop for Mac
- ~500MB disk space
- Internet connection (for binary download)

### Kubernetes Testing
- k3d installed (`brew install k3d`)
- kubectl installed
- Helm 3+ installed (`brew install helm`)

### Corporate Deployment
- Access to corporate Nexus registry
- AWS RDS PostgreSQL instance (12+)
- EKS cluster access
- kubectl configured for EKS
- Helm 3+ installed

---

## What This Provides

### ✅ Working Components

1. **Docker Images**
   - Built from official Temporal binaries
   - No reliance on Docker Hub
   - Ready for Nexus push

2. **Local Development**
   - PostgreSQL in Docker
   - Temporal server + UI via docker-compose
   - Fast startup (~30 seconds)
   - Persistent data

3. **Kubernetes Deployment**
   - Production-ready HELM chart
   - Tested on k3d
   - External database support
   - Secrets management
   - Auto-scaling ready

4. **Python Client**
   - Working workflow examples
   - Activity implementations
   - Retry policies
   - Error handling

### 📚 Documentation

- Phase-specific README files
- Local testing guide
- Production deployment guide
- Troubleshooting sections
- Comprehensive review document

---

## Usage Examples

### Create a Namespace

```bash
# Using Temporal CLI
temporal operator namespace create my-namespace

# Or via Python SDK
from temporalio.client import Client

async def main():
    client = await Client.connect("localhost:7233")
    await client.operator_service.create_namespace("my-namespace")
```

### Run Python Worker

```bash
cd python-client
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Start worker
python worker.py
```

### Start a Workflow

```bash
# In another terminal
python start_workflow.py
```

### Access UI

- **Docker Compose**: http://localhost:8080
- **k3d**: `kubectl port-forward -n temporal svc/temporal-ui 8081:8080` → http://localhost:8081
- **Production**: https://temporal-ui.your-company.com

---

## Testing Status

### ✅ Tested and Working

- Docker image builds
- PostgreSQL container startup and health checks
- Database schema setup script
- Docker Compose deployment
- HELM chart linting (`helm lint`)
- k3d cluster deployment
- Pod health and readiness checks
- UI accessibility (port-forward and NodePort)
- Database connectivity from k3d (via host.k3d.internal)
- Python worker connection (Docker Compose)
- Workflow execution and visibility in UI

### 📋 Ready to Test

- Python worker connection to k3d Temporal
- Production EKS deployment
- Ingress configuration
- AWS RDS connectivity
- Multi-replica scaling

---

## Deployment Comparison

| Aspect | Local (Docker Compose) | k3d | Production (EKS) |
|--------|----------------------|-----|------------------|
| **Database** | Docker PostgreSQL | Docker PostgreSQL (host) | AWS RDS |
| **Images** | Local Docker | Local Docker | Nexus Registry |
| **Access** | localhost:8080 | Port-forward | Ingress/ALB |
| **Replicas** | 1 each | 1 each | 3+ server, 2+ UI |
| **Secrets** | Plain password | K8s Secret | K8s Secret |
| **Monitoring** | None | None | Prometheus (future) |
| **Auth** | None | None | LDAP (future) |

---

## Next Steps

### For Local Development
- ✅ Everything ready to use!
- Run docker-compose for quick testing
- Iterate on workflows and activities

### For Kubernetes Testing
- ✅ k3d cluster tested and working
- Test Python client with k3d
- Verify end-to-end workflows

### For Production Deployment
1. Update `values-production.yaml` with:
   - Your Nexus registry URLs
   - AWS RDS endpoint
   - Ingress domain name
2. Push images to Nexus
3. Setup AWS RDS (PostgreSQL 15+)
4. Run schema setup against RDS
5. Deploy HELM chart to EKS
6. Configure Ingress/ALB
7. Test with production workload

### Future Enhancements
- [ ] LDAP/AD authentication for UI
- [ ] Prometheus metrics + Grafana dashboards
- [ ] Schema setup as Kubernetes init job
- [ ] HorizontalPodAutoscaler for auto-scaling
- [ ] Separate service deployments (microservices)
- [ ] TLS/mTLS for inter-service communication

---

## Troubleshooting

### Docker Compose Issues

**Pods not starting:**
```bash
docker-compose logs temporal
docker-compose logs temporal-ui
```

**Database connection failed:**
```bash
# Check PostgreSQL is running
cd postgres && docker-compose ps

# Check schemas exist
docker exec -it temporal-postgres psql -U temporal -c "\l"
```

### k3d Issues

**Pods in CrashLoopBackOff:**
```bash
kubectl logs -n temporal <pod-name>
kubectl describe pod -n temporal <pod-name>
```

**Can't access UI:**
```bash
# Check service
kubectl get svc -n temporal

# Port-forward
kubectl port-forward -n temporal svc/temporal-ui 8081:8080
```

**Database authentication failed:**
- Check secret: `kubectl get secret temporal-db-credentials -n temporal -o yaml`
- Verify PostgreSQL is accessible from k3d: `kubectl exec -n temporal <pod> -- ping host.k3d.internal`

### Common Issues

**Issue**: `docker-compose restart` doesn't pick up config changes

**Solution**: Use `docker-compose down && docker-compose up -d`

---

**Issue**: Port already in use (7233, 8080)

**Solution**:
```bash
# Find process using port
lsof -i :8080
# Kill or use different port
```

---

**Issue**: Images not found in k3d

**Solution**: Re-import images
```bash
k3d image import temporal-server:1.24.2 -c temporal-test
k3d image import temporal-ui:2.30.0 -c temporal-test
```

---

## Support & Resources

- **Project Review**: See `REVIEW.md` for comprehensive analysis
- **Temporal Docs**: https://docs.temporal.io/
- **Temporal GitHub**: https://github.com/temporalio/temporal
- **HELM Chart Docs**: See `temporal-helm/README.md`
- **Local Testing**: See `temporal-helm/LOCAL-TESTING.md`

---

## License

This setup is for internal corporate use. Temporal itself is licensed under MIT.

---

**Status**: ✅ Production-ready (after pushing to Nexus and deploying to EKS)
