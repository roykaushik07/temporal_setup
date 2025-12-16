#!/bin/bash

set -e

echo "Setting up Temporal database schemas..."
echo "========================================"

# Check if temporal-sql-tool exists
if [ ! -f "../temporal-server/binaries/temporal-sql-tool" ]; then
    echo "Error: temporal-sql-tool not found!"
    echo "Please run: cd ../temporal-server && ./download-binaries.sh"
    exit 1
fi

# Database connection info
DB_HOST="postgres"
DB_PORT="5432"
DB_USER="temporal"
DB_PASSWORD="temporal"

echo "1. Setting up default schema (temporal database)..."
docker run --rm --network temporal-network \
    -v "$(pwd)/../temporal-server/binaries:/binaries:ro" \
    postgres:15-alpine \
    /binaries/temporal-sql-tool \
    --plugin postgres12 \
    --ep "${DB_HOST}" \
    --port "${DB_PORT}" \
    --user "${DB_USER}" \
    --password "${DB_PASSWORD}" \
    --database temporal \
    setup-schema -v 0.0

echo ""
echo "2. Updating default schema to latest version..."
docker run --rm --network temporal-network \
    -v "$(pwd)/../temporal-server/binaries:/binaries:ro" \
    postgres:15-alpine \
    /binaries/temporal-sql-tool \
    --plugin postgres12 \
    --ep "${DB_HOST}" \
    --port "${DB_PORT}" \
    --user "${DB_USER}" \
    --password "${DB_PASSWORD}" \
    --database temporal \
    update-schema -d /binaries/schema/postgresql/v12/temporal/versioned

echo ""
echo "3. Setting up visibility schema (temporal_visibility database)..."
docker run --rm --network temporal-network \
    -v "$(pwd)/../temporal-server/binaries:/binaries:ro" \
    postgres:15-alpine \
    /binaries/temporal-sql-tool \
    --plugin postgres12 \
    --ep "${DB_HOST}" \
    --port "${DB_PORT}" \
    --user "${DB_USER}" \
    --password "${DB_PASSWORD}" \
    --database temporal_visibility \
    setup-schema -v 0.0

echo ""
echo "4. Updating visibility schema to latest version..."
docker run --rm --network temporal-network \
    -v "$(pwd)/../temporal-server/binaries:/binaries:ro" \
    postgres:15-alpine \
    /binaries/temporal-sql-tool \
    --plugin postgres12 \
    --ep "${DB_HOST}" \
    --port "${DB_PORT}" \
    --user "${DB_USER}" \
    --password "${DB_PASSWORD}" \
    --database temporal_visibility \
    update-schema -d /binaries/schema/postgresql/v12/visibility/versioned

echo ""
echo "========================================"
echo "✓ Database schemas setup complete!"
echo "You can now start Temporal: docker-compose up -d"
