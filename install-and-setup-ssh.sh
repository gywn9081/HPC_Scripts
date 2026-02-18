#!/usr/bin/env bash

# --- Configs ---------------------------------------
USERNAME="mpiuser"

# Cluster host list (Format: IP hostname)
# ip address for head node is supposed to be set to the first ip address in the subnet, but its set up to this now so we deal with it

CLUSTER_HOSTS="
10.42.0.111    headnode 
10.42.0.101    compute01
10.42.0.102    compute02
10.42.0.103    compute03
"

# 1. Install SSH
echo "Installing SSH..."
sudo apt-get update && sudo apt-get install -y ssh

# 2. Check if running as the correct user
if [ "$USER" != "$USERNAME" ]; then
    echo "Current user is $USER. Switching to $USERNAME..."
    # Using 'sudo' to switch to ensure it has permission to run the script
    exec sudo -u "$USERNAME" "$0" "$@"
    exit
fi

# 3. Generate SSH Keys (if they don't exist)
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generating SSH keys for $USERNAME..."
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
else
    echo "SSH keys already exist. Skipping generation."
fi

# 4. Handle Shared Home Directory Logic
echo "Updating authorized_keys..."
# We use grep to check if the key is already there to avoid duplicates
if ! grep -qf ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys 2>/dev/null; then
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi

# 5. Process CLUSTER_HOSTS for known_hosts
echo "Adding nodes to known_hosts to prevent manual prompts..."

# Extract every individual word (IPs and hostnames) from the config variable
# adding 'localhost' for good measure.
targets=$(echo "$CLUSTER_HOSTS localhost" | tr -s ' ' '\n' | sort -u)

for target in $targets; do
    if [ -n "$target" ]; then
        echo "Scanning $target..."
        # Remove old entry if it exists to prevent 'Host key verification failed' if IPs change
        ssh-keygen -R "$target" &>/dev/null
        # Scan and append to known_hosts
        ssh-keyscan -H "$target" >> ~/.ssh/known_hosts 2>/dev/null
    fi
done

echo "----------------------------------------------------"
echo "Setup complete!"
echo "Try testing with: ssh $(echo $CLUSTER_HOSTS | awk '{print $2}')"