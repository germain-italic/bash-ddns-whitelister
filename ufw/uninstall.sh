#!/bin/bash
# Uninstall script for bash-ufw-ddns
# Usage: ./uninstall.sh <hostname> [ssh_port] [ssh_user]
#
# This script will:
# - Remove all UFW rules managed by this tool
# - Remove cron jobs
# - Delete the installation directory
# - Clean up logs and cache

set -e

HOSTNAME="$1"
SSH_PORT="${2:-22}"
SSH_USER="${3:-root}"
INSTALL_DIR="/root/bash-ufw-ddns"

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

echo -e "${GREEN}=== Uninstalling bash-ufw-ddns from ${HOSTNAME} ===${NC}"
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
INSTALL_DIR="/root/bash-ufw-ddns"

echo "=== Uninstalling bash-ufw-ddns ==="

# Check if UFW is available
if ! command -v ufw &> /dev/null; then
    echo "WARNING: UFW command not found, skipping firewall rules cleanup"
    UFW_AVAILABLE=false
else
    UFW_AVAILABLE=true
fi

# Step 1: Remove UFW rules
if [ "$UFW_AVAILABLE" = true ] && [ -f "${INSTALL_DIR}/ufw_rules.conf" ]; then
    echo "Removing UFW rules managed by this tool..."

    # Read each rule and delete it
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue

        # Parse rule: RULE_NAME|PROTO|PORT|HOSTNAME|COMMENT
        IFS='|' read -ra PARTS <<< "$line"

        local rule_name="${PARTS[0]:-}"
        local proto="${PARTS[1]:-}"
        local port="${PARTS[2]:-}"
        local hostname="${PARTS[3]:-}"
        local comment="${PARTS[4]:-}"

        if [[ -z "$hostname" ]]; then
            continue
        fi

        # Get cached IP
        cache_file="${INSTALL_DIR}/.cache/$(echo "$hostname" | sed 's/[^a-zA-Z0-9]/_/g').cache"

        if [[ -f "$cache_file" ]]; then
            cached_ip=$(cat "$cache_file")

            if [[ -n "$cached_ip" ]]; then
                # Try to delete the UFW rule
                if [[ -n "$port" ]]; then
                    if ufw delete allow from "$cached_ip" proto "$proto" to any port "$port" 2>/dev/null; then
                        echo "  ✓ Deleted UFW rule: from $cached_ip proto $proto port $port"
                    else
                        echo "  ℹ Rule not found (already deleted?): from $cached_ip proto $proto port $port"
                    fi
                else
                    if ufw delete allow from "$cached_ip" 2>/dev/null; then
                        echo "  ✓ Deleted UFW rule: from $cached_ip"
                    else
                        echo "  ℹ Rule not found (already deleted?): from $cached_ip"
                    fi
                fi
            fi
        else
            echo "  ℹ No cached IP for $hostname, skipping"
        fi
    done < "${INSTALL_DIR}/ufw_rules.conf"

    echo "✓ Firewall rules cleaned"
else
    echo "ℹ No rules configuration found or UFW not available, skipping firewall cleanup"
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
echo "  - All UFW rules managed by bash-ufw-ddns"
echo "  - Cron job for automatic updates"
echo "  - Installation directory: ${INSTALL_DIR}"
echo "  - Logs and cache files"
