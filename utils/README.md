# bash-utils-ddns

Utility scripts for managing DDNS firewall deployments across multiple servers.

This repository contains helper scripts for deploying and managing dynamic DNS firewall solutions on multiple servers.

## Scripts

### detect-firewall.sh

Automatically detects the firewall type (iptables, UFW, Plesk, or none) on all configured servers.

**Usage:**
```bash
./detect-firewall.sh
```

**Output:**
- Categorized list of servers by firewall type
- Machine-readable output for automation
- Connection status for each server

### deploy-ssh-keys.sh

Deploys SSH public keys (local and NAS) to all configured servers for passwordless authentication.

**Usage:**
```bash
./deploy-ssh-keys.sh [--dry-run]
```

**Options:**
- `--dry-run`: Show what would be deployed without making changes

**Features:**
- Deploys both local and NAS SSH keys
- Checks for existing keys to avoid duplicates
- Handles connection failures gracefully
- Provides detailed deployment summary

### test-nas-connectivity.sh

Tests SSH and rsync connectivity from NAS to all servers.

**Note:** This script must be run FROM the NAS server, not from your local machine.

**Usage:**
```bash
./test-nas-connectivity.sh server1:port:user [server2:port:user ...]
```

**Example:**
```bash
./test-nas-connectivity.sh \
    server1.example.com:22:root \
    server2.example.com:2222:root \
    server3.example.com:22:debian
```

**Tests performed:**
- SSH connectivity
- rsync file transfer
- Automatic cleanup of test files

## Configuration

1. Copy the environment template:
```bash
cp .env.dist .env
```

2. Edit `.env` and configure:
   - `NAS1_HOST`: Your NAS hostname
   - `NAS1_USER`: NAS SSH user (usually root)
   - `NAS1_PUBKEY`: NAS SSH public key
   - `LOCAL_SSH_PUBKEY`: Your local SSH public key
   - `SERVERS`: Array of servers (format: `hostname:port:user:firewall_type`)

**Example configuration:**
```bash
NAS1_HOST=nas1.example.com
NAS1_USER=root
NAS1_PUBKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... root@NAS1"
LOCAL_SSH_PUBKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD... user@host"

SERVERS=(
    "server1.example.com:22:root:iptables"
    "server2.example.com:22:root:plesk"
    "server3.example.com:2222:root:iptables"
    "server4.example.com:22:debian:ufw"
    "server5.example.com:22:root:iptables:SKIP"
)
```

**Server format:**
- `hostname`: Server hostname or IP
- `port`: SSH port (usually 22)
- `user`: SSH user (usually root)
- `firewall_type`: iptables, plesk, ufw, or none
- `SKIP` (optional): Add :SKIP to skip deployment

## Related Projects

These scripts are designed to work with:

- [bash-iptables-ddns](https://github.com/germain-italic/bash-iptables-ddns) - For iptables servers
- [bash-plesk-firewall-ddns](https://github.com/germain-italic/bash-plesk-firewall-ddns) - For Plesk servers
- [bash-ufw-ddns](https://github.com/germain-italic/bash-ufw-ddns) - For UFW servers

## Workflow

1. **Detect firewall types:**
   ```bash
   ./detect-firewall.sh
   ```

2. **Deploy SSH keys:**
   ```bash
   ./deploy-ssh-keys.sh
   ```

3. **Deploy DDNS scripts** (using appropriate repo for each firewall type)

4. **Test connectivity from NAS** (run on NAS):
   ```bash
   ./test-nas-connectivity.sh server1:22:root server2:22:root ...
   ```

## Security Notes

- Never commit the `.env` file (it contains sensitive keys)
- Always use SSH keys for authentication
- Restrict NAS access to specific IPs when possible
- Review firewall rules before deploying

## Requirements

- Bash 4.0+
- SSH client
- rsync (for connectivity tests)
- `dig` or `host` command (for DNS resolution in DDNS scripts)

## License

MIT License - See LICENSE file

## Author

Italic Agency
