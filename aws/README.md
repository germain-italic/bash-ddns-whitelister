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
- **Auto-installation** of AWS CLI if not present

## Requirements

- AWS API credentials (Access Key ID and Secret Access Key)
- `curl` for downloading AWS CLI (if not installed)
- `unzip` for extracting AWS CLI package
- `dig` or `host` for DNS resolution
- Security group must exist in AWS

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
   AWS_DEFAULT_REGION="eu-west-3"

   # Rules configuration
   AWS_RULES=(
       "sg-0f4dc24e75e170997|nas1|nas1.example.com|eu-west-3"
   )
   ```

## Rule Format

Each rule is defined as: `security_group_id|identifier|hostname|region`

- **security_group_id**: AWS security group ID (e.g., "sg-0f4dc24e75e170997")
- **identifier**: Unique identifier for this rule (e.g., "nas1", "backup")
- **hostname**: Dynamic hostname to resolve to IP
- **region**: AWS region (e.g., "eu-west-3", "us-east-1", "ap-southeast-1")

### Available Regions

See [AWS Regions](https://docs.aws.amazon.com/general/latest/gr/rande.html) for complete list.

Common regions:
- `eu-west-1`, `eu-west-2`, `eu-west-3` - Europe (Ireland, London, Paris)
- `us-east-1`, `us-east-2` - US East (N. Virginia, Ohio)
- `us-west-1`, `us-west-2` - US West (N. California, Oregon)
- `ap-southeast-1`, `ap-southeast-2` - Asia Pacific (Singapore, Sydney)

## Usage

### Manual Execution

```bash
./update.sh
```

The script will automatically install AWS CLI if not present.

### Automated Execution (Cron)

Add to crontab to run every 5 minutes:

```bash
*/5 * * * * /path/to/aws/update.sh >> /path/to/aws/cron.log 2>&1
```

## How It Works

1. **AWS CLI Check**: Verifies AWS CLI is installed, installs it automatically if needed
2. **DNS Resolution**: Resolves each configured hostname to its current IP
3. **Cache Check**: Compares with cached IP to detect changes
4. **Rule Management**:
   - If IP changed: Revokes old rule and authorizes new rule with new IP
   - If IP unchanged: No action taken
   - If rules exist for new IP: Reuses existing rules (avoids duplicates)
5. **Caching**: Stores new IP and rule ID for future comparisons
6. **Logging**: Records all actions with timestamps

## AWS CLI Auto-Installation

The script includes an automatic installation mechanism for AWS CLI v2:

- Detects if AWS CLI is already installed
- Downloads AWS CLI v2 from official AWS sources
- Extracts and installs automatically
- Handles both root and sudo scenarios
- Provides detailed error messages if installation fails

If AWS CLI installation fails, you can install it manually:

```bash
# Debian/Ubuntu
sudo apt-get install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

## Security Group Rule Details

Created rules have the following properties:
- **Direction**: Inbound
- **IP Range**: `<resolved-ip>/32`
- **Protocol**: TCP
- **Port Range**: 0-65535 (all TCP ports)

## Logging

Logs are stored in `update.log` and automatically rotated based on `LOG_ROTATION_HOURS` (default: 168 hours/1 week).

Log format:
```
[2025-11-17 01:00:00] Starting AWS security group update
[2025-11-17 01:00:01] Processing security group sg-123... - nas1 (nas.example.com) in region eu-west-3
[2025-11-17 01:00:02] IP change detected for nas1: 1.2.3.4 -> 5.6.7.8
[2025-11-17 01:00:03] Deleted rule ID: sgr-xyz789 (IP: 1.2.3.4/32)
[2025-11-17 01:00:04] Created TCP rule ID: sgr-abc456 for nas1 (5.6.7.8/32)
[2025-11-17 01:00:05] Update completed: 1 rule(s) updated
```

## Caching

The script uses two types of cache files in `.cache/`:

1. **IP Cache**: `<sg_id>_<identifier>_ip.cache`
   - Stores last known IP for comparison

2. **Rule ID Cache**: `<sg_id>_<identifier>_rule_id.cache`
   - Stores AWS rule ID for updates/deletions

## Troubleshooting

### AWS CLI Not Found

The script automatically installs AWS CLI if not found. If installation fails:

```
ERROR: unzip is not installed. Please install it first:
  sudo apt-get install unzip  # Debian/Ubuntu
  sudo yum install unzip      # RHEL/CentOS
```

**Solution**: Install `unzip` then re-run the script.

### Cannot Resolve Hostname

```
WARNING: Cannot resolve nas1.example.com
```

**Solution**:
- Check hostname is correct
- Verify DNS server is accessible
- Try changing `DNS_NAMESERVER` in `.env`

### AWS Authentication Failed

**Solution**:
- Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are correct
- Check IAM user has proper permissions
- Verify region is correct

### Rule Creation Failed

**Solution**:
- Check you have permission to modify the security group (ec2:AuthorizeSecurityGroupIngress)
- Verify the security group exists in the specified region
- Check AWS API rate limits

## Required IAM Permissions

Your AWS Access Key must have the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSecurityGroupRules",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    }
  ]
}
```

## Examples

### Single NAS, Single Security Group

```bash
AWS_RULES=(
    "sg-0f4dc24e75e170997|nas1|nas.example.com|eu-west-3"
)
```

### Multiple NAS, Same Security Group

```bash
AWS_RULES=(
    "sg-0f4dc24e75e170997|nas1|nas1.example.com|eu-west-3"
    "sg-0f4dc24e75e170997|nas2|nas2.example.com|eu-west-3"
)
```

### Multiple Security Groups, Different Regions

```bash
AWS_RULES=(
    "sg-0f4dc24e75e170997|nas1|nas.example.com|eu-west-3"
    "sg-abc123def456|backup|backup.example.com|us-east-1"
    "sg-xyz789uvw123|monitor|monitor.example.com|ap-southeast-1"
)
```

## Security Considerations

- **Credentials**: Never commit `.env` to version control
- **Permissions**: Limit IAM user permissions to security groups only
- **IP Whitelisting**: Consider whitelisting specific ports instead of all TCP ports
- **Monitoring**: Regularly review security group rules in AWS console

## Related Scripts

- `../iptables/update.sh` - Server-level iptables management
- `../scaleway/update.sh` - Scaleway security group management
- `../utils/generate-report.sh` - Comprehensive server status reports

## Support

For issues or questions, check the main [README](../README.md) or [API_INTEGRATION.md](../API_INTEGRATION.md).
