# Plesk Firewall DynDNS Manager

Automatic Plesk Firewall rules updater for dynamic hostnames (DynDNS).

Based on [Plesk Firewall CLI documentation](https://support.plesk.com/hc/en-us/articles/12377519983511-How-to-manage-local-firewall-rules-using-Plesk-Firewall-in-Plesk-for-Linux).

## Features

- Pure Bash (no external dependencies except Plesk)
- Automatic DNS resolution with local cache
- Updates Plesk firewall rules only when IP changes
- Detailed logging with rotation
- Auto-confirmation of firewall changes
- Safe operation (updates existing rules seamlessly)

## Requirements

- Plesk Obsidian 18+ (or any version with `plesk ext firewall` support)
- Root access
- SSH access to the server

## Installation

```bash
git clone https://github.com/germain-italic/bash-plesk-firewall-ddns.git
cd bash-plesk-firewall-ddns
cp .env.dist .env
cp firewall_rules.conf.dist firewall_rules.conf
nano firewall_rules.conf
chmod +x update.sh
```

## Configuration

### `.env`

```bash
DNS_NAMESERVER=1.1.1.1
LOG_ROTATION_HOURS=168
```

### `firewall_rules.conf`

Pipe-separated format: `RULE_NAME|DIRECTION|ACTION|PORTS|HOSTNAME|COMMENT`

```bash
nas1-ssh|input|allow|22/tcp|nas1.example.com|Allow SSH from NAS1
nas2-web|input|allow|80/tcp,443/tcp|nas2.example.com|Allow web from NAS2
nas1-all|input|allow||nas1.example.com|Allow all from NAS1
```

**Fields:**
- `RULE_NAME`: Unique identifier for the rule (required)
- `DIRECTION`: `input` or `output` (required)
- `ACTION`: `allow` or `deny` (required)
- `PORTS`: Port specification (e.g., `22/tcp`, `80/tcp,443/tcp`) or empty for all
- `HOSTNAME`: Dynamic hostname to resolve (required)
- `COMMENT`: Optional description

## Testing

```bash
sudo ./update.sh
cat update.log
```

## Cron Setup

```bash
sudo crontab -e
```

Add line to run every 5 minutes:

```
*/5 * * * * /path/to/bash-plesk-firewall-ddns/update.sh
```

## File Structure

```
bash-plesk-firewall-ddns/
├── update.sh                 # Main script
├── .env                      # Configuration (create from .env.dist)
├── .env.dist                 # Configuration template
├── firewall_rules.conf       # Firewall rules (create from .dist)
├── firewall_rules.conf.dist  # Rules template
├── update.log                # Execution logs
├── .cache/                   # Resolved IPs cache
└── README.md
```

## How It Works

1. Loads configuration from `.env` and `firewall_rules.conf`
2. Resolves each hostname to IP (via `dig`, `host` or `getent`)
3. Compares with cached IP
4. If IP changed:
   - Updates Plesk firewall rule with new IP (or creates if doesn't exist)
   - Applies firewall changes
   - Auto-confirms within 60 seconds
5. Updates cache
6. Logs all operations
7. Rotates logs based on `LOG_ROTATION_HOURS`

## Differences from bash-iptables-ddns

| Feature | bash-iptables-ddns | bash-plesk-firewall-ddns |
|---------|-------------------|--------------------------|
| Target | Generic Linux servers | Plesk servers |
| Firewall API | Direct iptables | Plesk firewall extension |
| Rule format | iptables syntax | Pipe-separated config |
| Rule management | Delete old + Add new | Update existing rule |
| Confirmation | Not needed | Auto-confirm in 60s |
| Dependencies | iptables tools | Plesk installed |

## Security

- `.env` and `firewall_rules.conf` may contain sensitive data: `chmod 600`
- Script must run as root (required for Plesk firewall management)
- Add `.env` and `firewall_rules.conf` to `.gitignore`

## Troubleshooting

**Script fails with "Plesk command not found"**
- Ensure Plesk is installed and `/usr/local/psa/bin/plesk` exists
- Add Plesk to PATH if needed

**Rules not applied**
- Check logs: `cat update.log`
- Verify Plesk firewall is enabled: `plesk ext firewall --list`
- Test DNS resolution: `dig +short nas1.example.com`

**IP not updating**
- Check cache: `cat .cache/*.cache`
- Force update: `rm -rf .cache/`
- Verify hostname resolves: `host nas1.example.com`

## License

MIT License - See LICENSE file
