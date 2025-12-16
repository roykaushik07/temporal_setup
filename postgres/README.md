# PostgreSQL for Temporal - Local Development

This directory contains a Docker Compose setup for PostgreSQL, configured specifically for Temporal workflow engine.

## Overview

- **PostgreSQL Version**: 15 (Alpine-based)
- **Databases**:
  - `temporal` - Main Temporal database
  - `temporal_visibility` - Workflow visibility and search
- **Network**: `temporal-network` (shared with Temporal services)
- **Persistence**: Volume-backed for data persistence

## Why Separate from Temporal?

This PostgreSQL setup is intentionally separate from Temporal services because:
1. **Local Development**: Easy to start/stop database independently
2. **Production Migration**: Simple to swap with AWS RDS by just changing connection strings
3. **Data Persistence**: Database survives Temporal container restarts
4. **Clean Architecture**: Mirrors production setup where DB is external

## Directory Structure

```
postgres/
├── docker-compose.yml           # PostgreSQL container definition
├── .env.example                 # Configuration template
├── init-scripts/
│   └── 01-create-databases.sh  # Auto-creates visibility database
└── README.md                    # This file
```

## Quick Start

### 1. Create Environment File

```bash
cp .env.example .env
```

**Default values** (good for local development):
- Username: `temporal`
- Password: `temporal`
- Port: `5432`

### 2. Start PostgreSQL

```bash
docker-compose up -d
```

### 3. Verify It's Running

```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs -f

# Test connection
docker exec -it temporal-postgres psql -U temporal -c "\l"
```

**Expected output**: You should see both `temporal` and `temporal_visibility` databases listed.

## What Happens on First Start

1. PostgreSQL container starts
2. Creates `temporal` database (from POSTGRES_DB env var)
3. Runs init script: `01-create-databases.sh`
4. Creates `temporal_visibility` database
5. Ready for Temporal to connect!

## Connecting to PostgreSQL

### From Host Machine

```bash
psql -h localhost -p 5432 -U temporal -d temporal
# Password: temporal
```

### From Docker Containers (Same Network)

```bash
# Connection string
postgresql://temporal:temporal@postgres:5432/temporal
postgresql://temporal:temporal@postgres:5432/temporal_visibility
```

### From Temporal (Phase 3)

Temporal will use these environment variables:
```
DB_HOST=postgres
DB_PORT=5432
DB_USER=temporal
DB_PASSWORD=temporal
```

## Data Persistence

PostgreSQL data is stored in a Docker volume: `postgres_data`

```bash
# View volume
docker volume ls | grep postgres

# Inspect volume
docker volume inspect postgres_postgres_data
```

**Important**: Data persists even if you stop/remove the container!

## Common Operations

### Stop PostgreSQL

```bash
docker-compose down
```

Data remains in the volume.

### Stop and Remove Data

```bash
docker-compose down -v
```

**Warning**: This deletes all data!

### View Logs

```bash
docker-compose logs -f postgres
```

### Restart PostgreSQL

```bash
docker-compose restart
```

### Connect via psql

```bash
# Interactive shell
docker exec -it temporal-postgres psql -U temporal

# List databases
docker exec -it temporal-postgres psql -U temporal -c "\l"

# Connect to specific database
docker exec -it temporal-postgres psql -U temporal -d temporal_visibility
```

## Network Configuration

PostgreSQL is on the `temporal-network` bridge network, which allows:
- Temporal services to connect via hostname `postgres`
- Isolation from other Docker containers
- Easy service discovery

```bash
# Inspect network
docker network inspect temporal-network
```

## Customization

### Change Credentials

Edit `.env` file:
```env
POSTGRES_USER=myuser
POSTGRES_PASSWORD=mypassword
```

Then restart:
```bash
docker-compose down -v  # Remove old data
docker-compose up -d    # Start with new credentials
```

### Change Port

Edit `.env` file:
```env
POSTGRES_PORT=5433
```

This changes the **host** port (container always uses 5432 internally).

### Add More Databases

Create additional init scripts in `init-scripts/`:
```bash
# Example: 02-create-custom-db.sh
CREATE DATABASE myapp;
```

Scripts run in alphabetical order.

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs postgres

# Common issues:
# - Port 5432 already in use (change POSTGRES_PORT in .env)
# - Permission issues (check Docker Desktop settings)
```

### Can't Connect from Host

```bash
# Verify container is running
docker-compose ps

# Check port mapping
docker port temporal-postgres

# Test connection
telnet localhost 5432
```

### Init Script Didn't Run

Init scripts only run on **first container creation**.

To re-run:
```bash
docker-compose down -v  # Remove volume
docker-compose up -d    # Recreate
```

### Database Missing

```bash
# List all databases
docker exec -it temporal-postgres psql -U temporal -c "\l"

# If temporal_visibility is missing, check init script logs
docker-compose logs postgres | grep visibility
```

## Health Check

The container includes a health check that runs every 10 seconds:

```bash
# View health status
docker inspect temporal-postgres | grep -A 10 Health
```

Healthy container shows: `"Status": "healthy"`

## For Production (AWS RDS)

When migrating to production:

1. **Create RDS PostgreSQL instance** in AWS
2. **Create databases**:
   ```sql
   CREATE DATABASE temporal;
   CREATE DATABASE temporal_visibility;
   ```
3. **Update Temporal configuration** to point to RDS endpoint
4. **Stop local PostgreSQL**: `docker-compose down`

No changes needed to Temporal - just update connection strings!

## Security Notes

**For Local Development:**
- Default credentials are fine
- Database exposed on localhost only

**For Production:**
- Use strong passwords
- Store credentials in Kubernetes Secrets
- Enable SSL/TLS for connections
- Use AWS RDS parameter groups for hardening
- Restrict network access via security groups

## Next Steps

Once PostgreSQL is running and verified:
1. **Phase 3**: Set up Temporal docker-compose to connect to this database
2. **Phase 4**: Create HELM chart that connects to AWS RDS instead

## Useful Commands Reference

```bash
# Start
docker-compose up -d

# Stop (keep data)
docker-compose down

# Stop (remove data)
docker-compose down -v

# Logs
docker-compose logs -f

# Status
docker-compose ps

# Execute SQL
docker exec -it temporal-postgres psql -U temporal -c "SELECT version();"

# Backup database
docker exec temporal-postgres pg_dump -U temporal temporal > backup.sql

# Restore database
docker exec -i temporal-postgres psql -U temporal temporal < backup.sql
```

## Resources

- [PostgreSQL Docker Official](https://hub.docker.com/_/postgres)
- [Temporal Database Setup](https://docs.temporal.io/self-hosted-guide/setup#database)
- [Docker Compose Reference](https://docs.docker.com/compose/)
