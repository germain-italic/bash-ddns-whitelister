#!/bin/bash
# Update AWS Security Group rules with dynamic DNS IPs
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
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
    echo "ERROR: AWS_ACCESS_KEY_ID not set in .env"
    exit 1
fi

if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    echo "ERROR: AWS_SECRET_ACCESS_KEY not set in .env"
    exit 1
fi

if [[ -z "${AWS_DEFAULT_REGION:-}" ]]; then
    echo "ERROR: AWS_DEFAULT_REGION not set in .env"
    exit 1
fi

# Export AWS credentials for AWS CLI
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION

# Check and install AWS CLI if needed
ensure_aws_cli() {
    if command -v aws &> /dev/null; then
        # AWS CLI already installed
        return 0
    fi

    echo "AWS CLI not found. Installing..."

    # Check for unzip
    if ! command -v unzip &> /dev/null; then
        echo "ERROR: unzip is not installed. Please install it first:"
        echo "  sudo apt-get install unzip  # Debian/Ubuntu"
        echo "  sudo yum install unzip      # RHEL/CentOS"
        return 1
    fi

    # Create temp directory
    local tmp_dir=$(mktemp -d)
    local original_dir=$(pwd)
    cd "$tmp_dir"

    # Download AWS CLI v2
    echo "Downloading AWS CLI..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

    if [[ ! -f "awscliv2.zip" ]] || [[ ! -s "awscliv2.zip" ]]; then
        echo "ERROR: Failed to download AWS CLI"
        cd "$original_dir"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Unzip
    echo "Extracting..."
    if ! unzip -q awscliv2.zip 2>&1; then
        echo "ERROR: Failed to extract AWS CLI package"
        cd "$original_dir"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Install (requires sudo)
    echo "Installing AWS CLI..."
    local install_output
    if [[ $EUID -eq 0 ]]; then
        # Running as root
        install_output=$(./aws/install 2>&1)
    else
        # Need sudo
        install_output=$(sudo ./aws/install 2>&1)
    fi

    local install_result=$?

    # Cleanup
    cd "$original_dir"
    rm -rf "$tmp_dir"

    # Verify installation
    if [[ $install_result -eq 0 ]] && command -v aws &> /dev/null; then
        echo "AWS CLI installed successfully: $(aws --version)"
        return 0
    else
        echo "ERROR: AWS CLI installation failed"
        echo "Install output: $install_output"
        return 1
    fi
}

# Ensure AWS CLI is installed
ensure_aws_cli || exit 1

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

# Find security group rules by IP address (AWS CLI v1 compatible)
# Returns "true" if a rule exists for the IP, "" if not
find_rules_in_sg_by_ip() {
    local sg_id="$1"
    local ip="$2"
    local region="${3:-$AWS_DEFAULT_REGION}"

    # Return empty if no IP provided
    if [[ -z "$ip" ]]; then
        echo ""
        return 0
    fi

    # Get security group details using AWS CLI v1 compatible command
    local sg_data=$(aws ec2 describe-security-groups \
        --region "$region" \
        --group-ids "$sg_id" \
        --query "SecurityGroups[0].IpPermissions[?contains(IpRanges[].CidrIp, '${ip}/32')]" \
        --output json 2>/dev/null)

    # Check if any rules were found
    if [[ -n "$sg_data" ]] && [[ "$sg_data" != "[]" ]] && [[ "$sg_data" != "null" ]]; then
        echo "true"
    else
        echo ""
    fi
}

# Create security group rule (TCP only)
create_security_group_rule() {
    local sg_id="$1"
    local ip="$2"
    local identifier="$3"
    local region="${4:-$AWS_DEFAULT_REGION}"

    # Create inbound TCP rule for all ports
    local response=$(aws ec2 authorize-security-group-ingress \
        --region "$region" \
        --group-id "$sg_id" \
        --ip-permissions IpProtocol=tcp,FromPort=0,ToPort=65535,IpRanges="[{CidrIp=${ip}/32,Description=${identifier}}]" \
        --output json 2>&1)

    if [[ $? -eq 0 ]]; then
        # Extract rule ID from response
        local rule_id=$(echo "$response" | grep -o '"SecurityGroupRuleId": "[^"]*"' | head -1 | cut -d'"' -f4)

        if [[ -n "$rule_id" ]]; then
            log "Created TCP rule ID: ${rule_id} for ${identifier} (${ip}/32)"

            # Cache rule ID
            local cache_key="${sg_id}_${identifier}_rule_id"
            echo "$rule_id" > "$CACHE_DIR/${cache_key}.cache"
            return 0
        fi
    fi

    log "ERROR: Failed to create TCP rule for ${identifier}"
    return 1
}

# Delete security group rules with IP verification (AWS CLI v1 compatible)
# IMPORTANT: Only deletes rules if their IP matches expected_ip (safety check)
delete_security_group_rules_by_ip() {
    local sg_id="$1"
    local expected_ip="$2"
    local region="${3:-$AWS_DEFAULT_REGION}"

    # Safety check: require expected_ip
    if [[ -z "$expected_ip" ]]; then
        log "ERROR: delete_security_group_rules_by_ip requires expected_ip parameter"
        return 1
    fi

    # Get all IP permissions for this IP (AWS CLI v1 compatible)
    local ip_perms=$(aws ec2 describe-security-groups \
        --region "$region" \
        --group-ids "$sg_id" \
        --query "SecurityGroups[0].IpPermissions[?contains(IpRanges[].CidrIp, '${expected_ip}/32')]" \
        --output json 2>/dev/null)

    # Check if any rules exist
    if [[ -z "$ip_perms" ]] || [[ "$ip_perms" == "[]" ]] || [[ "$ip_perms" == "null" ]]; then
        log "No rules found for ${expected_ip}/32"
        return 0
    fi

    # Revoke using ip-permissions structure (AWS CLI v1 compatible)
    aws ec2 revoke-security-group-ingress \
        --region "$region" \
        --group-id "$sg_id" \
        --ip-permissions "$ip_perms" \
        --output json &>/dev/null

    if [[ $? -eq 0 ]]; then
        log "Deleted rules for IP: ${expected_ip}/32"
    else
        log "WARNING: Failed to delete rules for ${expected_ip}/32"
    fi
}

# Update security group rules (delete old, create/reuse new)
update_security_group_rules() {
    local sg_id="$1"
    local old_ip="$2"
    local new_ip="$3"
    local identifier="$4"
    local region="${5:-$AWS_DEFAULT_REGION}"

    # Delete old rules if old IP is provided
    if [[ -n "$old_ip" ]]; then
        local old_rules_exist=$(find_rules_in_sg_by_ip "$sg_id" "$old_ip" "$region")
        if [[ -n "$old_rules_exist" ]]; then
            log "Found old rules for ${identifier} (${old_ip}), deleting..."
            delete_security_group_rules_by_ip "$sg_id" "$old_ip" "$region"
        fi
    fi

    # Check if rules already exist for new IP (avoid duplicates)
    local existing_new_rules=$(find_rules_in_sg_by_ip "$sg_id" "$new_ip" "$region")

    if [[ -n "$existing_new_rules" ]]; then
        # Rules already exist for this IP - reuse them instead of creating duplicates
        log "Rules already exist for ${identifier} (${new_ip}), reusing existing rules"
    else
        # Create new rule (none exist for this IP)
        create_security_group_rule "$sg_id" "$new_ip" "$identifier" "$region"
    fi
}

# Main update function
update_aws_rules() {
    local updated=0

    # Check if AWS_RULES is defined
    if [[ -z "${AWS_RULES[@]:-}" ]]; then
        log "No AWS_RULES defined in .env"
        return 0
    fi

    for rule in "${AWS_RULES[@]}"; do
        # Parse rule: security_group_id|identifier|hostname|region
        IFS='|' read -ra PARTS <<< "$rule"

        local sg_id="${PARTS[0]:-}"
        local identifier="${PARTS[1]:-}"
        local hostname="${PARTS[2]:-}"
        local region="${PARTS[3]:-$AWS_DEFAULT_REGION}"

        if [[ -z "$sg_id" ]] || [[ -z "$identifier" ]] || [[ -z "$hostname" ]]; then
            log "WARNING: Invalid rule format: $rule"
            continue
        fi

        log "Processing security group ${sg_id} - ${identifier} (${hostname}) in region ${region}"

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

            # Update rules (pass old IP for safe deletion, new IP for creation/reuse)
            update_security_group_rules "$sg_id" "$cached_ip" "$current_ip" "$identifier" "$region"

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
log "Starting AWS security group update"
update_aws_rules
log "Update finished"
