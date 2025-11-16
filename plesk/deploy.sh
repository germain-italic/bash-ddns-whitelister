#!/bin/bash
# Deployment script for bash-plesk-firewall-ddns
# Usage: ./deploy.sh <hostname> [ssh_port] [ssh_user]

set -e

HOSTNAME="$1"
SSH_PORT="${2:-22}"
SSH_USER="${3:-root}"
INSTALL_DIR="/root/bash-plesk-firewall-ddns"
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

echo -e "${GREEN}=== Deploying bash-plesk-firewall-ddns to ${HOSTNAME} ===${NC}"
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

# Check if Plesk is installed
echo -e "${YELLOW}Checking for Plesk installation...${NC}"
if ! ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" "command -v plesk" > /dev/null 2>&1; then
    echo -e "${RED}Error: Plesk not found on ${HOSTNAME}${NC}"
    echo "This script is for Plesk servers only."
    exit 1
fi
echo -e "${GREEN}✓ Plesk detected${NC}"
echo

# Clone or update repository
echo -e "${YELLOW}Installing repository...${NC}"
ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" bash << 'ENDSSH'
set -e
INSTALL_DIR="/root/bash-plesk-firewall-ddns"
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
INSTALL_DIR="/root/bash-plesk-firewall-ddns"
cd "${INSTALL_DIR}"

if [ ! -f ".env" ]; then
    echo "Creating .env from template..."
    cat > .env << 'EOF'
# Configuration for update.sh

# DNS nameserver for hostname resolution
DNS_NAMESERVER=1.1.1.1

# Log rotation (keep logs older than N hours)
LOG_ROTATION_HOURS=168
EOF
else
    echo ".env already exists, skipping"
fi
ENDSSH
echo -e "${GREEN}✓ .env configured${NC}"
echo

# Configure firewall_rules.conf if not exists
echo -e "${YELLOW}Configuring firewall_rules.conf...${NC}"
ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" bash << 'ENDSSH'
set -e
INSTALL_DIR="/root/bash-plesk-firewall-ddns"
cd "${INSTALL_DIR}"

if [ ! -f "firewall_rules.conf" ]; then
    echo "Creating firewall_rules.conf..."
    cat > firewall_rules.conf << 'EOF'
# Plesk Firewall rules configuration with dynamic hostnames
# Format: RULE_NAME|DIRECTION|ACTION|PORTS|HOSTNAME|COMMENT

# Allow all traffic from NAS1 (dynamic IP)
nas1-all|input|allow||nas1.example.com|Allow all from NAS1
EOF
else
    echo "firewall_rules.conf already exists, skipping"
fi
ENDSSH
echo -e "${GREEN}✓ firewall_rules.conf configured${NC}"
echo

# Setup cron job
echo -e "${YELLOW}Setting up cron job...${NC}"
ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" bash << 'ENDSSH'
set -e
INSTALL_DIR="/root/bash-plesk-firewall-ddns"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "${INSTALL_DIR}/update.sh"; then
    echo "Cron job already exists, skipping"
else
    echo "Adding cron job..."
    (crontab -l 2>/dev/null || true; echo "*/5 * * * * ${INSTALL_DIR}/update.sh >> ${INSTALL_DIR}/cron.log 2>&1") | crontab -
fi
ENDSSH
echo -e "${GREEN}✓ Cron job configured${NC}"
echo

# Run initial update
echo -e "${YELLOW}Running initial update...${NC}"
ssh -p "${SSH_PORT}" "${SSH_USER}@${HOSTNAME}" bash << 'ENDSSH'
set -e
INSTALL_DIR="/root/bash-plesk-firewall-ddns"
cd "${INSTALL_DIR}"
./update.sh
ENDSSH
echo -e "${GREEN}✓ Initial update completed${NC}"
echo

echo -e "${GREEN}=== Deployment completed successfully ===${NC}"
echo
echo "You can check the logs with:"
echo "  ssh -p ${SSH_PORT} ${SSH_USER}@${HOSTNAME} 'tail -f ${INSTALL_DIR}/update.log'"
