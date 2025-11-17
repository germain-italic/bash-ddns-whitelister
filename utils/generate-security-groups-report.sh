#!/bin/bash
# Generate Security Groups CSV report
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

# Source cloud provider configurations
SCALEWAY_ENV="${REPO_DIR}/scaleway/.env"
AWS_ENV="${REPO_DIR}/aws/.env"
OVH_ENV="${REPO_DIR}/ovhcloud/.env"

total_groups=0

# ============================================================================
# SCALEWAY SECURITY GROUPS
# ============================================================================

echo -e "${MAGENTA}Checking Scaleway Security Groups...${NC}"

if [[ -f "$SCALEWAY_ENV" ]]; then
    source "$SCALEWAY_ENV"

    if [[ -n "$SCW_SECRET_KEY" ]] && [[ -n "$SCW_DEFAULT_ORGANIZATION_ID" ]]; then
        # List all zones to check
        ZONES=("fr-par-1" "fr-par-2" "fr-par-3" "nl-ams-1" "nl-ams-2" "pl-waw-1" "pl-waw-2")

        for zone in "${ZONES[@]}"; do
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

                    # Check which server manages this SG (from scaleway/update.sh)
                    script_host="1p.italic.fr"  # Default management server for Scaleway
                    cron_status="See $script_host"
                    comments="Managed via API script"

                    if [[ -z "$associated_servers" ]]; then
                        associated_servers="None"
                    fi

                    echo "Scaleway,${sg_id},${sg_name},${zone},${script_host},${cron_status},\"${associated_servers}\",${rules_count},\"${comments}\"" >> "$OUTPUT_FILE"
                    total_groups=$((total_groups + 1))

                    echo -e "  ${GREEN}✓${NC} $sg_name ($zone) - $rules_count rules"
                done
            fi
        done
    else
        echo -e "  ${YELLOW}⚠${NC} Scaleway credentials not configured"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Scaleway .env not found"
fi

# ============================================================================
# AWS SECURITY GROUPS
# ============================================================================

echo -e "${MAGENTA}Checking AWS Security Groups...${NC}"

if [[ -f "$AWS_ENV" ]]; then
    source "$AWS_ENV"

    if [[ -n "$AWS_ACCESS_KEY_ID" ]] && [[ -n "$AWS_SECRET_ACCESS_KEY" ]]; then
        # Extract unique regions from AWS_RULES or use AWS_DEFAULT_REGION
        declare -a REGIONS
        if [[ ${#AWS_RULES[@]} -gt 0 ]]; then
            # Extract regions from AWS_RULES (4th field)
            for rule_config in "${AWS_RULES[@]}"; do
                IFS='|' read -ra PARTS <<< "$rule_config"
                region="${PARTS[3]:-}"
                if [[ -n "$region" ]] && [[ ! " ${REGIONS[@]} " =~ " ${region} " ]]; then
                    REGIONS+=("$region")
                fi
            done
        else
            # Fallback to AWS_DEFAULT_REGION if no rules configured
            REGIONS=("${AWS_DEFAULT_REGION:-us-east-1}")
        fi

        echo -e "  ${CYAN}Scanning regions: ${REGIONS[*]}${NC}"

        for region in "${REGIONS[@]}"; do
            # Get security groups (using AWS CLI if available)
            if command -v aws &> /dev/null; then
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

                        script_host="TBD"  # To be determined based on which server manages AWS SG
                        cron_status="N/A"
                        comments="Managed via AWS API"

                        if [[ -z "$associated_servers" ]]; then
                            associated_servers="None"
                        fi

                        echo "AWS,${sg_id},${sg_name},${region},${script_host},${cron_status},\"${associated_servers}\",${rules_count},\"${comments}\"" >> "$OUTPUT_FILE"
                        total_groups=$((total_groups + 1))

                        echo -e "  ${GREEN}✓${NC} $sg_name ($region) - $rules_count rules"
                    done
                fi
            else
                echo -e "  ${YELLOW}⚠${NC} AWS CLI not installed"
            fi
        done
    else
        echo -e "  ${YELLOW}⚠${NC} AWS credentials not configured"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} AWS .env not found"
fi

# ============================================================================
# OVH EDGE NETWORK FIREWALL
# ============================================================================

echo -e "${MAGENTA}Checking OVH Edge Network Firewall...${NC}"

# OVH API call with authentication
ovh_api_call() {
    local method="$1"
    local endpoint="$2"
    local body="${3:-}"

    local url="https://eu.api.ovh.com/1.0${endpoint}"
    local timestamp=$(date +%s)

    # Calculate signature
    # Signature = "$1$" + SHA1_HEX(AS+"+"+CK+"+"+METHOD+"+"+QUERY+"+"+BODY+"+"+TSTAMP)
    local signature_data="${OVH_APPLICATION_SECRET}+${OVH_CONSUMER_KEY}+${method}+${url}+${body}+${timestamp}"
    local signature=$(echo -n "$signature_data" | sha1sum | awk '{print $1}')
    local full_signature="\$1\$${signature}"

    # Make API call
    curl -s -X "$method" \
        -H "X-Ovh-Application: ${OVH_APPLICATION_KEY}" \
        -H "X-Ovh-Consumer: ${OVH_CONSUMER_KEY}" \
        -H "X-Ovh-Timestamp: ${timestamp}" \
        -H "X-Ovh-Signature: ${full_signature}" \
        "$url"
}

if [[ -f "$OVH_ENV" ]]; then
    source "$OVH_ENV"

    if [[ -n "$OVH_APPLICATION_KEY" ]] && [[ -n "$OVH_APPLICATION_SECRET" ]] && [[ -n "$OVH_CONSUMER_KEY" ]]; then
        # Check if OVH_RULES array exists and has entries
        if [[ ${#OVH_RULES[@]} -gt 0 ]]; then
            # Process each IP in OVH_RULES
            for rule_config in "${OVH_RULES[@]}"; do
                # Parse rule: ip_address|identifier|hostname
                IFS='|' read -ra PARTS <<< "$rule_config"
                ovh_ip="${PARTS[0]}"
                rule_identifier="${PARTS[1]:-unknown}"
                rule_hostname="${PARTS[2]:-}"

                # Get firewall rules for this IP
                # OVH API uses URL-encoded IP (replace . with %2E)
                ovh_ip_encoded=$(echo "$ovh_ip" | sed 's/\./\%2E/g')
                rules_response=$(ovh_api_call "GET" "/ip/${ovh_ip_encoded}/firewall")

                # Count rules
                rules_count=$(echo "$rules_response" | jq -r '. | length' 2>/dev/null || echo "0")

                script_host="TBD"  # To be determined - which server runs the OVH update script
                cron_status="N/A"
                associated_servers="debug.not.live ($ovh_ip)"
                comments="Managed via OVH API - Hostname: $rule_hostname"

                echo "OVH,${ovh_ip},Edge Network Firewall,ovh-eu,${script_host},${cron_status},\"${associated_servers}\",${rules_count},\"${comments}\"" >> "$OUTPUT_FILE"
                total_groups=$((total_groups + 1))

                echo -e "  ${GREEN}✓${NC} OVH Edge Network Firewall ($ovh_ip) - $rules_count rules"
            done
        else
            echo -e "  ${YELLOW}⚠${NC} No OVH_RULES configured"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} OVH credentials not configured"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} OVH .env not found"
fi

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Report Generation Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total security groups: $total_groups"
echo -e "Output file: ${GREEN}$OUTPUT_FILE${NC}"
echo
echo "You can view the report with:"
echo "  cat $OUTPUT_FILE"
echo "  column -t -s',' $OUTPUT_FILE | less -S"
echo
