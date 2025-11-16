#!/bin/bash
# Update sshd Match Address blocks with dynamic DNS hostnames
# Manages Match Address IP lists in /etc/ssh/sshd_config
# Usage: ./sshd-match-address-update.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
CACHE_DIR="${SCRIPT_DIR}/.cache"
LOG_FILE="${SCRIPT_DIR}/sshd-match-address-update.log"
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.backup-$(date +%Y%m%d-%H%M%S)"

# Log rotation settings (in hours)
LOG_ROTATION_HOURS="${LOG_ROTATION_HOURS:-168}"  # Default: 1 week

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

# Source the .env file
source "$ENV_FILE"

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
    local identifier="$1"
    local cache_file="$CACHE_DIR/sshd_${identifier}.cache"

    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
    else
        echo ""
    fi
}

# Cache IP
cache_ip() {
    local identifier="$1"
    local ip="$2"
    local cache_file="$CACHE_DIR/sshd_${identifier}.cache"

    echo "$ip" > "$cache_file"
}

# Backup sshd_config
backup_sshd_config() {
    if [[ -f "$SSHD_CONFIG" ]]; then
        cp "$SSHD_CONFIG" "$SSHD_BACKUP"
        log "Backed up sshd_config to $SSHD_BACKUP"
    fi
}

# Validate sshd configuration
validate_sshd_config() {
    if sshd -t 2>/dev/null; then
        return 0
    else
        log "ERROR: sshd configuration validation failed"
        return 1
    fi
}

# Reload sshd
reload_sshd() {
    if systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null; then
        log "sshd reloaded successfully"
        return 0
    else
        log "ERROR: Failed to reload sshd"
        return 1
    fi
}

# Update Match Address block
update_match_address() {
    local identifier="$1"
    local hostname="$2"
    local new_ip="$3"
    local old_ip="$4"

    # Find the line with the comment (take first occurrence only)
    local comment_line=$(grep -n "# bash-ddns-whitelister: ${identifier}" "$SSHD_CONFIG" | head -1 | cut -d: -f1)

    if [[ -z "$comment_line" ]]; then
        log "ERROR: No Match Address block found for identifier: ${identifier}"
        return 1
    fi

    # Get the Match Address line (should be next line after comment)
    local match_line=$((comment_line + 1))
    local match_content=$(sed -n "${match_line}p" "$SSHD_CONFIG")

    if [[ ! "$match_content" =~ ^Match\ Address ]]; then
        log "ERROR: Expected 'Match Address' at line ${match_line}, found: ${match_content}"
        return 1
    fi

    # Extract current IP list
    local ip_list=$(echo "$match_content" | sed -E 's/^Match Address\s+//')

    # Update IP list
    local new_ip_list=""
    if [[ -n "$old_ip" ]]; then
        # Replace old IP with new IP
        new_ip_list=$(echo "$ip_list" | sed "s/${old_ip}/${new_ip}/g")
    else
        # Add new IP to the list
        if [[ -n "$ip_list" ]]; then
            new_ip_list="${new_ip},${ip_list}"
        else
            new_ip_list="${new_ip}"
        fi
    fi

    # Create temporary file with updated content
    local temp_file=$(mktemp)
    sed "${match_line}s|.*|Match Address ${new_ip_list}|" "$SSHD_CONFIG" > "$temp_file"

    # Backup original
    backup_sshd_config

    # Replace with updated version
    cat "$temp_file" > "$SSHD_CONFIG"
    rm "$temp_file"

    # Validate
    if validate_sshd_config; then
        log "Updated Match Address for ${identifier}: ${old_ip:-none} -> ${new_ip}"
        reload_sshd
        return 0
    else
        # Restore backup
        log "ERROR: Validation failed, restoring backup"
        cp "$SSHD_BACKUP" "$SSHD_CONFIG"
        return 1
    fi
}

# Main update function
update_sshd_match_addresses() {
    local updated=0

    # Check if SSHD_MATCH_ADDRESS_RULES is defined
    if [[ -z "${SSHD_MATCH_ADDRESS_RULES[@]}" ]]; then
        log "No SSHD_MATCH_ADDRESS_RULES defined in .env"
        return 0
    fi

    for rule in "${SSHD_MATCH_ADDRESS_RULES[@]}"; do
        # Parse rule: identifier|hostname
        IFS='|' read -ra PARTS <<< "$rule"

        local identifier="${PARTS[0]:-}"
        local hostname="${PARTS[1]:-}"

        if [[ -z "$identifier" ]] || [[ -z "$hostname" ]]; then
            log "WARNING: Invalid rule format: $rule"
            continue
        fi

        # Resolve current IP
        local current_ip=$(resolve_hostname "$hostname")

        if [[ -z "$current_ip" ]]; then
            log "WARNING: Cannot resolve $hostname"
            continue
        fi

        # Check if IP has changed
        local cached_ip=$(get_cached_ip "$identifier")

        if [[ "$current_ip" != "$cached_ip" ]]; then
            log "Change detected for ${identifier} (${hostname}): ${cached_ip:-none} -> ${current_ip}"

            # Update Match Address block
            if update_match_address "$identifier" "$hostname" "$current_ip" "$cached_ip"; then
                # Cache new IP
                cache_ip "$identifier" "$current_ip"
                updated=$((updated + 1))
            fi
        fi
    done

    if [[ $updated -gt 0 ]]; then
        log "Update completed: $updated Match Address block(s) updated"
    fi
}

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}" >&2
    exit 1
fi

# Check if sshd_config exists
if [[ ! -f "$SSHD_CONFIG" ]]; then
    log "ERROR: $SSHD_CONFIG not found"
    exit 1
fi

# Main execution
rotate_logs
log "Starting sshd Match Address update"
update_sshd_match_addresses
log "Update finished"
