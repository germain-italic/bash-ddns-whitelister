# NAS Management Scripts

## update.sh

Automatic iptables rules updater for dynamic hostnames (DynDNS).

### Features

- Pure Bash (no external dependencies)
- Automatic DNS resolution with local cache
- Updates iptables rules only when IP changes
- Detailed logging with rotation
- Safe operation (deletes old rule before adding new one)

### Installation

```bash
cd scripts
cp .env.dist .env
cp dyndns_rules.conf.dist dyndns_rules.conf
nano .env
nano dyndns_rules.conf
chmod +x update.sh
```

### Configuration

**`.env`**

```bash
DNS_NAMESERVER=1.1.1.1
LOG_ROTATION_HOURS=168
```

**`dyndns_rules.conf`**

Standard iptables rules format (like `iptables -S` output):

```bash
-A INPUT -p tcp -s nas1.synology.me --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
-A INPUT -i eth0 -s nas1.synology.me -j ACCEPT
```

### Testing

```bash
sudo ./update.sh
cat update.log
```

### Cron Setup

```bash
sudo crontab -e
```

Add line to run every 5 minutes:

```
*/5 * * * * /path/to/scripts/update.sh
```

### File Structure

```
scripts/
├── update.sh                 # Main script
├── .env                      # Configuration (create from .env.dist)
├── .env.dist                 # Configuration template
├── dyndns_rules.conf         # iptables rules (create from .dist)
├── dyndns_rules.conf.dist    # Rules template
├── update.log                # Execution logs
├── .cache/                   # Resolved IPs cache
└── README.md
```

### Rule Examples

**Allow SSH from NAS**

```bash
-A INPUT -p tcp -s nas1.synology.me --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
```

**Allow all traffic from NAS**

```bash
-A INPUT -i eth0 -s nas1.synology.me -j ACCEPT
```

**NAT/Port forwarding**

```bash
-A PREROUTING -i eth0 -s nas1.synology.me -p tcp --dport 443 -j DNAT --to-destination 192.168.1.100:8443 -t nat
```

**Allow multiple ports**

```bash
-A INPUT -p tcp -s nas2.synology.me -m multiport --dports 22,80,443 -j ACCEPT
```

### How It Works

1. Loads configuration from `.env` and `dyndns_rules.conf`
2. Extracts hostnames from rules
3. Resolves each hostname to IP (via `dig`, `host` or `getent`)
4. Compares with cached IP
5. If IP changed:
   - Deletes old rule (with old IP)
   - Adds new rule (with new IP)
6. Updates cache
7. Logs all operations
8. Rotates logs based on `LOG_ROTATION_HOURS`

### Security

- `.env` may contain sensitive data: `chmod 600 .env`
- Script must run as root (required for iptables)
- Add `.env` and `dyndns_rules.conf` to `.gitignore`
