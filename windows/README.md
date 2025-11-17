# Windows Firewall DDNS Updater

Automatic Windows Firewall rule management for dynamic DNS hostnames on Windows Server 2022.

## Overview

This tool automatically updates Windows Firewall rules when IP addresses of dynamic DNS hostnames change. Perfect for managing access from servers with dynamic IPs (like NAS with DDNS services).

## Requirements

- Windows Server 2022 Standard (or compatible)
- Administrator privileges
- PowerShell 5.1 or later
- OpenSSH Server installed and configured (for remote deployment)
- SSH key-based authentication configured

## Features

- Automatic DNS resolution and firewall rule updates
- Support for Inbound and Outbound rules
- Support for TCP, UDP, and Any protocol
- Port-specific or port-agnostic rules
- IP address caching to minimize unnecessary updates
- Detailed logging with automatic rotation
- Scheduled task for periodic execution (every 5 minutes)

## Installation

### Prerequisites on Windows Server

1. **Install OpenSSH Server** (if not already installed):
   ```powershell
   Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
   Start-Service sshd
   Set-Service -Name sshd -StartupType 'Automatic'
   ```

2. **Configure SSH for key-based authentication**:

   **IMPORTANT**: For Administrator accounts, SSH keys must be placed in a special location:

   ```powershell
   # Create the directory if it doesn't exist
   New-Item -ItemType Directory -Force -Path C:\ProgramData\ssh

   # Copy your public key content to this file
   # (replace the content below with your actual public key)
   Set-Content -Path C:\ProgramData\ssh\administrators_authorized_keys -Value "ssh-rsa AAAAB3Nza..."

   # Set correct permissions (CRITICAL - SSH won't work without this)
   icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r
   icacls C:\ProgramData\ssh\administrators_authorized_keys /grant SYSTEM:`(F`)
   icacls C:\ProgramData\ssh\administrators_authorized_keys /grant BUILTIN\Administrators:`(F`)
   ```

   **Note**: For non-Administrator users, use `C:\Users\USERNAME\.ssh\authorized_keys` instead.

   Alternatively, use the utility script from Linux/WSL:
   ```bash
   # From your Linux/WSL machine
   cd utils
   ./deploy-ssh-keys.sh
   ```

### Deployment from Linux/WSL

1. **Deploy using the deployment script**:
   ```bash
   cd windows
   ./deploy.sh windows-server.example.com 22 Administrator
   ```

2. **Configure the environment**:
   - Edit `C:\bash-windows-firewall-ddns\.env` with your DNS server settings
   - Edit `C:\bash-windows-firewall-ddns\firewall_rules.conf` with your firewall rules

3. **Test the script**:
   ```powershell
   # On Windows Server
   cd C:\bash-windows-firewall-ddns
   powershell -ExecutionPolicy Bypass -File update.ps1
   ```

### Manual Installation (directly on Windows Server)

1. **Create installation directory**:
   ```powershell
   New-Item -ItemType Directory -Path "C:\bash-windows-firewall-ddns"
   cd C:\bash-windows-firewall-ddns
   ```

2. **Download/copy files**:
   - `update.ps1`
   - `.env.dist` → `.env`
   - `firewall_rules.conf.dist` → `firewall_rules.conf`

3. **Configure** `.env` and `firewall_rules.conf`

4. **Create scheduled task**:
   ```powershell
   $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File 'C:\bash-windows-firewall-ddns\update.ps1'"
   $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
   $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
   $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1) -RestartCount 3

   Register-ScheduledTask -TaskName "WindowsFirewallDDNS" -Action $action -Trigger $trigger -Principal $principal -Settings $settings
   ```

## Configuration

### .env File

```ini
DNS_NAMESERVER="1.1.1.1"
LOG_ROTATION_HOURS="168"
```

- `DNS_NAMESERVER`: DNS server for hostname resolution (e.g., 1.1.1.1, 8.8.8.8)
- `LOG_ROTATION_HOURS`: Log retention period in hours (default: 168 = 1 week)

### firewall_rules.conf File

Format: `RULE_NAME|DIRECTION|ACTION|PROTOCOL|PORT|HOSTNAME|COMMENT`

**Fields:**
- `RULE_NAME`: Unique name for the rule (no spaces)
- `DIRECTION`: `Inbound` or `Outbound`
- `ACTION`: `Allow` or `Block`
- `PROTOCOL`: `TCP`, `UDP`, or `Any` (empty = any)
- `PORT`: Port number (empty = any port)
- `HOSTNAME`: Dynamic DNS hostname to resolve
- `COMMENT`: Rule description (optional)

**Examples:**

```ini
# Allow SSH from NAS
AllowSSHFromNAS|Inbound|Allow|TCP|22|nas.example.com|SSH access from NAS

# Allow RDP from office
AllowRDPFromOffice|Inbound|Allow|TCP|3389|office.example.com|RDP from office

# Allow HTTPS from backup server
AllowHTTPSFromBackup|Inbound|Allow|TCP|443|backup.example.com|HTTPS from backup

# Allow SMB from NAS
AllowSMBFromNAS|Inbound|Allow|TCP|445|nas.example.com|SMB file sharing

# Allow all traffic from trusted host
AllowAllFromTrusted|Inbound|Allow||||trusted.example.com|Allow all from trusted

# Block outbound to specific host
BlockOutboundToHost|Outbound|Block|||blocked.example.com|Block traffic to host
```

## How It Works

1. **DNS Resolution**: Resolves dynamic hostnames using configured DNS server
2. **Change Detection**: Compares with cached IPs from previous runs
3. **Rule Management**: When IP changes:
   - Removes old firewall rule with old IP
   - Creates new firewall rule with new IP
   - Updates cache with new IP
4. **Logging**: All changes logged with timestamps to `update.log`
5. **Automation**: Runs via scheduled task every 5 minutes

## Management

### View Scheduled Task

```powershell
Get-ScheduledTask -TaskName "WindowsFirewallDDNS"
```

### Run Manually

```powershell
cd C:\bash-windows-firewall-ddns
powershell -ExecutionPolicy Bypass -File update.ps1
```

### View Logs

```powershell
Get-Content C:\bash-windows-firewall-ddns\update.log -Tail 50
```

### View Current Firewall Rules

```powershell
# List all rules created by this script
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*NAS*" -or $_.DisplayName -like "*Allow*" }

# View specific rule details
Get-NetFirewallRule -DisplayName "AllowSSHFromNAS" | Get-NetFirewallAddressFilter
```

### Disable/Enable Scheduled Task

```powershell
# Disable
Disable-ScheduledTask -TaskName "WindowsFirewallDDNS"

# Enable
Enable-ScheduledTask -TaskName "WindowsFirewallDDNS"
```

## Troubleshooting

### Script fails with "Execution Policy" error

Run PowerShell as Administrator and set execution policy:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

Or run with bypass flag:
```powershell
powershell -ExecutionPolicy Bypass -File update.ps1
```

### DNS resolution fails

1. Check DNS server is reachable:
   ```powershell
   Test-Connection -ComputerName 1.1.1.1
   ```

2. Test DNS resolution manually:
   ```powershell
   Resolve-DnsName -Name nas.example.com -Type A
   ```

3. Try different DNS server in `.env` (e.g., 8.8.8.8)

### Firewall rules not updating

1. Check script is running:
   ```powershell
   Get-ScheduledTaskInfo -TaskName "WindowsFirewallDDNS"
   ```

2. View logs for errors:
   ```powershell
   Get-Content C:\bash-windows-firewall-ddns\update.log
   ```

3. Verify Administrator privileges:
   ```powershell
   ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
   ```

### SSH connection fails during deployment

1. **Verify OpenSSH Server is running**:
   ```powershell
   Get-Service sshd
   ```

2. **Check firewall allows SSH**:
   ```powershell
   Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
   ```

3. **Verify SSH keys are deployed in the CORRECT location**:

   **For Administrator accounts** (IMPORTANT):
   ```powershell
   # SSH keys MUST be in this location for Administrator
   Get-Content C:\ProgramData\ssh\administrators_authorized_keys

   # Verify permissions are correct
   icacls C:\ProgramData\ssh\administrators_authorized_keys
   # Should show: SYSTEM:(F) and BUILTIN\Administrators:(F) ONLY
   ```

   **For non-Administrator users**:
   ```powershell
   Get-Content C:\Users\USERNAME\.ssh\authorized_keys
   ```

4. **Fix Administrator SSH key permissions** (if needed):
   ```powershell
   icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r
   icacls C:\ProgramData\ssh\administrators_authorized_keys /grant SYSTEM:`(F`)
   icacls C:\ProgramData\ssh\administrators_authorized_keys /grant BUILTIN\Administrators:`(F`)

   # Restart SSH service after fixing permissions
   Restart-Service sshd
   ```

## Security Notes

- Script requires Administrator privileges to manage firewall
- Runs as SYSTEM account via scheduled task
- All sensitive data (hostnames, IPs) stored in local configuration files
- No external credentials required (uses Windows Firewall API)
- Logs contain resolved IPs and rule changes

## Files

- `update.ps1`: Main PowerShell script for updating firewall rules
- `.env`: Configuration file (DNS server, log settings)
- `firewall_rules.conf`: Firewall rules configuration
- `.cache/`: IP address cache directory
- `update.log`: Log file with timestamps
- `deploy.sh`: Remote deployment script (run from Linux/WSL)

## Uninstallation

```powershell
# Remove scheduled task
Unregister-ScheduledTask -TaskName "WindowsFirewallDDNS" -Confirm:$false

# Remove firewall rules (adjust pattern as needed)
Get-NetFirewallRule | Where-Object { $_.Description -like "*DDNS*" } | Remove-NetFirewallRule

# Remove installation directory
Remove-Item -Path "C:\bash-windows-firewall-ddns" -Recurse -Force
```

## Integration with bash-ddns-whitelister

This tool is part of the `bash-ddns-whitelister` project which supports multiple firewall types:

- **iptables** (Linux)
- **UFW** (Ubuntu/Debian)
- **Plesk Firewall** (Plesk servers)
- **Windows Firewall** (Windows Server 2022)
- **Scaleway Security Groups** (Cloud API)
- **AWS Security Groups** (Cloud API)
- **OVH Edge Network Firewall** (Cloud API)

See main repository README for multi-platform deployment strategies.

## License

MIT License - See LICENSE file

## Support

For issues or questions, please check:
1. Logs in `C:\bash-windows-firewall-ddns\update.log`
2. Scheduled task status
3. DNS resolution manually
4. Windows Event Viewer for system errors
