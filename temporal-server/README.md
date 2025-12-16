# Temporal Server - Docker Images

This directory contains the necessary files to build custom Docker images for Temporal Server and UI using downloaded binaries instead of relying on public Docker registries.

## Overview

- **Temporal Version**: 1.24.2
- **UI Version**: 2.30.0
- **Base Image**: Alpine Linux 3.19

## Prerequisites

- Docker Desktop installed and running
- ~500MB disk space for binaries
- Internet connection to download binaries from GitHub

## Directory Structure

```
temporal-server/
├── Dockerfile              # Temporal server image
├── Dockerfile.ui           # Temporal UI image
├── download-binaries.sh    # Script to download binaries
├── binaries/               # Downloaded binaries (gitignored)
│   ├── temporal-server
│   └── ui-server
├── config/
│   └── development.yaml    # Temporal server configuration
└── README.md               # This file
```

## Step 1: Download Binaries

Run the download script to fetch Temporal binaries from GitHub releases:

```bash
cd temporal-server
./download-binaries.sh
```

This script will:
- Download Temporal Server v1.24.2 (Linux AMD64)
- Download Temporal UI v2.30.0 (Linux AMD64)
- Extract all binaries to the `binaries/` directory
- Verify that all required binaries are present

**Expected binaries:**
- `temporal-server` - Main Temporal server (runs the workflow engine)
- `ui-server` - Temporal UI server (web interface)

**Note:** Database schema setup will be handled automatically using Temporal's auto-setup feature when we configure docker-compose in Phase 3.

## Step 2: Build Docker Images

### Build Temporal Server Image

```bash
docker build -t temporal-server:1.24.2 -f Dockerfile .
```

### Build Temporal UI Image

```bash
docker build -t temporal-ui:2.30.0 -f Dockerfile.ui .
```

## Step 3: Verify Images

Check that the images were built successfully:

```bash
# List images
docker images | grep temporal

# Check server version
docker run --rm temporal-server:1.24.2 --version

# Check UI version
docker run --rm temporal-ui:2.30.0 --version
```

## Configuration

### Environment Variables

The Temporal server configuration (`config/development.yaml`) uses environment variables for database connection:

- `DB_HOST` - PostgreSQL hostname (default: localhost)
- `DB_PORT` - PostgreSQL port (default: 5432)
- `DB_USER` - PostgreSQL user (default: temporal)
- `DB_PASSWORD` - PostgreSQL password (default: temporal)

These can be overridden when running containers via docker-compose or Kubernetes.

### Ports

**Temporal Server:**
- `7233` - Frontend gRPC (main entry point for clients)
- `7234` - History service
- `7235` - Matching service
- `7239` - Worker service
- `9090` - Prometheus metrics

**Temporal UI:**
- `8080` - Web UI

## For Corporate Environment (Nexus)

After building the images locally, tag and push them to your corporate Nexus registry:

```bash
# Tag images for Nexus
docker tag temporal-server:1.24.2 <your-nexus-url>/temporal-server:1.24.2
docker tag temporal-ui:2.30.0 <your-nexus-url>/temporal-ui:2.30.0

# Login to Nexus
docker login <your-nexus-url>

# Push images
docker push <your-nexus-url>/temporal-server:1.24.2
docker push <your-nexus-url>/temporal-ui:2.30.0
```

## Security Notes

- Images run as non-root user `temporal` (UID/GID 1000)
- Minimal Alpine base reduces attack surface
- Health checks included for container orchestration
- TLS can be enabled in production via configuration

## Troubleshooting

### Binary Download Issues

If download fails, manually download from:
- Temporal Server: https://github.com/temporalio/temporal/releases/tag/v1.24.2
- Temporal UI: https://github.com/temporalio/ui-server/releases/tag/v2.30.0

Extract tarballs to `binaries/` directory.

### Build Issues

**Error: "COPY failed: file not found"**
- Ensure you've run `download-binaries.sh` first
- Check that `binaries/` directory contains all required files

**Error: "permission denied"**
- Make sure `download-binaries.sh` is executable: `chmod +x download-binaries.sh`

### Runtime Issues

**Server won't start:**
- Check database connectivity (PostgreSQL must be running)
- Verify environment variables are set correctly
- Check logs: `docker logs <container-id>`

## Next Steps

After building the images:
1. Set up PostgreSQL (see `../postgres/README.md`)
2. Configure docker-compose for local testing (see `../temporal-compose/README.md`)
3. Deploy to Kubernetes using HELM chart (see `../temporal-helm/README.md`)

## Binary Checksums

For security verification, check SHA256 checksums from official release pages:
- Temporal Server: https://github.com/temporalio/temporal/releases/tag/v1.24.2
- UI Server: https://github.com/temporalio/ui-server/releases/tag/v2.30.0

## Additional Resources

- [Temporal Documentation](https://docs.temporal.io/)
- [Temporal Server Configuration](https://docs.temporal.io/references/configuration)
- [Temporal CLI](https://docs.temporal.io/cli)
