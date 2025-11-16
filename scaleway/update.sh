#!/bin/bash
# Update Scaleway Security Group rules with dynamic DNS IPs
# Automatically manages inbound rules for dynamic hostnames
# Usage: ./update.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
CACHE_DIR="${SCRIPT_DIR}/.cache"
LOG_FILE="${SCRIPT_DIR}/update.log"

# Log rotation settings (in hours)
LOG_ROTATION_HOURS="${LOG_ROTATION_HOURS:-168}"  # Default: 1 week

# Scaleway API base URL
SCW_API_BASE="https://api.scaleway.com/instance/v1"

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
if [[ -z "${SCW_SECRET_KEY:-}" ]]; then
    echo "ERROR: SCW_SECRET_KEY not set in .env"
    exit 1
fi

if [[ -z "${SCW_DEFAULT_PROJECT_ID:-}" ]]; then
    echo "ERROR: SCW_DEFAULT_PROJECT_ID not set in .env"
    exit 1
fi

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

# Call Scaleway API
scw_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local zone="${4:-fr-par-1}"

    local url="${SCW_API_BASE}/zones/${zone}${endpoint}"

    local curl_args=(
        -s
        -X "$method"
        -H "X-Auth-Token: ${SCW_SECRET_KEY}"
        -H "Content-Type: application/json"
    )

    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi

    curl "${curl_args[@]}" "$url"
}

# Get security group ID by name
get_security_group_id() {
    local sg_name="$1"
    local zone="${2:-fr-par-1}"

    local response=$(scw_api_call "GET" "/security_groups?project=${SCW_DEFAULT_PROJECT_ID}" "" "$zone")

    # Parse JSON to find security group by name
    local sg_id=$(echo "$response" | grep -o "\"id\":\"[^\"]*\".*\"name\":\"${sg_name}\"" | grep -o "\"id\":\"[^\"]*\"" | head -1 | cut -d'"' -f4)

    if [[ -z "$sg_id" ]]; then
        # Try reverse order (name might come before id)
        sg_id=$(echo "$response" | grep -o "\"name\":\"${sg_name}\".*\"id\":\"[^\"]*\"" | grep -o "\"id\":\"[^\"]*\"" | head -1 | cut -d'"' -f4)
    fi

    echo "$sg_id"
}

# List rules for a security group
list_security_group_rules() {
    local sg_id="$1"
    local zone="${2:-fr-par-1}"

    scw_api_call "GET" "/security_groups/${sg_id}" "" "$zone"
}

# Find rules by identifier (returns comma-separated rule IDs)
find_rules_by_identifier() {
    local sg_id="$1"
    local identifier="$2"
    local zone="${3:-fr-par-1}"

    local cache_key="${sg_id}_${identifier}_rule_ids"
    local cached_rule_ids=$(get_cached_ip "$cache_key")

    if [[ -n "$cached_rule_ids" ]]; then
        # Return cached rule IDs
        echo "$cached_rule_ids"
        return 0
    fi

    echo ""
}

# Create security group rules (TCP, UDP, ICMP)
create_security_group_rules() {
    local sg_id="$1"
    local ip="$2"
    local identifier="$3"
    local zone="${4:-fr-par-1}"

    local protocols=("TCP" "UDP" "ICMP")
    local rule_ids=()
    local success=true

    for protocol in "${protocols[@]}"; do
        local rule_data="{\"action\":\"accept\",\"direction\":\"inbound\",\"ip_range\":\"${ip}/32\",\"protocol\":\"${protocol}\",\"editable\":true}"

        local response=$(scw_api_call "POST" "/security_groups/${sg_id}/rules" "$rule_data" "$zone")

        # Extract rule ID from response (format: {"rule": {"id": "xxx"}})
        local rule_id=$(echo "$response" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"/\1/')

        if [[ -n "$rule_id" ]]; then
            rule_ids+=("$rule_id")
            log "Created ${protocol} rule ID: ${rule_id} for ${identifier} (${ip}/32)"
        else
            log "ERROR: Failed to create ${protocol} rule for ${identifier}"
            success=false
        fi
    done

    if $success; then
        # Cache all rule IDs (comma separated)
        local cache_key="${sg_id}_${identifier}_rule_ids"
        printf '%s\n' "${rule_ids[@]}" | paste -sd ',' > "$CACHE_DIR/${cache_key}.cache"
        return 0
    else
        return 1
    fi
}

# Delete security group rules (comma-separated IDs)
delete_security_group_rules() {
    local sg_id="$1"
    local rule_ids="$2"
    local zone="${3:-fr-par-1}"

    IFS=',' read -ra IDS <<< "$rule_ids"
    for rule_id in "${IDS[@]}"; do
        scw_api_call "DELETE" "/security_groups/${sg_id}/rules/${rule_id}" "" "$zone"
        log "Deleted rule ID: ${rule_id}"
    done
}

# Update security group rules (delete old, create new)
update_security_group_rules() {
    local sg_id="$1"
    local old_rule_ids="$2"
    local new_ip="$3"
    local identifier="$4"
    local zone="${5:-fr-par-1}"

    # Delete old rules
    if [[ -n "$old_rule_ids" ]]; then
        delete_security_group_rules "$sg_id" "$old_rule_ids" "$zone"
    fi

    # Create new rules
    create_security_group_rules "$sg_id" "$new_ip" "$identifier" "$zone"
}

# Main update function
update_scaleway_rules() {
    local updated=0

    # Check if SCALEWAY_RULES is defined
    if [[ -z "${SCALEWAY_RULES[@]:-}" ]]; then
        log "No SCALEWAY_RULES defined in .env"
        return 0
    fi

    for rule in "${SCALEWAY_RULES[@]}"; do
        # Parse rule: security_group_id|identifier|hostname|zone
        IFS='|' read -ra PARTS <<< "$rule"

        local sg_id="${PARTS[0]:-}"
        local identifier="${PARTS[1]:-}"
        local hostname="${PARTS[2]:-}"
        local zone="${PARTS[3]:-PAR1}"

        if [[ -z "$sg_id" ]] || [[ -z "$identifier" ]] || [[ -z "$hostname" ]]; then
            log "WARNING: Invalid rule format: $rule"
            continue
        fi

        log "Processing security group ${sg_id} - ${identifier} (${hostname}) in zone ${zone}"

        # Resolve current IP
        local current_ip=$(resolve_hostname "$hostname")

        if [[ -z "$current_ip" ]]; then
            log "WARNING: Cannot resolve ${hostname}"
            continue
        fi

        # Check if IP has changed
        local cache_key="${sg_id}_${identifier}_ip"
        local cached_ip=$(get_cached_ip "$cache_key")

        if [[ "$current_ip" != "$cached_ip" ]]; then
            log "IP change detected for ${identifier}: ${cached_ip:-none} -> ${current_ip}"

            # Find existing rules
            local existing_rule_ids=$(find_rules_by_identifier "$sg_id" "$identifier" "$zone")

            # Update rules
            update_security_group_rules "$sg_id" "$existing_rule_ids" "$current_ip" "$identifier" "$zone"

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
log "Starting Scaleway security group update"
update_scaleway_rules
log "Update finished"
