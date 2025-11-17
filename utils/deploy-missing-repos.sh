#!/bin/bash
# Deploy bash-ddns-whitelister on servers that don't have it yet

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

# Source the .env file
source "$ENV_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Deploying bash-ddns-whitelister to missing servers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Process each server
for server in "${SERVERS[@]}"; do
    IFS=':' read -ra PARTS <<< "$server"

    host="${PARTS[0]:-}"
    port="${PARTS[1]:-22}"
    user="${PARTS[2]:-root}"
    firewall_type="${PARTS[3]:-}"
    skip="${PARTS[4]:-}"

    if [[ "$skip" == "SKIP" ]]; then
        continue
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📡 Processing: $host (firewall: $firewall_type)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check if repo already exists
    REPO_EXISTS=$(ssh -p "$port" "${user}@${host}" "[ -d /root/bash-ddns-whitelister ] && echo 'yes' || echo 'no'" 2>/dev/null || echo "no")

    if [[ "$REPO_EXISTS" == "yes" ]]; then
        echo "✓ Repository already exists, pulling latest..."
        ssh -p "$port" "${user}@${host}" "cd /root/bash-ddns-whitelister && git pull" 2>&1 || echo "⚠️ Pull failed"
    else
        echo "📥 Cloning repository..."
        ssh -p "$port" "${user}@${host}" "cd /root && git clone https://github.com/germain-italic/bash-ddns-whitelister.git" 2>&1 || {
            echo "❌ Failed to clone on $host"
            continue
        }
        echo "✅ Repository cloned"
    fi

    # Now deploy the appropriate firewall script based on type
    case "$firewall_type" in
        iptables)
            echo "🔧 Deploying iptables script..."
            ssh -p "$port" "${user}@${host}" "cd /root/bash-ddns-whitelister/iptables && ./deploy.sh localhost $port $user" 2>&1 || echo "⚠️ Deployment failed"
            ;;
        ufw)
            echo "🔧 Deploying UFW script..."
            ssh -p "$port" "${user}@${host}" "cd /root/bash-ddns-whitelister/ufw && ./deploy.sh localhost $port $user" 2>&1 || echo "⚠️ Deployment failed"
            ;;
        plesk)
            echo "🔧 Deploying Plesk script..."
            ssh -p "$port" "${user}@${host}" "cd /root/bash-ddns-whitelister/plesk && ./deploy.sh localhost $port $user" 2>&1 || echo "⚠️ Deployment failed"
            ;;
        none)
            echo "ℹ️ No firewall type specified, skipping deployment"
            ;;
        *)
            echo "⚠️ Unknown firewall type: $firewall_type"
            ;;
    esac

    echo "✅ Completed: $host"
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Deployment completed on all servers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
