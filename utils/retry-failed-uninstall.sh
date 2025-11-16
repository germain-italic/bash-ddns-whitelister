#!/bin/bash
# Retry uninstall on specific failed servers
# This is a temporary script to retry the servers that failed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Retry Failed Uninstalls${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# First, pull latest changes to get the fix
echo -e "${YELLOW}Pulling latest changes...${NC}"
cd "$REPO_DIR"
git pull origin master
echo -e "${GREEN}✓ Repository updated${NC}"
echo

# Define only the servers that failed
FAILED_SERVERS=(
    # Add servers that failed here based on output
    # We'll identify them from the error log
)

# For now, let's just run uninstall-all.sh again
# since it will skip already-uninstalled servers gracefully
echo -e "${YELLOW}Running full uninstall again (will skip already-clean servers)...${NC}"
cd "${SCRIPT_DIR}"
./uninstall-all.sh
