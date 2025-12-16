# Temporal Server & UI - Docker Compose

This directory contains Docker Compose configuration to run Temporal Server and UI locally, connecting to the PostgreSQL database from Phase 2.

## Overview

- **Temporal Server**: Custom-built image (from Phase 1)
- **Temporal UI**: Custom-built image (from Phase 1)
- **Database**: Connects to PostgreSQL container (from Phase 2)
- **Auto-Setup**: Database schemas created automatically on first start

## Architecture

```
┌─────────────────────┐
│   Temporal UI       │
│   localhost:8080    │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│  Temporal Server    │
│   localhost:7233    │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│    PostgreSQL       │
│  (from postgres/)   │
└─────────────────────┘
```

## Prerequisites

Before starting Temporal, ensure:

1. ✅ **Phase 1 Complete**: Docker images built
   - `temporal-server:1.24.2`
   - `temporal-ui:2.30.0`

2. ✅ **Phase 2 Complete**: PostgreSQL running
   ```bash
   cd ../postgres
   docker-compose up -d
   ```

3. ✅ **Network exists**: `temporal-network`
   ```bash
   docker network inspect temporal-network
   ```

## Quick Start

### 1. Configure Environment (Optional)

Default values work for local development:

```bash
# Optional: customize if needed
cp .env.example .env
```

### 2. Start Temporal

```bash
docker-compose up -d
```

This will:
- Start Temporal Server (waits for PostgreSQL to be healthy)
- Auto-create database schemas in PostgreSQL
- Start Temporal UI
- Both services connect to PostgreSQL

### 3. Wait for Startup (Important!)

First-time startup takes **1-2 minutes** because:
- Database schemas are being created
- Temporal server initializes

```bash
# Watch the logs
docker-compose logs -f temporal

# Look for: "Started Temporal server"
```

### 4. Verify It's Working

```bash
# Check container status
docker-compose ps

# Both should be "Up" and healthy
```

### 5. Access Temporal UI

Open in browser: **http://localhost:8080**

You should see the Temporal Web UI with:
- Workflows page (empty initially)
- Default namespace created

## What Runs Where

### Temporal Server
- **Container**: `temporal-server`
- **Frontend gRPC**: `localhost:7233` (for client connections)
- **Metrics**: `localhost:9090` (Prometheus format)

### Temporal UI
- **Container**: `temporal-ui`
- **Web Interface**: `localhost:8080`
- **Connects to**: `temporal:7233`

### Database Connection
- **Host**: `postgres` (container name)
- **Port**: `5432`
- **Databases**: `temporal`, `temporal_visibility`

## First-Time Setup

On first start, Temporal automatically:
1. Connects to PostgreSQL
2. Creates required tables in `temporal` database
3. Creates required tables in `temporal_visibility` database
4. Initializes default namespace
5. Starts accepting connections

**This is controlled by**: `AUTO_SETUP=true` in docker-compose.yml

## Testing the Setup

### Test 1: Check UI Access

```bash
open http://localhost:8080
```

Should load Temporal Web UI.

### Test 2: Check Server Health

```bash
# From host machine (requires temporal CLI installed)
temporal operator cluster health --address localhost:7233

# OR just check if port is open
nc -zv localhost 7233
```

### Test 3: Verify Database Schemas

```bash
# Connect to PostgreSQL
docker exec -it temporal-postgres psql -U temporal -d temporal

# List tables (should see many temporal_* tables)
\dt

# Exit
\q
```

## Common Commands

### Start Services

```bash
docker-compose up -d
```

### Stop Services

```bash
docker-compose down
```

**Note**: PostgreSQL keeps running (it's in separate compose file).

### View Logs

```bash
# All services
docker-compose logs -f

# Just Temporal server
docker-compose logs -f temporal

# Just UI
docker-compose logs -f temporal-ui
```

### Restart Services

```bash
docker-compose restart
```

### Check Status

```bash
docker-compose ps
```

## Environment Variables

Edit `.env` file to customize:

### Database Connection
```env
DB_HOST=postgres          # PostgreSQL container name
DB_PORT=5432             # PostgreSQL port
DB_USER=temporal         # Database user
DB_PASSWORD=temporal     # Database password
```

### Temporal Ports
```env
TEMPORAL_FRONTEND_PORT=7233    # Client gRPC endpoint
TEMPORAL_METRICS_PORT=9090     # Prometheus metrics
TEMPORAL_UI_PORT=8080          # Web UI
```

### CORS (for web clients)
```env
TEMPORAL_CORS_ORIGINS=http://localhost:3000
```

## Network Configuration

Both Temporal and PostgreSQL use the **same network**: `temporal-network`

This allows:
- Temporal to connect to PostgreSQL via hostname `postgres`
- Service discovery without hardcoded IPs
- Isolation from other Docker containers

## Troubleshooting

### Temporal Server Won't Start

**Check PostgreSQL is running**:
```bash
cd ../postgres
docker-compose ps
```

**Check network exists**:
```bash
docker network ls | grep temporal
```

**View logs**:
```bash
docker-compose logs temporal
```

### Can't Access UI (localhost:8080)

**Check UI container is running**:
```bash
docker-compose ps
```

**Check port is not in use**:
```bash
lsof -i :8080
```

**View UI logs**:
```bash
docker-compose logs temporal-ui
```

### Database Connection Errors

**Error: "could not connect to server"**
- Ensure PostgreSQL is running: `cd ../postgres && docker-compose ps`
- Check DB credentials in `.env` match postgres/.env

**Error: "database does not exist"**
- Restart with fresh setup: `docker-compose down && docker-compose up -d`
- Check init script ran: `docker-compose logs postgres | grep visibility`

### Schema Creation Failed

If schemas don't auto-create:

```bash
# Restart with fresh database (CAUTION: deletes data)
docker-compose down
cd ../postgres
docker-compose down -v
docker-compose up -d
cd ../temporal-compose
docker-compose up -d
```

### Port Already in Use

**Port 7233 in use**:
```bash
# Find what's using it
lsof -i :7233

# Change port in .env
TEMPORAL_FRONTEND_PORT=7234
```

**Port 8080 in use**:
```bash
# Change UI port in .env
TEMPORAL_UI_PORT=8081
```

## Configuration Files

### development.yaml

Located at: `../temporal-server/config/development.yaml`

This file is mounted into the container and configures:
- Database connection (uses environment variables)
- Server ports
- Persistence settings
- Logging level

**Note**: Already configured in Phase 1, no changes needed.

## Working with Temporal

### Create a Namespace

Temporal has a "default" namespace created automatically.

To create additional namespaces, you'll need the Temporal CLI (optional):

```bash
# Install Temporal CLI on your Mac (optional)
brew install temporal

# Create namespace
temporal operator namespace create my-namespace --address localhost:7233
```

### Connect Your Application

Your Python workers/clients (Phase 5) will connect using:

```python
from temporalio.client import Client

client = await Client.connect("localhost:7233")
```

## Data Persistence

- **Temporal Configuration**: Ephemeral (recreated from image)
- **Workflow Data**: Persists in PostgreSQL
- **PostgreSQL Data**: Persists in Docker volume (see postgres/README.md)

**Stopping Temporal** (docker-compose down):
- ✅ Workflow history preserved in PostgreSQL
- ✅ Can restart and continue workflows

**Stopping PostgreSQL** (postgres/docker-compose down):
- ✅ Data still in volume
- ✅ Survives restarts

**Removing PostgreSQL volume** (down -v):
- ❌ All workflows lost
- ❌ Must recreate schemas

## For Production (EKS Migration)

This local setup mirrors production architecture:

**Local**:
- Temporal in Docker Compose
- PostgreSQL in Docker
- Connection: `postgres:5432`

**Production (EKS)**:
- Temporal in Kubernetes (via HELM - Phase 4)
- AWS RDS PostgreSQL
- Connection: `<rds-endpoint>:5432`

**Migration**: Just change DB_HOST to RDS endpoint!

## Monitoring

### Prometheus Metrics

Temporal exposes metrics at: `http://localhost:9090/metrics`

```bash
# View metrics
curl http://localhost:9090/metrics
```

### Logs

```bash
# View in real-time
docker-compose logs -f temporal

# Save to file
docker-compose logs temporal > temporal.log
```

## Complete Workflow

### Starting Everything (from scratch)

```bash
# 1. Start PostgreSQL
cd /Users/kaushikroy/workspace/temporal/postgres
docker-compose up -d

# 2. Wait for PostgreSQL to be ready (10-20 seconds)
docker-compose logs -f
# Look for: "database system is ready to accept connections"

# 3. Start Temporal
cd /Users/kaushikroy/workspace/temporal/temporal-compose
docker-compose up -d

# 4. Wait for Temporal to initialize (1-2 minutes)
docker-compose logs -f temporal
# Look for: "Started Temporal server"

# 5. Access UI
open http://localhost:8080
```

### Stopping Everything

```bash
# Stop Temporal
cd /Users/kaushikroy/workspace/temporal/temporal-compose
docker-compose down

# Stop PostgreSQL
cd /Users/kaushikroy/workspace/temporal/postgres
docker-compose down
```

**Data is preserved** in PostgreSQL volume.

### Clean Restart (fresh database)

```bash
# Stop everything and remove data
cd /Users/kaushikroy/workspace/temporal/temporal-compose
docker-compose down

cd /Users/kaushikroy/workspace/temporal/postgres
docker-compose down -v  # -v removes volumes

# Start fresh
docker-compose up -d
cd /Users/kaushikroy/workspace/temporal/temporal-compose
docker-compose up -d
```

## Next Steps

Once Temporal is running successfully:
1. ✅ Access UI at http://localhost:8080
2. ✅ Verify server at localhost:7233
3. ➡️ **Phase 4**: Create HELM chart for Kubernetes/EKS
4. ➡️ **Phase 5**: Build Python client to test workflows

## Resources

- [Temporal Server Configuration](https://docs.temporal.io/references/configuration)
- [Temporal Architecture](https://docs.temporal.io/clusters)
- [Web UI Guide](https://docs.temporal.io/web-ui)
