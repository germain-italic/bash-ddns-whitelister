# UFW DDNS Whitelister

Automatic UFW firewall rule management for dynamic DNS hostnames.

## Quick Start

```bash
# Deploy to a server
./deploy.sh server.example.com 22 root

# Check logs on remote server
ssh root@server 'tail -f /root/bash-ufw-ddns/ufw/update.log'
```

## Configuration

### ufw_rules.conf

Pipe-delimited format: `RULE_NAME|PROTO|PORT|HOSTNAME|COMMENT`

```bash
# Allow all traffic from NAS (dynamic IP)
nas1-all|tcp||nas.example.com|Allow all from NAS

# Allow SSH from office
office-ssh|tcp|22|office.example.com|Office SSH access
```

Leave PORT empty for "allow from IP" (all ports).

### .env

```bash
DNS_NAMESERVER=1.1.1.1
LOG_ROTATION_HOURS=168
```

## How It Works

1. Script reads `ufw_rules.conf`
2. Resolves hostname to IP via DNS
3. Compares with cached IP (`.cache/` directory)
4. If changed: deletes old UFW rule, adds new rule with updated IP
5. All rules tagged with `[bash-ddns-whitelister]` comment

## Uninstall

```bash
./uninstall.sh server.example.com 22 root
```

See main [README](../README.md) for complete documentation.
