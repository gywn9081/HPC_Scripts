#!/bin/bash/env bash

# configs --------------------------------------
echo "=== Verifying Home Folder Configuration ==="
HEAD_NODE="headnode"
USERNAME="mpiuser"
EXPECTED_UID="2642"
GATEWAY_ADDRESS="10.42.0.1/24"

DIR="/home/$USERNAME"
EXPORTS_FILE="/etc/exports"
EXPORT_LINE="$DIR *(rw,sync,no_subtree_check)"
FSTAB_FILE="/etc/fstab"
# fstab should have 6 fields; this is the common safe form:
FSTAB_LINE="${HEAD_NODE}:${DIR} ${DIR} nfs defaults,_netdev 0 0"
# --------------------------------------------------

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./setup-home-folder.sh"
  exit 1
fi

# check directory exists
echo "[ALL] Ensuring $DIR exists with correct ownership"
if [[ ! -d "$DIR" ]]; then
    echo "Directory $DIR does not exist."
    echo "Creating $DIR"
    mkdir -p "$DIR"
    chown $USERNAME:$USERNAME "$DIR"
fi

# check 755 permissions
chmod u+rwx,g+rx,o+rx "$DIR"

# Add export entry if not already present
if ! grep -Fxq "$EXPORT_LINE" "$EXPORTS_FILE"; then
    echo "[ALL] Adding NFS export entry..."
    echo "$EXPORT_LINE" >> "$EXPORTS_FILE"
else
    echo "[ALL] Export entry already exists."
fi

# Reload NFS exports
echo "[ALL] Reloading NFS exports"
exportfs -ra

# Check folder is checked correctly
if command -v showmount >/dev/null 2>&1; then
showmount -e "$HEAD_NODE" || true
else
    echo "[HEAD NODE] showmount not found (run 'setup-nfs.sh' to use it)."
    exit 1
fi
else
    echo "[NODE] Not head node (${HEAD_NODE}); skipping exports/NFS-server steps."
fi

# Firewall check
echo "[ALL] Firewall check (ufw)..."
if command -v ufw >/dev/null 2>&1; then
  # This will add the rule if needed; ufw may say "Skipping" if it already exists.
  ufw allow from "$GATEWAY_ADDRESS" >/dev/null || true
else
  echo "[ALL] ufw not installed; skipping ufw rule."
fi

# ===== ALL NODES: mount share =====
echo "[ALL] Ensuring mount point ${DIR} exists..."
mkdir -p "$DIR"

echo "[ALL] Mounting ${HEAD_NODE}:${DIR} -> ${DIR}"
if mountpoint -q "$DIR"; then
  echo "[ALL] Already mounted: ${DIR}"
else
  # may fail if NFS client tools missing; we’ll surface the error
  mount "${HEAD_NODE}:${DIR}" "$DIR"
  echo "[ALL] Mounted."
fi

# ===== ALL NODES: ensure fstab entry for boot mount =====
echo "[ALL] Ensuring fstab entry exists..."
if ! grep -Fxq "$FSTAB_LINE" "$FSTAB_FILE"; then
  echo "$FSTAB_LINE" >> "$FSTAB_FILE"
  echo "[ALL] Added fstab line:"
  echo "      $FSTAB_LINE"
else
  echo "[ALL] fstab line already present."
fi

echo "Done."
echo "Tip: to test sharing, create a file on master:  touch ${DIR}/hello"
echo "Then check other nodes:  ls -l ${DIR}/hello"