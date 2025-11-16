#!/bin/bash
# Deployment script for bash-iptables-ddns
# Usage: ./deploy.sh <hostname> [ssh_port] [ssh_user]

set -e

HOSTNAME="$1"
SSH_PORT="${2:-22}"
SSH_USER="${3:-root}"
INSTALL_DIR="/root/bash-iptables-ddns"
REPO_URL="https://github.com/germain-italic/bash-ddns-whitelister"

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

echo -e "${GREEN}=== Deploying bash-iptables-ddns to ${HOSTNAME} ===${NC}"
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

# Clone or update repository
echo -e "${YELLOW}Installing repository...${NC}"
ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" bash << 'ENDSSH'
set -e
INSTALL_DIR="/root/bash-iptables-ddns"
REPO_URL="https://github.com/germain-italic/bash-ddns-whitelister"

if [ -d "${INSTALL_DIR}" ]; then
    echo "Directory exists, pulling latest changes..."
    cd "${INSTALL_DIR}"
    git pull
else
    echo "Cloning repository..."
    git clone "${REPO_URL}" "${INSTALL_DIR}"
fi
ENDSSH
echo -e "${GREEN}✓ Repository installed${NC}"
echo

# Configure .env if not exists
echo -e "${YELLOW}Configuring .env...${NC}"
ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" bash << 'ENDSSH'
set -e
INSTALL_DIR="/root/bash-iptables-ddns"
cd "${INSTALL_DIR}/iptables"

if [ ! -f ".env" ]; then
    echo "Creating .env from template..."
    cat > .env << 'EOF'
# Configuration for update.sh

# DNS nameserver for hostname resolution
DNS_NAMESERVER=1.1.1.1

# Log rotation (keep logs older than N hours)
LOG_ROTATION_HOURS=168

# Dynamic hostnames to monitor (optional, for reference only)
# Script automatically detects hostnames in rules
NAS1_HOSTNAME=nas1.example.com
NAS2_HOSTNAME=nas2.example.com
EOF
else
    echo ".env already exists, skipping"
fi
ENDSSH
echo -e "${GREEN}✓ .env configured${NC}"
echo

# Configure dyndns_rules.conf if not exists
echo -e "${YELLOW}Configuring dyndns_rules.conf...${NC}"
ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" bash << 'ENDSSH'
set -e
INSTALL_DIR="/root/bash-iptables-ddns"
cd "${INSTALL_DIR}/iptables"

if [ ! -f "dyndns_rules.conf" ]; then
    echo "Creating dyndns_rules.conf..."
    cat > dyndns_rules.conf << 'EOF'
# iptables rules configuration with dynamic hostnames
# Format: standard iptables rules (like iptables -S output)
# Hostnames will be automatically resolved and updated

# Allow all traffic from NAS1 (dynamic IP)
-A INPUT -s nas1.example.com -j ACCEPT
EOF
else
    echo "dyndns_rules.conf already exists, skipping"
fi
ENDSSH
echo -e "${GREEN}✓ dyndns_rules.conf configured${NC}"
echo

# Setup cron job
echo -e "${YELLOW}Setting up cron job...${NC}"
ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" bash << 'ENDSSH'
set -e
INSTALL_DIR="/root/bash-iptables-ddns"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "${INSTALL_DIR}/iptables/update.sh"; then
    echo "Cron job already exists, skipping"
else
    echo "Adding cron job..."
    (crontab -l 2>/dev/null || true; echo "*/5 * * * * ${INSTALL_DIR}/iptables/update.sh >> ${INSTALL_DIR}/iptables/cron.log 2>&1") | crontab -
fi
ENDSSH
echo -e "${GREEN}✓ Cron job configured${NC}"
echo

# Run initial update
echo -e "${YELLOW}Running initial update...${NC}"
ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" bash << 'ENDSSH'
set -e
INSTALL_DIR="/root/bash-iptables-ddns"
cd "${INSTALL_DIR}/iptables"
./update.sh
ENDSSH
echo -e "${GREEN}✓ Initial update completed${NC}"
echo

echo -e "${GREEN}=== Deployment completed successfully ===${NC}"
echo
echo "You can check the logs with:"
echo "  ssh -p ${SSH_PORT} ${SSH_USER}@${HOSTNAME} 'tail -f ${INSTALL_DIR}/iptables/update.log'"
