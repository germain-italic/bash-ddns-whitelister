# Utility Scripts

Helper scripts for managing DDNS firewall deployments across multiple servers.

## Available Scripts

### detect-firewall.sh
Automatically detects firewall type (iptables, UFW, Plesk, or none) on all configured servers.

```bash
./detect-firewall.sh
```

### deploy-ssh-keys.sh
Deploys SSH public keys to all configured servers for passwordless authentication.

```bash
./deploy-ssh-keys.sh [--dry-run]
```

### test-nas-connectivity.sh
Tests SSH and rsync connectivity from NAS to servers. **Must be run FROM the NAS.**

```bash
# Run this on the NAS
./test-nas-connectivity.sh server1:22:root server2:22:root
```

### test-nas-blocking.sh
Tests that NAS is properly blocked from all servers (verifies firewall rules work).

```bash
./test-nas-blocking.sh
```

### verify-cron-cleanup.sh
Verifies that cron jobs have been removed from all servers (useful after uninstall).

```bash
./verify-cron-cleanup.sh
```

### verify-cron-installed.sh
Verifies that cron jobs are properly installed on all servers.

```bash
./verify-cron-installed.sh
```

### uninstall-all.sh
Uninstalls DDNS scripts from all servers at once.

```bash
./uninstall-all.sh
```

### sshd-match-address-update.sh
Updates sshd Match Address blocks with dynamic DNS IPs. Useful for servers that restrict root login by IP.

```bash
./sshd-match-address-update.sh
```

**Requirements:**
- The sshd_config must have a comment `# bash-ddns-whitelister: <identifier>` before the Match Address line
- Must be run as root on the target server

**Example sshd_config:**
```
# bash-ddns-whitelister: nas1
Match Address 81.51.73.213,other.ip.here
    PermitRootLogin prohibit-password
```

### generate-report.sh
Generates comprehensive CSV reports with all server status information.

```bash
./generate-report.sh [output.csv]
```

Reports include: connectivity, script installation, cron status, SSH keys, firewall configuration, OS info, and security warnings.

## Configuration

Copy and edit `.env`:

```bash
cp .env.dist .env
```

**Required variables:**
- `NAS1_HOST` - NAS hostname
- `NAS1_USER` - NAS SSH user
- `NAS1_PUBKEY` - NAS SSH public key
- `LOCAL_SSH_PUBKEY` - Your local SSH public key
- `SERVERS` - Array of servers (`hostname:port:user:firewall_type`)

See main [README](../README.md) for complete documentation.
