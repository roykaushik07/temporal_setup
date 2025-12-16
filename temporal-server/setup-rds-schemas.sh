#!/bin/bash

#############################################################################
# Temporal RDS Schema Setup Script
#############################################################################
# This script sets up the required database schemas for Temporal in AWS RDS.
# It downloads schema files and initializes both databases:
#   1. temporal (main database)
#   2. temporal_visibility (search/query database)
#
# Usage:
#   ./setup-rds-schemas.sh
#
# The script will prompt for required information.
#############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}${1}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Check if temporal-sql-tool exists
check_sql_tool() {
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    SQL_TOOL="${SCRIPT_DIR}/binaries/temporal-sql-tool"

    if [ ! -f "$SQL_TOOL" ]; then
        print_error "temporal-sql-tool not found at: $SQL_TOOL"
        echo "Please ensure the binary exists in temporal-server/binaries/"
        exit 1
    fi

    if [ ! -x "$SQL_TOOL" ]; then
        print_info "Making temporal-sql-tool executable..."
        chmod +x "$SQL_TOOL"
    fi

    print_success "Found temporal-sql-tool"
}

# Download schema files
download_schemas() {
    local version=$1
    local temp_dir="/tmp/temporal-schemas-$$"

    print_info "Downloading Temporal schema files (version ${version})..."

    mkdir -p "$temp_dir"
    cd "$temp_dir"

    # Try curl first, fallback to wget
    if command -v curl &> /dev/null; then
        curl -sL "https://github.com/temporalio/temporal/archive/refs/tags/v${version}.tar.gz" -o "temporal.tar.gz"
    elif command -v wget &> /dev/null; then
        wget -q "https://github.com/temporalio/temporal/archive/refs/tags/v${version}.tar.gz" -O "temporal.tar.gz"
    else
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    print_info "Extracting schema files..."
    tar -xzf temporal.tar.gz

    SCHEMA_DIR="${temp_dir}/temporal-${version}/schema/postgresql/v12"

    if [ ! -d "$SCHEMA_DIR" ]; then
        print_error "Schema directory not found: $SCHEMA_DIR"
        exit 1
    fi

    print_success "Schema files downloaded to: $SCHEMA_DIR"
    echo "$SCHEMA_DIR"
}

# Setup database schema
setup_database() {
    local db_name=$1
    local schema_type=$2
    local rds_endpoint=$3
    local rds_port=$4
    local db_user=$5
    local db_password=$6
    local schema_dir=$7
    local use_tls=$8

    print_header "Setting up ${db_name} database"

    # Build TLS flags
    local tls_flags=""
    if [ "$use_tls" = "true" ]; then
        tls_flags="--tls --tls-disable-host-verification"
    fi

    # Setup base schema (version 0.0)
    print_info "Creating base schema (version 0.0)..."
    "$SQL_TOOL" \
        --plugin postgres12 \
        --ep "$rds_endpoint" \
        --port "$rds_port" \
        --user "$db_user" \
        --password "$db_password" \
        --database "$db_name" \
        $tls_flags \
        setup-schema -v 0.0

    print_success "Base schema created"

    # Update to latest schema version
    print_info "Updating to latest schema version..."
    "$SQL_TOOL" \
        --plugin postgres12 \
        --ep "$rds_endpoint" \
        --port "$rds_port" \
        --user "$db_user" \
        --password "$db_password" \
        --database "$db_name" \
        $tls_flags \
        update-schema -d "${schema_dir}/${schema_type}/versioned"

    print_success "${db_name} schema setup complete!"
}

# Verify schema setup
verify_setup() {
    local db_name=$1
    local rds_endpoint=$2
    local rds_port=$3
    local db_user=$4
    local db_password=$5
    local use_tls=$6

    print_info "Verifying ${db_name} database..."

    # Build psql SSL mode
    local ssl_mode="disable"
    if [ "$use_tls" = "true" ]; then
        ssl_mode="require"
    fi

    # Check if psql is available
    if ! command -v psql &> /dev/null; then
        print_warning "psql not found - skipping verification"
        print_info "Install PostgreSQL client to enable verification"
        return
    fi

    # Count tables
    local table_count=$(PGPASSWORD="$db_password" psql \
        -h "$rds_endpoint" \
        -p "$rds_port" \
        -U "$db_user" \
        -d "$db_name" \
        -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" \
        --quiet \
        2>/dev/null | xargs)

    if [ -n "$table_count" ] && [ "$table_count" -gt 0 ]; then
        print_success "${db_name}: Found ${table_count} tables"
    else
        print_warning "${db_name}: Could not verify tables (might need manual check)"
    fi
}

# Prompt for configuration
prompt_config() {
    print_header "Temporal RDS Schema Setup"

    echo "This script will set up Temporal database schemas in your AWS RDS instance."
    echo ""

    # RDS Endpoint
    read -p "$(echo -e ${BLUE}RDS Endpoint${NC}) (e.g., mydb.xxxxx.us-east-1.rds.amazonaws.com): " RDS_ENDPOINT
    if [ -z "$RDS_ENDPOINT" ]; then
        print_error "RDS endpoint is required"
        exit 1
    fi

    # Port
    read -p "$(echo -e ${BLUE}Port${NC}) [5432]: " RDS_PORT
    RDS_PORT=${RDS_PORT:-5432}

    # Database user
    read -p "$(echo -e ${BLUE}Database User${NC}) [temporal]: " DB_USER
    DB_USER=${DB_USER:-temporal}

    # Database password
    read -sp "$(echo -e ${BLUE}Database Password${NC}): " DB_PASSWORD
    echo ""
    if [ -z "$DB_PASSWORD" ]; then
        print_error "Database password is required"
        exit 1
    fi

    # Main database name
    read -p "$(echo -e ${BLUE}Main Database Name${NC}) [temporal]: " MAIN_DB
    MAIN_DB=${MAIN_DB:-temporal}

    # Visibility database name
    read -p "$(echo -e ${BLUE}Visibility Database Name${NC}) [temporal_visibility]: " VISIBILITY_DB
    VISIBILITY_DB=${VISIBILITY_DB:-temporal_visibility}

    # Temporal version
    read -p "$(echo -e ${BLUE}Temporal Version${NC}) [1.24.2]: " TEMPORAL_VERSION
    TEMPORAL_VERSION=${TEMPORAL_VERSION:-1.24.2}

    # Use TLS
    read -p "$(echo -e ${BLUE}Use TLS/SSL${NC}) (y/n) [y]: " USE_TLS_INPUT
    USE_TLS_INPUT=${USE_TLS_INPUT:-y}
    if [[ "$USE_TLS_INPUT" =~ ^[Yy]$ ]]; then
        USE_TLS="true"
    else
        USE_TLS="false"
    fi

    echo ""
    print_info "Configuration Summary:"
    echo "  RDS Endpoint: $RDS_ENDPOINT"
    echo "  Port: $RDS_PORT"
    echo "  User: $DB_USER"
    echo "  Main Database: $MAIN_DB"
    echo "  Visibility Database: $VISIBILITY_DB"
    echo "  Temporal Version: $TEMPORAL_VERSION"
    echo "  Use TLS: $USE_TLS"
    echo ""

    read -p "$(echo -e ${YELLOW}Proceed with setup?${NC}) (y/n): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        print_info "Setup cancelled"
        exit 0
    fi
}

# Main execution
main() {
    print_header "Temporal RDS Schema Setup"

    # Check prerequisites
    check_sql_tool

    # Get configuration
    prompt_config

    # Download schema files
    SCHEMA_DIR=$(download_schemas "$TEMPORAL_VERSION")

    # Setup main database
    setup_database \
        "$MAIN_DB" \
        "temporal" \
        "$RDS_ENDPOINT" \
        "$RDS_PORT" \
        "$DB_USER" \
        "$DB_PASSWORD" \
        "$SCHEMA_DIR" \
        "$USE_TLS"

    # Setup visibility database
    setup_database \
        "$VISIBILITY_DB" \
        "visibility" \
        "$RDS_ENDPOINT" \
        "$RDS_PORT" \
        "$DB_USER" \
        "$DB_PASSWORD" \
        "$SCHEMA_DIR" \
        "$USE_TLS"

    # Verify setup
    echo ""
    print_header "Verification"
    verify_setup "$MAIN_DB" "$RDS_ENDPOINT" "$RDS_PORT" "$DB_USER" "$DB_PASSWORD" "$USE_TLS"
    verify_setup "$VISIBILITY_DB" "$RDS_ENDPOINT" "$RDS_PORT" "$DB_USER" "$DB_PASSWORD" "$USE_TLS"

    # Cleanup
    print_info "Cleaning up temporary files..."
    rm -rf "/tmp/temporal-schemas-$$"

    # Success!
    echo ""
    print_header "Setup Complete!"
    print_success "Temporal database schemas are ready!"
    echo ""
    echo "Next steps:"
    echo "  1. Create Kubernetes secret with database credentials:"
    echo "     kubectl create secret generic temporal-db-credentials \\"
    echo "       --from-literal=username=$DB_USER \\"
    echo "       --from-literal=password='***' \\"
    echo "       -n temporal"
    echo ""
    echo "  2. Update your values-production.yaml:"
    echo "     database:"
    echo "       external:"
    echo "         host: \"$RDS_ENDPOINT\""
    echo "         port: $RDS_PORT"
    echo "         defaultDatabase: $MAIN_DB"
    echo "         visibilityDatabase: $VISIBILITY_DB"
    echo "         user: $DB_USER"
    echo "         existingSecret: \"temporal-db-credentials\""
    echo "         ssl:"
    echo "           enabled: $USE_TLS"
    echo "           mode: require"
    echo ""
    echo "  3. Deploy HELM chart:"
    echo "     helm install temporal ./temporal-helm \\"
    echo "       -f values-production.yaml \\"
    echo "       -n temporal --create-namespace"
    echo ""
}

# Run main function
main
