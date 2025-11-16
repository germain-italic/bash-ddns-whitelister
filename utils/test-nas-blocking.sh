#!/bin/bash
# Test that NAS is blocked from all servers
# This script attempts to connect from NAS to each server to verify blocking
# Usage: ./test-nas-blocking.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  NAS Blocking Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

# Source the .env file
source "$ENV_FILE"

# Check if SERVERS array is defined
if [[ -z "${SERVERS[@]}" ]]; then
    echo -e "${RED}ERROR: SERVERS array not defined in .env${NC}"
    exit 1
fi

# Check if NAS host is defined
if [[ -z "$NAS1_HOST" ]]; then
    echo -e "${RED}ERROR: NAS1_HOST not defined in .env${NC}"
    exit 1
fi

echo -e "${GREEN}Testing NAS blocking on ${#SERVERS[@]} server(s)...${NC}"
echo -e "NAS: ${NAS1_HOST}"
echo

# Counters
total=0
blocked=0
accessible=0
errors=0

# Process each server
for server_config in "${SERVERS[@]}"; do
    total=$((total + 1))

    # Parse server configuration
    IFS=':' read -ra PARTS <<< "$server_config"

    hostname="${PARTS[0]}"
    port="${PARTS[1]:-22}"
    user="${PARTS[2]:-root}"
    firewall_type="${PARTS[3]:-iptables}"
    skip_flag="${PARTS[4]:-}"

    # Skip if marked
    if [[ "$skip_flag" == "SKIP" ]] || [[ "$firewall_type" == "none" ]]; then
        continue
    fi

    echo -n "Testing ${hostname}:${port}... "

    # Try to connect from NAS to server with short timeout
    # We use ProxyJump to route through NAS
    result=$(timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ProxyJump="root@${NAS1_HOST}" \
        -p "${port}" "${user}@${hostname}" \
        "echo 'CONNECTED'" 2>&1 || echo "BLOCKED")

    if [[ "$result" == "CONNECTED" ]]; then
        echo -e "${RED}✗ ACCESSIBLE (should be blocked!)${NC}"
        accessible=$((accessible + 1))
    elif [[ "$result" =~ "BLOCKED" ]] || [[ "$result" =~ "timed out" ]] || [[ "$result" =~ "Connection refused" ]] || [[ "$result" =~ "Connection reset" ]]; then
        echo -e "${GREEN}✓ Blocked${NC}"
        blocked=$((blocked + 1))
    else
        echo -e "${YELLOW}? Unknown status${NC}"
        echo "  Output: $result" | head -1
        errors=$((errors + 1))
    fi
done

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Blocking Verification Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total servers tested:  $total"
echo -e "${GREEN}Blocked (expected):    $blocked${NC}"
echo -e "${RED}Accessible (problem):  $accessible${NC}"
echo -e "${YELLOW}Errors/Unknown:        $errors${NC}"
echo

if [[ $accessible -gt 0 ]]; then
    echo -e "${RED}⚠ WARNING: Some servers are still accessible from NAS!${NC}"
    echo "These servers need to have their firewall rules checked."
    exit 1
elif [[ $errors -gt 0 ]]; then
    echo -e "${YELLOW}⚠ Some servers could not be tested${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All servers are properly blocking NAS access!${NC}"
fi
