#!/bin/bash
# Detect firewall type on all servers
# Outputs: ufw, plesk, iptables, or none

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load environment
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please copy .env.dist to .env and configure it"
    exit 1
fi

source "$ENV_FILE"

# Counters by type
UFW_COUNT=0
PLESK_COUNT=0
IPTABLES_COUNT=0
NONE_COUNT=0
FAILED_COUNT=0

# Arrays to track results
declare -a UFW_SERVERS
declare -a PLESK_SERVERS
declare -a IPTABLES_SERVERS
declare -a NONE_SERVERS
declare -a FAILED_SERVERS

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Firewall Detection Tool                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo

# Function to detect firewall on a single server
detect_firewall() {
    local server_info="$1"
    local hostname port user

    IFS=':' read -r hostname port user <<< "$server_info"

    # SSH options for non-interactive connection
    SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5"

    echo -e "${YELLOW}Checking ${hostname}:${port}...${NC}"

    # Check if server is reachable
    if ! timeout 10 ssh $SSH_OPTS -p "$port" "${user}@${hostname}" "echo 'OK'" > /dev/null 2>&1; then
        echo -e "${RED}  ✗ Cannot connect${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_SERVERS+=("${hostname}:${port}")
        echo
        return 1
    fi

    # Detect firewall type
    # Priority: 1. Plesk Firewall, 2. UFW, 3. iptables, 4. none
    local firewall_type="none"

    # Check for Plesk Firewall first (not just Plesk, but the Firewall module)
    if ssh $SSH_OPTS -p "$port" "${user}@${hostname}" "command -v plesk > /dev/null 2>&1 && plesk ext firewall --help > /dev/null 2>&1" 2>/dev/null; then
        firewall_type="plesk"
        echo -e "  ${CYAN}Firewall: Plesk Firewall${NC}"
        PLESK_COUNT=$((PLESK_COUNT + 1))
        PLESK_SERVERS+=("${hostname}:${port}:${user}")
    # Check for UFW (must be before iptables since ufw uses iptables)
    elif ssh $SSH_OPTS -p "$port" "${user}@${hostname}" "command -v ufw > /dev/null 2>&1" 2>/dev/null; then
        # UFW exists, now check if it's active
        local ufw_status=$(ssh $SSH_OPTS -p "$port" "${user}@${hostname}" "ufw status 2>/dev/null | head -1" 2>/dev/null)
        if echo "$ufw_status" | grep -qi "Status: active"; then
            firewall_type="ufw"
            echo -e "  ${GREEN}Firewall: UFW (active)${NC}"
            UFW_COUNT=$((UFW_COUNT + 1))
            UFW_SERVERS+=("${hostname}:${port}:${user}")
        else
            # UFW exists but not active, check iptables
            if ssh $SSH_OPTS -p "$port" "${user}@${hostname}" "command -v iptables > /dev/null 2>&1 && iptables -L -n | grep -q 'Chain'" 2>/dev/null; then
                firewall_type="iptables"
                echo -e "  ${GREEN}Firewall: iptables${NC}"
                IPTABLES_COUNT=$((IPTABLES_COUNT + 1))
                IPTABLES_SERVERS+=("${hostname}:${port}:${user}")
            else
                firewall_type="none"
                echo -e "  ${YELLOW}Firewall: UFW installed but inactive${NC}"
                NONE_COUNT=$((NONE_COUNT + 1))
                NONE_SERVERS+=("${hostname}:${port}:${user}")
            fi
        fi
    # Check for iptables
    elif ssh $SSH_OPTS -p "$port" "${user}@${hostname}" "command -v iptables > /dev/null 2>&1 && iptables -L -n | grep -q 'Chain'" 2>/dev/null; then
        firewall_type="iptables"
        echo -e "  ${GREEN}Firewall: iptables${NC}"
        IPTABLES_COUNT=$((IPTABLES_COUNT + 1))
        IPTABLES_SERVERS+=("${hostname}:${port}:${user}")
    else
        firewall_type="none"
        echo -e "  ${YELLOW}Firewall: none or unknown${NC}"
        NONE_COUNT=$((NONE_COUNT + 1))
        NONE_SERVERS+=("${hostname}:${port}:${user}")
    fi

    echo
}

# Run detection on all servers
for server in "${SERVERS[@]}"; do
    detect_firewall "$server"
done

# Summary
echo "========================================"
echo
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 Detection Summary                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "Total servers checked: $((UFW_COUNT + PLESK_COUNT + IPTABLES_COUNT + NONE_COUNT + FAILED_COUNT))"
echo
echo -e "${CYAN}Plesk Firewall:  ${PLESK_COUNT}${NC}"
echo -e "${GREEN}UFW:             ${UFW_COUNT}${NC}"
echo -e "${GREEN}iptables:        ${IPTABLES_COUNT}${NC}"
echo -e "${YELLOW}None/Unknown:    ${NONE_COUNT}${NC}"
echo -e "${RED}Failed:          ${FAILED_COUNT}${NC}"
echo

if [ ${#PLESK_SERVERS[@]} -gt 0 ]; then
    echo -e "${CYAN}Plesk Firewall servers:${NC}"
    for server in "${PLESK_SERVERS[@]}"; do
        echo -e "  ${CYAN}•${NC} $server"
    done
    echo
fi

if [ ${#UFW_SERVERS[@]} -gt 0 ]; then
    echo -e "${GREEN}UFW servers:${NC}"
    for server in "${UFW_SERVERS[@]}"; do
        echo -e "  ${GREEN}•${NC} $server"
    done
    echo
fi

if [ ${#IPTABLES_SERVERS[@]} -gt 0 ]; then
    echo -e "${GREEN}iptables servers:${NC}"
    for server in "${IPTABLES_SERVERS[@]}"; do
        echo -e "  ${GREEN}•${NC} $server"
    done
    echo
fi

if [ ${#NONE_SERVERS[@]} -gt 0 ]; then
    echo -e "${YELLOW}No firewall detected:${NC}"
    for server in "${NONE_SERVERS[@]}"; do
        echo -e "  ${YELLOW}•${NC} $server"
    done
    echo
fi

if [ ${#FAILED_SERVERS[@]} -gt 0 ]; then
    echo -e "${RED}Failed to connect:${NC}"
    for server in "${FAILED_SERVERS[@]}"; do
        echo -e "  ${RED}✗${NC} $server"
    done
    echo
fi

# Output machine-readable format
echo "========================================"
echo -e "${BLUE}Machine-readable output:${NC}"
echo
echo "# Format: hostname:port:user:firewall_type"
for server in "${PLESK_SERVERS[@]}"; do
    echo "${server}:plesk"
done
for server in "${UFW_SERVERS[@]}"; do
    echo "${server}:ufw"
done
for server in "${IPTABLES_SERVERS[@]}"; do
    echo "${server}:iptables"
done
for server in "${NONE_SERVERS[@]}"; do
    echo "${server}:none"
done
