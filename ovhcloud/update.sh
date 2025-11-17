#!/bin/bash
# Update OVH Edge Network Firewall rules with dynamic DNS IPs
# Automatically manages firewall rules for dynamic hostnames
# Usage: ./update.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
CACHE_DIR="${SCRIPT_DIR}/.cache"
LOG_FILE="${SCRIPT_DIR}/update.log"

# Log rotation settings (in hours)
LOG_ROTATION_HOURS="${LOG_ROTATION_HOURS:-168}"  # Default: 1 week

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: .env file not found at $ENV_FILE"
    exit 1
fi

# Source the .env file
source "$ENV_FILE"

# Validate required environment variables
if [[ -z "${OVH_APPLICATION_KEY:-}" ]]; then
    echo "ERROR: OVH_APPLICATION_KEY not set in .env"
    exit 1
fi

if [[ -z "${OVH_APPLICATION_SECRET:-}" ]]; then
    echo "ERROR: OVH_APPLICATION_SECRET not set in .env"
    exit 1
fi

if [[ -z "${OVH_CONSUMER_KEY:-}" ]]; then
    echo "ERROR: OVH_CONSUMER_KEY not set in .env"
    echo "Please generate a consumer key first using the OVH API console"
    exit 1
fi

# OVH API endpoint
OVH_ENDPOINT="${OVH_ENDPOINT:-ovh-eu}"
case "$OVH_ENDPOINT" in
    ovh-eu)
        API_URL="https://eu.api.ovh.com/1.0"
        ;;
    ovh-ca)
        API_URL="https://ca.api.ovh.com/1.0"
        ;;
    *)
        API_URL="https://api.ovh.com/1.0"
        ;;
esac

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Rotate logs if needed
rotate_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        local log_age_hours=$(( ($(date +%s) - $(stat -c %Y "$LOG_FILE" 2>/dev/null || stat -f %m "$LOG_FILE")) / 3600 ))
        if [[ $log_age_hours -ge $LOG_ROTATION_HOURS ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            log "Log rotated (age: ${log_age_hours}h)"
        fi
    fi
}

# Validate IPv4 address
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
    local cache_key="$1"
    local cache_file="$CACHE_DIR/${cache_key}.cache"

    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
    else
        echo ""
    fi
}

# Cache IP
cache_ip() {
    local cache_key="$1"
    local ip="$2"
    local cache_file="$CACHE_DIR/${cache_key}.cache"

    echo "$ip" > "$cache_file"
}

# OVH API call with authentication
ovh_api_call() {
    local method="$1"
    local endpoint="$2"
    local body="${3:-}"

    local url="${API_URL}${endpoint}"
    local timestamp=$(date +%s)

    # Calculate signature
    # Signature = "$1$" + SHA1_HEX(AS+"+"+CK+"+"+METHOD+"+"+QUERY+"+"+BODY+"+"+TSTAMP)
    local signature_data="${OVH_APPLICATION_SECRET}+${OVH_CONSUMER_KEY}+${method}+${url}+${body}+${timestamp}"
    local signature=$(echo -n "$signature_data" | sha1sum | awk '{print $1}')
    local full_signature="\$1\$${signature}"

    # Make API call
    if [[ "$method" == "GET" ]] || [[ "$method" == "DELETE" ]]; then
        curl -s -X "$method" \
            -H "X-Ovh-Application: ${OVH_APPLICATION_KEY}" \
            -H "X-Ovh-Consumer: ${OVH_CONSUMER_KEY}" \
            -H "X-Ovh-Timestamp: ${timestamp}" \
            -H "X-Ovh-Signature: ${full_signature}" \
            "$url"
    else
        curl -s -X "$method" \
            -H "X-Ovh-Application: ${OVH_APPLICATION_KEY}" \
            -H "X-Ovh-Consumer: ${OVH_CONSUMER_KEY}" \
            -H "X-Ovh-Timestamp: ${timestamp}" \
            -H "X-Ovh-Signature: ${full_signature}" \
            -H "Content-Type: application/json" \
            -d "$body" \
            "$url"
    fi
}

# List firewall rules for an IP
list_firewall_rules() {
    local ip_address="$1"

    # OVH API: /ip/{ip}/firewall/{ipOnFirewall}/rule
    ovh_api_call "GET" "/ip/${ip_address}/firewall/${ip_address}/rule"
}

# Get rule details by rule ID
get_rule_details() {
    local ip_address="$1"
    local rule_id="$2"

    ovh_api_call "GET" "/ip/${ip_address}/firewall/${ip_address}/rule/${rule_id}"
}

# Find firewall rule ID by source IP
find_rule_by_source() {
    local ip_address="$1"
    local source_ip="$2"

    # Get all rule IDs
    local rule_ids=$(list_firewall_rules "$ip_address")

    # Parse array like [1,2,3,4]
    local ids=$(echo "$rule_ids" | tr -d '[]' | tr ',' ' ')

    # Check each rule to find matching source (with or without /32)
    for rule_id in $ids; do
        local rule_details=$(get_rule_details "$ip_address" "$rule_id")
        local rule_source=$(echo "$rule_details" | grep -o '"source":"[^"]*"' | cut -d'"' -f4)

        # Match with or without CIDR notation
        if [[ "$rule_source" == "$source_ip" ]] || [[ "$rule_source" == "${source_ip}/32" ]]; then
            echo "$rule_id"
            return 0
        fi
    done

    echo ""
}

# Add firewall rule
add_firewall_rule() {
    local ip_address="$1"
    local source_ip="$2"
    local identifier="$3"

    # Get existing rules to find the first available sequence number
    local rule_ids=$(list_firewall_rules "$ip_address")
    local ids=$(echo "$rule_ids" | tr -d '[]' | tr ',' ' ')

    # Collect used sequence numbers
    local used_sequences=()
    for rule_id in $ids; do
        local rule_details=$(get_rule_details "$ip_address" "$rule_id")
        local seq=$(echo "$rule_details" | grep -o '"sequence":[0-9]*' | cut -d':' -f2)
        if [[ -n "$seq" ]]; then
            used_sequences+=($seq)
        fi
    done

    # Find first available sequence (0-19)
    local next_sequence=-1
    for seq in {0..19}; do
        local found=0
        for used in "${used_sequences[@]}"; do
            if [[ $used -eq $seq ]]; then
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            next_sequence=$seq
            break
        fi
    done

    # Check if we found an available slot
    if [[ $next_sequence -eq -1 ]]; then
        log "ERROR: No available sequence slots (firewall is full, 20/20 rules)"
        return 1
    fi

    # OVH requires CIDR notation and sequence
    local body="{\"action\":\"permit\",\"protocol\":\"tcp\",\"source\":\"${source_ip}/32\",\"sequence\":${next_sequence}}"

    local response=$(ovh_api_call "POST" "/ip/${ip_address}/firewall/${ip_address}/rule" "$body")

    # Check for errors in response
    if echo "$response" | grep -q '"sequence"'; then
        local rule_id=$(echo "$response" | grep -o '"sequence":[0-9]*' | cut -d':' -f2)
        log "Created firewall rule ID ${rule_id} for ${identifier} (${source_ip}/32) on ${ip_address}"
        return 0
    else
        log "ERROR: Failed to create firewall rule for ${identifier}: $response"
        return 1
    fi
}

# Delete firewall rule
delete_firewall_rule() {
    local ip_address="$1"
    local rule_id="$2"

    local response=$(ovh_api_call "DELETE" "/ip/${ip_address}/firewall/${ip_address}/rule/${rule_id}")

    if [[ $? -eq 0 ]]; then
        log "Deleted firewall rule ID ${rule_id} on ${ip_address}"
        return 0
    else
        log "WARNING: Failed to delete firewall rule ID ${rule_id}"
        return 1
    fi
}

# Update firewall rules
update_firewall_rules() {
    local ip_address="$1"
    local old_ip="$2"
    local new_ip="$3"
    local identifier="$4"

    # Delete old rule if exists
    if [[ -n "$old_ip" ]]; then
        local old_rule_id=$(find_rule_by_source "$ip_address" "$old_ip")
        if [[ -n "$old_rule_id" ]]; then
            log "Found old rule ID ${old_rule_id} for ${identifier} (${old_ip}), deleting..."
            delete_firewall_rule "$ip_address" "$old_rule_id"
        fi
    fi

    # Check if rule already exists for new IP
    local existing_rule_id=$(find_rule_by_source "$ip_address" "$new_ip")

    if [[ -n "$existing_rule_id" ]]; then
        log "Rule ID ${existing_rule_id} already exists for ${identifier} (${new_ip}), reusing existing rule"
    else
        # Create new rule
        add_firewall_rule "$ip_address" "$new_ip" "$identifier"
    fi
}

# Main update function
update_ovh_rules() {
    local updated=0

    # Check if OVH_RULES is defined
    if [[ -z "${OVH_RULES[@]:-}" ]]; then
        log "No OVH_RULES defined in .env"
        return 0
    fi

    for rule in "${OVH_RULES[@]}"; do
        # Parse rule: ip_address|identifier|hostname
        IFS='|' read -ra PARTS <<< "$rule"

        local ip_address="${PARTS[0]:-}"
        local identifier="${PARTS[1]:-}"
        local hostname="${PARTS[2]:-}"

        if [[ -z "$ip_address" ]] || [[ -z "$identifier" ]] || [[ -z "$hostname" ]]; then
            log "WARNING: Invalid rule format: $rule"
            continue
        fi

        log "Processing ${ip_address} - ${identifier} (${hostname})"

        # Resolve current IP
        local current_ip=$(resolve_hostname "$hostname")

        if [[ -z "$current_ip" ]]; then
            log "WARNING: Cannot resolve ${hostname}"
            continue
        fi

        # Check if IP has changed
        local cache_key="${ip_address}_${identifier}_ip"
        local cached_ip=$(get_cached_ip "$cache_key")

        if [[ "$current_ip" != "$cached_ip" ]]; then
            log "IP change detected for ${identifier}: ${cached_ip:-none} -> ${current_ip}"

            # Update rules
            update_firewall_rules "$ip_address" "$cached_ip" "$current_ip" "$identifier"

            # Cache new IP
            cache_ip "$cache_key" "$current_ip"

            updated=$((updated + 1))
        else
            log "No change for ${identifier} (${current_ip})"
        fi
    done

    if [[ $updated -gt 0 ]]; then
        log "Update completed: ${updated} rule(s) updated"
    fi
}

# Main execution
rotate_logs
log "Starting OVH firewall update"
update_ovh_rules
log "Update finished"
