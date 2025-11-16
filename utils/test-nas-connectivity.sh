#!/bin/bash
# Test script to verify NAS can connect to all servers
# This script should be run FROM the NAS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Server list loaded from command line arguments or default
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No servers specified${NC}"
    echo "Usage: $0 server1:port:user [server2:port:user ...]"
    echo "Example: $0 server1.example.com:22:root server2.example.com:2222:root"
    exit 1
fi

# Counters
TOTAL=0
SUCCESS=0
FAILED=0

# Arrays to track results
declare -a FAILED_SERVERS
declare -a SUCCESS_SERVERS

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     NAS Connectivity Test                              ║${NC}"
echo -e "${BLUE}║     Testing SSH + rsync from NAS to servers            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "Running from: $(hostname)"
echo -e "Date: $(date)"
echo
echo "----------------------------------------"
echo

# Function to test a single server
test_server() {
    local server_info="$1"
    local hostname port user

    IFS=':' read -r hostname port user <<< "$server_info"

    TOTAL=$((TOTAL + 1))

    echo -e "${YELLOW}[$TOTAL] Testing ${hostname}:${port} (${user})...${NC}"

    # Test 1: Basic SSH connection
    echo -n "  SSH connection... "
    if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$port" "${user}@${hostname}" "echo 'OK'" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ FAILED${NC}"
        FAILED=$((FAILED + 1))
        FAILED_SERVERS+=("${hostname}:${port} (SSH failed)")
        return 1
    fi

    # Test 2: Create a test file for rsync
    local test_file="/tmp/nas-test-$(date +%s).txt"
    echo "Test from NAS at $(date)" > "$test_file"

    # Test 3: rsync test
    echo -n "  rsync test... "
    if timeout 15 rsync -avz -e "ssh -p $port -o StrictHostKeyChecking=no -o ConnectTimeout=5" "$test_file" "${user}@${hostname}:/tmp/" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"

        # Cleanup remote file
        ssh -p "$port" "${user}@${hostname}" "rm -f /tmp/$(basename $test_file)" 2>/dev/null || true

        SUCCESS=$((SUCCESS + 1))
        SUCCESS_SERVERS+=("${hostname}:${port}")
        echo -e "${GREEN}✓ [$TOTAL] ${hostname} - All tests passed${NC}"
    else
        echo -e "${RED}✗ FAILED${NC}"
        FAILED=$((FAILED + 1))
        FAILED_SERVERS+=("${hostname}:${port} (rsync failed)")
        echo -e "${RED}✗ [$TOTAL] ${hostname} - rsync test failed${NC}"
    fi

    # Cleanup local test file
    rm -f "$test_file"

    echo
}

# Run tests on all servers
for server in "$@"; do
    test_server "$server"
done

# Summary
echo "========================================"
echo
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 Test Summary                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "Total servers tested: ${TOTAL}"
echo -e "${GREEN}Successful:           ${SUCCESS}${NC}"
echo -e "${RED}Failed:               ${FAILED}${NC}"
echo

if [ ${#SUCCESS_SERVERS[@]} -gt 0 ]; then
    echo -e "${GREEN}Successful connections:${NC}"
    for server in "${SUCCESS_SERVERS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $server"
    done
    echo
fi

if [ ${#FAILED_SERVERS[@]} -gt 0 ]; then
    echo -e "${RED}Failed connections:${NC}"
    for server in "${FAILED_SERVERS[@]}"; do
        echo -e "  ${RED}✗${NC} $server"
    done
    echo
fi

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}All connectivity tests passed!${NC}"
    echo -e "${GREEN}NAS can successfully connect to all servers${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${RED}Some tests failed!${NC}"
    echo -e "${RED}Please check firewall rules on failed servers${NC}"
    echo -e "${RED}════════════════════════════════════════${NC}"
    exit 1
fi
