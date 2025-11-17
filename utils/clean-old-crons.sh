#!/bin/bash
# Clean old cron entries referencing old repo names
# Removes cron lines with: bash-iptables-ddns, bash-ufw-ddns, bash-plesk-ddns, bash-utils-ddns

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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 Cleaning old cron entries from all servers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Process each server
for server in "${SERVERS[@]}"; do
    IFS=':' read -ra PARTS <<< "$server"

    host="${PARTS[0]:-}"
    port="${PARTS[1]:-22}"
    user="${PARTS[2]:-root}"
    skip="${PARTS[4]:-}"

    if [[ "$skip" == "SKIP" ]]; then
        continue
    fi

    echo "📡 $host"

    # Remove old cron entries
    ssh -p "$port" "${user}@${host}" '
        TMPFILE=$(mktemp)
        crontab -l 2>/dev/null > "$TMPFILE" || echo "" > "$TMPFILE"

        # Count old entries
        OLD_COUNT=$(grep -cE "bash-(iptables|ufw|plesk|utils)-ddns" "$TMPFILE" || echo "0")

        if [[ "$OLD_COUNT" -gt 0 ]]; then
            # Remove old entries
            grep -vE "bash-(iptables|ufw|plesk|utils)-ddns" "$TMPFILE" > "${TMPFILE}.new" || echo "" > "${TMPFILE}.new"
            crontab "${TMPFILE}.new"
            rm -f "$TMPFILE" "${TMPFILE}.new"
            echo "  ✅ Removed $OLD_COUNT old cron entry/entries"
        else
            rm -f "$TMPFILE"
            echo "  ✓ No old cron entries"
        fi
    ' 2>&1 || echo "  ❌ Failed to clean cron on $host"

done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cron cleanup completed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
