# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./setup-static-network-slurm.sh"
  exit 1
fi


# These are the dependencies needed by linpack
apt update && sudo apt upgrade -y
apt install -y build-essential gfortran \
                    hwloc numactl \
                    net-tools
