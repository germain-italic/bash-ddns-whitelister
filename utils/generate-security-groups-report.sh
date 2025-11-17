#!/bin/bash
# Generate Security Groups CSV report with dynamic server discovery
# Queries Scaleway, AWS, and OVH APIs to list security groups and associated servers
# Usage: ./generate-security-groups-report.sh [output.csv]
#
# NOTE: This script requires 'jq' for JSON parsing
# Install with: sudo apt-get install -y jq

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Create reports directory if it doesn't exist
REPORTS_DIR="${REPO_DIR}/reports"
mkdir -p "$REPORTS_DIR"

# Default output file with date
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
OUTPUT_FILE="${1:-${REPORTS_DIR}/security-groups-report_${DATE}.csv}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Security Groups Report Generator${NC}"
echo -e "${BLUE}  (Dynamic Server Discovery)${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: 'jq' is required but not installed${NC}"
    echo "Install it with: sudo apt-get install -y jq"
    exit 1
fi

# CSV Header
cat > "$OUTPUT_FILE" << 'HEADER'
Provider,Security Group ID,Security Group Name,Region/Zone,Script Installed On,Cron Status,Associated Servers,DDNS Rules Count,Comments
HEADER

total_groups=0

# ============================================================================
# PHASE 1: DISCOVERY - Find which servers manage which cloud providers
# ============================================================================

echo -e "${MAGENTA}Phase 1: Discovering cloud provider configurations on servers...${NC}"
echo

# Source utils .env for SERVERS array
UTILS_ENV="${SCRIPT_DIR}/.env"
if [[ ! -f "$UTILS_ENV" ]]; then
    echo -e "${RED}ERROR: Utils .env file not found at $UTILS_ENV${NC}"
    exit 1
fi
source "$UTILS_ENV"

# Arrays to store discovered server configurations
declare -A SCALEWAY_SERVERS  # key: server_hostname, value: 1
declare -A AWS_SERVERS       # key: server_hostname, value: 1
declare -A OVH_SERVERS       # key: server_hostname, value: 1

# Discover cloud providers on each server
for server_config in "${SERVERS[@]}"; do
    IFS=':' read -ra PARTS <<< "$server_config"
    hostname="${PARTS[0]}"
    port="${PARTS[1]}"
    user="${PARTS[2]}"
    firewall_type="${PARTS[3]:-none}"
    skip_flag="${PARTS[4]:-}"

    # Skip if skip flag is present
    if [[ "$skip_flag" == "skip" ]]; then
        continue
    fi

    # Skip Windows servers
    if [[ "$firewall_type" == "windows" ]]; then
        continue
    fi

    echo -e "  ${CYAN}Checking ${hostname}...${NC}"

    # Test SSH connectivity with short timeout
    if ! ssh -p "$port" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${user}@${hostname}" "echo test" &> /dev/null; then
        echo -e "    ${YELLOW}⚠${NC} Cannot connect via SSH, skipping"
        continue
    fi

    # Check for Scaleway config
    if ssh -p "$port" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${user}@${hostname}" "test -f /root/bash-ddns-whitelister/scaleway/.env" 2>/dev/null; then
        SCALEWAY_SERVERS["$hostname"]="$port:$user"
        echo -e "    ${GREEN}✓${NC} Scaleway configuration found"
    fi

    # Check for AWS config
    if ssh -p "$port" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${user}@${hostname}" "test -f /root/bash-ddns-whitelister/aws/.env" 2>/dev/null; then
        AWS_SERVERS["$hostname"]="$port:$user"
        echo -e "    ${GREEN}✓${NC} AWS configuration found"
    fi

    # Check for OVH config
    if ssh -p "$port" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${user}@${hostname}" "test -f /root/bash-ddns-whitelister/ovhcloud/.env" 2>/dev/null; then
        OVH_SERVERS["$hostname"]="$port:$user"
        echo -e "    ${GREEN}✓${NC} OVH configuration found"
    fi
done

echo
echo -e "${GREEN}Discovery Summary:${NC}"
echo -e "  Scaleway: ${#SCALEWAY_SERVERS[@]} server(s)"
echo -e "  AWS:      ${#AWS_SERVERS[@]} server(s)"
echo -e "  OVH:      ${#OVH_SERVERS[@]} server(s)"
echo

# ============================================================================
# PHASE 2: SCALEWAY SECURITY GROUPS
# ============================================================================

echo -e "${MAGENTA}Phase 2: Checking Scaleway Security Groups...${NC}"
echo

if [[ ${#SCALEWAY_SERVERS[@]} -eq 0 ]]; then
    echo -e "  ${YELLOW}⚠${NC} No servers with Scaleway configuration found"
else
    for server_hostname in "${!SCALEWAY_SERVERS[@]}"; do
        echo -e "  ${CYAN}Processing Scaleway config from ${server_hostname}...${NC}"

        IFS=':' read -ra CONN <<< "${SCALEWAY_SERVERS[$server_hostname]}"
        port="${CONN[0]}"
        user="${CONN[1]}"

        # Read remote .env file and extract credentials
        remote_env=$(ssh -p "$port" -o StrictHostKeyChecking=no "${user}@${server_hostname}" "cat /root/bash-ddns-whitelister/scaleway/.env" 2>/dev/null || echo "")

        if [[ -z "$remote_env" ]]; then
            echo -e "    ${RED}✗${NC} Failed to read .env file"
            continue
        fi

        # Extract credentials from remote .env
        SCW_SECRET_KEY=$(echo "$remote_env" | grep '^SCW_SECRET_KEY=' | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        SCW_DEFAULT_ORGANIZATION_ID=$(echo "$remote_env" | grep '^SCW_DEFAULT_ORGANIZATION_ID=' | cut -d'=' -f2- | tr -d '"' | tr -d "'")

        if [[ -z "$SCW_SECRET_KEY" ]] || [[ -z "$SCW_DEFAULT_ORGANIZATION_ID" ]]; then
            echo -e "    ${YELLOW}⚠${NC} Missing credentials in .env"
            continue
        fi

        # Read SCALEWAY_RULES array from remote server
        rules_raw=$(ssh -p "$port" -o StrictHostKeyChecking=no "${user}@${server_hostname}" \
            "source /root/bash-ddns-whitelister/scaleway/.env; for rule in \"\${SCALEWAY_RULES[@]}\"; do echo \"\$rule\"; done" 2>/dev/null || echo "")

        if [[ -z "$rules_raw" ]]; then
            echo -e "    ${YELLOW}⚠${NC} No SCALEWAY_RULES configured"
            continue
        fi

        # Extract unique zones from rules
        declare -A zones_map
        while IFS= read -r rule; do
            if [[ -n "$rule" ]]; then
                IFS='|' read -ra RULE_PARTS <<< "$rule"
                zone="${RULE_PARTS[3]:-}"
                if [[ -n "$zone" ]]; then
                    zones_map["$zone"]=1
                fi
            fi
        done <<< "$rules_raw"

        # Query security groups for each zone
        for zone in "${!zones_map[@]}"; do
            echo -e "    ${CYAN}Querying zone: $zone${NC}"

            # Get security groups for this zone
            sg_response=$(curl -s -X GET \
                -H "X-Auth-Token: $SCW_SECRET_KEY" \
                "https://api.scaleway.com/instance/v1/zones/${zone}/security_groups")

            # Parse security groups
            sg_count=$(echo "$sg_response" | jq -r '.security_groups | length' 2>/dev/null || echo "0")

            if [[ "$sg_count" -gt 0 ]]; then
                for i in $(seq 0 $((sg_count - 1))); do
                    sg_id=$(echo "$sg_response" | jq -r ".security_groups[$i].id")
                    sg_name=$(echo "$sg_response" | jq -r ".security_groups[$i].name")

                    # Get servers using this security group
                    servers_response=$(curl -s -X GET \
                        -H "X-Auth-Token: $SCW_SECRET_KEY" \
                        "https://api.scaleway.com/instance/v1/zones/${zone}/servers")

                    # Find servers with this security group
                    associated_servers=""
                    server_count=$(echo "$servers_response" | jq -r '.servers | length' 2>/dev/null || echo "0")

                    for j in $(seq 0 $((server_count - 1))); do
                        server_sg=$(echo "$servers_response" | jq -r ".servers[$j].security_group.id")
                        if [[ "$server_sg" == "$sg_id" ]]; then
                            server_name=$(echo "$servers_response" | jq -r ".servers[$j].name")
                            server_ip=$(echo "$servers_response" | jq -r ".servers[$j].public_ip.address")
                            if [[ -z "$associated_servers" ]]; then
                                associated_servers="${server_name} (${server_ip})"
                            else
                                associated_servers="${associated_servers}; ${server_name} (${server_ip})"
                            fi
                        fi
                    done

                    # Get DDNS rules count from security group rules
                    rules_response=$(curl -s -X GET \
                        -H "X-Auth-Token: $SCW_SECRET_KEY" \
                        "https://api.scaleway.com/instance/v1/zones/${zone}/security_groups/${sg_id}/rules")

                    rules_count=$(echo "$rules_response" | jq -r '.rules | length' 2>/dev/null || echo "0")

                    # Check cron status on managing server
                    cron_check=$(ssh -p "$port" -o StrictHostKeyChecking=no "${user}@${server_hostname}" \
                        "crontab -l 2>/dev/null | grep -q 'bash-ddns-whitelister/scaleway/update.sh' && echo 'Active' || echo 'Not found'" 2>/dev/null || echo "Unknown")

                    script_host="$server_hostname"
                    cron_status="$cron_check"
                    comments="Managed via Scaleway API script on $server_hostname"

                    if [[ -z "$associated_servers" ]]; then
                        associated_servers="None"
                    fi

                    echo "Scaleway,${sg_id},${sg_name},${zone},${script_host},${cron_status},\"${associated_servers}\",${rules_count},\"${comments}\"" >> "$OUTPUT_FILE"
                    total_groups=$((total_groups + 1))

                    echo -e "      ${GREEN}✓${NC} $sg_name - $rules_count rules"
                done
            fi
        done

        # Clean up zones_map for next iteration
        unset zones_map
        declare -A zones_map
    done
fi

echo

# ============================================================================
# PHASE 3: AWS SECURITY GROUPS
# ============================================================================

echo -e "${MAGENTA}Phase 3: Checking AWS Security Groups...${NC}"
echo

if [[ ${#AWS_SERVERS[@]} -eq 0 ]]; then
    echo -e "  ${YELLOW}⚠${NC} No servers with AWS configuration found"
else
    # Check if AWS CLI is available locally
    if ! command -v aws &> /dev/null; then
        echo -e "  ${YELLOW}⚠${NC} AWS CLI not installed locally, skipping AWS checks"
    else
        for server_hostname in "${!AWS_SERVERS[@]}"; do
            echo -e "  ${CYAN}Processing AWS config from ${server_hostname}...${NC}"

            IFS=':' read -ra CONN <<< "${AWS_SERVERS[$server_hostname]}"
            port="${CONN[0]}"
            user="${CONN[1]}"

            # Read remote .env file and extract credentials
            remote_env=$(ssh -p "$port" -o StrictHostKeyChecking=no "${user}@${server_hostname}" "cat /root/bash-ddns-whitelister/aws/.env" 2>/dev/null || echo "")

            if [[ -z "$remote_env" ]]; then
                echo -e "    ${RED}✗${NC} Failed to read .env file"
                continue
            fi

            # Extract credentials from remote .env
            AWS_ACCESS_KEY_ID=$(echo "$remote_env" | grep '^AWS_ACCESS_KEY_ID=' | cut -d'=' -f2- | tr -d '"' | tr -d "'")
            AWS_SECRET_ACCESS_KEY=$(echo "$remote_env" | grep '^AWS_SECRET_ACCESS_KEY=' | cut -d'=' -f2- | tr -d '"' | tr -d "'")
            AWS_DEFAULT_REGION=$(echo "$remote_env" | grep '^AWS_DEFAULT_REGION=' | cut -d'=' -f2- | tr -d '"' | tr -d "'")

            if [[ -z "$AWS_ACCESS_KEY_ID" ]] || [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
                echo -e "    ${YELLOW}⚠${NC} Missing credentials in .env"
                continue
            fi

            # Read AWS_RULES array from remote server
            rules_raw=$(ssh -p "$port" -o StrictHostKeyChecking=no "${user}@${server_hostname}" \
                "source /root/bash-ddns-whitelister/aws/.env; for rule in \"\${AWS_RULES[@]}\"; do echo \"\$rule\"; done" 2>/dev/null || echo "")

            # Extract unique regions from rules
            declare -A regions_map
            if [[ -n "$rules_raw" ]]; then
                while IFS= read -r rule; do
                    if [[ -n "$rule" ]]; then
                        IFS='|' read -ra RULE_PARTS <<< "$rule"
                        region="${RULE_PARTS[3]:-}"
                        if [[ -n "$region" ]]; then
                            regions_map["$region"]=1
                        fi
                    fi
                done <<< "$rules_raw"
            fi

            # Fallback to AWS_DEFAULT_REGION if no rules configured
            if [[ ${#regions_map[@]} -eq 0 ]] && [[ -n "$AWS_DEFAULT_REGION" ]]; then
                regions_map["$AWS_DEFAULT_REGION"]=1
            fi

            if [[ ${#regions_map[@]} -eq 0 ]]; then
                echo -e "    ${YELLOW}⚠${NC} No regions configured"
                continue
            fi

            echo -e "    ${CYAN}Scanning regions: ${!regions_map[*]}${NC}"

            # Query security groups for each region
            for region in "${!regions_map[@]}"; do
                sg_list=$(AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
                    aws ec2 describe-security-groups --region "$region" --output json 2>/dev/null || echo '{"SecurityGroups":[]}')

                sg_count=$(echo "$sg_list" | jq -r '.SecurityGroups | length')

                if [[ "$sg_count" -gt 0 ]]; then
                    for i in $(seq 0 $((sg_count - 1))); do
                        sg_id=$(echo "$sg_list" | jq -r ".SecurityGroups[$i].GroupId")
                        sg_name=$(echo "$sg_list" | jq -r ".SecurityGroups[$i].GroupName")

                        # Get instances using this security group
                        instances=$(AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
                            aws ec2 describe-instances --region "$region" \
                            --filters "Name=instance.group-id,Values=$sg_id" \
                            --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],PublicIpAddress]' \
                            --output json 2>/dev/null || echo '[]')

                        associated_servers=""
                        instance_count=$(echo "$instances" | jq -r '. | length')

                        for j in $(seq 0 $((instance_count - 1))); do
                            server_name=$(echo "$instances" | jq -r ".[$j][0][0]")
                            server_ip=$(echo "$instances" | jq -r ".[$j][0][1]")
                            if [[ -n "$server_name" ]] && [[ "$server_name" != "null" ]]; then
                                if [[ -z "$associated_servers" ]]; then
                                    associated_servers="${server_name} (${server_ip})"
                                else
                                    associated_servers="${associated_servers}; ${server_name} (${server_ip})"
                                fi
                            fi
                        done

                        # Count ingress rules
                        rules_count=$(echo "$sg_list" | jq -r ".SecurityGroups[$i].IpPermissions | length")

                        # Check cron status on managing server
                        cron_check=$(ssh -p "$port" -o StrictHostKeyChecking=no "${user}@${server_hostname}" \
                            "crontab -l 2>/dev/null | grep -q 'bash-ddns-whitelister/aws/update.sh' && echo 'Active' || echo 'Not found'" 2>/dev/null || echo "Unknown")

                        script_host="$server_hostname"
                        cron_status="$cron_check"
                        comments="Managed via AWS API script on $server_hostname"

                        if [[ -z "$associated_servers" ]]; then
                            associated_servers="None"
                        fi

                        echo "AWS,${sg_id},${sg_name},${region},${script_host},${cron_status},\"${associated_servers}\",${rules_count},\"${comments}\"" >> "$OUTPUT_FILE"
                        total_groups=$((total_groups + 1))

                        echo -e "      ${GREEN}✓${NC} $sg_name ($region) - $rules_count rules"
                    done
                fi
            done

            # Clean up regions_map for next iteration
            unset regions_map
            declare -A regions_map
        done
    fi
fi

echo

# ============================================================================
# PHASE 4: OVH EDGE NETWORK FIREWALL
# ============================================================================

echo -e "${MAGENTA}Phase 4: Checking OVH Edge Network Firewall...${NC}"
echo

# OVH API call with authentication
ovh_api_call() {
    local method="$1"
    local endpoint="$2"
    local body="${3:-}"
    local app_key="$4"
    local app_secret="$5"
    local consumer_key="$6"

    local url="https://eu.api.ovh.com/1.0${endpoint}"
    local timestamp=$(date +%s)

    # Calculate signature
    # Signature = "$1$" + SHA1_HEX(AS+"+"+CK+"+"+METHOD+"+"+QUERY+"+"+BODY+"+"+TSTAMP)
    local signature_data="${app_secret}+${consumer_key}+${method}+${url}+${body}+${timestamp}"
    local signature=$(echo -n "$signature_data" | sha1sum | awk '{print $1}')
    local full_signature="\$1\$${signature}"

    # Make API call
    curl -s -X "$method" \
        -H "X-Ovh-Application: ${app_key}" \
        -H "X-Ovh-Consumer: ${consumer_key}" \
        -H "X-Ovh-Timestamp: ${timestamp}" \
        -H "X-Ovh-Signature: ${full_signature}" \
        "$url"
}

if [[ ${#OVH_SERVERS[@]} -eq 0 ]]; then
    echo -e "  ${YELLOW}⚠${NC} No servers with OVH configuration found"
else
    for server_hostname in "${!OVH_SERVERS[@]}"; do
        echo -e "  ${CYAN}Processing OVH config from ${server_hostname}...${NC}"

        IFS=':' read -ra CONN <<< "${OVH_SERVERS[$server_hostname]}"
        port="${CONN[0]}"
        user="${CONN[1]}"

        # Read remote .env file and extract credentials
        remote_env=$(ssh -p "$port" -o StrictHostKeyChecking=no "${user}@${server_hostname}" "cat /root/bash-ddns-whitelister/ovhcloud/.env" 2>/dev/null || echo "")

        if [[ -z "$remote_env" ]]; then
            echo -e "    ${RED}✗${NC} Failed to read .env file"
            continue
        fi

        # Extract credentials from remote .env
        OVH_APPLICATION_KEY=$(echo "$remote_env" | grep '^OVH_APPLICATION_KEY=' | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        OVH_APPLICATION_SECRET=$(echo "$remote_env" | grep '^OVH_APPLICATION_SECRET=' | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        OVH_CONSUMER_KEY=$(echo "$remote_env" | grep '^OVH_CONSUMER_KEY=' | cut -d'=' -f2- | tr -d '"' | tr -d "'")

        if [[ -z "$OVH_APPLICATION_KEY" ]] || [[ -z "$OVH_APPLICATION_SECRET" ]] || [[ -z "$OVH_CONSUMER_KEY" ]]; then
            echo -e "    ${YELLOW}⚠${NC} Missing credentials in .env"
            continue
        fi

        # Read OVH_RULES array from remote server
        rules_raw=$(ssh -p "$port" -o StrictHostKeyChecking=no "${user}@${server_hostname}" \
            "source /root/bash-ddns-whitelister/ovhcloud/.env; for rule in \"\${OVH_RULES[@]}\"; do echo \"\$rule\"; done" 2>/dev/null || echo "")

        if [[ -z "$rules_raw" ]]; then
            echo -e "    ${YELLOW}⚠${NC} No OVH_RULES configured"
            continue
        fi

        # Process each IP in OVH_RULES
        while IFS= read -r rule_config; do
            if [[ -z "$rule_config" ]]; then
                continue
            fi

            # Parse rule: ip_address|identifier|hostname
            IFS='|' read -ra PARTS <<< "$rule_config"
            ovh_ip="${PARTS[0]}"
            rule_identifier="${PARTS[1]:-unknown}"
            rule_hostname="${PARTS[2]:-}"

            # Get firewall rules for this IP
            # OVH API uses URL-encoded IP (replace . with %2E)
            ovh_ip_encoded=$(echo "$ovh_ip" | sed 's/\./\%2E/g')
            rules_response=$(ovh_api_call "GET" "/ip/${ovh_ip_encoded}/firewall" "" \
                "$OVH_APPLICATION_KEY" "$OVH_APPLICATION_SECRET" "$OVH_CONSUMER_KEY")

            # Count rules
            rules_count=$(echo "$rules_response" | jq -r '. | length' 2>/dev/null || echo "0")

            # Check cron status on managing server
            cron_check=$(ssh -p "$port" -o StrictHostKeyChecking=no "${user}@${server_hostname}" \
                "crontab -l 2>/dev/null | grep -q 'bash-ddns-whitelister/ovhcloud/update.sh' && echo 'Active' || echo 'Not found'" 2>/dev/null || echo "Unknown")

            script_host="$server_hostname"
            cron_status="$cron_check"
            associated_servers="$rule_hostname ($ovh_ip)"
            comments="Managed via OVH API script on $server_hostname"

            echo "OVH,${ovh_ip},Edge Network Firewall,ovh-eu,${script_host},${cron_status},\"${associated_servers}\",${rules_count},\"${comments}\"" >> "$OUTPUT_FILE"
            total_groups=$((total_groups + 1))

            echo -e "    ${GREEN}✓${NC} OVH Edge Network Firewall ($ovh_ip) - $rules_count rules"
        done <<< "$rules_raw"
    done
fi

echo
echo -e "${GREEN}✓${NC} Report generated: ${GREEN}$(basename "$OUTPUT_FILE")${NC}"
echo -e "  Total security groups: $total_groups"
echo
