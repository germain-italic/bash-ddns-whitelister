#!/bin/bash
# Deployment script for Windows Firewall DDNS updater
# Deploys PowerShell scripts to remote Windows Server via SSH

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
SSH_HOST="${1:-}"
SSH_PORT="${2:-22}"
SSH_USER="${3:-Administrator}"
INSTALL_DIR="C:\\bash-windows-firewall-ddns"

# Check arguments
if [ -z "$SSH_HOST" ]; then
    echo -e "${RED}Usage: $0 <hostname> [port] [user]${NC}"
    echo "Example: $0 windows-server.example.com 22 Administrator"
    exit 1
fi

echo -e "${GREEN}=== Deploying bash-windows-firewall-ddns to $SSH_HOST ===${NC}"
echo "SSH: $SSH_USER@$SSH_HOST:$SSH_PORT"
echo "Install directory: $INSTALL_DIR"
echo ""

# Test SSH connection
echo -e "${YELLOW}Testing SSH connection...${NC}"
if ! ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER@$SSH_HOST" "exit" 2>/dev/null; then
    echo -e "${RED}Error: Cannot connect to $SSH_HOST${NC}"
    echo "Please ensure:"
    echo "  1. SSH server (OpenSSH) is installed on Windows Server"
    echo "  2. SSH keys are deployed"
    echo "  3. Firewall allows SSH connections"
    exit 1
fi

echo -e "${GREEN}SSH connection successful${NC}"
echo ""

# Check if PowerShell is available
echo -e "${YELLOW}Checking PowerShell availability...${NC}"
if ! ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "powershell -Command \"Write-Output 'OK'\"" 2>/dev/null | grep -q "OK"; then
    echo -e "${RED}Error: PowerShell not available on remote host${NC}"
    exit 1
fi

echo -e "${GREEN}PowerShell available${NC}"
echo ""

# Check if running as Administrator
echo -e "${YELLOW}Checking Administrator privileges...${NC}"
IS_ADMIN=$(ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "powershell -Command \"([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)\"" 2>/dev/null || echo "False")

if [[ "$IS_ADMIN" != *"True"* ]]; then
    echo -e "${YELLOW}Warning: Remote user may not have Administrator privileges${NC}"
    echo "Windows Firewall management requires Administrator access"
fi

# Create installation directory
echo -e "${YELLOW}Creating installation directory...${NC}"
ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "powershell -Command \"New-Item -ItemType Directory -Force -Path '$INSTALL_DIR' | Out-Null\""

# Copy PowerShell script
echo -e "${YELLOW}Copying update.ps1...${NC}"
scp -P "$SSH_PORT" "$(dirname "$0")/update.ps1" "$SSH_USER@$SSH_HOST:$INSTALL_DIR/update.ps1"

# Copy .env if it exists, otherwise copy .env.dist
if [ -f "$(dirname "$0")/.env" ]; then
    echo -e "${YELLOW}Copying .env configuration...${NC}"
    scp -P "$SSH_PORT" "$(dirname "$0")/.env" "$SSH_USER@$SSH_HOST:$INSTALL_DIR/.env"
else
    echo -e "${YELLOW}Copying .env.dist template...${NC}"
    scp -P "$SSH_PORT" "$(dirname "$0")/.env.dist" "$SSH_USER@$SSH_HOST:$INSTALL_DIR/.env"
    echo -e "${YELLOW}WARNING: .env.dist copied - you must configure it!${NC}"
fi

# Copy firewall_rules.conf if it exists, otherwise copy template
if [ -f "$(dirname "$0")/firewall_rules.conf" ]; then
    echo -e "${YELLOW}Copying firewall_rules.conf...${NC}"
    scp -P "$SSH_PORT" "$(dirname "$0")/firewall_rules.conf" "$SSH_USER@$SSH_HOST:$INSTALL_DIR/firewall_rules.conf"
else
    echo -e "${YELLOW}Copying firewall_rules.conf.dist template...${NC}"
    scp -P "$SSH_PORT" "$(dirname "$0")/firewall_rules.conf.dist" "$SSH_USER@$SSH_HOST:$INSTALL_DIR/firewall_rules.conf"
    echo -e "${YELLOW}WARNING: firewall_rules.conf.dist copied - you must configure it!${NC}"
fi

# Test the update script
echo ""
echo -e "${YELLOW}Testing update script...${NC}"
if ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "powershell -ExecutionPolicy Bypass -File '$INSTALL_DIR\\update.ps1'" 2>&1 | tail -10; then
    echo -e "${GREEN}Update script executed successfully${NC}"
else
    echo -e "${RED}Warning: Update script test failed${NC}"
fi

# Setup scheduled task
echo ""
echo -e "${YELLOW}Setting up scheduled task...${NC}"

TASK_SCRIPT=$(cat <<'EOFTASK'
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File 'INSTALL_DIR\update.ps1'"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1) -RestartCount 3

# Remove old task if exists
Unregister-ScheduledTask -TaskName "WindowsFirewallDDNS" -Confirm:$false -ErrorAction SilentlyContinue

# Register new task
Register-ScheduledTask -TaskName "WindowsFirewallDDNS" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Update Windows Firewall rules for dynamic DNS hostnames"

Write-Output "Scheduled task created successfully"
EOFTASK
)

# Replace INSTALL_DIR placeholder
TASK_SCRIPT="${TASK_SCRIPT//INSTALL_DIR/$INSTALL_DIR}"

if ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "powershell -Command \"$TASK_SCRIPT\"" 2>&1 | grep -q "successfully"; then
    echo -e "${GREEN}Scheduled task configured (runs every 5 minutes)${NC}"
else
    echo -e "${YELLOW}Warning: Could not create scheduled task${NC}"
    echo "You may need to create it manually with Administrator privileges"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Configure $INSTALL_DIR\\.env with DNS settings"
echo "  2. Configure $INSTALL_DIR\\firewall_rules.conf with your rules"
echo "  3. Verify scheduled task: Get-ScheduledTask -TaskName 'WindowsFirewallDDNS'"
echo "  4. Check logs: Get-Content $INSTALL_DIR\\update.log"
echo ""
