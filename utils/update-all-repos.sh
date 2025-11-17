#!/bin/bash
# Update bash-ddns-whitelister repo on all servers and clean old repos
# This script:
# 1. Pulls latest changes in bash-ddns-whitelister
# 2. Removes old repo directories (bash-iptables-ddns, bash-ufw-ddns, bash-plesk-ddns, bash-utils-ddns)
# 3. Checks and cleans old cron entries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

# Source the .env file
source "$ENV_FILE"

# Old repo names to remove
OLD_REPOS=(
    "bash-iptables-ddns"
    "bash-ufw-ddns"
    "bash-plesk-ddns"
    "bash-utils-ddns"
)

# Process each server
for server in "${SERVERS[@]}"; do
    IFS=':' read -ra PARTS <<< "$server"

    host="${PARTS[0]:-}"
    port="${PARTS[1]:-22}"
    user="${PARTS[2]:-root}"
    firewall_type="${PARTS[3]:-}"
    skip="${PARTS[4]:-}"

    if [[ "$skip" == "SKIP" ]]; then
        echo "⏭️  Skipping $host (marked as SKIP)"
        continue
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📡 Processing: $host"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Pull latest changes in bash-ddns-whitelister
    echo "🔄 Pulling latest changes..."
    ssh -p "$port" "${user}@${host}" '
        if [[ -d /root/bash-ddns-whitelister ]]; then
            cd /root/bash-ddns-whitelister
            git pull
            echo "✅ Pulled latest changes"
        else
            echo "⚠️  /root/bash-ddns-whitelister not found"
        fi
    ' 2>&1 || echo "❌ Failed to pull on $host"

    # Remove old repos
    echo "🗑️  Removing old repos..."
    for old_repo in "${OLD_REPOS[@]}"; do
        ssh -p "$port" "${user}@${host}" "
            if [[ -d /root/${old_repo} ]]; then
                rm -rf /root/${old_repo}
                echo \"  ✅ Removed ${old_repo}\"
            fi
        " 2>&1 || echo "  ⚠️  Failed to remove ${old_repo} on $host"
    done

    # Check crontab for old references
    echo "🔍 Checking crontab for old repo references..."
    ssh -p "$port" "${user}@${host}" '
        crontab -l 2>/dev/null | grep -E "bash-(iptables|ufw|plesk|utils)-ddns" || echo "  ✅ No old cron entries found"
    ' 2>&1 || true

    # Show current crontab with bash-ddns-whitelister
    echo "📋 Current bash-ddns-whitelister cron entries:"
    ssh -p "$port" "${user}@${host}" '
        crontab -l 2>/dev/null | grep "bash-ddns-whitelister" || echo "  ⚠️  No bash-ddns-whitelister cron entries"
    ' 2>&1 || true

    echo "✅ Completed: $host"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All servers processed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
