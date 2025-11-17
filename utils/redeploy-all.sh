#!/bin/bash
# Re-deploy bash-ddns-whitelister firewall scripts to all servers

set -euo pipefail

REPO_DIR="/home/germain/dev/bash-ddns-whitelister"

# Servers to deploy (host:port:user:firewall_type)
SERVERS=(
    "server1.example.com:22:root:iptables"
    "server2.example.com:22:root:plesk"
    "server3.example.com:22:root:iptables"
    "server4.example.com:22:root:iptables"
    "server5.example.com:22:root:iptables"
    "server6.example.com:22:root:iptables"
    "server7.example.com:22:root:ufw"
    "server8.example.com:22:root:ufw"
    "server9.example.com:22:root:iptables"
    "server10.example.com:2222:root:iptables"
    "server11.example.com:22:root:iptables"
    "server12.example.com:22:root:iptables"
    "server13.example.com:22:root:plesk"
)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Re-deploying firewall scripts to all servers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for server in "${SERVERS[@]}"; do
    IFS=':' read -ra PARTS <<< "$server"

    host="${PARTS[0]}"
    port="${PARTS[1]}"
    user="${PARTS[2]}"
    fw="${PARTS[3]}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📡 $host ($fw)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    cd "$REPO_DIR/$fw"

    if ./deploy.sh "$host" "$port" "$user"; then
        echo "✅ Deployed successfully"
    else
        echo "❌ Deployment failed"
    fi

    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All deployments completed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
