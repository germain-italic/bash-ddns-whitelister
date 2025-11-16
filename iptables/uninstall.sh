#!/bin/bash
# Uninstall script for bash-iptables-ddns
# Usage: ./uninstall.sh <hostname> [ssh_port] [ssh_user]
#
# This script will:
# - Remove all iptables rules managed by this tool
# - Remove cron jobs
# - Delete the installation directory
# - Clean up logs and cache

set -e

HOSTNAME="$1"
SSH_PORT="${2:-22}"
SSH_USER="${3:-root}"
INSTALL_DIR="/root/bash-iptables-ddns"

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

echo -e "${GREEN}=== Uninstalling bash-iptables-ddns from ${HOSTNAME} ===${NC}"
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
INSTALL_DIR="/root/bash-iptables-ddns"

echo "=== Uninstalling bash-iptables-ddns ==="

# Step 1: Remove firewall rules
if [ -f "${INSTALL_DIR}/dyndns_rules.conf" ]; then
    echo "Removing iptables rules managed by this tool..."

    # Read each rule and delete it
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue

        # Extract hostnames from rule
        hostnames=$(grep -oE '[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+' <<< "$line" || true)

        if [[ -z "$hostnames" ]]; then
            continue
        fi

        # For each hostname, try to get cached IP and delete rule
        for hostname in $hostnames; do
            cache_file="${INSTALL_DIR}/.cache/$(echo "$hostname" | sed 's/[^a-zA-Z0-9]/_/g').cache"

            if [[ -f "$cache_file" ]]; then
                cached_ip=$(cat "$cache_file")
                if [[ -n "$cached_ip" ]]; then
                    # Replace hostname with IP in rule
                    rule_with_ip=$(echo "$line" | sed "s/$hostname/$cached_ip/g")
                    # Convert -A to -D for deletion
                    delete_rule=$(echo "$rule_with_ip" | sed 's/^-A/-D/')

                    # Try to delete the rule
                    if iptables $delete_rule 2>/dev/null; then
                        echo "  ✓ Deleted rule: iptables $delete_rule"
                    else
                        echo "  ℹ Rule not found (already deleted?): iptables $delete_rule"
                    fi
                fi
            fi
        done
    done < "${INSTALL_DIR}/dyndns_rules.conf"

    echo "✓ Firewall rules cleaned"
else
    echo "ℹ No rules configuration found, skipping firewall cleanup"
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
echo "  - All iptables rules managed by bash-iptables-ddns"
echo "  - Cron job for automatic updates"
echo "  - Installation directory: ${INSTALL_DIR}"
echo "  - Logs and cache files"
