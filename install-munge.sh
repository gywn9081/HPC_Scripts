#!/usr/bin/env bash
set -e

echo "=== Installing MUNGE ==="

if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./install-munge.sh"
  exit 1
fi

apt update
apt install -y munge libmunge-dev

echo "Ensuring munge directories"
mkdir -p /etc/munge /var/lib/munge /var/log/munge /run/munge

chown -R munge:munge /etc/munge /var/lib/munge /var/log/munge /run/munge
chmod 0700 /etc/munge /var/lib/munge /var/log/munge /run/munge

echo
echo "⚠️ IMPORTANT:"
echo "Copy the SAME /etc/munge/munge.key to ALL nodes"
echo "Permissions must be: munge:munge 0400"
echo
echo "Do NOT start munge until the key is in place."
