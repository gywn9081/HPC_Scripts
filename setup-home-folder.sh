#!/usr/bin/env bash

# configs --------------------------------------
echo "=== Verifying Home Folder Configuration ==="
HEAD_NODE="headnode"
CURRENT_HOST=$(hostname -s)
USERNAME="mpiuser"
EXPECTED_UID="2642"
GATEWAY_ADDRESS="10.42.0.1/24"

DIR="/home/$USERNAME"
EXPORTS_FILE="/etc/exports"
EXPORT_LINE="$DIR 10.42.0.0/24(rw,sync,no_subtree_check,no_root_squash)"
FSTAB_FILE="/etc/fstab"
FSTAB_LINE="${HEAD_NODE}:${DIR} ${DIR} nfs defaults,_netdev,hard,intr 0 0"
# --------------------------------------------------

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./setup-home-folder.sh"
  exit 1
fi

# 0. ENFORCE UID EXPECTATIONS
if id "$USERNAME" &>/dev/null; then
    ACTUAL_UID=$(id -u "$USERNAME")
    if [[ "$ACTUAL_UID" != "$EXPECTED_UID" ]]; then
        echo "ERROR: $USERNAME has UID $ACTUAL_UID, expected $EXPECTED_UID"
        exit 1
    fi
else
    echo "ERROR: User $USERNAME does not exist"
    exit 1
fi

# 1. ENSURE DIRECTORY EXISTS (All Nodes)
echo "[ALL] Ensuring $DIR exists with correct ownership"
if [[ ! -d "$DIR" ]]; then
    echo "Creating $DIR"
    mkdir -p "$DIR"
    # Note: chown might fail if the user mpiuser doesn't exist yet
    chown $USERNAME:$USERNAME "$DIR" || true
fi
chmod 755 "$DIR"

# 2. HEAD NODE ONLY: Setup Exports
if [[ "$CURRENT_HOST" == "$HEAD_NODE" ]]; then
    echo "[HEAD NODE] Configuring NFS Exports..."
    
    if ! grep -Fxq "$EXPORT_LINE" "$EXPORTS_FILE"; then
        echo "$EXPORT_LINE" >> "$EXPORTS_FILE"
    fi

    echo "[HEAD NODE] Reloading NFS exports"
    exportfs -ra

    if command -v ufw >/dev/null 2>&1; then
        echo "[HEAD NODE] Updating firewall..."
        ufw allow from "$GATEWAY_ADDRESS" >/dev/null || true
    fi

# 3. WORKER NODES ONLY: Mount the Share
else
    echo "[NODE] Configuring Client Mounts..."
    
    if mountpoint -q "$DIR"; then
        echo "[NODE] Already mounted: $DIR"
    else
        echo "[NODE] Mounting ${HEAD_NODE}:${DIR}..."
        mount "${HEAD_NODE}:${DIR}" "$DIR" || echo "Mount failed - check if nfs-common is installed."
    fi

    # Ensure fstab entry for persistence
    if ! grep -q "${HEAD_NODE}:${DIR}" "$FSTAB_FILE"; then
        echo "$FSTAB_LINE" >> "$FSTAB_FILE"
        echo "[NODE] Added fstab entry."
    fi
fi

echo "Done on $CURRENT_HOST."
