#!/bin/bash
#
# update.sh
# Automatic iptables rules updater for dynamic hostnames
# Run as root via cron (ex: */5 * * * *)
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration files
ENV_FILE="${SCRIPT_DIR}/.env"
RULES_FILE="${SCRIPT_DIR}/dyndns_rules.conf"
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

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Rotate logs based on LOG_ROTATION_HOURS
rotate_logs() {
    local rotation_hours="${LOG_ROTATION_HOURS:-168}"

    if [[ -f "$LOG_FILE" ]]; then
        # Find lines older than rotation_hours
        local cutoff_timestamp=$(date -d "$rotation_hours hours ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-${rotation_hours}H '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")

        if [[ -n "$cutoff_timestamp" ]]; then
            # Create temp file with recent logs only
            local temp_log="${LOG_FILE}.tmp"
            grep -E "^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]" "$LOG_FILE" | \
                awk -v cutoff="$cutoff_timestamp" '$0 >= "["cutoff"]"' > "$temp_log" 2>/dev/null || true

            # Replace log file if temp file is not empty
            if [[ -s "$temp_log" ]]; then
                mv "$temp_log" "$LOG_FILE"
            else
                rm -f "$temp_log"
            fi
        fi
    fi
}

# Validate IPv4 address format
validate_ipv4() {
    local ip=$1

    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ $octet -gt 255 ]]; then
                return 1  # Invalid: octet > 255
            fi
        done
        return 0  # Valid IP
    else
        return 1  # Invalid format
    fi
}

# Resolve hostname to IP
resolve_hostname() {
    local hostname="$1"
    local nameserver="${DNS_NAMESERVER:-1.1.1.1}"
    local ip

    # DNS resolution with dig or host fallback
    if command -v dig &> /dev/null; then
        ip=$(dig +short "@$nameserver" "$hostname" A | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
    elif command -v host &> /dev/null; then
        ip=$(host "$hostname" "$nameserver" | grep "has address" | awk '{print $4}' | head -n1)
    else
        ip=$(getent hosts "$hostname" | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
    fi

    # Validate IP format
    if [[ -n "$ip" ]] && validate_ipv4 "$ip"; then
        echo "$ip"
    else
        echo ""
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

# Extract hostnames from iptables rule
extract_hostnames() {
    local rule="$1"
    # Search for patterns that look like hostnames (contain dot and letters)
    grep -oE '[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+' <<< "$rule" || true
}

# Replace hostname with IP in rule
replace_hostname_with_ip() {
    local rule="$1"
    local hostname="$2"
    local ip="$3"

    # Escape special regex characters in hostname for safe sed replacement
    local escaped_hostname=$(printf '%s\n' "$hostname" | sed 's/[.[\*^$()+?{|]/\\&/g')

    echo "$rule" | sed "s/$escaped_hostname/$ip/g"
}

# Apply iptables rule
apply_rule() {
    local rule="$1"
    local action="$2"  # "add" or "delete"

    # Validate rule doesn't contain dangerous characters
    if [[ "$rule" =~ [\;\|\&\`\$\(\)] ]]; then
        log "ERROR: Rule contains forbidden characters: $rule"
        return 1
    fi

    # Convert rule to iptables arguments
    local iptables_args

    if [[ "$action" == "add" ]]; then
        # Keep -A or -I as is (no transformation needed for add)
        iptables_args="$rule"
        # Add comment to identify rules managed by bash-ddns-whitelister
        # Only add if rule doesn't already have a comment
        if [[ ! "$iptables_args" =~ -m\ comment ]]; then
            iptables_args="$iptables_args -m comment --comment \"bash-ddns-whitelister\""
        fi
    else
        # For delete, replace -A or -I with -D (remove line number if present)
        iptables_args=$(echo "$rule" | sed -E 's/^-[AI] ([A-Z]+) [0-9]+/-D \1/' | sed 's/^-A /-D /')
        # Add comment for deletion too (must match the rule exactly)
        if [[ ! "$iptables_args" =~ -m\ comment ]]; then
            iptables_args="$iptables_args -m comment --comment \"bash-ddns-whitelister\""
        fi
    fi

    # Execute command directly without eval (safer)
    if iptables $iptables_args 2>/dev/null; then
        log "Rule ${action}: iptables $iptables_args"
        return 0
    else
        log "ERROR executing: iptables $iptables_args"
        return 1
    fi
}

# Main update function
update_rules() {
    local updated=0

    # Read rules file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue

        # Extract potential hostnames from rule
        local hostnames=$(extract_hostnames "$line")

        if [[ -z "$hostnames" ]]; then
            continue
        fi

        local rule_changed=false
        local updated_rule="$line"

        # For each hostname found
        for hostname in $hostnames; do
            # Resolve current IP
            local current_ip=$(resolve_hostname "$hostname")

            if [[ -z "$current_ip" ]]; then
                log "WARNING: Cannot resolve $hostname"
                continue
            fi

            # Check if IP has changed
            local cached_ip=$(get_cached_ip "$hostname")

            if [[ "$current_ip" != "$cached_ip" ]]; then
                log "Change detected for $hostname: $cached_ip -> $current_ip"

                # If rule with old IP exists, delete it
                if [[ -n "$cached_ip" ]]; then
                    local old_rule=$(replace_hostname_with_ip "$line" "$hostname" "$cached_ip")
                    apply_rule "$old_rule" "delete" || true
                fi

                # Update rule with new IP
                updated_rule=$(replace_hostname_with_ip "$updated_rule" "$hostname" "$current_ip")
                rule_changed=true

                # Cache new IP
                cache_ip "$hostname" "$current_ip"

                updated=$((updated + 1))
            fi
        done

        # Apply updated rule if needed
        if [[ "$rule_changed" == true ]]; then
            apply_rule "$updated_rule" "add"
        fi

    done < "$RULES_FILE"

    if [[ $updated -gt 0 ]]; then
        log "Update completed: $updated hostname(s) updated"
    fi
}

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Main execution
rotate_logs
log "Starting iptables rules update"
update_rules
log "Update finished"
