# bash-ufw-ddns

Automatic UFW firewall rules updater for dynamic hostnames.

This script automatically updates UFW firewall rules when IP addresses of dynamic hostnames change. Perfect for managing access from servers with dynamic IPs (like Synology NAS with DDNS).

## Features

- 🔄 Automatic IP resolution and UFW rule updates
- 💾 DNS caching to minimize unnecessary updates
- 📝 Detailed logging with automatic rotation
- ⏰ Cron-ready for periodic execution
- 🔒 Safe rule management (delete old, add new)

## Installation

1. Clone this repository:
```bash
git clone https://github.com/germain-italic/bash-ufw-ddns
cd bash-ufw-ddns
```

2. Copy and configure the environment file:
```bash
cp .env.dist .env
# Edit .env if needed (default values should work)
```

3. Copy and configure the rules file:
```bash
cp ufw_rules.conf.dist ufw_rules.conf
# Edit ufw_rules.conf to add your dynamic hostnames
```

4. Test the script:
```bash
sudo ./update.sh
```

5. Add to crontab for automatic updates (every 5 minutes):
```bash
crontab -e
# Add this line:
*/5 * * * * /root/bash-ufw-ddns/update.sh >> /root/bash-ufw-ddns/cron.log 2>&1
```

## Configuration

### .env

```bash
# DNS nameserver for hostname resolution
DNS_NAMESERVER=1.1.1.1

# Log rotation (keep logs older than N hours)
LOG_ROTATION_HOURS=168
```

### ufw_rules.conf

Format: `RULE_NAME|PROTO|PORT|HOSTNAME|COMMENT`

- **PROTO**: `tcp` or `udp` (leave empty for all)
- **PORT**: port number (leave empty for all ports)
- **HOSTNAME**: dynamic hostname to resolve
- **COMMENT**: UFW comment (optional)

Example:
```
# Allow all traffic from NAS1
nas1-all||nas1.example.com|Allow all from NAS1

# Allow SSH from NAS1
nas1-ssh|tcp|22|nas1.example.com|SSH from NAS1

# Allow MySQL from NAS1
nas1-mysql|tcp|3306|nas1.example.com|MySQL from NAS1
```

## How it works

1. Reads `ufw_rules.conf` for rules with dynamic hostnames
2. Resolves each hostname to its current IP using DNS
3. Compares with cached IP (from previous run)
4. If IP changed:
   - Deletes old UFW rule with old IP
   - Adds new UFW rule with new IP
   - Updates cache with new IP
5. Logs all changes to `update.log`

## Logs

- **update.log**: Main log file with all IP changes and actions
- **cron.log**: Cron execution log
- Logs are automatically rotated based on `LOG_ROTATION_HOURS`

## Requirements

- Root access (UFW management)
- UFW installed and active
- `dig` or `host` command for DNS resolution
- Bash 4.0+

## License

MIT License - See LICENSE file

## Author

Italic Agency
