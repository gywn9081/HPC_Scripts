#!/usr/bin/env bash

# configs ------------------------------
echo "=== Master Node Network File System Setup ==="
HEAD_NODE="headnode"
USERNAME="mpiuser"
# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./setup-network-file-system.sh"
  exit 1
fi

#run sudo apt update
echo "running sudo apt-get update"
sudo apt-get update

# check which type of node is being used, then install NFS server if needed
if [[ "$(hostname -s)" == "$HEAD_NODE" ]]; then
      if ! dpkg -s nfs-kernel-server &>/dev/null; then
      echo "[HEAD NODE] NFS server not found. Installing..."
      apt-get install -y nfs-kernel-server
fi
else
      if ! dpkg -s nfs-common &>/dev/null; then
      echo "[NODE] NFS client not found. Installing..."
      apt-get install -y nfs-common
      fi
fi

echo "NFS setup complete on $(hostname -s)."
