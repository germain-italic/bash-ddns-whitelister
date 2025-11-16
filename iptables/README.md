# iptables DDNS Whitelister

Automatic iptables firewall rule management for dynamic DNS hostnames.

## Quick Start

```bash
# Deploy to a server
./deploy.sh server.example.com 22 root

# Check logs on remote server
ssh root@server 'tail -f /root/bash-iptables-ddns/iptables/update.log'
```

## Configuration

### dyndns_rules.conf

Standard iptables rules format. Hostnames are automatically resolved and replaced with IPs:

```bash
# Allow all traffic from NAS (dynamic IP)
-A INPUT -s nas.example.com -j ACCEPT

# Allow SSH from specific host
-A INPUT -s office.example.com -p tcp --dport 22 -j ACCEPT
```

### .env

```bash
DNS_NAMESERVER=1.1.1.1
LOG_ROTATION_HOURS=168
```

## How It Works

1. Script reads `dyndns_rules.conf` 
2. Extracts hostnames from rules
3. Resolves each hostname to IP via DNS
4. Compares with cached IP (`.cache/` directory)
5. If changed: deletes old rule, adds new rule with updated IP
6. All rules tagged with `bash-ddns-whitelister` comment

## Uninstall

```bash
./uninstall.sh server.example.com 22 root
```

See main [README](../README.md) for complete documentation.
