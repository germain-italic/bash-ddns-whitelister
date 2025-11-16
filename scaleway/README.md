# Scaleway Security Group DDNS Whitelist

Automatic security group rule management for Scaleway instances with dynamic DNS hostnames.

## Overview

This script automatically updates Scaleway security group rules when a dynamic hostname's IP changes. It uses the Scaleway API to manage inbound rules.

## Features

- Automatic IP resolution from dynamic hostnames
- Creates/updates security group rules via Scaleway API
- Supports multiple security groups and hostnames
- IP caching to minimize API calls
- Comprehensive logging with rotation
- Multi-zone support

## Requirements

- Scaleway API credentials (Secret Key)
- `curl` for API calls
- `dig` or `host` for DNS resolution
- Security group must exist in Scaleway

## Configuration

1. Copy the environment template:
   ```bash
   cp .env.dist .env
   ```

2. Edit `.env` with your credentials:
   ```bash
   # Scaleway API credentials
   SCW_ACCESS_KEY="your-access-key"
   SCW_SECRET_KEY="your-secret-key"
   SCW_DEFAULT_ORGANIZATION_ID="your-org-id"
   SCW_DEFAULT_PROJECT_ID="your-project-id"

   # Rules configuration
   SCALEWAY_RULES=(
       "office-vpn|nas1|nas1.example.com|fr-par-1"
       "office-vpn|nas2|nas2.example.com|fr-par-1"
   )
   ```

## Rule Format

Each rule is defined as: `security_group_name|identifier|hostname|zone`

- **security_group_name**: Name of the Scaleway security group (must exist)
- **identifier**: Unique identifier for this rule (e.g., "nas1", "backup")
- **hostname**: Dynamic hostname to resolve to IP
- **zone**: Scaleway zone (e.g., "fr-par-1", "fr-par-2", "nl-ams-1", "pl-waw-1")

### Available Zones

- `fr-par-1`, `fr-par-2`, `fr-par-3` - Paris, France
- `nl-ams-1`, `nl-ams-2` - Amsterdam, Netherlands
- `pl-waw-1`, `pl-waw-2` - Warsaw, Poland

## Usage

### Manual Execution

```bash
./update.sh
```

### Automated Execution (Cron)

Add to crontab to run every 5 minutes:

```bash
*/5 * * * * /path/to/scaleway/update.sh >> /path/to/scaleway/cron.log 2>&1
```

## How It Works

1. **DNS Resolution**: Resolves each configured hostname to its current IP
2. **Cache Check**: Compares with cached IP to detect changes
3. **API Lookup**: Finds the security group by name
4. **Rule Management**:
   - If IP changed: Deletes old rule and creates new rule with new IP
   - If IP unchanged: No action taken
5. **Caching**: Stores new IP and rule ID for future comparisons
6. **Logging**: Records all actions with timestamps

## Security Group Rule Details

Created rules have the following properties:
- **Action**: accept
- **Direction**: inbound
- **IP Range**: `<resolved-ip>/32`
- **Protocol**: ALL (allows all protocols)
- **Editable**: true

## Logging

Logs are stored in `update.log` and automatically rotated based on `LOG_ROTATION_HOURS` (default: 168 hours/1 week).

Log format:
```
[2025-11-16 22:00:00] Starting Scaleway security group update
[2025-11-16 22:00:01] Processing office-vpn (abc123...) - nas1 (nas1.example.com)
[2025-11-16 22:00:02] IP change detected for nas1: 1.2.3.4 -> 5.6.7.8
[2025-11-16 22:00:03] Deleted rule ID: rule-xyz789
[2025-11-16 22:00:04] Created rule ID: rule-abc456 for nas1 (5.6.7.8/32)
[2025-11-16 22:00:05] Update completed: 1 rule(s) updated
```

## Caching

The script uses two types of cache files in `.cache/`:

1. **IP Cache**: `<sg_id>_<identifier>_ip.cache`
   - Stores last known IP for comparison

2. **Rule ID Cache**: `<sg_id>_<identifier>_rule_id.cache`
   - Stores Scaleway rule ID for updates/deletions

## Troubleshooting

### Security Group Not Found

```
ERROR: Security group 'office-vpn' not found in zone fr-par-1
```

**Solution**: Verify the security group exists and the name is correct. Check zone is correct.

### Cannot Resolve Hostname

```
WARNING: Cannot resolve nas1.example.com
```

**Solution**:
- Check hostname is correct
- Verify DNS server is accessible
- Try changing `DNS_NAMESERVER` in `.env`

### API Authentication Failed

**Solution**: Verify `SCW_SECRET_KEY` is correct and has not expired.

### Rule Creation Failed

**Solution**:
- Check you have permission to modify the security group
- Verify the security group is in the correct project
- Check API rate limits

## API Rate Limits

Scaleway has API rate limits. The script minimizes API calls by:
- Using IP cache (only updates on IP changes)
- Using rule ID cache (avoids searching for rules)
- Batching operations per security group

## Examples

### Single NAS, Single Security Group

```bash
SCALEWAY_RULES=(
    "office-vpn|nas1|nas.example.com|fr-par-1"
)
```

### Multiple NAS, Same Security Group

```bash
SCALEWAY_RULES=(
    "office-vpn|nas1|nas1.example.com|fr-par-1"
    "office-vpn|nas2|nas2.example.com|fr-par-1"
)
```

### Multiple Security Groups, Different Zones

```bash
SCALEWAY_RULES=(
    "office-vpn|nas1|nas.example.com|fr-par-1"
    "backup-access|backup|backup.example.com|nl-ams-1"
    "monitoring|monitor|monitor.example.com|pl-waw-1"
)
```

## Security Considerations

- **Credentials**: Never commit `.env` to version control
- **Permissions**: Limit API token permissions to security groups only
- **IP Whitelisting**: Consider whitelisting specific ports instead of ALL protocols
- **Monitoring**: Regularly review security group rules in Scaleway console

## Related Scripts

- `../iptables/update.sh` - Server-level iptables management
- `../utils/generate-report.sh` - Comprehensive server status reports

## Support

For issues or questions, check the main [README](../README.md) or [API_INTEGRATION.md](../API_INTEGRATION.md).
