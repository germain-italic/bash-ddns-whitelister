# AWS Security Group DDNS Whitelist

Automatic security group rule management for AWS EC2 instances with dynamic DNS hostnames.

## Overview

This script automatically updates AWS security group rules when a dynamic hostname's IP changes. It uses the AWS CLI to manage inbound rules.

## Features

- Automatic IP resolution from dynamic hostnames
- Creates/updates security group rules via AWS CLI
- Supports multiple security groups and hostnames
- IP caching to minimize API calls
- Comprehensive logging with rotation
- Multi-region support

## Requirements

- AWS CLI installed and configured
- AWS IAM user with appropriate permissions (see below)
- `dig` or `host` for DNS resolution
- Security group must exist in AWS

## IAM Permissions Required

Create an IAM user with the following policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSecurityGroupRules",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    }
  ]
}
```

## Configuration

1. Copy the environment template:
   ```bash
   cp .env.dist .env
   ```

2. Edit `.env` with your credentials:
   ```bash
   # AWS API credentials
   AWS_ACCESS_KEY_ID="your-access-key-id"
   AWS_SECRET_ACCESS_KEY="your-secret-access-key"
   AWS_DEFAULT_REGION="eu-west-1"

   # Rules configuration
   AWS_RULES=(
       "sg-0123456789abcdef0|nas1|nas1.example.com|eu-west-1"
       "sg-abcdef0123456789|nas2|nas2.example.com|us-east-1"
   )
   ```

## Rule Format

Each rule is defined as: `security_group_id|identifier|hostname|region`

- **security_group_id**: ID of the AWS security group (e.g., "sg-0123456789abcdef0")
- **identifier**: Unique identifier for this rule (e.g., "nas1", "backup")
- **hostname**: Dynamic hostname to resolve to IP
- **region**: AWS region (e.g., "eu-west-1", "us-east-1", "ap-southeast-1")

### Common AWS Regions

- `eu-west-1` - Ireland
- `eu-west-2` - London
- `eu-west-3` - Paris
- `eu-central-1` - Frankfurt
- `us-east-1` - N. Virginia
- `us-west-1` - N. California
- `us-west-2` - Oregon
- `ap-southeast-1` - Singapore
- `ap-northeast-1` - Tokyo

## Usage

### Install AWS CLI

If not already installed:

```bash
# On Debian/Ubuntu
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

### Manual Execution

```bash
./update.sh
```

### Automated Execution (Cron)

Add to crontab to run every 5 minutes:

```bash
*/5 * * * * /path/to/aws/update.sh >> /path/to/aws/cron.log 2>&1
```

## How It Works

1. **DNS Resolution**: Resolves each configured hostname to its current IP
2. **Cache Check**: Compares with cached IP to detect changes
3. **Rule Management**:
   - If IP changed: Deletes old rule and creates new rule with new IP
   - If IP unchanged: No action taken
4. **Caching**: Stores new IP and rule ID for future comparisons
5. **Logging**: Records all actions with timestamps

## Security Group Rule Details

Created rules have the following properties:
- **Protocol**: TCP
- **Port Range**: 0-65535 (all TCP ports)
- **IP Range**: `<resolved-ip>/32`
- **Description**: Identifier specified in the rule

## Logging

Logs are stored in `update.log` and automatically rotated based on `LOG_ROTATION_HOURS` (default: 168 hours/1 week).

Log format:
```
[2025-11-17 00:00:00] Starting AWS security group update
[2025-11-17 00:00:01] Processing security group sg-abc123 - nas1 (nas1.example.com)
[2025-11-17 00:00:02] IP change detected for nas1: 1.2.3.4 -> 5.6.7.8
[2025-11-17 00:00:03] Deleted rule ID: sgr-xyz789
[2025-11-17 00:00:04] Created TCP rule ID: sgr-abc456 for nas1 (5.6.7.8/32)
[2025-11-17 00:00:05] Update completed: 1 rule(s) updated
```

## Caching

The script uses two types of cache files in `.cache/`:

1. **IP Cache**: `<sg_id>_<identifier>_ip.cache`
   - Stores last known IP for comparison

2. **Rule ID Cache**: `<sg_id>_<identifier>_rule_id.cache`
   - Stores AWS rule ID for updates/deletions

## Troubleshooting

### Security Group Not Found

```
ERROR: Cannot find security group sg-abc123
```

**Solution**: Verify the security group exists and the ID is correct. Check region is correct.

### Cannot Resolve Hostname

```
WARNING: Cannot resolve nas1.example.com
```

**Solution**:
- Check hostname is correct
- Verify DNS server is accessible
- Try changing `DNS_NAMESERVER` in `.env`

### AWS Authentication Failed

**Solution**: Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are correct.

### Permission Denied

```
ERROR: User is not authorized to perform: ec2:AuthorizeSecurityGroupIngress
```

**Solution**: Check IAM user has the required permissions (see IAM Permissions section).

### AWS CLI Not Found

```
ERROR: aws command not found
```

**Solution**: Install AWS CLI (see Installation section).

## API Rate Limits

AWS has API rate limits. The script minimizes API calls by:
- Using IP cache (only updates on IP changes)
- Using rule ID cache (avoids searching for rules)
- Batching operations per security group

## Examples

### Single NAS, Single Security Group

```bash
AWS_RULES=(
    "sg-0123456789abcdef0|nas1|nas.example.com|eu-west-1"
)
```

### Multiple NAS, Same Security Group

```bash
AWS_RULES=(
    "sg-0123456789abcdef0|nas1|nas1.example.com|eu-west-1"
    "sg-0123456789abcdef0|nas2|nas2.example.com|eu-west-1"
)
```

### Multiple Security Groups, Different Regions

```bash
AWS_RULES=(
    "sg-0123456789abcdef0|nas1|nas.example.com|eu-west-1"
    "sg-abcdef0123456789|backup|backup.example.com|us-east-1"
    "sg-fedcba9876543210|monitoring|monitor.example.com|ap-southeast-1"
)
```

## Security Considerations

- **Credentials**: Never commit `.env` to version control
- **Permissions**: Limit IAM user permissions to security groups only
- **IP Whitelisting**: Consider limiting to specific ports instead of all TCP
- **Monitoring**: Regularly review security group rules in AWS console

## Related Scripts

- `../scaleway/update.sh` - Scaleway security group management
- `../iptables/update.sh` - Server-level iptables management
- `../utils/generate-report.sh` - Comprehensive server status reports

## Support

For issues or questions, check the main [README](../README.md).
