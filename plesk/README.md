# Plesk Firewall DDNS Whitelister

Automatic Plesk Firewall rule management for dynamic DNS hostnames.

## Quick Start

```bash
# Deploy to a server
./deploy.sh server.example.com 22 root

# Check logs on remote server
ssh root@server 'tail -f /root/bash-plesk-firewall-ddns/plesk/update.log'
```

## Configuration

### firewall_rules.conf

Pipe-delimited format: `RULE_NAME|DIRECTION|ACTION|PORTS|HOSTNAME|COMMENT`

```bash
# Allow all traffic from NAS (dynamic IP)
nas1-all|input|allow||nas.example.com|Allow all from NAS

# Allow SSH from office
office-ssh|input|allow|22/tcp|office.example.com|Office SSH access
```

### .env

```bash
DNS_NAMESERVER=1.1.1.1
LOG_ROTATION_HOURS=168
```

## How It Works

1. Script reads `firewall_rules.conf`
2. Resolves hostname to IP via DNS
3. Compares with cached IP (`.cache/` directory)
4. If changed: updates or creates Plesk firewall rule
5. Applies changes with `--apply -auto-confirm-this-may-lock-me-out-of-the-server`
6. All rules tagged with `[bash-ddns-whitelister]` comment

## Uninstall

```bash
./uninstall.sh server.example.com 22 root
```

See main [README](../README.md) for complete documentation.
