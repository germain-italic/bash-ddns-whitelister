# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository provides automatic firewall whitelist management for dynamic DNS hostnames across three firewall types: iptables, Plesk Firewall, and UFW. Each implementation follows the same architecture pattern but uses different APIs/commands.

## Architecture Pattern

All three firewall implementations share a common architecture:

### Core Components (Shared Pattern)

1. **update.sh** - Main update script that:
   - Resolves hostnames to IPs using DNS nameserver
   - Compares against cached IPs in `.cache/` directory
   - When IP changes: deletes old rule, adds new rule, updates cache
   - Logs all changes with timestamps
   - Rotates logs based on `LOG_ROTATION_HOURS`
   - Runs via cron every 5 minutes

2. **deploy.sh** - Deployment script that:
   - Clones/updates repo from GitHub on remote server
   - Creates `.env` and rules config from templates if missing
   - Sets up cron job for periodic updates
   - Runs initial update

3. **Configuration Files**:
   - `.env` - Environment variables (DNS nameserver, log rotation)
   - Rules config - Firewall-specific rule definitions (varies by type)
   - `.cache/*.cache` - Cached IPs for each hostname (auto-generated)

### Implementation Differences

**iptables** (`iptables/`):
- Rules format: Standard iptables syntax (e.g., `-A INPUT -s hostname -j ACCEPT`)
- Updates: Extract hostnames via regex, replace with IPs, apply with `iptables` command
- Config: `dyndns_rules.conf`

**Plesk** (`plesk/`):
- Rules format: Pipe-delimited (`RULE_NAME|DIRECTION|ACTION|PORTS|HOSTNAME|COMMENT`)
- Updates: Uses `plesk ext firewall` CLI, updates by rule name or ID
- Config: `firewall_rules.conf`
- Special: Requires `--apply -auto-confirm-this-may-lock-me-out-of-the-server` after changes

**UFW** (`ufw/`):
- Rules format: Pipe-delimited (`RULE_NAME|PROTO|PORT|HOSTNAME|COMMENT`)
- Updates: Uses `ufw` commands (delete old, add new)
- Config: `ufw_rules.conf`

### Utility Scripts (`utils/`)

- **detect-firewall.sh** - Auto-detects firewall type on remote servers
- **deploy-ssh-keys.sh** - Deploys SSH keys to multiple servers for passwordless access
- **test-nas-connectivity.sh** - Tests connectivity from NAS to all configured servers

## Common Commands

### Deployment Workflow

```bash
# 1. Detect firewall types on servers
cd utils
cp .env.dist .env  # Edit with your server list
./detect-firewall.sh

# 2. Deploy SSH keys to all servers
./deploy-ssh-keys.sh

# 3. Deploy to servers based on firewall type
cd ../iptables
./deploy.sh server.example.com 22 root

cd ../plesk
./deploy.sh server.example.com 22 root

cd ../ufw
./deploy.sh server.example.com 22 root

# 4. Test connectivity from NAS
ssh root@nas
./test-nas-connectivity.sh server1:22:root server2:22:root
```

### Monitoring

```bash
# Check logs on remote server
ssh root@server 'tail -f /root/bash-iptables-ddns/update.log'
ssh root@server 'tail -f /root/bash-plesk-firewall-ddns/update.log'
ssh root@server 'tail -f /root/bash-ufw-ddns/update.log'

# Verify cron job
ssh root@server 'crontab -l | grep update.sh'

# Test DNS resolution
dig @1.1.1.1 hostname.example.com
```

### Local Testing

```bash
# Test scripts with syntax check
bash -n iptables/update.sh
bash -n plesk/update.sh
bash -n ufw/update.sh

# Dry run deployment utilities
cd utils
./deploy-ssh-keys.sh --dry-run
```

## Critical Security Rules

### Files That MUST NOT Be Committed

**Configuration files** containing real data are gitignored:
- `.env` files (contain real hostnames, IPs, SSH keys)
- `dyndns_rules.conf` / `firewall_rules.conf` / `ufw_rules.conf` (real firewall rules)
- `*.log` files
- `.cache/` directories

**Template files** are safe to commit:
- `.env.dist` (example configuration)
- `*_rules.conf.dist` (example rules)

Always verify before committing:
```bash
git status
git diff --cached
```

## Configuration Format Reference

### .env File

```bash
DNS_NAMESERVER=1.1.1.1          # DNS server for resolution
LOG_ROTATION_HOURS=168          # Keep logs for N hours (default: 7 days)
```

### iptables Rules (dyndns_rules.conf)

Standard iptables syntax with hostnames:
```
-A INPUT -s dynamic.hostname.example -j ACCEPT
-A INPUT -s nas.example.com -p tcp --dport 22 -j ACCEPT
```

### Plesk Rules (firewall_rules.conf)

Format: `RULE_NAME|DIRECTION|ACTION|PORTS|HOSTNAME|COMMENT`
```
nas_access|input|allow||nas.example.com|NAS full access
ssh_nas|input|allow|22|nas.example.com|SSH from NAS
```

### UFW Rules (ufw_rules.conf)

Format: `RULE_NAME|PROTO|PORT|HOSTNAME|COMMENT`
```
nas_ssh|tcp|22|nas.example.com|SSH access from NAS
nas_https|tcp|443|nas.example.com|HTTPS from NAS
```

## Key Implementation Details

### DNS Resolution Fallback Chain

All update scripts use this resolution order:
1. `dig +short @$nameserver` (preferred)
2. `host $hostname $nameserver` (fallback)
3. `getent hosts` (last resort)

### Caching Mechanism

- Each hostname gets a cache file: `.cache/hostname_with_dots_as_underscores.cache`
- Contains single line with current IP
- Only updates firewall when cached IP != resolved IP
- Prevents unnecessary rule churn

### Log Rotation

- Automatically rotates based on `LOG_ROTATION_HOURS` (default: 168 = 1 week)
- Uses timestamp-based filtering to keep recent entries
- Runs on every script execution

### Cron Setup

All scripts deployed to run every 5 minutes:
```cron
*/5 * * * * /root/bash-iptables-ddns/update.sh >> /root/bash-iptables-ddns/cron.log 2>&1
*/5 * * * * /root/bash-plesk-firewall-ddns/update.sh >> /root/bash-plesk-firewall-ddns/cron.log 2>&1
*/5 * * * * /root/bash-ufw-ddns/update.sh >> /root/bash-ufw-ddns/cron.log 2>&1
```

## Common Issues

### "unbound variable" errors
- Check that all pipe-delimited fields are present in rules config
- Ensure `set -euo pipefail` compatibility by providing default values with `${VAR:-default}`

### DNS resolution failures
- Verify `DNS_NAMESERVER` in `.env`
- Test manually: `dig @1.1.1.1 hostname.example.com`
- Check network connectivity from server

### Rules not updating
- Verify cron is running: `crontab -l`
- Check script has execute permissions: `chmod +x update.sh`
- Review logs for errors

### Plesk-specific: Changes not applied
- Ensure `--apply -auto-confirm-this-may-lock-me-out-of-the-server` is used
- Check Plesk firewall extension is installed: `plesk ext firewall --list`

### UFW-specific: Rule duplicates
- UFW may create duplicate rules if not properly deleted first
- Script deletes old IP rule before adding new one to prevent this
