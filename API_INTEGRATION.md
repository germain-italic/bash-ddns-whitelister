# API Integration for Network-Level Firewalls

Some servers are protected by cloud provider network-level firewalls (security groups, edge firewalls) that require API calls to manage IP whitelisting. This document lists the servers and required API integrations.

## Overview

The following servers have both:
1. **Server-level firewall** (iptables/UFW/Plesk) - ✅ Already managed by bash-ddns-whitelister
2. **Network-level firewall** - ⚠️ Requires API integration scripts

## Servers Requiring API Integration

### 1. Scaleway Security Groups (2 servers)

**Servers:**
- `1p.italic.fr` (iptables + Scaleway security group)
- `discourse.italic.fr` (iptables + Scaleway security group)

**Current Status:**
- ✅ Server-level iptables rules deployed and working
- ❌ Network-level security group blocks NAS connections

**API Documentation:**
- [Scaleway Instance API](https://www.scaleway.com/en/developers/api/instance/)
- [Security Groups API Reference](https://www.scaleway.com/en/developers/api/instance/#path-security-groups)

**Required API Calls:**
```bash
# Get security group ID
GET /instance/v1/zones/{zone}/servers/{server_id}

# List security group rules
GET /instance/v1/zones/{zone}/security_groups/{security_group_id}

# Add inbound rule for NAS IP
POST /instance/v1/zones/{zone}/security_groups/{security_group_id}/rules
{
  "action": "accept",
  "direction": "inbound",
  "ip_range": "81.51.73.213/32",
  "protocol": "ALL",
  "description": "NAS nas1.example.com (managed by bash-ddns-whitelister)"
}

# Update rule when IP changes
PUT /instance/v1/zones/{zone}/security_groups/{security_group_id}/rules/{rule_id}

# Delete old rule
DELETE /instance/v1/zones/{zone}/security_groups/{security_group_id}/rules/{rule_id}
```

**Authentication:**
- API Token (X-Auth-Token header)
- Can be generated in Scaleway Console

**Script to Develop:**
- `utils/scaleway-security-group-update.sh`
- Should follow same pattern as update.sh scripts
- Store security group IDs and zones in config

---

### 2. AWS Security Groups (1 server)

**Servers:**
- `13.36.123.138` (iptables + AWS EC2 security group)

**Current Status:**
- ✅ Server-level iptables rules deployed and working
- ❌ Network-level security group blocks NAS connections

**API Documentation:**
- [AWS EC2 API Reference](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/)
- [Security Groups Actions](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_Operations_Amazon_EC2.html)

**Required API Calls:**
```bash
# Describe instance to get security group IDs
aws ec2 describe-instances --instance-ids i-xxxxx

# Add inbound rule for NAS IP
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --ip-permissions IpProtocol=-1,FromPort=-1,ToPort=-1,IpRanges='[{CidrIp=81.51.73.213/32,Description="NAS nas1.example.com"}]'

# Revoke old rule when IP changes
aws ec2 revoke-security-group-ingress \
  --group-id sg-xxxxx \
  --ip-permissions IpProtocol=-1,FromPort=-1,ToPort=-1,IpRanges='[{CidrIp=<old-ip>/32}]'
```

**Authentication:**
- AWS Access Key ID and Secret Access Key
- Can use IAM role if running from AWS
- Or AWS CLI credentials file

**Script to Develop:**
- `utils/aws-security-group-update.sh`
- Should follow same pattern as update.sh scripts
- Store instance IDs, security group IDs, and region in config

---

### 3. OVH Edge Network Firewall (1 server)

**Servers:**
- `debug.not.live:2222` (iptables + OVH edge network firewall)

**Current Status:**
- ✅ Server-level iptables rules deployed and working
- ❌ Network-level edge firewall blocks NAS connections

**API Documentation:**
- [OVH API Console](https://api.ovh.com/console/)
- [IP Firewall API](https://api.ovh.com/console/#/ip)

**Required API Calls:**
```bash
# List firewall rules for an IP
GET /ip/{ip}/firewall

# Add firewall rule
POST /ip/{ip}/firewall
{
  "action": "permit",
  "protocol": "all",
  "source": "81.51.73.213",
  "tcpOption": {
    "fragments": false
  }
}

# Remove rule when IP changes
DELETE /ip/{ip}/firewall/{ipOnFirewall}
```

**Authentication:**
- Application Key, Application Secret, Consumer Key
- Can be generated in OVH API Console

**Script to Develop:**
- `utils/ovh-edge-firewall-update.sh`
- Should follow same pattern as update.sh scripts
- Store IP addresses and service names in config

---

## Common Script Architecture

All API integration scripts should follow this pattern:

### Configuration (.env)
```bash
# Cloud provider credentials
SCALEWAY_API_TOKEN="scw-xxxxx"
SCALEWAY_ZONE="fr-par-1"

AWS_ACCESS_KEY_ID="AKIA..."
AWS_SECRET_ACCESS_KEY="..."
AWS_REGION="eu-west-3"

OVH_APP_KEY="..."
OVH_APP_SECRET="..."
OVH_CONSUMER_KEY="..."

# Server-specific config
# Format: hostname:cloud_resource_id
SCALEWAY_SERVERS=(
    "1p.italic.fr:sg-xxxxx"
    "discourse.italic.fr:sg-yyyyy"
)

AWS_SERVERS=(
    "13.36.123.138:sg-xxxxx"
)

OVH_SERVERS=(
    "debug.not.live:51.210.xx.xx"
)

# NAS hostname to whitelist
NAS_HOSTNAME="nas1.example.com"
```

### Script Flow
1. Read configuration
2. Resolve NAS hostname to current IP
3. Check cached IP (same as current scripts)
4. If IP changed:
   - Call API to remove old rule (if exists)
   - Call API to add new rule with new IP
   - Update cache
5. Log results

### Error Handling
- API connection failures
- Rate limiting
- Invalid credentials
- Rule conflicts

### Logging
- Same format as current update.sh scripts
- Log API calls and responses
- Store in respective directories

---

## Implementation Priority

1. **Scaleway** (2 servers) - Most critical
2. **AWS** (1 server) - Medium priority
3. **OVH** (1 server) - Lower priority

---

## Testing Checklist

For each API integration script:

- [ ] Test with valid credentials
- [ ] Test with invalid credentials (should fail gracefully)
- [ ] Test IP update (change NAS IP)
- [ ] Test no change (IP same as cached)
- [ ] Test first run (no cached IP)
- [ ] Test API rate limiting handling
- [ ] Test concurrent execution safety
- [ ] Verify rules are properly labeled/tagged
- [ ] Test cron job integration

---

## Future Enhancements

- Unified API management script that detects cloud provider automatically
- Dashboard to view all rules across all providers
- Alerts when API calls fail
- Automatic credential rotation
- Terraform/IaC integration for infrastructure-as-code approach

---

## Notes

- All server-level firewalls (iptables/UFW/Plesk) are already working
- Network-level firewalls only block connections from outside the local machine
- SSH access works because you connect from whitelisted IPs
- NAS connections fail because NAS IP (81.51.73.213) is not whitelisted at network level
