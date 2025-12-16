#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Versions
TEMPORAL_VERSION="1.24.2"
UI_VERSION="2.30.0"

# URLs
TEMPORAL_URL="https://github.com/temporalio/temporal/releases/download/v${TEMPORAL_VERSION}/temporal_${TEMPORAL_VERSION}_linux_amd64.tar.gz"
UI_URL="https://github.com/temporalio/ui-server/releases/download/v${UI_VERSION}/ui-server_${UI_VERSION}_linux_amd64.tar.gz"

# Checksums (SHA256) - These should be verified from the release page
# TODO: Update these checksums from the actual release pages
TEMPORAL_CHECKSUM=""
UI_CHECKSUM=""

BINARIES_DIR="./binaries"

echo -e "${GREEN}Temporal Binary Download Script${NC}"
echo "================================"
echo "Temporal Server: v${TEMPORAL_VERSION}"
echo "Temporal UI: v${UI_VERSION}"
echo ""

# Create binaries directory
mkdir -p "${BINARIES_DIR}"

# Download Temporal Server
echo -e "${YELLOW}Downloading Temporal Server...${NC}"
if [ -f "${BINARIES_DIR}/temporal_${TEMPORAL_VERSION}_linux_amd64.tar.gz" ]; then
    echo -e "${GREEN}Temporal server tarball already exists, skipping download${NC}"
else
    curl -L "${TEMPORAL_URL}" -o "${BINARIES_DIR}/temporal_${TEMPORAL_VERSION}_linux_amd64.tar.gz"
    echo -e "${GREEN}✓ Downloaded Temporal Server${NC}"
fi

# Download Temporal UI
echo -e "${YELLOW}Downloading Temporal UI...${NC}"
if [ -f "${BINARIES_DIR}/ui-server_${UI_VERSION}_linux_amd64.tar.gz" ]; then
    echo -e "${GREEN}UI server tarball already exists, skipping download${NC}"
else
    curl -L "${UI_URL}" -o "${BINARIES_DIR}/ui-server_${UI_VERSION}_linux_amd64.tar.gz"
    echo -e "${GREEN}✓ Downloaded Temporal UI${NC}"
fi

# Extract Temporal Server
echo -e "${YELLOW}Extracting Temporal Server binaries...${NC}"
cd "${BINARIES_DIR}"
tar -xzf "temporal_${TEMPORAL_VERSION}_linux_amd64.tar.gz"
echo -e "${GREEN}✓ Extracted Temporal Server${NC}"

# Extract Temporal UI
echo -e "${YELLOW}Extracting Temporal UI binaries...${NC}"
tar -xzf "ui-server_${UI_VERSION}_linux_amd64.tar.gz"
echo -e "${GREEN}✓ Extracted Temporal UI${NC}"

cd ..

# Verify binaries exist
echo ""
echo -e "${YELLOW}Verifying binaries...${NC}"

BINARIES=(
    "temporal-server"
    "ui-server"
)

ALL_FOUND=true
for binary in "${BINARIES[@]}"; do
    if [ -f "${BINARIES_DIR}/${binary}" ]; then
        echo -e "${GREEN}✓ Found: ${binary}${NC}"
    else
        echo -e "${RED}✗ Missing: ${binary}${NC}"
        ALL_FOUND=false
    fi
done

echo ""
if [ "$ALL_FOUND" = true ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}All binaries downloaded successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Build Docker images:"
    echo "   docker build -t temporal-server:1.24.2 -f Dockerfile ."
    echo "   docker build -t temporal-ui:2.30.0 -f Dockerfile.ui ."
    echo ""
    echo "2. Verify versions:"
    echo "   docker run --rm temporal-server:1.24.2 --version"
    echo "   docker run --rm temporal-ui:2.30.0 --version"
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Some binaries are missing!${NC}"
    echo -e "${RED}Please check the extraction process.${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
