#!/bin/bash
# Verify that cron jobs are properly installed on all servers
# Usage: ./verify-cron-installed.sh

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
echo -e "${BLUE}  Cron Installation Verification${NC}"
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

echo -e "${GREEN}Checking ${#SERVERS[@]} server(s) for cron jobs...${NC}"
echo

# Counters
total=0
has_cron=0
no_cron=0
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

    # Check for cron jobs based on firewall type
    case "$firewall_type" in
        iptables)
            cron_pattern="bash-iptables-ddns"
            ;;
        plesk)
            cron_pattern="bash-plesk-firewall-ddns"
            ;;
        ufw)
            cron_pattern="bash-ufw-ddns"
            ;;
        *)
            echo -e "${YELLOW}Unknown firewall type: $firewall_type${NC}"
            errors=$((errors + 1))
            continue
            ;;
    esac

    cron_output=$(ssh -p "$port" -o ConnectTimeout=10 "${user}@${hostname}" "crontab -l 2>/dev/null | grep '$cron_pattern' || echo ''" 2>&1)

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}ERROR (connection failed)${NC}"
        errors=$((errors + 1))
        continue
    fi

    if [[ -n "$cron_output" ]]; then
        echo -e "${GREEN}✓ Cron installed${NC}"
        echo "  $cron_output" | sed 's/^/    /'
        has_cron=$((has_cron + 1))
    else
        echo -e "${RED}✗ No cron found${NC}"
        no_cron=$((no_cron + 1))
    fi
done

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verification Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total servers checked: $total"
echo -e "${GREEN}Has cron jobs:         $has_cron${NC}"
echo -e "${RED}Missing cron jobs:     $no_cron${NC}"
echo -e "${YELLOW}Errors:                $errors${NC}"
echo

if [[ $no_cron -gt 0 ]]; then
    echo -e "${RED}⚠ Warning: Some servers are missing cron jobs${NC}"
    echo "You may need to redeploy the scripts to these servers"
    exit 1
elif [[ $errors -gt 0 ]]; then
    echo -e "${YELLOW}⚠ Some servers could not be checked${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All servers have cron jobs installed!${NC}"
fi
