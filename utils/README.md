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
