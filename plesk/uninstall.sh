#!/bin/bash
# Uninstall script for bash-plesk-firewall-ddns
# Usage: ./uninstall.sh <hostname> [ssh_port] [ssh_user]
#
# This script will:
# - Remove all Plesk firewall rules managed by this tool
# - Remove cron jobs
# - Delete the installation directory
# - Clean up logs and cache

set -e

HOSTNAME="$1"
SSH_PORT="${2:-22}"
SSH_USER="${3:-root}"
INSTALL_DIR="/root/bash-plesk-firewall-ddns"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ -z "$HOSTNAME" ]; then
    echo -e "${RED}Error: hostname required${NC}"
    echo "Usage: $0 <hostname> [ssh_port] [ssh_user]"
    exit 1
fi

echo -e "${GREEN}=== Uninstalling bash-plesk-firewall-ddns from ${HOSTNAME} ===${NC}"
echo "SSH: ${SSH_USER}@${HOSTNAME}:${SSH_PORT}"
echo "Install directory: ${INSTALL_DIR}"
echo

# Check if we can connect
echo -e "${YELLOW}Testing SSH connection...${NC}"
if ! ssh -p "${SSH_PORT}" -o ConnectTimeout=10 "${SSH_USER}@${HOSTNAME}" "echo 'Connection OK'" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to ${HOSTNAME}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH connection OK${NC}"
echo

# Perform uninstallation
echo -e "${YELLOW}Starting uninstallation...${NC}"
ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" bash << 'ENDSSH'
set -e
INSTALL_DIR="/root/bash-plesk-firewall-ddns"

echo "=== Uninstalling bash-plesk-firewall-ddns ==="

# Check if Plesk is available
if ! command -v plesk &> /dev/null; then
    echo "WARNING: Plesk command not found, skipping firewall rules cleanup"
    PLESK_AVAILABLE=false
else
    PLESK_AVAILABLE=true
fi

# Step 1: Remove Plesk firewall rules
if [ "$PLESK_AVAILABLE" = true ] && [ -f "${INSTALL_DIR}/firewall_rules.conf" ]; then
    echo "Removing Plesk firewall rules managed by this tool..."

    # Read each rule and delete it by name
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue

        # Parse rule: RULE_NAME|DIRECTION|ACTION|PORTS|HOSTNAME|COMMENT
        IFS='|' read -r rule_name direction action ports hostname comment <<< "$line"

        # Trim whitespace
        rule_name=$(echo "$rule_name" | xargs)

        if [[ -z "$rule_name" ]]; then
            continue
        fi

        # Get rule ID
        rule_id=$(plesk ext firewall --list-json 2>/dev/null | \
            python3 -c "import sys, json; rule_name = sys.argv[1]; rules = json.load(sys.stdin); print(next((r['id'] for r in rules if r['name'] == rule_name), ''))" "$rule_name" || echo "")

        if [[ -n "$rule_id" ]]; then
            # Delete the rule by ID
            if plesk ext firewall --remove-rule -id "$rule_id" 2>/dev/null; then
                echo "  ✓ Deleted rule: $rule_name (ID: $rule_id)"
            else
                echo "  ⚠ Failed to delete rule: $rule_name"
            fi
        else
            echo "  ℹ Rule not found: $rule_name (already deleted?)"
        fi
    done < "${INSTALL_DIR}/firewall_rules.conf"

    # Apply changes
    echo "Applying Plesk firewall changes..."
    if plesk ext firewall --apply -auto-confirm-this-may-lock-me-out-of-the-server 2>/dev/null; then
        echo "✓ Firewall changes applied"
    else
        echo "⚠ Warning: Failed to apply firewall changes"
    fi

    echo "✓ Firewall rules cleaned"
else
    echo "ℹ No rules configuration found or Plesk not available, skipping firewall cleanup"
fi

# Step 2: Remove cron job
echo "Removing cron job..."
if crontab -l 2>/dev/null | grep -q "${INSTALL_DIR}/update.sh"; then
    # Remove the cron job
    (crontab -l 2>/dev/null | grep -v "${INSTALL_DIR}/update.sh") | crontab -
    echo "✓ Cron job removed"
else
    echo "ℹ No cron job found"
fi

# Step 3: Remove installation directory
if [ -d "${INSTALL_DIR}" ]; then
    echo "Removing installation directory..."
    rm -rf "${INSTALL_DIR}"
    echo "✓ Installation directory removed: ${INSTALL_DIR}"
else
    echo "ℹ Installation directory not found: ${INSTALL_DIR}"
fi

echo ""
echo "=== Uninstallation completed successfully ==="
ENDSSH

echo -e "${GREEN}=== Uninstallation completed successfully ===${NC}"
echo
echo "The following items have been removed from ${HOSTNAME}:"
echo "  - All Plesk firewall rules managed by bash-plesk-firewall-ddns"
echo "  - Cron job for automatic updates"
echo "  - Installation directory: ${INSTALL_DIR}"
echo "  - Logs and cache files"
