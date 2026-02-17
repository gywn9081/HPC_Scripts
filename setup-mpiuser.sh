#!/usr/bin/env bash

# configs ------------------------------
USERNAME="mpiuser"
EXPECTED_UID="2642"

# Check if UID is already taken by another user
EXISTING_USER_WITH_UID=$(getent passwd "$EXPECTED_UID" | cut -d: -f1)

if [ -n "$EXISTING_USER_WITH_UID" ] && [ "$EXISTING_USER_WITH_UID" != "$USERNAME" ]; then
    echo "UID $EXPECTED_UID is already in use by user: $EXISTING_USER_WITH_UID"
    echo "Please choose a different UID or change the existing username"
    exit 1
fi

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./setup-static-network-slurm.sh"
  exit 1
fi

# Check if user exists
if id "$USERNAME" &>/dev/null; then

    CURRENT_UID=$(id -u "$USERNAME")

    if [ "$CURRENT_UID" -eq "$EXPECTED_UID" ]; then
        echo "User $USERNAME already exists with this UID $EXPECTED_UID."
    else
        echo "User $USERNAME exists but has UID $CURRENT_UID."
        echo "Changing UID to $EXPECTED_UID..."

        usermod -u "$EXPECTED_UID" "$USERNAME"

        echo "Updating file ownership to match new UID..."

        find / -user "$CURRENT_UID" -exec chown -h "$USERNAME" {} \; 2>/dev/null

        echo "UID successfully updated."
    fi

else
    echo "User $USERNAME does not exist. Creating with UID $EXPECTED_UID..."
    # Could switch this to useradd
    adduser --gecos "" --uid "$EXPECTED_UID" "$USERNAME"
fi
