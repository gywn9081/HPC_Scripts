#!/usr/bin/env bash
set -e

echo "=== Installing SLURM Head Node ==="

if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./install-slurm-headnode.sh"
  exit 1
fi

apt update
apt install -y slurm-wlm slurmdbd mariadb-server

echo "Creating SLURM directories"
mkdir -p /etc/slurm /var/log/slurm /var/spool/slurmctld

chown slurm:slurm /var/log/slurm /var/spool/slurmctld
chmod 0755 /var/log/slurm /var/spool/slurmctld

echo
echo "⚠️ NEXT STEPS (manual but required):"
echo "1. Create /etc/slurm/slurm.conf"
echo "2. Copy slurm.conf to ALL compute nodes"
echo "3. Ensure Munge is running everywhere"
echo
echo "To start controller:"
echo "  sudo systemctl enable --now slurmctld"
