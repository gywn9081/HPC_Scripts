#!/usr/bin/env bash

# --- Configs ---------------------------------------
USERNAME="mpiuser"

# Cluster host list (Format: IP hostname)
# We will extract the hostnames from this list for the Hydra 'hosts' file
CLUSTER_HOSTS="
10.42.0.111    headnode     // ip address for head node is supposed to be set to the first ip address in the subnet, but its set up to this now so we deal with it
10.42.0.101    compute01
10.42.0.102    compute02
10.42.0.103    compute03
"

# 1. Install MPICH (Hydra is included)
echo "Installing MPICH and Hydra Process Manager..."
sudo apt-get update && sudo apt-get install -y mpich

# 2. Check if running as the correct user for configuration
if [ "$USER" != "$USERNAME" ]; then
    echo "Switching to $USERNAME to configure Hydra hosts file..."
    exec sudo -u "$USERNAME" "$0" "$@"
    exit
fi

# 3. Navigate to mpiuser home directory
cd ~ || exit

# 4. Create the Hydra 'hosts' file
echo "Creating Hydra 'hosts' file in ~..."

# This logic extracts the second column (hostnames) from your CLUSTER_HOSTS variable
# and writes them line-by-line into the file.
echo "$CLUSTER_HOSTS" | awk '{print $2}' | sed '/^$/d' > hosts

# 5. Set correct permissions
chmod 644 ~/hosts

echo "----------------------------------------------------"
echo "Hydra Setup Complete!"
echo "Your 'hosts' file contains:"
cat ~/hosts
echo "----------------------------------------------------"
echo "To test your MPI cluster, try running:"
echo "mpirun -f ~/hosts -n 4 hostname"