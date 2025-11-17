# OVH Edge Network Firewall DDNS Whitelist

Automatic firewall rule management for OVH Edge Network Firewall with dynamic DNS hostnames.

## Overview

This script automatically updates OVH Edge Network Firewall rules when a dynamic hostname's IP changes. It uses the OVH API to manage inbound rules.

## Features

- Automatic IP resolution from dynamic hostnames
- Creates/updates firewall rules via OVH API
- Supports multiple IPs and hostnames
- IP caching to minimize API calls
- Comprehensive logging with rotation
- OVH API authentication with signature verification

## Requirements

- OVH API credentials (Application Key, Application Secret, Consumer Key)
- `curl` for API calls
- `dig` or `host` for DNS resolution
- IP must have Edge Network Firewall enabled in OVH

## Configuration

1. Copy the environment template:
   ```bash
   cp .env.dist .env
   ```

2. Edit `.env` with your credentials:
   ```bash
   # OVH API credentials
   OVH_APPLICATION_KEY="your-application-key"
   OVH_APPLICATION_SECRET="your-application-secret"
   OVH_CONSUMER_KEY="your-consumer-key"
   OVH_ENDPOINT="ovh-eu"

   # Rules configuration
   OVH_RULES=(
       "203.0.113.10|nas1|nas1.example.com"
   )
   ```

## OVH API Credentials

### Creating API Credentials

1. Go to [OVH API Token Creation](https://eu.api.ovh.com/createToken/)
2. Fill in:
   - **Application name**: e.g., "ddns-whitelister"
   - **Application description**: e.g., "DDNS firewall management"
   - **Validity**: Unlimited
   - **Rights**:
     - GET `/ip/*`
     - POST `/ip/*/firewall`
     - DELETE `/ip/*/firewall/*`
3. Click "Create keys"
4. Save:
   - **Application Key** (AK)
   - **Application Secret** (AS)
   - **Consumer Key** (CK)

### Authentication

The script uses OVH's signature-based authentication:
- Signature = `$1$` + SHA1(`AS + CK + METHOD + URL + BODY + TIMESTAMP`)
- All requests include headers:
  - `X-Ovh-Application`: Application Key
  - `X-Ovh-Consumer`: Consumer Key
  - `X-Ovh-Timestamp`: Unix timestamp
  - `X-Ovh-Signature`: Calculated signature

## Rule Format

Each rule is defined as: `ip_address|identifier|hostname`

- **ip_address**: OVH IP address with firewall enabled (e.g., "203.0.113.10")
- **identifier**: Unique identifier for this rule (e.g., "nas1", "office")
- **hostname**: Dynamic hostname to resolve to IP

## Usage

### Manual Execution

```bash
./update.sh
```

### Automated Execution (Cron)

Add to crontab to run every 5 minutes:

```bash
*/5 * * * * /path/to/ovhcloud/update.sh >> /path/to/ovhcloud/cron.log 2>&1
```

## How It Works

1. **DNS Resolution**: Resolves each configured hostname to its current IP
2. **Cache Check**: Compares with cached IP to detect changes
3. **API Calls**:
   - List existing firewall rules
   - If IP changed: Delete old rule and create new rule with new IP
   - If IP unchanged: No action taken
   - If rule exists for new IP: Reuses existing rule
4. **Caching**: Stores new IP for future comparisons
5. **Logging**: Records all actions with timestamps

## Firewall Rule Details

Created rules have the following properties:
- **Action**: permit
- **Protocol**: TCP
- **Source**: `<resolved-ip>`

## Logging

Logs are stored in `update.log` and automatically rotated based on `LOG_ROTATION_HOURS` (default: 168 hours/1 week).

Log format:
```
[2025-11-17 02:00:00] Starting OVH firewall update
[2025-11-17 02:00:01] Processing 203.0.113.10 - nas1 (nas.example.com)
[2025-11-17 02:00:02] IP change detected for nas1: 1.2.3.4 -> 5.6.7.8
[2025-11-17 02:00:03] Deleted firewall rule for 1.2.3.4 on 203.0.113.10
[2025-11-17 02:00:04] Created firewall rule for nas1 (5.6.7.8) on 203.0.113.10
[2025-11-17 02:00:05] Update completed: 1 rule(s) updated
```

## Caching

The script uses cache files in `.cache/`:

- **IP Cache**: `<ip_address>_<identifier>_ip.cache`
  - Stores last known IP for comparison

## Troubleshooting

### Cannot Resolve Hostname

```
WARNING: Cannot resolve nas1.example.com
```

**Solution**:
- Check hostname is correct
- Verify DNS server is accessible
- Try changing `DNS_NAMESERVER` in `.env`

### OVH API Authentication Failed

**Solution**:
- Verify credentials are correct
- Check Consumer Key is still valid
- Verify API rights include `/ip/*/firewall`

### Rule Creation Failed

**Solution**:
- Check IP has Edge Network Firewall enabled in OVH Manager
- Verify API credentials have proper rights
- Check API rate limits

## API Rate Limits

OVH has API rate limits. The script minimizes API calls by:
- Using IP cache (only updates on IP changes)
- Batching operations per IP address

## Examples

### Single NAS, Single IP

```bash
OVH_RULES=(
    "203.0.113.10|nas1|nas.example.com"
)
```

### Multiple NAS, Same IP

```bash
OVH_RULES=(
    "203.0.113.10|nas1|nas1.example.com"
    "203.0.113.10|nas2|nas2.example.com"
)
```

### Multiple IPs

```bash
OVH_RULES=(
    "203.0.113.10|nas1|nas.example.com"
    "54.38.123.45|backup|backup.example.com"
)
```

## Security Considerations

- **Credentials**: Never commit `.env` to version control
- **Permissions**: Limit API token rights to firewall management only
- **Monitoring**: Regularly review firewall rules in OVH Manager

## Related Scripts

- `../iptables/update.sh` - Server-level iptables management
- `../scaleway/update.sh` - Scaleway security group management
- `../aws/update.sh` - AWS Security Group management

## Support

For issues or questions, check the main [README](../README.md) or [API_INTEGRATION.md](../API_INTEGRATION.md).
