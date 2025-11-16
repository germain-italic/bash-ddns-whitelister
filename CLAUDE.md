# CLAUDE.md - bash-ddns-whitelister

## Overview

This repository contains scripts for automatic firewall whitelist management for dynamic DNS hostnames. It supports multiple firewall types: iptables, Plesk Firewall, and UFW.

## Repository Structure

```
bash-ddns-whitelister/
├── iptables/          # iptables firewall management
│   ├── update.sh      # Main update script
│   ├── deploy.sh      # Deployment script
│   ├── .env.dist      # Environment template
│   └── dyndns_rules.conf.dist  # Rules template
├── plesk/             # Plesk Firewall management
│   ├── update.sh
│   ├── deploy.sh
│   ├── .env.dist
│   └── firewall_rules.conf.dist
├── ufw/               # UFW firewall management
│   ├── update.sh
│   ├── deploy.sh
│   ├── .env.dist
│   └── ufw_rules.conf.dist
└── utils/             # Utility scripts
    ├── detect-firewall.sh      # Auto-detect firewall type
    ├── deploy-ssh-keys.sh      # Deploy SSH keys to servers
    └── test-nas-connectivity.sh # Test connectivity from NAS
```

## Important Security Notes

### Files that MUST NOT be committed

1. **Configuration files** containing real data:
   - `.env` (contains real hostnames, IPs, SSH keys)
   - `dyndns_rules.conf` / `firewall_rules.conf` / `ufw_rules.conf`
   - Any `*.log` files
   - `.cache/` directories

2. **Template files** are safe to commit:
   - `.env.dist`
   - `*_rules.conf.dist`
   - These contain example/placeholder data only

3. **Scripts** are safe to commit:
   - All `.sh` scripts
   - `README.md` files
   - Documentation

### Current .gitignore

The `.gitignore` is configured to exclude ALL sensitive files. Always verify before committing:
```bash
git status
git diff --cached
```

## Development Workflow

### Adding New Features

1. Test locally first
2. Update appropriate subdirectory (iptables/plesk/ufw/utils)
3. Update relevant README.md
4. Verify no sensitive data: `git status`
5. Commit and push

### Deploying to Servers

1. Use `utils/detect-firewall.sh` to identify firewall types
2. Use `utils/deploy-ssh-keys.sh` to deploy SSH access
3. Use appropriate `*/deploy.sh` script for each firewall type
4. Test with `utils/test-nas-connectivity.sh` (run from NAS)

## Configuration Format

### .env file (template in .env.dist)

Contains:
- DNS nameserver
- Log rotation settings
- Example hostnames (anonymized)

**NEVER commit the actual .env file**

### Rules configuration files

**iptables** (dyndns_rules.conf):
```
# Format: standard iptables rules
-A INPUT -s dynamic.hostname.example -j ACCEPT
```

**Plesk** (firewall_rules.conf):
```
# Format: RULE_NAME|DIRECTION|ACTION|PORTS|HOSTNAME|COMMENT
rule1|input|allow||dynamic.hostname.example|Description
```

**UFW** (ufw_rules.conf):
```
# Format: RULE_NAME|PROTO|PORT|HOSTNAME|COMMENT
rule1|tcp|22|dynamic.hostname.example|SSH access
```

## Testing

### Local Testing

Before deploying, test scripts locally:
```bash
# Dry run
./utils/deploy-ssh-keys.sh --dry-run

# Test firewall detection
./utils/detect-firewall.sh
```

### Production Testing

After deployment:
```bash
# Check logs on remote server
ssh root@server 'tail -f /root/bash-iptables-ddns/update.log'

# Test from NAS
ssh root@nas
./test-nas-connectivity.sh server1:22:root server2:22:root
```

## Troubleshooting

### Script fails with "unbound variable"

- Check that all fields in rules config are present
- Use `:-` default values for optional fields

### DNS resolution fails

- Verify `DNS_NAMESERVER` in .env
- Test manually: `dig @1.1.1.1 hostname.example.com`

### Firewall rules not updating

- Check cron is running: `crontab -l`
- Verify script has execute permissions
- Check logs for errors

### SSH connection fails

- Verify SSH keys are deployed
- Check firewall allows your IP
- Test manually: `ssh -p 22 user@server`

## Cron Setup

All update scripts run via cron every 5 minutes:
```cron
*/5 * * * * /root/bash-iptables-ddns/update.sh >> /root/bash-iptables-ddns/cron.log 2>&1
*/5 * * * * /root/bash-plesk-firewall-ddns/update.sh >> /root/bash-plesk-firewall-ddns/cron.log 2>&1
*/5 * * * * /root/bash-ufw-ddns/update.sh >> /root/bash-ufw-ddns/cron.log 2>&1
```

## Log Management

Logs are automatically rotated based on `LOG_ROTATION_HOURS` setting in `.env` (default: 168 hours = 1 week).

## Security Best Practices

1. **Never commit sensitive data**
   - Use `.env.dist` templates only
   - Keep real `.env` files local/on servers only

2. **Use SSH keys only**
   - No password authentication
   - Restrict key access to specific IPs when possible

3. **Monitor logs**
   - Regularly check update logs
   - Watch for DNS resolution failures
   - Alert on repeated failures

4. **Test before deploying**
   - Always use --dry-run first
   - Test on non-production servers first
   - Verify firewall rules don't lock you out

## Support

For issues or questions:
1. Check logs on affected server
2. Verify configuration files
3. Test DNS resolution manually
4. Check firewall allows required ports

## License

MIT License - See LICENSE file
