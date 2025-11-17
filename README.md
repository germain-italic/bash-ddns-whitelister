# bash-ddns-whitelister

Automatic firewall whitelist management for dynamic DNS hostnames across multiple firewall types.

This unified repository contains tools to automatically update firewall rules when IP addresses of dynamic hostnames change. Perfect for managing access from servers with dynamic IPs (like NAS with DDNS).

## 📁 Repository Structure

```
bash-ddns-whitelister/
├── iptables/          # For iptables-based firewalls
├── plesk/             # For Plesk Firewall
├── ufw/               # For UFW (Uncomplicated Firewall)
├── scaleway/          # For Scaleway Security Groups API
├── aws/               # For AWS Security Groups API
├── ovhcloud/          # For OVH Edge Network Firewall API
└── utils/             # Utility scripts for mass deployment
```

## 🚀 Quick Start

### Interactive Menu

Use the interactive menu for easy access to all features:

```bash
./menu.sh
```

![Interactive Menu](https://files.italic.fr/WindowsTerminal_QrEuDNvNxT.png)

The menu provides organized access to:
- 🟢 Deploy scripts to servers
- 🔴 Uninstall scripts from servers
- 🔵 View configuration files
- 🟡 Utilities & tools
- 🟣 Firewall management
- 🔵 Verification & testing
- 🟢 Documentation & help

### Manual Deployment

Or use the command-line tools directly:

#### 1. Detect Firewall Types

Use the utility script to automatically detect what firewall each server uses:

```bash
cd utils
cp .env.dist .env
# Edit .env with your server list
./detect-firewall.sh
```

#### 2. Deploy SSH Keys

Deploy your SSH keys to all servers for passwordless authentication:

```bash
cd utils
./deploy-ssh-keys.sh
```

#### 3. Deploy DDNS Scripts

Based on firewall type detected, deploy the appropriate script:

**For iptables servers:**
```bash
cd iptables
./deploy.sh server.example.com 22 root
```

**For Plesk servers:**
```bash
cd plesk
./deploy.sh server.example.com 22 root
```

**For UFW servers:**
```bash
cd ufw
./deploy.sh server.example.com 22 root
```

#### 4. Test Connectivity

Test that your NAS can connect to all servers (run this FROM the NAS):

```bash
cd utils
./test-nas-connectivity.sh server1:22:root server2:22:root ...
```

## 📖 Detailed Documentation

Each subdirectory contains its own README with specific instructions:

- [iptables/README.md](iptables/README.md) - For iptables-based firewalls
- [plesk/README.md](plesk/README.md) - For Plesk Firewall
- [ufw/README.md](ufw/README.md) - For UFW firewalls
- [utils/README.md](utils/README.md) - Utility scripts documentation

## 🔧 How It Works

1. **DNS Resolution**: Resolves dynamic hostnames to IP addresses
2. **Change Detection**: Compares with cached IPs from previous runs
3. **Rule Management**: When IP changes:
   - Deletes old firewall rule with old IP
   - Adds new firewall rule with new IP
   - Updates cache with new IP
4. **Logging**: All changes logged with timestamps
5. **Automation**: Runs via cron every 5 minutes

## ✨ Features

- 🔄 Automatic IP resolution and firewall rule updates
- 💾 DNS caching to minimize unnecessary updates
- 📝 Detailed logging with automatic rotation
- ⏰ Cron-ready for periodic execution
- 🔒 Safe rule management (delete old, add new)
- 🎯 Support for multiple firewall types
- 🛠️ Mass deployment utilities
- 🧪 Connectivity testing tools

## 🔐 Security

- All sensitive data (hostnames, IPs, SSH keys) stored in `.env` files
- `.env` files are gitignored and never committed
- SSH key-based authentication only
- Template `.env.dist` files provided for easy setup

## 📋 Requirements

- Root access on target servers
- SSH key-based authentication configured
- Bash 4.0+
- Git (for deployment)
- `dig` or `host` command (for DNS resolution)
- `rsync` (for connectivity tests)

## 🤝 Workflow Example

Complete workflow for managing DDNS whitelisting:

```bash
# 1. Clone the repository
git clone https://github.com/germain-italic/bash-ddns-whitelister
cd bash-ddns-whitelister

# 2. Configure utilities
cd utils
cp .env.dist .env
# Edit .env with your servers and SSH keys

# 3. Detect firewall types
./detect-firewall.sh

# 4. Deploy SSH keys
./deploy-ssh-keys.sh

# 5. Deploy DDNS scripts to each server type
# For server-level firewalls (iptables, UFW, Plesk)
cd ../iptables
./deploy.sh server1.example.com 22 root

cd ../plesk
./deploy.sh server2.example.com 22 root

cd ../ufw
./deploy.sh server3.example.com 22 root

# For cloud provider APIs (Scaleway, AWS, OVH)
cd ../scaleway
./deploy.sh server4.example.com 22 root

cd ../aws
./deploy.sh server5.example.com 22 root

cd ../ovhcloud
./deploy.sh server6.example.com 22 root

# 6. Test from NAS (run this command ON the NAS)
cd ../utils
./test-nas-connectivity.sh server1:22:root server2:22:root server3:22:root
```

## 📊 Supported Firewall Types

| Firewall | Directory | Description |
|----------|-----------|-------------|
| **iptables** | `/iptables` | Standard Linux iptables firewall |
| **Plesk** | `/plesk` | Plesk Firewall (GUI-based) |
| **UFW** | `/ufw` | Uncomplicated Firewall (Ubuntu/Debian) |

## 🐛 Troubleshooting

**Problem**: Script can't connect to servers
- Check SSH key is deployed: `ssh user@server "echo OK"`
- Verify firewall allows your IP
- Check `.env` configuration

**Problem**: Rules not updating
- Check cron is running: `crontab -l`
- Review logs: `tail -f /root/bash-*/update.log`
- Verify DNS resolution: `dig hostname.example.com`

**Problem**: Permission denied
- Ensure running as root
- Check script is executable: `chmod +x update.sh`

## 📝 License

MIT License - See LICENSE file

## 👥 Author

Italic Agency

## 🙏 Contributing

Contributions welcome! Please feel free to submit a Pull Request.
