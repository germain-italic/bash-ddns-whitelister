#!/bin/bash
# Re-deploy bash-ddns-whitelister firewall scripts to all servers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found at $ENV_FILE"
    echo "Please copy .env.dist to .env and configure your servers"
    exit 1
fi

# Source the .env file to get SERVERS array
source "$ENV_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Re-deploying firewall scripts to all servers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for server in "${SERVERS[@]}"; do
    IFS=':' read -ra PARTS <<< "$server"

    host="${PARTS[0]}"
    port="${PARTS[1]}"
    user="${PARTS[2]}"
    fw="${PARTS[3]}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📡 $host ($fw)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    cd "$REPO_DIR/$fw"

    if ./deploy.sh "$host" "$port" "$user"; then
        echo "✅ Deployed successfully"
    else
        echo "❌ Deployment failed"
    fi

    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All deployments completed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
