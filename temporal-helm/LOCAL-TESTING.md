# Local Testing Guide - HELM Chart with k3d

This guide walks you through testing the HELM chart locally using k3d (Kubernetes in Docker).

## Prerequisites

- ✅ Docker Desktop running
- ✅ PostgreSQL running (from Phase 2)
- ✅ Docker images built (from Phase 1)
- ✅ Helm 3 installed
- ⚠️ k3d (we'll install this)

## Step 1: Install k3d

```bash
# Install k3d via Homebrew
brew install k3d

# Verify installation
k3d version
```

## Step 2: Create Local Kubernetes Cluster

```bash
# Create a k3d cluster named "temporal-test"
k3d cluster create temporal-test \
  --api-port 6550 \
  --servers 1 \
  --agents 0 \
  --port "8081:30080@server:0"

# This creates:
# - 1 server node (control plane)
# - 0 agent nodes (workers) - we don't need them for testing
# - Port mapping 8081->30080 for accessing services
```

**Verify cluster is running:**

```bash
kubectl cluster-info
kubectl get nodes
```

You should see one node running.

## Step 3: Load Docker Images into k3d

k3d needs access to your local Docker images:

```bash
# Load Temporal server image
k3d image import temporal-server:1.24.2 -c temporal-test

# Load Temporal UI image
k3d image import temporal-ui:2.30.0 -c temporal-test

# Verify images are available
docker exec k3d-temporal-test-server-0 crictl images | grep temporal
```

You should see both images listed.

## Step 4: Ensure PostgreSQL is Accessible

Your PostgreSQL from Phase 2 needs to be accessible from k3d.

**Check PostgreSQL is running:**

```bash
cd /Users/kaushikroy/workspace/temporal/postgres
docker-compose ps
```

Should show `temporal-postgres` as healthy.

**Make sure it's on the right network:**

```bash
# Check PostgreSQL container network
docker inspect temporal-postgres | grep NetworkMode

# It should be on bridge or temporal-network
# k3d can reach it via host.k3d.internal
```

## Step 5: Test HELM Chart

### Lint the Chart

```bash
cd /Users/kaushikroy/workspace/temporal/temporal-helm

helm lint . -f values-local.yaml
```

Should show: `1 chart(s) linted, 0 chart(s) failed`

### Dry-Run Install

```bash
helm install temporal . \
  -f values-local.yaml \
  --dry-run \
  --debug \
  --namespace temporal \
  --create-namespace
```

Review the output - these are the Kubernetes resources that would be created.

### Actually Install

```bash
helm install temporal . \
  -f values-local.yaml \
  --namespace temporal \
  --create-namespace
```

**Expected output:**
```
NAME: temporal
LAST DEPLOYED: ...
NAMESPACE: temporal
STATUS: deployed
```

## Step 6: Verify Deployment

### Check Pods

```bash
kubectl get pods -n temporal

# Wait for pods to be Running
kubectl get pods -n temporal --watch
```

**Expected:**
- `temporal-server-xxxxx` - Running
- `temporal-ui-xxxxx` - Running

**If pods are not starting, check logs:**

```bash
# Server logs
kubectl logs -n temporal deployment/temporal-server

# UI logs
kubectl logs -n temporal deployment/temporal-ui
```

### Check Services

```bash
kubectl get svc -n temporal
```

Should show:
- `temporal-server` (ClusterIP)
- `temporal-ui` (NodePort)

### Check ConfigMaps

```bash
kubectl get configmap -n temporal

# View server config
kubectl get configmap temporal-server-config -n temporal -o yaml
```

## Step 7: Access Temporal UI

Since we used NodePort, get the mapped port:

```bash
kubectl get svc temporal-ui -n temporal
```

Look for the NodePort (30000-32767 range).

**Access UI:**

```bash
# Option 1: Port-forward (easier)
kubectl port-forward -n temporal svc/temporal-ui 8081:8080
```

Then open: **http://localhost:8081**

**Option 2: Via NodePort**

```bash
# Get the NodePort
NODE_PORT=$(kubectl get svc temporal-ui -n temporal -o jsonpath='{.spec.ports[0].nodePort}')
echo "UI available at: http://localhost:$NODE_PORT"
```

## Step 8: Test with Python Client

Your Python worker can connect to Temporal in k3d:

### Port-Forward Temporal Server

```bash
kubectl port-forward -n temporal svc/temporal-server 7233:7233
```

### Run Worker (New Terminal)

```bash
cd /Users/kaushikroy/workspace/temporal/python-client
source venv/bin/activate
python worker.py
```

### Start Workflow (Another Terminal)

```bash
cd /Users/kaushikroy/workspace/temporal/python-client
source venv/bin/activate
python start_workflow.py
```

You should see the workflow execute and appear in the k3d-hosted Temporal UI!

## Troubleshooting

### Pods in CrashLoopBackOff

**Check pod logs:**
```bash
kubectl logs -n temporal <pod-name>
```

**Common issues:**
- Can't connect to PostgreSQL: Check `host.k3d.internal` resolves
- Image not found: Re-import images with `k3d image import`
- Database schema missing: Check Phase 3 schema setup was done

### Can't Access UI

```bash
# Check UI pod is running
kubectl get pods -n temporal

# Check UI service
kubectl get svc temporal-ui -n temporal

# View UI logs
kubectl logs -n temporal deployment/temporal-ui
```

### Database Connection Issues

**Test from inside k3d:**

```bash
# Get server pod name
POD=$(kubectl get pods -n temporal -l app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}')

# Check if host.k3d.internal resolves
kubectl exec -n temporal $POD -- ping -c 1 host.k3d.internal

# Should show successful ping to your host machine
```

**If it doesn't work:**

```bash
# Check what IP host.k3d.internal resolves to
kubectl exec -n temporal $POD -- nslookup host.k3d.internal
```

## Cleanup

### Delete HELM Release

```bash
helm uninstall temporal -n temporal
```

### Delete Namespace

```bash
kubectl delete namespace temporal
```

### Delete k3d Cluster

```bash
k3d cluster delete temporal-test
```

### Keep PostgreSQL Running

Your PostgreSQL from Phase 2 can stay running for other tests.

## What This Tests

✅ **HELM chart structure** - Templates render correctly
✅ **Kubernetes resources** - Deployments, Services work
✅ **Docker images** - Built correctly, run in k8s
✅ **Configuration** - ConfigMaps, environment variables
✅ **Networking** - Pods can reach PostgreSQL
✅ **UI accessibility** - Can access web interface
✅ **Workflow execution** - Python client can connect

## Next Steps

Once local testing passes:
1. ✅ You know the HELM chart works
2. ✅ Ready to deploy to corporate EKS
3. ✅ Just need to:
   - Change values-production.yaml
   - Point to AWS RDS
   - Point to Nexus images
   - Deploy!

## Differences: Local vs Production

| Aspect | Local (k3d) | Production (EKS) |
|--------|-------------|------------------|
| **Images** | Local Docker | Nexus registry |
| **Database** | Docker PostgreSQL | AWS RDS |
| **Replicas** | 1 each | 3+ each |
| **Access** | Port-forward | Ingress/ALB |
| **Resources** | Minimal | Production-sized |
| **Secrets** | Plain password | K8s Secrets |

The HELM chart handles both with different values files!
