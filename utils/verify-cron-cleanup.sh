#!/bin/bash
# Verify that cron jobs have been properly removed from all servers
# Usage: ./verify-cron-cleanup.sh

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
echo -e "${BLUE}  Cron Cleanup Verification${NC}"
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

echo -e "${GREEN}Checking ${#SERVERS[@]} server(s) for remaining cron jobs...${NC}"
echo

# Counters
total=0
clean=0
has_cron=0
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

    echo -n "Checking $hostname... "

    # Check for cron jobs
    cron_output=$(ssh -p "$port" -o ConnectTimeout=10 "${user}@${hostname}" "crontab -l 2>/dev/null | grep -E '(bash-iptables-ddns|bash-plesk-firewall-ddns|bash-ufw-ddns)' || echo ''" 2>&1)

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}ERROR (connection failed)${NC}"
        errors=$((errors + 1))
        continue
    fi

    if [[ -z "$cron_output" ]]; then
        echo -e "${GREEN}✓ Clean (no cron jobs)${NC}"
        clean=$((clean + 1))
    else
        echo -e "${YELLOW}⚠ Found cron job(s):${NC}"
        echo "$cron_output" | sed 's/^/  /'
        has_cron=$((has_cron + 1))
    fi
done

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verification Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total servers checked: $total"
echo -e "${GREEN}Clean (no crons):      $clean${NC}"
echo -e "${YELLOW}Has cron jobs:         $has_cron${NC}"
echo -e "${RED}Errors:                $errors${NC}"
echo

if [[ $has_cron -gt 0 ]]; then
    echo -e "${YELLOW}⚠ Warning: Some servers still have cron jobs configured${NC}"
    echo "You may need to manually remove them or re-run the uninstall script"
    exit 1
elif [[ $errors -gt 0 ]]; then
    echo -e "${RED}⚠ Some servers could not be checked${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All servers are clean - no cron jobs found!${NC}"
fi
