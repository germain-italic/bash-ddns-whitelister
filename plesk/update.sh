#!/bin/bash
#
# update.sh
# Automatic Plesk Firewall rules updater for dynamic hostnames
# Run as root via cron (ex: */5 * * * *)
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration files
ENV_FILE="${SCRIPT_DIR}/.env"
RULES_FILE="${SCRIPT_DIR}/firewall_rules.conf"
CACHE_DIR="${SCRIPT_DIR}/.cache"
LOG_FILE="${SCRIPT_DIR}/update.log"

# Load environment variables
if [[ ! -f "$ENV_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: .env file not found: $ENV_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

source "$ENV_FILE"

# Check rules file exists
if [[ ! -f "$RULES_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Rules file not found: $RULES_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

# Create cache directory if needed
mkdir -p "$CACHE_DIR"

# Check if Plesk firewall extension is available
if ! command -v plesk &> /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Plesk command not found. This script requires Plesk." | tee -a "$LOG_FILE"
    exit 1
fi

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Rotate logs based on LOG_ROTATION_HOURS
rotate_logs() {
    local rotation_hours="${LOG_ROTATION_HOURS:-168}"

    if [[ -f "$LOG_FILE" ]]; then
        local cutoff_timestamp=$(date -d "$rotation_hours hours ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-${rotation_hours}H '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")

        if [[ -n "$cutoff_timestamp" ]]; then
            local temp_log="${LOG_FILE}.tmp"
            grep -E "^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]" "$LOG_FILE" | \
                awk -v cutoff="$cutoff_timestamp" '$0 >= "["cutoff"]"' > "$temp_log" 2>/dev/null || true

            if [[ -s "$temp_log" ]]; then
                mv "$temp_log" "$LOG_FILE"
            else
                rm -f "$temp_log"
            fi
        fi
    fi
}

# Resolve hostname to IP
resolve_hostname() {
    local hostname="$1"
    local nameserver="${DNS_NAMESERVER:-1.1.1.1}"

    if command -v dig &> /dev/null; then
        dig +short "@$nameserver" "$hostname" A | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1
    elif command -v host &> /dev/null; then
        host "$hostname" "$nameserver" | grep "has address" | awk '{print $4}' | head -n1
    else
        getent hosts "$hostname" | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1
    fi
}

# Get cached IP
get_cached_ip() {
    local hostname="$1"
    local cache_file="$CACHE_DIR/$(echo "$hostname" | sed 's/[^a-zA-Z0-9]/_/g').cache"

    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
    else
        echo ""
    fi
}

# Cache IP
cache_ip() {
    local hostname="$1"
    local ip="$2"
    local cache_file="$CACHE_DIR/$(echo "$hostname" | sed 's/[^a-zA-Z0-9]/_/g').cache"

    echo "$ip" > "$cache_file"
}

# Get Plesk firewall rule ID by name
get_rule_id() {
    local rule_name="$1"
    plesk ext firewall --list-json 2>/dev/null | \
        python3 -c "import sys, json; rules = json.load(sys.stdin); print(next((r['id'] for r in rules if r['name'] == '${rule_name}'), ''))"
}

# Create or update Plesk firewall rule
update_plesk_rule() {
    local rule_name="$1"
    local direction="$2"
    local action="$3"
    local ports="$4"
    local ip="$5"
    local comment="${6:-}"

    log "Updating Plesk firewall rule: $rule_name for IP $ip"

    # Check if rule already exists
    local rule_id=$(get_rule_id "$rule_name")

    # Build the command
    local cmd="plesk ext firewall --set-rule"

    if [[ -n "$rule_id" ]]; then
        # Update existing rule by ID
        cmd="$cmd -id $rule_id"
        log "Updating existing rule (ID: $rule_id)"
    else
        # Create new rule by name
        cmd="$cmd -name '$rule_name'"
        log "Creating new rule"
    fi

    cmd="$cmd -direction $direction -action $action"

    if [[ -n "$ports" ]]; then
        cmd="$cmd -ports '$ports'"
    fi

    if [[ -n "$ip" ]]; then
        cmd="$cmd -remote-addresses '$ip'"
    fi

    # Execute command and capture output
    local output=$(eval "$cmd" 2>&1)
    echo "$output" >> "$LOG_FILE"

    # Check if rule was created or updated successfully
    if echo "$output" | grep -q "was created\|was updated"; then
        log "Rule created/updated successfully: $rule_name"
        return 0
    else
        log "ERROR: Failed to create/update rule: $rule_name"
        log "Output: $output"
        return 1
    fi
}

# Apply Plesk firewall changes
apply_and_confirm() {
    log "Applying Plesk firewall changes with auto-confirm..."

    # Apply changes with auto-confirm option
    # This is safer for automated scripts as it doesn't require a second SSH session
    local output=$(plesk ext firewall --apply -auto-confirm-this-may-lock-me-out-of-the-server 2>&1)
    echo "$output" >> "$LOG_FILE"

    if echo "$output" | grep -q "were applied\|was applied\|were confirmed\|was confirmed"; then
        log "Firewall changes applied and confirmed successfully"
        return 0
    else
        log "WARNING: Firewall apply output unclear"
        log "Output: $output"
        return 0
    fi
}

# Main update function
update_rules() {
    local updated=0
    local rules_to_apply=()

    # Read rules file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue

        # Parse rule configuration
        # Format: RULE_NAME|DIRECTION|ACTION|PORTS|HOSTNAME|COMMENT
        IFS='|' read -r rule_name direction action ports hostname comment <<< "$line"

        # Trim whitespace
        rule_name=$(echo "$rule_name" | xargs)
        direction=$(echo "$direction" | xargs)
        action=$(echo "$action" | xargs)
        ports=$(echo "$ports" | xargs)
        hostname=$(echo "$hostname" | xargs)
        comment=$(echo "$comment" | xargs)

        # Validate required fields
        if [[ -z "$rule_name" ]] || [[ -z "$direction" ]] || [[ -z "$action" ]] || [[ -z "$hostname" ]]; then
            log "WARNING: Invalid rule format, skipping: $line"
            continue
        fi

        # Resolve hostname to IP
        local current_ip=$(resolve_hostname "$hostname")

        if [[ -z "$current_ip" ]]; then
            log "WARNING: Cannot resolve $hostname for rule $rule_name"
            continue
        fi

        # Check if IP has changed
        local cached_ip=$(get_cached_ip "$hostname")

        if [[ "$current_ip" != "$cached_ip" ]]; then
            log "IP change detected for $hostname: $cached_ip -> $current_ip"

            # Update the rule
            if update_plesk_rule "$rule_name" "$direction" "$action" "$ports" "$current_ip" "$comment"; then
                cache_ip "$hostname" "$current_ip"
                updated=$((updated + 1))
                rules_to_apply+=("$rule_name")
            fi
        fi

    done < "$RULES_FILE"

    # Apply firewall changes if any rules were updated
    if [[ $updated -gt 0 ]]; then
        log "Total rules updated: $updated"
        if apply_and_confirm; then
            log "Firewall apply completed successfully"
        else
            log "WARNING: Firewall apply may have failed"
        fi
    else
        log "No rules updated (no IP changes detected)"
    fi
}

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Main execution
rotate_logs
log "Starting Plesk firewall rules update"
update_rules
log "Update finished"
