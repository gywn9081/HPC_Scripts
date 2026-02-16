#!/usr/bin/env bash
set -e

echo "=== SLURM Static Network Bootstrap ==="

# ----------- CONFIG (EDIT PER NODE) ----------------
HOSTNAME="compute02"

NODE_IP="10.42.0.102/24"
GATEWAY="10.42.0.1"

HEAD_HOSTNAME="headnode"
HEAD_IP="10.42.0.111"

DNS_SERVERS="10.42.0.1,8.8.8.8"

# Cluster host list (IP hostname)
CLUSTER_HOSTS="
10.42.0.111    headnode
10.42.0.101  compute01
10.42.0.102  compute02
10.42.0.103  compute03
"
# --------------------------------------------------

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./setup-static-network-slurm.sh"
  exit 1
fi

echo "Setting hostname to $HOSTNAME"
hostnamectl set-hostname "$HOSTNAME"

# Ensure /etc/hostname is correct
echo "$HOSTNAME" > /etc/hostname

# Detect Ethernet interface
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^en|^eth' | head -n 1)

if [ -z "$IFACE" ]; then
  echo "ERROR: No Ethernet interface detected"
  exit 1
fi

echo "Detected interface: $IFACE"

NETPLAN_FILE="/etc/netplan/01-slurm-static.yaml"

echo "Writing netplan config"
cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      addresses:
        - $NODE_IP
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS_SERVERS]
      optional: true
  wifis:
    wlan0:
      dhcp4: true
      optional: true
      access-points:
        "TigerWiFi-Guest":
          password: "TrumanTiger"
EOF

# Disable cloud-init netplan if present
if [ -f /etc/netplan/50-cloud-init.yaml ]; then
  mv /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak
fi

echo "Disabling NetworkManager (if present)"
systemctl disable --now NetworkManager 2>/dev/null || true

echo "Enabling systemd-networkd"
systemctl enable --now systemd-networkd
systemctl enable --now systemd-resolved

echo "Applying netplan"
netplan generate
netplan apply
systemctl restart systemd-networkd

# ---------------- /etc/hosts ----------------
echo "Updating /etc/hosts"

# Preserve localhost lines
grep -E '^(127\.0\.0\.1|::1)' /etc/hosts > /tmp/hosts.new

echo "$CLUSTER_HOSTS" >> /tmp/hosts.new

mv /tmp/hosts.new /etc/hosts

# ---------------- Validation ----------------
echo
echo "=== Validation ==="

echo "Hostname:"
hostname

echo
echo "IP configuration:"
ip addr show "$IFACE"

echo
echo "Routing table:"
ip route

echo
echo "Pinging head node ($HEAD_HOSTNAME / $HEAD_IP)"
if ping -c 3 "$HEAD_IP" > /dev/null; then
  echo "✔ Head node reachable by IP"
else
  echo "✖ ERROR: Cannot reach head node by IP"
  exit 1
fi

if ping -c 3 "$HEAD_HOSTNAME" > /dev/null; then
  echo "✔ Head node reachable by hostname"
else
  echo "✖ ERROR: Cannot resolve head node hostname"
  exit 1
fi

echo
echo "=== Network bootstrap complete ==="
echo "Node $HOSTNAME is ready for munge + SLURM"
