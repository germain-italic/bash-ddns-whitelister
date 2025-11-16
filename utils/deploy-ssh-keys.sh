#!/bin/bash
# Deploy SSH public keys to all servers
# Deploys both local SSH key and NAS SSH key

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please copy .env.dist to .env and configure it"
    exit 1
fi

source "$ENV_FILE"

# Counters
TOTAL=0
SUCCESS=0
FAILED=0
ALREADY_INSTALLED=0

# Arrays to track results
declare -a FAILED_SERVERS
declare -a SUCCESS_SERVERS
declare -a ALREADY_INSTALLED_SERVERS

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Deploy SSH Keys to All Servers                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo

# Parse command line arguments
DRY_RUN=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=1
            echo -e "${YELLOW}DRY RUN MODE: No actual deployment will be performed${NC}"
            echo
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Function to deploy keys to a single server
deploy_keys() {
    local server_info="$1"
    local hostname port user

    IFS=':' read -r hostname port user <<< "$server_info"

    TOTAL=$((TOTAL + 1))

    echo -e "${YELLOW}[$TOTAL] Deploying to ${hostname}:${port} (${user})...${NC}"

    if [ $DRY_RUN -eq 1 ]; then
        echo -e "${BLUE}  Would deploy keys to ${user}@${hostname}:${port}${NC}"
        SUCCESS=$((SUCCESS + 1))
        return 0
    fi

    # SSH options for non-interactive connection
    SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5"

    # Check if server is reachable
    if ! timeout 10 ssh $SSH_OPTS -p "$port" "${user}@${hostname}" "echo 'OK'" > /dev/null 2>&1; then
        echo -e "${RED}✗ Cannot connect to ${hostname}${NC}"
        FAILED=$((FAILED + 1))
        FAILED_SERVERS+=("${hostname}:${port} (connection failed)")
        return 1
    fi

    # Check if keys are already installed
    local nas_key_exists=$(ssh $SSH_OPTS -p "$port" "${user}@${hostname}" "grep -q '${NAS1_PUBKEY}' ~/.ssh/authorized_keys 2>/dev/null && echo 'yes' || echo 'no'")
    local local_key_exists=$(ssh $SSH_OPTS -p "$port" "${user}@${hostname}" "grep -q '${LOCAL_SSH_PUBKEY}' ~/.ssh/authorized_keys 2>/dev/null && echo 'yes' || echo 'no'")

    if [[ "$nas_key_exists" == "yes" ]] && [[ "$local_key_exists" == "yes" ]]; then
        echo -e "${BLUE}⊙ Keys already installed on ${hostname}${NC}"
        ALREADY_INSTALLED=$((ALREADY_INSTALLED + 1))
        ALREADY_INSTALLED_SERVERS+=("${hostname}:${port}")
        return 0
    fi

    # Deploy the keys
    if ssh $SSH_OPTS -p "$port" "${user}@${hostname}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
        echo '${NAS1_PUBKEY}' >> ~/.ssh/authorized_keys && \
        echo '${LOCAL_SSH_PUBKEY}' >> ~/.ssh/authorized_keys && \
        chmod 600 ~/.ssh/authorized_keys && \
        sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys"; then
        echo -e "${GREEN}✓ Keys deployed successfully to ${hostname}${NC}"
        SUCCESS=$((SUCCESS + 1))
        SUCCESS_SERVERS+=("${hostname}:${port}")
    else
        echo -e "${RED}✗ Failed to deploy keys to ${hostname}${NC}"
        FAILED=$((FAILED + 1))
        FAILED_SERVERS+=("${hostname}:${port} (deployment failed)")
    fi

    echo
}

# Deploy to all servers
echo -e "${YELLOW}Starting deployment...${NC}"
echo "========================================"
echo

for server in "${SERVERS[@]}"; do
    # Skip if marked as SKIP
    if [[ "$server" == *":SKIP" ]]; then
        echo -e "${BLUE}Skipping $(echo $server | cut -d: -f1)${NC}"
        continue
    fi
    deploy_keys "$server"
done

# Summary
echo "========================================"
echo
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 Deployment Summary                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "Total servers:        ${TOTAL}"
echo -e "${GREEN}Newly deployed:       ${SUCCESS}${NC}"
echo -e "${BLUE}Already installed:    ${ALREADY_INSTALLED}${NC}"
echo -e "${RED}Failed:               ${FAILED}${NC}"
echo

if [ ${#SUCCESS_SERVERS[@]} -gt 0 ]; then
    echo -e "${GREEN}Successfully deployed:${NC}"
    for server in "${SUCCESS_SERVERS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $server"
    done
    echo
fi

if [ ${#ALREADY_INSTALLED_SERVERS[@]} -gt 0 ]; then
    echo -e "${BLUE}Already installed:${NC}"
    for server in "${ALREADY_INSTALLED_SERVERS[@]}"; do
        echo -e "  ${BLUE}⊙${NC} $server"
    done
    echo
fi

if [ ${#FAILED_SERVERS[@]} -gt 0 ]; then
    echo -e "${RED}Failed deployments:${NC}"
    for server in "${FAILED_SERVERS[@]}"; do
        echo -e "  ${RED}✗${NC} $server"
    done
    echo
fi

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}SSH key deployment completed!${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${RED}Some deployments failed!${NC}"
    echo -e "${RED}════════════════════════════════════════${NC}"
    exit 1
fi
