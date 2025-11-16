#!/bin/bash
# Mass uninstall script for bash-ddns-whitelister
# This script reads server list from .env and runs appropriate uninstall script
# Usage: ./uninstall-all.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Mass Uninstall - bash-ddns-whitelister${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}ERROR: .env file not found${NC}"
    echo "Please create .env from .env.dist and configure your servers"
    echo "  cp ${SCRIPT_DIR}/.env.dist ${ENV_FILE}"
    exit 1
fi

# Source the .env file
source "$ENV_FILE"

# Check if SERVERS array is defined
if [[ -z "${SERVERS[@]}" ]]; then
    echo -e "${RED}ERROR: SERVERS array not defined in .env${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#SERVERS[@]} server(s) in configuration${NC}"
echo

# Counters
total=0
success=0
failed=0
skipped=0

# Process each server
for server_config in "${SERVERS[@]}"; do
    total=$((total + 1))

    # Parse server configuration
    # Format: hostname:port:user:firewall_type[:skip]
    IFS=':' read -ra PARTS <<< "$server_config"

    hostname="${PARTS[0]}"
    port="${PARTS[1]:-22}"
    user="${PARTS[2]:-root}"
    firewall_type="${PARTS[3]:-iptables}"
    skip_flag="${PARTS[4]:-}"

    # Skip if marked
    if [[ "$skip_flag" == "SKIP" ]]; then
        echo -e "${YELLOW}⊘ Skipping $hostname (marked as SKIP)${NC}"
        skipped=$((skipped + 1))
        continue
    fi

    # Skip if firewall_type is none
    if [[ "$firewall_type" == "none" ]]; then
        echo -e "${YELLOW}⊘ Skipping $hostname (firewall_type: none)${NC}"
        skipped=$((skipped + 1))
        continue
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Processing: $hostname${NC}"
    echo -e "${BLUE}  Port: $port | User: $user | Firewall: $firewall_type${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Determine which uninstall script to use
    case "$firewall_type" in
        iptables)
            uninstall_script="${REPO_DIR}/iptables/uninstall.sh"
            ;;
        plesk)
            uninstall_script="${REPO_DIR}/plesk/uninstall.sh"
            ;;
        ufw)
            uninstall_script="${REPO_DIR}/ufw/uninstall.sh"
            ;;
        *)
            echo -e "${RED}✗ Unknown firewall type: $firewall_type${NC}"
            failed=$((failed + 1))
            echo
            continue
            ;;
    esac

    # Check if uninstall script exists
    if [[ ! -f "$uninstall_script" ]]; then
        echo -e "${RED}✗ Uninstall script not found: $uninstall_script${NC}"
        failed=$((failed + 1))
        echo
        continue
    fi

    # Run uninstall script
    if "$uninstall_script" "$hostname" "$port" "$user"; then
        echo -e "${GREEN}✓ Successfully uninstalled from $hostname${NC}"
        success=$((success + 1))
    else
        echo -e "${RED}✗ Failed to uninstall from $hostname${NC}"
        failed=$((failed + 1))
    fi

    echo
done

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Uninstallation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total servers:     $total"
echo -e "${GREEN}Successful:        $success${NC}"
echo -e "${RED}Failed:            $failed${NC}"
echo -e "${YELLOW}Skipped:           $skipped${NC}"
echo

if [[ $failed -gt 0 ]]; then
    echo -e "${RED}⚠ Some uninstallations failed. Please check the output above.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All uninstallations completed successfully!${NC}"
fi
