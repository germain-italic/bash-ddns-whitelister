#!/bin/bash
# Generate comprehensive CSV report for all servers
# Tests connectivity, deployment status, firewall configuration, etc.
# Usage: ./generate-report.sh [output.csv]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Create reports directory if it doesn't exist
REPORTS_DIR="${REPO_DIR}/reports"
mkdir -p "$REPORTS_DIR"

# Default output file with date
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
OUTPUT_FILE="${1:-${REPORTS_DIR}/server-report_${DATE}.csv}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Server Report Generator${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}ERROR: .env file not found${NC}"
    exit 1
fi

# Source the .env file
source "$ENV_FILE"

# Check if SERVERS array is defined
if [[ -z "${SERVERS[@]}" ]]; then
    echo -e "${RED}ERROR: SERVERS array not defined in .env${NC}"
    exit 1
fi

echo -e "${GREEN}Testing ${#SERVERS[@]} server(s)...${NC}"
echo -e "Output file: ${OUTPUT_FILE}"
echo

# CSV Header
cat > "$OUTPUT_FILE" << 'HEADER'
Hostname,Port,User,Firewall Type,SSH Connectivity,Script Installed,Cron Installed,SSH Key Deployed,NAS Can Connect,NAS Blocked,Firewall Active,Firewall Default Policy,OS Distribution,OS Version,Comments
HEADER

# Function to test SSH connectivity
test_ssh() {
    local host="$1"
    local port="$2"
    local user="$3"
    
    if timeout 5 ssh -p "$port" -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${user}@${host}" "echo OK" &>/dev/null; then
        echo "YES"
    else
        echo "NO"
    fi
}

# Function to check if script is installed
check_script_installed() {
    local host="$1"
    local port="$2"
    local user="$3"
    local fw_type="$4"

    local install_dir=""
    case "$fw_type" in
        iptables|plesk|ufw) install_dir="/root/bash-ddns-whitelister" ;;
        windows) install_dir="C:\\bash-windows-firewall-ddns" ;;
        none) echo "N/A"; return ;;
        *) echo "N/A"; return ;;
    esac

    if [[ "$fw_type" == "windows" ]]; then
        if ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" "powershell -Command \"Test-Path '$install_dir'\" 2>/dev/null" 2>/dev/null | grep -q "True"; then
            echo "YES"
        else
            echo "NO"
        fi
    else
        if ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" "[ -d '$install_dir' ]" 2>/dev/null; then
            echo "YES"
        else
            echo "NO"
        fi
    fi
}

# Function to check if cron is installed
check_cron() {
    local host="$1"
    local port="$2"
    local user="$3"
    local fw_type="$4"

    case "$fw_type" in
        windows)
            # Check for Windows scheduled task
            if ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" "powershell -Command \"Get-ScheduledTask -TaskName 'WindowsFirewallDDNS' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty TaskName\" 2>/dev/null" 2>/dev/null | grep -q "WindowsFirewallDDNS"; then
                echo "YES"
            else
                echo "NO"
            fi
            return
            ;;
        none) echo "N/A"; return ;;
        iptables|plesk|ufw)
            # Check ONLY for new unified repo (bash-ddns-whitelister)
            if ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" "crontab -l 2>/dev/null | grep -q 'bash-ddns-whitelister'" 2>/dev/null; then
                echo "YES"
            else
                echo "NO"
            fi
            ;;
        *) echo "N/A"; return ;;
    esac
}

# Function to check if SSH key is deployed
check_ssh_key() {
    local host="$1"
    local port="$2"
    local user="$3"
    
    local key_fingerprint="${LOCAL_SSH_PUBKEY%% *}"
    if ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" "grep -q '$key_fingerprint' ~/.ssh/authorized_keys 2>/dev/null" 2>/dev/null; then
        echo "YES"
    else
        echo "NO"
    fi
}

# Function to test NAS connectivity (from this machine, using ProxyJump)
test_nas_access() {
    local host="$1"
    local port="$2"
    local user="$3"
    
    if [[ -z "$NAS1_HOST" ]]; then
        echo "N/A"
        return
    fi
    
    # Try to connect from NAS to server (ProxyJump through NAS)
    if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ProxyJump="root@${NAS1_HOST}" \
        -p "$port" "${user}@${host}" "echo OK" &>/dev/null 2>&1; then
        echo "YES"
    else
        echo "NO"
    fi
}

# Function to get OS info
get_os_info() {
    local host="$1"
    local port="$2"
    local user="$3"
    local fw_type="$4"

    # For Windows, use PowerShell to get OS info
    if [[ "$fw_type" == "windows" ]]; then
        local os_info=$(ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" \
            "powershell -Command \"Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption\" 2>/dev/null; powershell -Command \"Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Version\" 2>/dev/null" 2>/dev/null)

        if [[ -n "$os_info" ]]; then
            local os_name=$(echo "$os_info" | head -1 | sed 's/Microsoft //')
            local os_version=$(echo "$os_info" | tail -1)
            echo "${os_name}|${os_version}"
        else
            echo "Windows|Unknown"
        fi
    else
        # For Linux, use /etc/os-release
        local os_info=$(ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" \
            "if [ -f /etc/os-release ]; then . /etc/os-release; echo \"\$NAME|\$VERSION_ID\"; else echo 'Unknown|Unknown'; fi" 2>/dev/null)

        if [[ -n "$os_info" ]]; then
            echo "$os_info"
        else
            echo "Unknown|Unknown"
        fi
    fi
}

# Function to check firewall status and default policy
check_firewall_status() {
    local host="$1"
    local port="$2"
    local user="$3"
    local fw_type="$4"
    
    case "$fw_type" in
        iptables)
            local fw_info=$(ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" \
                "iptables -L INPUT -n 2>/dev/null | head -1" 2>/dev/null)
            
            if [[ "$fw_info" =~ "policy DROP" ]]; then
                echo "ACTIVE|DROP"
            elif [[ "$fw_info" =~ "policy ACCEPT" ]]; then
                echo "ACTIVE|ACCEPT"
            elif [[ "$fw_info" =~ "policy REJECT" ]]; then
                echo "ACTIVE|REJECT"
            else
                echo "UNKNOWN|UNKNOWN"
            fi
            ;;
        plesk)
            local enabled=$(ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" \
                "plesk ext firewall --is-enabled 2>/dev/null && echo YES || echo NO" 2>/dev/null)
            echo "${enabled:-UNKNOWN}|N/A"
            ;;
        ufw)
            local status=$(ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" \
                "ufw status 2>/dev/null | head -1" 2>/dev/null)

            if [[ "$status" =~ "Status: active" ]]; then
                local policy=$(ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" \
                    "ufw status verbose 2>/dev/null | grep 'Default:' | head -1" 2>/dev/null)

                if [[ "$policy" =~ "deny (incoming)" ]]; then
                    echo "ACTIVE|DENY"
                else
                    echo "ACTIVE|UNKNOWN"
                fi
            else
                echo "INACTIVE|N/A"
            fi
            ;;
        windows)
            # Check Windows Firewall status
            local fw_status=$(ssh -p "$port" -o ConnectTimeout=5 "${user}@${host}" \
                "powershell -Command \"Get-NetFirewallProfile -Profile Domain,Public,Private | Where-Object { \\\$_.Enabled -eq 'True' } | Select-Object -ExpandProperty Name\" 2>/dev/null" 2>/dev/null)

            if [[ -n "$fw_status" ]]; then
                echo "ACTIVE|Enabled"
            else
                echo "INACTIVE|N/A"
            fi
            ;;
        none)
            echo "N/A|N/A"
            ;;
        *)
            echo "UNKNOWN|UNKNOWN"
            ;;
    esac
}

# Function to generate comments
generate_comments() {
    local fw_active="$1"
    local fw_policy="$2"
    local fw_type="$3"
    local ssh_ok="$4"
    local hostname="$5"

    local comments=""

    # Check for network-level firewall protection
    if [[ "$hostname" == "1p.italic.fr" ]] || [[ "$hostname" == "discourse.italic.fr" ]]; then
        comments="⚠️ Protected by Scaleway security group - API script needed for whitelist"
    elif [[ "$hostname" == "13.36.123.138" ]] || [[ "$hostname" == "43.198.96.78" ]]; then
        comments="⚠️ Protected by AWS security group - API script needed for whitelist"
    elif [[ "$hostname" == "debug.not.live" ]]; then
        comments="⚠️ Protected by OVH edge network firewall - API script needed for whitelist"
    fi

    # Check for security issues
    if [[ "$fw_policy" == "ACCEPT" ]]; then
        comments="${comments:+$comments; }⚠️ SECURITY: Default ACCEPT policy - server accepts all connections!"
    fi

    if [[ "$fw_active" == "INACTIVE" ]] && [[ "$fw_type" != "none" ]]; then
        comments="${comments:+$comments; }⚠️ Firewall installed but not active"
    fi

    if [[ "$ssh_ok" == "NO" ]]; then
        comments="${comments:+$comments; }Cannot connect - check SSH access"
    fi

    if [[ -z "$comments" ]]; then
        echo "OK"
    else
        echo "$comments"
    fi
}

# Process each server
total=0
for server_config in "${SERVERS[@]}"; do
    total=$((total + 1))
    
    # Parse server configuration
    IFS=':' read -ra PARTS <<< "$server_config"
    
    hostname="${PARTS[0]}"
    port="${PARTS[1]:-22}"
    user="${PARTS[2]:-root}"
    firewall_type="${PARTS[3]:-iptables}"
    skip_flag="${PARTS[4]:-}"
    
    echo -n "[$total/${#SERVERS[@]}] Testing $hostname... "
    
    # Skip if marked
    if [[ "$skip_flag" == "SKIP" ]]; then
        echo "SKIPPED"
        echo "$hostname,$port,$user,$firewall_type,SKIPPED,SKIPPED,SKIPPED,SKIPPED,SKIPPED,SKIPPED,SKIPPED,SKIPPED,SKIPPED,SKIPPED,Marked as SKIP" >> "$OUTPUT_FILE"
        continue
    fi
    
    # Test SSH connectivity first
    ssh_ok=$(test_ssh "$hostname" "$port" "$user")
    
    if [[ "$ssh_ok" == "NO" ]]; then
        echo "FAILED (no SSH)"
        echo "$hostname,$port,$user,$firewall_type,NO,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,N/A,Cannot connect via SSH" >> "$OUTPUT_FILE"
        continue
    fi
    
    # Run all tests in parallel for speed
    script_installed=$(check_script_installed "$hostname" "$port" "$user" "$firewall_type")
    cron_installed=$(check_cron "$hostname" "$port" "$user" "$firewall_type")
    ssh_key_deployed=$(check_ssh_key "$hostname" "$port" "$user")
    nas_can_connect=$(test_nas_access "$hostname" "$port" "$user")
    
    # NAS blocked is inverse of NAS can connect
    if [[ "$nas_can_connect" == "YES" ]]; then
        nas_blocked="NO"
    elif [[ "$nas_can_connect" == "NO" ]]; then
        nas_blocked="YES"
    else
        nas_blocked="N/A"
    fi
    
    os_info=$(get_os_info "$hostname" "$port" "$user" "$firewall_type")
    IFS='|' read -r os_distro os_version <<< "$os_info"
    
    fw_status=$(check_firewall_status "$hostname" "$port" "$user" "$firewall_type")
    IFS='|' read -r fw_active fw_policy <<< "$fw_status"

    comments=$(generate_comments "$fw_active" "$fw_policy" "$firewall_type" "$ssh_ok" "$hostname")
    
    # Write to CSV
    echo "$hostname,$port,$user,$firewall_type,$ssh_ok,$script_installed,$cron_installed,$ssh_key_deployed,$nas_can_connect,$nas_blocked,$fw_active,$fw_policy,\"$os_distro\",\"$os_version\",\"$comments\"" >> "$OUTPUT_FILE"
    
    echo "OK"
done

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Report Generation Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Tested servers: $total"
echo -e "Output file: ${GREEN}$OUTPUT_FILE${NC}"
echo
echo "You can view the report with:"
echo "  cat $OUTPUT_FILE"
echo "  column -t -s',' $OUTPUT_FILE | less -S"
echo
