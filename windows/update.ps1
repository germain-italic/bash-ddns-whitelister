# Windows Firewall DDNS Update Script
# Automatically updates Windows Firewall rules when dynamic DNS hostnames change IP addresses

#Requires -RunAsAdministrator

# Configuration
$SCRIPT_DIR = $PSScriptRoot
$ENV_FILE = Join-Path $SCRIPT_DIR ".env"
$RULES_FILE = Join-Path $SCRIPT_DIR "firewall_rules.conf"
$CACHE_DIR = Join-Path $SCRIPT_DIR ".cache"
$LOG_FILE = Join-Path $SCRIPT_DIR "update.log"

# Create cache directory if it doesn't exist
if (-not (Test-Path $CACHE_DIR)) {
    New-Item -ItemType Directory -Path $CACHE_DIR | Out-Null
}

# Function to write to log file with timestamp
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $LOG_FILE -Value $logMessage
    Write-Host $logMessage
}

# Function to resolve hostname to IP
function Resolve-HostnameToIP {
    param([string]$Hostname)

    try {
        $result = Resolve-DnsName -Name $Hostname -Type A -ErrorAction Stop
        if ($result -and $result.IPAddress) {
            return $result.IPAddress
        }
    } catch {
        Write-Log "ERROR: Failed to resolve $Hostname - $_"
        return $null
    }

    return $null
}

# Function to rotate old logs
function Rotate-Logs {
    param([int]$MaxAgeHours)

    if (Test-Path $LOG_FILE) {
        $logAge = (Get-Date) - (Get-Item $LOG_FILE).LastWriteTime
        if ($logAge.TotalHours -gt $MaxAgeHours) {
            $archiveName = Join-Path $SCRIPT_DIR "update.log.old"
            Move-Item -Path $LOG_FILE -Destination $archiveName -Force
            Write-Log "Rotated old log file"
        }
    }
}

# Load environment variables
if (-not (Test-Path $ENV_FILE)) {
    Write-Error "ERROR: .env file not found at $ENV_FILE"
    exit 1
}

# Parse .env file
$envVars = @{}
Get-Content $ENV_FILE | ForEach-Object {
    if ($_ -match '^([^#][^=]+)=(.*)$') {
        $envVars[$matches[1].Trim()] = $matches[2].Trim().Trim('"')
    }
}

$DNS_NAMESERVER = $envVars["DNS_NAMESERVER"]
$LOG_ROTATION_HOURS = [int]$envVars["LOG_ROTATION_HOURS"]

# Rotate logs if needed
if ($LOG_ROTATION_HOURS -gt 0) {
    Rotate-Logs -MaxAgeHours $LOG_ROTATION_HOURS
}

Write-Log "=========================================="
Write-Log "Starting Windows Firewall DDNS update"
Write-Log "=========================================="

# Check if rules file exists
if (-not (Test-Path $RULES_FILE)) {
    Write-Log "ERROR: Rules file not found at $RULES_FILE"
    exit 1
}

# Read and process rules
$rulesProcessed = 0
$rulesUpdated = 0

Get-Content $RULES_FILE | ForEach-Object {
    $line = $_.Trim()

    # Skip comments and empty lines
    if ($line -match '^#' -or $line -eq '') {
        return
    }

    # Parse rule: RULE_NAME|DIRECTION|ACTION|PROTOCOL|PORT|HOSTNAME|COMMENT
    $fields = $line -split '\|'
    if ($fields.Count -lt 6) {
        Write-Log "WARNING: Invalid rule format: $line"
        return
    }

    $ruleName = $fields[0].Trim()
    $direction = $fields[1].Trim()  # Inbound or Outbound
    $action = $fields[2].Trim()     # Allow or Block
    $protocol = $fields[3].Trim()   # TCP, UDP, or Any
    $port = $fields[4].Trim()       # Port number or empty
    $hostname = $fields[5].Trim()
    $comment = if ($fields.Count -gt 6) { $fields[6].Trim() } else { "DDNS rule for $hostname" }

    $rulesProcessed++

    Write-Log "Processing rule: $ruleName"

    # Resolve hostname
    $newIP = Resolve-HostnameToIP -Hostname $hostname
    if (-not $newIP) {
        Write-Log "ERROR: Could not resolve $hostname, skipping..."
        return
    }

    Write-Log "Resolved $hostname to $newIP"

    # Check cache
    $cacheFile = Join-Path $CACHE_DIR "$ruleName.cache"
    $cachedIP = $null
    if (Test-Path $cacheFile) {
        $cachedIP = Get-Content $cacheFile -ErrorAction SilentlyContinue
    }

    # Check if IP changed
    if ($newIP -eq $cachedIP) {
        Write-Log "IP unchanged for $hostname ($newIP), skipping..."
        return
    }

    Write-Log "IP changed for $hostname (old: $cachedIP, new: $newIP)"

    # Remove old firewall rule if it exists
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Write-Log "Removing old firewall rule: $ruleName"
        Remove-NetFirewallRule -DisplayName $ruleName
    }

    # Create new firewall rule
    Write-Log "Creating new firewall rule: $ruleName"

    $ruleParams = @{
        DisplayName = $ruleName
        Description = $comment
        Direction = $direction
        Action = $action
        Enabled = 'True'
    }

    # Add protocol if specified
    if ($protocol -ne '' -and $protocol -ne 'Any') {
        $ruleParams['Protocol'] = $protocol
    }

    # Add port if specified
    if ($port -ne '') {
        if ($direction -eq 'Inbound') {
            $ruleParams['LocalPort'] = $port
        } else {
            $ruleParams['RemotePort'] = $port
        }
    }

    # Add remote address
    $ruleParams['RemoteAddress'] = $newIP

    try {
        New-NetFirewallRule @ruleParams | Out-Null
        Write-Log "Successfully created firewall rule for $newIP"

        # Update cache
        Set-Content -Path $cacheFile -Value $newIP
        $rulesUpdated++
    } catch {
        Write-Log "ERROR: Failed to create firewall rule: $_"
    }
}

Write-Log "=========================================="
Write-Log "Update complete: $rulesProcessed rules processed, $rulesUpdated rules updated"
Write-Log "=========================================="
