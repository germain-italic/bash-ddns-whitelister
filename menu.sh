#!/bin/bash
# Interactive menu for bash-ddns-whitelister
# Provides a user-friendly TUI to access all repository features

set -e

# Colors and formatting
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Repository root
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Clear screen
clear_screen() {
    clear
}

# Print header
print_header() {
    clear_screen
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}${MAGENTA}bash-ddns-whitelister${NC} - Dynamic DNS Firewall Management       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Print menu option
print_option() {
    local num="$1"
    local text="$2"
    local color="${3:-$GREEN}"
    echo -e "  ${BOLD}${color}${num}.${NC} ${text}"
}

# Print separator
print_separator() {
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
}

# Wait for user input
wait_for_key() {
    echo
    echo -e "${YELLOW}Press any key to continue...${NC}"
    read -n 1 -s
}

# Main menu
show_main_menu() {
    print_header
    echo -e "${BOLD}Main Menu${NC}"
    print_separator
    echo
    print_option "1" "Deploy scripts to servers" "$GREEN"
    print_option "2" "Uninstall scripts from servers" "$RED"
    print_option "3" "View Configuration" "$CYAN"
    print_option "4" "Utilities & Tools" "$YELLOW"
    print_option "5" "Firewall Management" "$MAGENTA"
    print_option "6" "Verification & Testing" "$BLUE"
    print_option "7" "Documentation & Help" "$GREEN"
    echo
    print_separator
    print_option "0" "Exit" "$RED"
    echo
    echo -n "Select an option: "
    read choice

    case $choice in
        1) deployment_menu ;;
        2) uninstall_menu ;;
        3) configuration_menu ;;
        4) utilities_menu ;;
        5) firewall_menu ;;
        6) verification_menu ;;
        7) documentation_menu ;;
        0) exit 0 ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            wait_for_key
            show_main_menu
            ;;
    esac
}

# Deployment menu
deployment_menu() {
    print_header
    echo -e "${BOLD}${GREEN}Deployment Menu${NC}"
    print_separator
    echo
    print_option "1" "Deploy to iptables servers" "$GREEN"
    print_option "2" "Deploy to Plesk servers" "$GREEN"
    print_option "3" "Deploy to UFW servers" "$GREEN"
    print_option "4" "Deploy to Scaleway Security Groups" "$GREEN"
    print_option "5" "Deploy to AWS Security Groups" "$GREEN"
    print_option "6" "Deploy to OVH Edge Network Firewall" "$GREEN"
    print_option "7" "Detect firewall types on all servers" "$CYAN"
    print_option "8" "Deploy SSH keys to servers" "$CYAN"
    echo
    print_separator
    print_option "0" "Back to main menu" "$YELLOW"
    echo
    echo -n "Select an option: "
    read choice

    case $choice in
        1) deploy_iptables ;;
        2) deploy_plesk ;;
        3) deploy_ufw ;;
        4) deploy_scaleway ;;
        5) deploy_aws ;;
        6) deploy_ovh ;;
        7) detect_firewalls ;;
        8) deploy_ssh_keys ;;
        0) show_main_menu ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            wait_for_key
            deployment_menu
            ;;
    esac
}

# Uninstall menu
uninstall_menu() {
    print_header
    echo -e "${BOLD}${RED}Uninstall Menu${NC}"
    print_separator
    echo
    echo -e "${YELLOW}⚠ Warning: This will remove DDNS scripts and firewall rules${NC}"
    echo
    print_option "1" "Uninstall from all servers" "$RED"
    print_option "2" "Uninstall from iptables servers" "$RED"
    print_option "3" "Uninstall from Plesk servers" "$RED"
    print_option "4" "Uninstall from UFW servers" "$RED"
    print_option "5" "Uninstall from specific server" "$RED"
    echo
    print_separator
    print_option "0" "Back to main menu" "$YELLOW"
    echo
    echo -n "Select an option: "
    read choice

    case $choice in
        1) uninstall_all ;;
        2) uninstall_iptables ;;
        3) uninstall_plesk ;;
        4) uninstall_ufw ;;
        5) uninstall_specific ;;
        0) show_main_menu ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            wait_for_key
            uninstall_menu
            ;;
    esac
}

# Configuration menu
configuration_menu() {
    print_header
    echo -e "${BOLD}${CYAN}View Configuration${NC}"
    print_separator
    echo
    print_option "1" "View utils/.env (servers & SSH keys)" "$CYAN"
    print_option "2" "View iptables/.env (DNS settings)" "$CYAN"
    print_option "3" "View plesk/.env (DNS settings)" "$CYAN"
    print_option "4" "View ufw/.env (DNS settings)" "$CYAN"
    print_option "5" "View all .env files summary" "$GREEN"
    echo
    print_separator
    print_option "0" "Back to main menu" "$YELLOW"
    echo
    echo -n "Select an option: "
    read choice

    case $choice in
        1) view_utils_env ;;
        2) view_iptables_env ;;
        3) view_plesk_env ;;
        4) view_ufw_env ;;
        5) view_all_env_summary ;;
        0) show_main_menu ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            wait_for_key
            configuration_menu
            ;;
    esac
}

# Utilities menu
utilities_menu() {
    print_header
    echo -e "${BOLD}${CYAN}Utilities & Tools${NC}"
    print_separator
    echo
    print_option "1" "Detect firewall types on servers" "$CYAN"
    print_option "2" "Deploy SSH keys to servers" "$CYAN"
    print_option "3" "Test connectivity from NAS" "$CYAN"
    print_option "4" "Verify cron cleanup" "$CYAN"
    print_option "5" "Test NAS blocking on all servers" "$CYAN"
    print_option "6" "Clean old cron entries from servers" "$CYAN"
    print_option "7" "Update repos on all servers" "$CYAN"
    print_option "8" "Redeploy to all servers" "$CYAN"
    print_option "9" "Deploy to missing servers" "$CYAN"
    print_option "10" "Generate deployment report (CSV)" "$GREEN"
    echo
    print_separator
    print_option "0" "Back to main menu" "$YELLOW"
    echo
    echo -n "Select an option: "
    read choice

    case $choice in
        1) detect_firewalls ;;
        2) deploy_ssh_keys ;;
        3) test_connectivity ;;
        4) verify_cron ;;
        5) test_nas_blocking ;;
        6) clean_old_crons ;;
        7) update_all_repos ;;
        8) redeploy_all ;;
        9) deploy_missing ;;
        10) generate_report ;;
        0) show_main_menu ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            wait_for_key
            utilities_menu
            ;;
    esac
}

# Firewall menu
firewall_menu() {
    print_header
    echo -e "${BOLD}${YELLOW}Firewall Management${NC}"
    print_separator
    echo
    echo -e "${CYAN}Server-level Firewalls:${NC}"
    echo
    print_option "1" "iptables - View configuration" "$YELLOW"
    print_option "2" "Plesk - View configuration" "$YELLOW"
    print_option "3" "UFW - View configuration" "$YELLOW"
    echo
    echo -e "${CYAN}Cloud Provider APIs:${NC}"
    echo
    print_option "4" "Scaleway - View configuration" "$MAGENTA"
    print_option "5" "AWS - View configuration" "$MAGENTA"
    print_option "6" "OVH - View configuration" "$MAGENTA"
    echo
    print_separator
    print_option "0" "Back to main menu" "$YELLOW"
    echo
    echo -n "Select an option: "
    read choice

    case $choice in
        1) show_iptables_config ;;
        2) show_plesk_config ;;
        3) show_ufw_config ;;
        4) show_scaleway_config ;;
        5) show_aws_config ;;
        6) show_ovh_config ;;
        0) show_main_menu ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            wait_for_key
            firewall_menu
            ;;
    esac
}

# Verification menu
verification_menu() {
    print_header
    echo -e "${BOLD}${BLUE}Verification & Testing${NC}"
    print_separator
    echo
    print_option "1" "Verify cron jobs installed on servers" "$BLUE"
    print_option "2" "Verify cron cleanup on all servers" "$BLUE"
    print_option "3" "Test NAS blocking on all servers" "$BLUE"
    print_option "4" "Test connectivity from NAS" "$BLUE"
    print_option "5" "Check DNS resolution" "$BLUE"
    print_option "6" "Generate comprehensive server report (CSV)" "$GREEN"
    print_option "7" "View deployment status" "$BLUE"
    echo
    print_separator
    print_option "0" "Back to main menu" "$YELLOW"
    echo
    echo -n "Select an option: "
    read choice

    case $choice in
        1) verify_cron_installed ;;
        2) verify_cron ;;
        3) test_nas_blocking ;;
        4) test_connectivity ;;
        5) check_dns ;;
        6) generate_report ;;
        7) view_status ;;
        0) show_main_menu ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            wait_for_key
            verification_menu
            ;;
    esac
}

# Documentation menu
documentation_menu() {
    print_header
    echo -e "${BOLD}${MAGENTA}Documentation & Help${NC}"
    print_separator
    echo
    print_option "1" "View README" "$MAGENTA"
    print_option "2" "View CLAUDE.md (Architecture)" "$MAGENTA"
    print_option "3" "View iptables documentation" "$MAGENTA"
    print_option "4" "View Plesk documentation" "$MAGENTA"
    print_option "5" "View UFW documentation" "$MAGENTA"
    print_option "6" "View security best practices" "$MAGENTA"
    echo
    print_separator
    print_option "0" "Back to main menu" "$YELLOW"
    echo
    echo -n "Select an option: "
    read choice

    case $choice in
        1) view_readme ;;
        2) view_claude_md ;;
        3) view_iptables_docs ;;
        4) view_plesk_docs ;;
        5) view_ufw_docs ;;
        6) view_security_docs ;;
        0) show_main_menu ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            wait_for_key
            documentation_menu
            ;;
    esac
}

# ============================================================================
# Configuration viewing functions
# ============================================================================

# View utils/.env
view_utils_env() {
    print_header
    echo -e "${BOLD}${CYAN}Utils Configuration (utils/.env)${NC}"
    print_separator
    echo

    if [ ! -f "${REPO_DIR}/utils/.env" ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        echo
        echo "This file contains:"
        echo "  • Server list (SERVERS array)"
        echo "  • NAS SSH configuration (NAS1_HOST, NAS1_USER, NAS1_PUBKEY)"
        echo "  • Local SSH public key (LOCAL_SSH_PUBKEY)"
        echo
        echo "Create it from utils/.env.dist template"
        wait_for_key
        configuration_menu
        return
    fi

    source "${REPO_DIR}/utils/.env"

    echo -e "${GREEN}NAS Configuration:${NC}"
    echo "  NAS1_HOST:    ${NAS1_HOST:-not set}"
    echo "  NAS1_USER:    ${NAS1_USER:-not set}"
    echo "  NAS1_PUBKEY:  ${NAS1_PUBKEY:0:50}..." # Show first 50 chars
    echo
    echo -e "${GREEN}Local SSH Key:${NC}"
    echo "  LOCAL_SSH_PUBKEY: ${LOCAL_SSH_PUBKEY:0:50}..."
    echo
    echo -e "${GREEN}Server List (${#SERVERS[@]} servers):${NC}"
    echo
    printf "  %-4s %-35s %-6s %-8s %-10s\n" "No" "Hostname" "Port" "User" "Firewall"
    echo "  ────────────────────────────────────────────────────────────────────"

    local idx=1
    for server_config in "${SERVERS[@]}"; do
        IFS=':' read -ra PARTS <<< "$server_config"
        local hostname="${PARTS[0]}"
        local port="${PARTS[1]:-22}"
        local user="${PARTS[2]:-root}"
        local firewall_type="${PARTS[3]:-iptables}"
        local skip_flag="${PARTS[4]:-}"

        if [[ "$skip_flag" == "SKIP" ]]; then
            hostname="$hostname (SKIP)"
        fi

        printf "  %-4s %-35s %-6s %-8s %-10s\n" "$idx" "$hostname" "$port" "$user" "$firewall_type"
        idx=$((idx + 1))
    done

    wait_for_key
    configuration_menu
}

# View iptables/.env
view_iptables_env() {
    print_header
    echo -e "${BOLD}${CYAN}iptables Configuration (iptables/.env)${NC}"
    print_separator
    echo

    if [ ! -f "${REPO_DIR}/iptables/.env" ]; then
        echo -e "${RED}ERROR: iptables/.env not found${NC}"
        echo
        echo "This file should contain:"
        echo "  • DNS_NAMESERVER (for hostname resolution)"
        echo "  • LOG_ROTATION_HOURS (log retention)"
        echo "  • Optional hostname references"
        echo
        echo "Create it from iptables/.env.dist template"
        wait_for_key
        configuration_menu
        return
    fi

    # Read the file and display key settings
    echo -e "${GREEN}DNS Configuration:${NC}"
    grep "^DNS_NAMESERVER=" "${REPO_DIR}/iptables/.env" 2>/dev/null || echo "  DNS_NAMESERVER: not set"
    echo
    echo -e "${GREEN}Log Settings:${NC}"
    grep "^LOG_ROTATION_HOURS=" "${REPO_DIR}/iptables/.env" 2>/dev/null || echo "  LOG_ROTATION_HOURS: not set"
    echo
    echo -e "${GREEN}Hostname References (optional):${NC}"
    grep "HOSTNAME=" "${REPO_DIR}/iptables/.env" 2>/dev/null | head -5 || echo "  (none defined)"
    echo
    echo -e "${CYAN}Full file content:${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    cat "${REPO_DIR}/iptables/.env"
    echo "────────────────────────────────────────────────────────────────────"

    wait_for_key
    configuration_menu
}

# View plesk/.env
view_plesk_env() {
    print_header
    echo -e "${BOLD}${CYAN}Plesk Configuration (plesk/.env)${NC}"
    print_separator
    echo

    if [ ! -f "${REPO_DIR}/plesk/.env" ]; then
        echo -e "${RED}ERROR: plesk/.env not found${NC}"
        echo
        echo "This file should contain:"
        echo "  • DNS_NAMESERVER (for hostname resolution)"
        echo "  • LOG_ROTATION_HOURS (log retention)"
        echo "  • Optional hostname references"
        echo
        echo "Create it from plesk/.env.dist template"
        wait_for_key
        configuration_menu
        return
    fi

    echo -e "${GREEN}DNS Configuration:${NC}"
    grep "^DNS_NAMESERVER=" "${REPO_DIR}/plesk/.env" 2>/dev/null || echo "  DNS_NAMESERVER: not set"
    echo
    echo -e "${GREEN}Log Settings:${NC}"
    grep "^LOG_ROTATION_HOURS=" "${REPO_DIR}/plesk/.env" 2>/dev/null || echo "  LOG_ROTATION_HOURS: not set"
    echo
    echo -e "${GREEN}Hostname References (optional):${NC}"
    grep "HOSTNAME=" "${REPO_DIR}/plesk/.env" 2>/dev/null | head -5 || echo "  (none defined)"
    echo
    echo -e "${CYAN}Full file content:${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    cat "${REPO_DIR}/plesk/.env"
    echo "────────────────────────────────────────────────────────────────────"

    wait_for_key
    configuration_menu
}

# View ufw/.env
view_ufw_env() {
    print_header
    echo -e "${BOLD}${CYAN}UFW Configuration (ufw/.env)${NC}"
    print_separator
    echo

    if [ ! -f "${REPO_DIR}/ufw/.env" ]; then
        echo -e "${RED}ERROR: ufw/.env not found${NC}"
        echo
        echo "This file should contain:"
        echo "  • DNS_NAMESERVER (for hostname resolution)"
        echo "  • LOG_ROTATION_HOURS (log retention)"
        echo "  • Optional hostname references"
        echo
        echo "Create it from ufw/.env.dist template"
        wait_for_key
        configuration_menu
        return
    fi

    echo -e "${GREEN}DNS Configuration:${NC}"
    grep "^DNS_NAMESERVER=" "${REPO_DIR}/ufw/.env" 2>/dev/null || echo "  DNS_NAMESERVER: not set"
    echo
    echo -e "${GREEN}Log Settings:${NC}"
    grep "^LOG_ROTATION_HOURS=" "${REPO_DIR}/ufw/.env" 2>/dev/null || echo "  LOG_ROTATION_HOURS: not set"
    echo
    echo -e "${GREEN}Hostname References (optional):${NC}"
    grep "HOSTNAME=" "${REPO_DIR}/ufw/.env" 2>/dev/null | head -5 || echo "  (none defined)"
    echo
    echo -e "${CYAN}Full file content:${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    cat "${REPO_DIR}/ufw/.env"
    echo "────────────────────────────────────────────────────────────────────"

    wait_for_key
    configuration_menu
}

# View all .env summary
view_all_env_summary() {
    print_header
    echo -e "${BOLD}${CYAN}All Configuration Summary${NC}"
    print_separator
    echo

    # Utils .env
    echo -e "${BOLD}${GREEN}1. Utils Configuration${NC} (utils/.env)"
    echo "   Purpose: Server list, SSH keys, NAS configuration"
    if [ -f "${REPO_DIR}/utils/.env" ]; then
        source "${REPO_DIR}/utils/.env"
        echo -e "   ${GREEN}✓ Found${NC}"
        echo "     - Servers: ${#SERVERS[@]}"
        echo "     - NAS Host: ${NAS1_HOST:-not set}"
        echo "     - NAS User: ${NAS1_USER:-not set}"
    else
        echo -e "   ${RED}✗ Not found${NC}"
    fi
    echo

    # iptables .env
    echo -e "${BOLD}${GREEN}2. iptables Configuration${NC} (iptables/.env)"
    echo "   Purpose: DNS nameserver, log rotation for iptables servers"
    if [ -f "${REPO_DIR}/iptables/.env" ]; then
        echo -e "   ${GREEN}✓ Found${NC}"
        local dns=$(grep "^DNS_NAMESERVER=" "${REPO_DIR}/iptables/.env" 2>/dev/null | cut -d'=' -f2)
        local log=$(grep "^LOG_ROTATION_HOURS=" "${REPO_DIR}/iptables/.env" 2>/dev/null | cut -d'=' -f2)
        echo "     - DNS Nameserver: ${dns:-not set}"
        echo "     - Log Rotation: ${log:-not set} hours"
    else
        echo -e "   ${RED}✗ Not found${NC}"
    fi
    echo

    # plesk .env
    echo -e "${BOLD}${GREEN}3. Plesk Configuration${NC} (plesk/.env)"
    echo "   Purpose: DNS nameserver, log rotation for Plesk servers"
    if [ -f "${REPO_DIR}/plesk/.env" ]; then
        echo -e "   ${GREEN}✓ Found${NC}"
        local dns=$(grep "^DNS_NAMESERVER=" "${REPO_DIR}/plesk/.env" 2>/dev/null | cut -d'=' -f2)
        local log=$(grep "^LOG_ROTATION_HOURS=" "${REPO_DIR}/plesk/.env" 2>/dev/null | cut -d'=' -f2)
        echo "     - DNS Nameserver: ${dns:-not set}"
        echo "     - Log Rotation: ${log:-not set} hours"
    else
        echo -e "   ${RED}✗ Not found${NC}"
    fi
    echo

    # ufw .env
    echo -e "${BOLD}${GREEN}4. UFW Configuration${NC} (ufw/.env)"
    echo "   Purpose: DNS nameserver, log rotation for UFW servers"
    if [ -f "${REPO_DIR}/ufw/.env" ]; then
        echo -e "   ${GREEN}✓ Found${NC}"
        local dns=$(grep "^DNS_NAMESERVER=" "${REPO_DIR}/ufw/.env" 2>/dev/null | cut -d'=' -f2)
        local log=$(grep "^LOG_ROTATION_HOURS=" "${REPO_DIR}/ufw/.env" 2>/dev/null | cut -d'=' -f2)
        echo "     - DNS Nameserver: ${dns:-not set}"
        echo "     - Log Rotation: ${log:-not set} hours"
    else
        echo -e "   ${RED}✗ Not found${NC}"
    fi
    echo

    print_separator
    echo -e "${YELLOW}Note: All .env files are gitignored (contain sensitive data)${NC}"
    echo -e "${YELLOW}Create them from corresponding .env.dist templates${NC}"

    wait_for_key
    configuration_menu
}

# ============================================================================
# Action functions
# ============================================================================

# Deploy to iptables servers
deploy_iptables() {
    print_header
    echo -e "${BOLD}${GREEN}Deploy to iptables Servers${NC}"
    print_separator
    echo
    echo "Enter server hostname (or press Enter to cancel):"
    read hostname

    if [ -z "$hostname" ]; then
        deployment_menu
        return
    fi

    echo "Enter SSH port [default: 22]:"
    read port
    port=${port:-22}

    echo "Enter SSH user [default: root]:"
    read user
    user=${user:-root}

    echo
    echo -e "${CYAN}Deploying to ${hostname}:${port} as ${user}...${NC}"
    cd "${REPO_DIR}/iptables"
    ./deploy.sh "$hostname" "$port" "$user"

    wait_for_key
    deployment_menu
}

# Deploy to Plesk servers
deploy_plesk() {
    print_header
    echo -e "${BOLD}${GREEN}Deploy to Plesk Servers${NC}"
    print_separator
    echo
    echo "Enter server hostname (or press Enter to cancel):"
    read hostname

    if [ -z "$hostname" ]; then
        deployment_menu
        return
    fi

    echo "Enter SSH port [default: 22]:"
    read port
    port=${port:-22}

    echo "Enter SSH user [default: root]:"
    read user
    user=${user:-root}

    echo
    echo -e "${CYAN}Deploying to ${hostname}:${port} as ${user}...${NC}"
    cd "${REPO_DIR}/plesk"
    ./deploy.sh "$hostname" "$port" "$user"

    wait_for_key
    deployment_menu
}

# Deploy to UFW servers
deploy_ufw() {
    print_header
    echo -e "${BOLD}${GREEN}Deploy to UFW Servers${NC}"
    print_separator
    echo
    echo "Enter server hostname (or press Enter to cancel):"
    read hostname

    if [ -z "$hostname" ]; then
        deployment_menu
        return
    fi

    echo "Enter SSH port [default: 22]:"
    read port
    port=${port:-22}

    echo "Enter SSH user [default: root]:"
    read user
    user=${user:-root}

    echo
    echo -e "${CYAN}Deploying to ${hostname}:${port} as ${user}...${NC}"
    cd "${REPO_DIR}/ufw"
    ./deploy.sh "$hostname" "$port" "$user"

    wait_for_key
    deployment_menu
}

# Deploy to Scaleway Security Groups
deploy_scaleway() {
    print_header
    echo -e "${BOLD}${GREEN}Deploy to Scaleway Security Groups${NC}"
    print_separator
    echo
    echo "Enter server hostname (or press Enter to cancel):"
    read hostname

    if [ -z "$hostname" ]; then
        deployment_menu
        return
    fi

    echo "Enter SSH port [default: 22]:"
    read port
    port=${port:-22}

    echo "Enter SSH user [default: root]:"
    read user
    user=${user:-root}

    echo
    echo -e "${CYAN}Deploying to ${hostname}:${port} as ${user}...${NC}"
    cd "${REPO_DIR}/scaleway"
    ./deploy.sh "$hostname" "$port" "$user"

    wait_for_key
    deployment_menu
}

# Deploy to AWS Security Groups
deploy_aws() {
    print_header
    echo -e "${BOLD}${GREEN}Deploy to AWS Security Groups${NC}"
    print_separator
    echo
    echo "Enter server hostname (or press Enter to cancel):"
    read hostname

    if [ -z "$hostname" ]; then
        deployment_menu
        return
    fi

    echo "Enter SSH port [default: 22]:"
    read port
    port=${port:-22}

    echo "Enter SSH user [default: root]:"
    read user
    user=${user:-root}

    echo
    echo -e "${CYAN}Deploying to ${hostname}:${port} as ${user}...${NC}"
    cd "${REPO_DIR}/aws"
    ./deploy.sh "$hostname" "$port" "$user"

    wait_for_key
    deployment_menu
}

# Deploy to OVH Edge Network Firewall
deploy_ovh() {
    print_header
    echo -e "${BOLD}${GREEN}Deploy to OVH Edge Network Firewall${NC}"
    print_separator
    echo
    echo "Enter server hostname (or press Enter to cancel):"
    read hostname

    if [ -z "$hostname" ]; then
        deployment_menu
        return
    fi

    echo "Enter SSH port [default: 22]:"
    read port
    port=${port:-22}

    echo "Enter SSH user [default: root]:"
    read user
    user=${user:-root}

    echo
    echo -e "${CYAN}Deploying to ${hostname}:${port} as ${user}...${NC}"
    cd "${REPO_DIR}/ovhcloud"
    ./deploy.sh "$hostname" "$port" "$user"

    wait_for_key
    deployment_menu
}

# Detect firewalls
detect_firewalls() {
    print_header
    echo -e "${BOLD}${CYAN}Detect Firewall Types${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        echo "Please create utils/.env from utils/.env.dist first"
        wait_for_key
        utilities_menu
        return
    fi

    ./detect-firewall.sh

    wait_for_key
    utilities_menu
}

# Deploy SSH keys
deploy_ssh_keys() {
    print_header
    echo -e "${BOLD}${CYAN}Deploy SSH Keys${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        echo "Please create utils/.env from utils/.env.dist first"
        wait_for_key
        utilities_menu
        return
    fi

    ./deploy-ssh-keys.sh

    wait_for_key
    utilities_menu
}

# Uninstall from all servers
uninstall_all() {
    print_header
    echo -e "${BOLD}${RED}Uninstall from All Servers${NC}"
    print_separator
    echo
    echo -e "${YELLOW}⚠ This will uninstall DDNS scripts from ALL servers!${NC}"
    echo
    echo "Are you sure? (yes/no):"
    read confirm

    if [ "$confirm" != "yes" ]; then
        echo "Cancelled."
        wait_for_key
        uninstall_menu
        return
    fi

    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        uninstall_menu
        return
    fi

    ./uninstall-all.sh

    wait_for_key
    uninstall_menu
}

# Uninstall from iptables servers
uninstall_iptables() {
    print_header
    echo -e "${BOLD}${RED}Uninstall from iptables Server${NC}"
    print_separator
    echo
    echo "Enter server hostname (or press Enter to cancel):"
    read hostname

    if [ -z "$hostname" ]; then
        uninstall_menu
        return
    fi

    echo "Enter SSH port [default: 22]:"
    read port
    port=${port:-22}

    echo "Enter SSH user [default: root]:"
    read user
    user=${user:-root}

    echo
    echo -e "${YELLOW}⚠ Uninstalling from ${hostname}:${port}...${NC}"
    cd "${REPO_DIR}/iptables"
    ./uninstall.sh "$hostname" "$port" "$user"

    wait_for_key
    uninstall_menu
}

# Uninstall from Plesk servers
uninstall_plesk() {
    print_header
    echo -e "${BOLD}${RED}Uninstall from Plesk Server${NC}"
    print_separator
    echo
    echo "Enter server hostname (or press Enter to cancel):"
    read hostname

    if [ -z "$hostname" ]; then
        uninstall_menu
        return
    fi

    echo "Enter SSH port [default: 22]:"
    read port
    port=${port:-22}

    echo "Enter SSH user [default: root]:"
    read user
    user=${user:-root}

    echo
    echo -e "${YELLOW}⚠ Uninstalling from ${hostname}:${port}...${NC}"
    cd "${REPO_DIR}/plesk"
    ./uninstall.sh "$hostname" "$port" "$user"

    wait_for_key
    uninstall_menu
}

# Uninstall from UFW servers
uninstall_ufw() {
    print_header
    echo -e "${BOLD}${RED}Uninstall from UFW Server${NC}"
    print_separator
    echo
    echo "Enter server hostname (or press Enter to cancel):"
    read hostname

    if [ -z "$hostname" ]; then
        uninstall_menu
        return
    fi

    echo "Enter SSH port [default: 22]:"
    read port
    port=${port:-22}

    echo "Enter SSH user [default: root]:"
    read user
    user=${user:-root}

    echo
    echo -e "${YELLOW}⚠ Uninstalling from ${hostname}:${port}...${NC}"
    cd "${REPO_DIR}/ufw"
    ./uninstall.sh "$hostname" "$port" "$user"

    wait_for_key
    uninstall_menu
}

# Uninstall from specific server
uninstall_specific() {
    print_header
    echo -e "${BOLD}${RED}Uninstall from Specific Server${NC}"
    print_separator
    echo
    echo "Select firewall type:"
    echo "  1. iptables"
    echo "  2. Plesk"
    echo "  3. UFW"
    echo
    echo -n "Choice: "
    read fw_choice

    case $fw_choice in
        1) uninstall_iptables ;;
        2) uninstall_plesk ;;
        3) uninstall_ufw ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            wait_for_key
            uninstall_menu
            ;;
    esac
}

# Test connectivity
test_connectivity() {
    print_header
    echo -e "${BOLD}${CYAN}Test Connectivity from NAS${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        utilities_menu
        return
    fi

    echo "Enter server list (format: server1:port:user server2:port:user):"
    read servers

    if [ -z "$servers" ]; then
        echo "Cancelled."
        wait_for_key
        utilities_menu
        return
    fi

    ./test-nas-connectivity.sh $servers

    wait_for_key
    utilities_menu
}

# Verify cron jobs installed
verify_cron_installed() {
    print_header
    echo -e "${BOLD}${BLUE}Verify Cron Jobs Installed${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        verification_menu
        return
    fi

    ./verify-cron-installed.sh

    wait_for_key
    verification_menu
}

# Verify cron cleanup
verify_cron() {
    print_header
    echo -e "${BOLD}${BLUE}Verify Cron Cleanup${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        verification_menu
        return
    fi

    ./verify-cron-cleanup.sh

    wait_for_key
    verification_menu
}

# Test NAS blocking
test_nas_blocking() {
    print_header
    echo -e "${BOLD}${BLUE}Test NAS Blocking${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        verification_menu
        return
    fi

    ./test-nas-blocking.sh

    wait_for_key
    verification_menu
}

# Check DNS resolution
check_dns() {
    print_header
    echo -e "${BOLD}${BLUE}Check DNS Resolution${NC}"
    print_separator
    echo
    echo "Enter hostname to resolve:"
    read hostname

    if [ -z "$hostname" ]; then
        verification_menu
        return
    fi

    echo
    echo -e "${CYAN}Resolving ${hostname}...${NC}"
    echo
    dig +short @1.1.1.1 "$hostname" A

    wait_for_key
    verification_menu
}

# Generate comprehensive report
generate_report() {
    print_header
    echo -e "${BOLD}${GREEN}Generate Comprehensive Server Report${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        verification_menu
        return
    fi

    echo -e "${CYAN}This will test all servers and generate a CSV report with:${NC}"
    echo "  • SSH connectivity"
    echo "  • Script installation status"
    echo "  • Cron job status"
    echo "  • SSH key deployment"
    echo "  • NAS connectivity"
    echo "  • Firewall status and policy"
    echo "  • OS distribution and version"
    echo "  • Security warnings"
    echo
    echo -e "${YELLOW}This may take a few minutes...${NC}"
    echo

    ./generate-report.sh

    echo
    echo -e "${GREEN}Report generated successfully!${NC}"
    echo
    echo "View the latest report with:"
    echo "  ls -lt ${REPO_DIR}/reports/ | head -5"
    echo
    echo "Or view in columns:"
    echo "  column -t -s',' \$(ls -t ${REPO_DIR}/reports/*.csv | head -1) | less -S"

    wait_for_key
    verification_menu
}

# View deployment status
view_status() {
    print_header
    echo -e "${BOLD}${BLUE}Deployment Status${NC}"
    print_separator
    echo

    # Show latest report if available
    latest_report=$(ls -t "${REPO_DIR}/reports"/*.csv 2>/dev/null | head -1)

    if [ -n "$latest_report" ]; then
        echo -e "${GREEN}Latest report: $(basename "$latest_report")${NC}"
        echo
        column -t -s',' "$latest_report" | less -S
    else
        echo -e "${YELLOW}No reports found${NC}"
        echo "Generate a report first using option 6 in Verification & Testing menu"
    fi

    wait_for_key
    verification_menu
}

# Show iptables configuration
show_iptables_config() {
    print_header
    echo -e "${BOLD}${YELLOW}iptables Configuration${NC}"
    print_separator
    echo
    echo "Template files:"
    echo "  - ${REPO_DIR}/iptables/.env.dist"
    echo "  - ${REPO_DIR}/iptables/dyndns_rules.conf.dist"
    echo
    echo "View:"
    echo "  1. .env.dist template"
    echo "  2. dyndns_rules.conf.dist template"
    echo "  0. Back"
    echo
    echo -n "Choice: "
    read choice

    case $choice in
        1) less "${REPO_DIR}/iptables/.env.dist" ;;
        2) less "${REPO_DIR}/iptables/dyndns_rules.conf.dist" ;;
        0) firewall_menu ; return ;;
    esac

    wait_for_key
    show_iptables_config
}

# Show Plesk configuration
show_plesk_config() {
    print_header
    echo -e "${BOLD}${YELLOW}Plesk Configuration${NC}"
    print_separator
    echo
    echo "Template files:"
    echo "  - ${REPO_DIR}/plesk/.env.dist"
    echo "  - ${REPO_DIR}/plesk/firewall_rules.conf.dist"
    echo
    echo "View:"
    echo "  1. .env.dist template"
    echo "  2. firewall_rules.conf.dist template"
    echo "  0. Back"
    echo
    echo -n "Choice: "
    read choice

    case $choice in
        1) less "${REPO_DIR}/plesk/.env.dist" ;;
        2) less "${REPO_DIR}/plesk/firewall_rules.conf.dist" ;;
        0) firewall_menu ; return ;;
    esac

    wait_for_key
    show_plesk_config
}

# Show UFW configuration
show_ufw_config() {
    print_header
    echo -e "${BOLD}${YELLOW}UFW Configuration${NC}"
    print_separator
    echo
    echo "Template files:"
    echo "  - ${REPO_DIR}/ufw/.env.dist"
    echo "  - ${REPO_DIR}/ufw/ufw_rules.conf.dist"
    echo
    echo "View:"
    echo "  1. .env.dist template"
    echo "  2. ufw_rules.conf.dist template"
    echo "  0. Back"
    echo
    echo -n "Choice: "
    read choice

    case $choice in
        1) less "${REPO_DIR}/ufw/.env.dist" ;;
        2) less "${REPO_DIR}/ufw/ufw_rules.conf.dist" ;;
        0) firewall_menu ; return ;;
    esac

    wait_for_key
    show_ufw_config
}

# View README
view_readme() {
    print_header
    echo -e "${BOLD}${MAGENTA}README${NC}"
    print_separator
    echo
    less "${REPO_DIR}/README.md"
    wait_for_key
    documentation_menu
}

# View CLAUDE.md
view_claude_md() {
    print_header
    echo -e "${BOLD}${MAGENTA}CLAUDE.md - Architecture Guide${NC}"
    print_separator
    echo
    less "${REPO_DIR}/CLAUDE.md"
    wait_for_key
    documentation_menu
}

# View iptables docs
view_iptables_docs() {
    print_header
    echo -e "${BOLD}${MAGENTA}iptables Documentation${NC}"
    print_separator
    echo
    less "${REPO_DIR}/iptables/README.md"
    wait_for_key
    documentation_menu
}

# View Plesk docs
view_plesk_docs() {
    print_header
    echo -e "${BOLD}${MAGENTA}Plesk Documentation${NC}"
    print_separator
    echo
    less "${REPO_DIR}/plesk/README.md"
    wait_for_key
    documentation_menu
}

# View UFW docs
view_ufw_docs() {
    print_header
    echo -e "${BOLD}${MAGENTA}UFW Documentation${NC}"
    print_separator
    echo
    less "${REPO_DIR}/ufw/README.md"
    wait_for_key
    documentation_menu
}

# View security docs
view_security_docs() {
    print_header
    echo -e "${BOLD}${MAGENTA}Security Best Practices${NC}"
    print_separator
    echo
    echo -e "${GREEN}✓ Security Features:${NC}"
    echo "  • All firewall rules tagged with [bash-ddns-whitelister]"
    echo "  • No sensitive data in git repository"
    echo "  • SSH key-based authentication only"
    echo "  • Input validation on all config fields"
    echo "  • DNS results validated (no IPs > 255)"
    echo "  • Command injection protections (no eval)"
    echo
    echo -e "${YELLOW}⚠ Important Security Notes:${NC}"
    echo "  • Never commit .env files (contain sensitive data)"
    echo "  • Keep *_rules.conf files local only"
    echo "  • Use strong SSH keys for server access"
    echo "  • Regularly review firewall rules"
    echo "  • Monitor update.log files for anomalies"
    echo "  • Test changes in non-production first"
    echo
    echo -e "${RED}⛔ Files That Must NOT Be Committed:${NC}"
    echo "  • .env (all directories)"
    echo "  • dyndns_rules.conf / firewall_rules.conf / ufw_rules.conf"
    echo "  • *.log files"
    echo "  • .cache/ directories"
    echo "  • SERVEURS_SOURCES.md (server list)"
    echo
    wait_for_key
    documentation_menu
}

# Clean old cron entries
clean_old_crons() {
    print_header
    echo -e "${BOLD}${CYAN}Clean Old Cron Entries${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        utilities_menu
        return
    fi

    ./clean-old-crons.sh

    wait_for_key
    utilities_menu
}

# Update all repos
update_all_repos() {
    print_header
    echo -e "${BOLD}${CYAN}Update Repos on All Servers${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        utilities_menu
        return
    fi

    ./update-all-repos.sh

    wait_for_key
    utilities_menu
}

# Redeploy to all servers
redeploy_all() {
    print_header
    echo -e "${BOLD}${CYAN}Redeploy to All Servers${NC}"
    print_separator
    echo
    echo -e "${YELLOW}WARNING: This will redeploy firewall scripts to ALL configured servers${NC}"
    echo
    echo -n "Are you sure? (y/N): "
    read confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        wait_for_key
        utilities_menu
        return
    fi

    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        utilities_menu
        return
    fi

    ./redeploy-all.sh

    wait_for_key
    utilities_menu
}

# Deploy to missing servers
deploy_missing() {
    print_header
    echo -e "${BOLD}${CYAN}Deploy to Missing Servers${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        utilities_menu
        return
    fi

    ./deploy-missing-repos.sh

    wait_for_key
    utilities_menu
}

# Generate deployment report
generate_report() {
    print_header
    echo -e "${BOLD}${GREEN}Generate Deployment Report${NC}"
    print_separator
    echo
    cd "${REPO_DIR}/utils"

    if [ ! -f .env ]; then
        echo -e "${RED}ERROR: utils/.env not found${NC}"
        wait_for_key
        utilities_menu
        return
    fi

    ./generate-report.sh

    wait_for_key
    utilities_menu
}

# Show Scaleway config
show_scaleway_config() {
    print_header
    echo -e "${BOLD}${MAGENTA}Scaleway Security Groups Configuration${NC}"
    print_separator
    echo

    if [ ! -f "${REPO_DIR}/scaleway/.env" ]; then
        echo -e "${RED}ERROR: scaleway/.env not found${NC}"
        echo
        echo "This file should contain:"
        echo "  • SCALEWAY_API_KEY - API access key"
        echo "  • SCALEWAY_ZONE - Zone (e.g., fr-par-1)"
        echo "  • SCALEWAY_SECURITY_GROUP_ID - Security group UUID"
        echo "  • LOG_ROTATION_HOURS - Log retention"
        echo
        echo "Create it from scaleway/.env.dist template"
        wait_for_key
        firewall_menu
        return
    fi

    echo -e "${GREEN}Scaleway Configuration:${NC}"
    echo
    grep "^SCALEWAY_" "${REPO_DIR}/scaleway/.env" 2>/dev/null | sed 's/SCALEWAY_API_KEY=.*/SCALEWAY_API_KEY=***HIDDEN***/' || echo "  No configuration found"
    echo
    grep "^LOG_ROTATION_HOURS=" "${REPO_DIR}/scaleway/.env" 2>/dev/null || echo "  LOG_ROTATION_HOURS: not set"
    echo

    if [ -f "${REPO_DIR}/scaleway/security_group_rules.conf" ]; then
        echo -e "${GREEN}Rules Configuration:${NC}"
        echo "  File: scaleway/security_group_rules.conf"
        echo "  Rules: $(grep -v '^#' "${REPO_DIR}/scaleway/security_group_rules.conf" | grep -v '^$' | wc -l)"
    fi

    wait_for_key
    firewall_menu
}

# Show AWS config
show_aws_config() {
    print_header
    echo -e "${BOLD}${MAGENTA}AWS Security Groups Configuration${NC}"
    print_separator
    echo

    if [ ! -f "${REPO_DIR}/aws/.env" ]; then
        echo -e "${RED}ERROR: aws/.env not found${NC}"
        echo
        echo "This file should contain:"
        echo "  • AWS_REGION - AWS region (e.g., ap-east-1)"
        echo "  • AWS_SECURITY_GROUP_ID - Security group ID"
        echo "  • LOG_ROTATION_HOURS - Log retention"
        echo
        echo "AWS credentials should be in ~/.aws/credentials"
        echo "Create .env from aws/.env.dist template"
        wait_for_key
        firewall_menu
        return
    fi

    echo -e "${GREEN}AWS Configuration:${NC}"
    echo
    grep "^AWS_" "${REPO_DIR}/aws/.env" 2>/dev/null || echo "  No configuration found"
    echo
    grep "^LOG_ROTATION_HOURS=" "${REPO_DIR}/aws/.env" 2>/dev/null || echo "  LOG_ROTATION_HOURS: not set"
    echo

    if [ -f "${REPO_DIR}/aws/security_group_rules.conf" ]; then
        echo -e "${GREEN}Rules Configuration:${NC}"
        echo "  File: aws/security_group_rules.conf"
        echo "  Rules: $(grep -v '^#' "${REPO_DIR}/aws/security_group_rules.conf" | grep -v '^$' | wc -l)"
    fi

    wait_for_key
    firewall_menu
}

# Show OVH config
show_ovh_config() {
    print_header
    echo -e "${BOLD}${MAGENTA}OVH Edge Network Firewall Configuration${NC}"
    print_separator
    echo

    if [ ! -f "${REPO_DIR}/ovhcloud/.env" ]; then
        echo -e "${RED}ERROR: ovhcloud/.env not found${NC}"
        echo
        echo "This file should contain:"
        echo "  • OVH_ENDPOINT - API endpoint (e.g., ovh-eu)"
        echo "  • OVH_APPLICATION_KEY - Application key"
        echo "  • OVH_APPLICATION_SECRET - Application secret"
        echo "  • OVH_CONSUMER_KEY - Consumer key"
        echo "  • OVH_SERVICE_NAME - Service name (IP address)"
        echo "  • LOG_ROTATION_HOURS - Log retention"
        echo
        echo "Create it from ovhcloud/.env.dist template"
        wait_for_key
        firewall_menu
        return
    fi

    echo -e "${GREEN}OVH Configuration:${NC}"
    echo
    grep "^OVH_" "${REPO_DIR}/ovhcloud/.env" 2>/dev/null | sed 's/OVH_APPLICATION_SECRET=.*/OVH_APPLICATION_SECRET=***HIDDEN***/' | sed 's/OVH_CONSUMER_KEY=.*/OVH_CONSUMER_KEY=***HIDDEN***/' || echo "  No configuration found"
    echo
    grep "^LOG_ROTATION_HOURS=" "${REPO_DIR}/ovhcloud/.env" 2>/dev/null || echo "  LOG_ROTATION_HOURS: not set"
    echo

    if [ -f "${REPO_DIR}/ovhcloud/firewall_rules.conf" ]; then
        echo -e "${GREEN}Rules Configuration:${NC}"
        echo "  File: ovhcloud/firewall_rules.conf"
        echo "  Rules: $(grep -v '^#' "${REPO_DIR}/ovhcloud/firewall_rules.conf" | grep -v '^$' | wc -l)"
    fi

    wait_for_key
    firewall_menu
}

# ============================================================================
# Main execution
# ============================================================================

# Check if we're in the repo root
if [ ! -f "${REPO_DIR}/README.md" ]; then
    echo -e "${RED}ERROR: This script must be run from the repository root${NC}"
    exit 1
fi

# Start the menu
show_main_menu
