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
    echo -e "${CYAN}║${NC}  ${BOLD}${MAGENTA}bash-ddns-whitelister${NC} - Dynamic DNS Firewall Management  ${CYAN}║${NC}"
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
    print_option "3" "Utilities & Tools" "$CYAN"
    print_option "4" "Firewall Management" "$YELLOW"
    print_option "5" "Verification & Testing" "$BLUE"
    print_option "6" "Documentation & Help" "$MAGENTA"
    echo
    print_separator
    print_option "0" "Exit" "$RED"
    echo
    echo -n "Select an option: "
    read choice

    case $choice in
        1) deployment_menu ;;
        2) uninstall_menu ;;
        3) utilities_menu ;;
        4) firewall_menu ;;
        5) verification_menu ;;
        6) documentation_menu ;;
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
    print_option "4" "Detect firewall types on all servers" "$CYAN"
    print_option "5" "Deploy SSH keys to servers" "$CYAN"
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
        4) detect_firewalls ;;
        5) deploy_ssh_keys ;;
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
    echo -e "${CYAN}Choose firewall type:${NC}"
    echo
    print_option "1" "iptables - View configuration" "$YELLOW"
    print_option "2" "Plesk - View configuration" "$YELLOW"
    print_option "3" "UFW - View configuration" "$YELLOW"
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
    print_option "1" "Verify cron cleanup on all servers" "$BLUE"
    print_option "2" "Test NAS blocking on all servers" "$BLUE"
    print_option "3" "Test connectivity from NAS" "$BLUE"
    print_option "4" "Check DNS resolution" "$BLUE"
    print_option "5" "View deployment status" "$BLUE"
    echo
    print_separator
    print_option "0" "Back to main menu" "$YELLOW"
    echo
    echo -n "Select an option: "
    read choice

    case $choice in
        1) verify_cron ;;
        2) test_nas_blocking ;;
        3) test_connectivity ;;
        4) check_dns ;;
        5) view_status ;;
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

# View deployment status
view_status() {
    print_header
    echo -e "${BOLD}${BLUE}Deployment Status${NC}"
    print_separator
    echo

    if [ -f "${REPO_DIR}/SERVEURS_SOURCES.md" ]; then
        less "${REPO_DIR}/SERVEURS_SOURCES.md"
    else
        echo -e "${YELLOW}Status file not found${NC}"
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
