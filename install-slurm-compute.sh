#!/usr/bin/env bash
set -e

echo "=== Installing SLURM Compute Node ==="

if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./install-slurm-compute.sh"
  exit 1
fi

apt update
apt install -y slurm-wlm

echo "Creating SLURM directories"
mkdir -p /etc/slurm /var/log/slurm /var/spool/slurmd

chown slurm:slurm /var/log/slurm
chmod 0755 /var/log/slurm /var/spool/slurmd

echo
echo "⚠️ REQUIRED:"
echo "Copy /etc/slurm/slurm.conf from head node"
echo
echo "After copying:"
echo "  sudo systemctl enable --now slurmd"
