#!/bin/bash
set -e

# This script runs automatically when PostgreSQL container starts for the first time
# It creates the temporal_visibility database needed by Temporal

echo "Creating temporal_visibility database..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create visibility database if it doesn't exist
    SELECT 'CREATE DATABASE temporal_visibility'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'temporal_visibility')\gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE temporal_visibility TO $POSTGRES_USER;
EOSQL

echo "temporal_visibility database created successfully!"
