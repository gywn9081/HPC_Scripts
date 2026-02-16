#!/usr/bin/env bash
set -e

echo "=== Installing OpenMP and MPI (SLURM Nodes) ==="

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./install-openmp-mpi.sh"
  exit 1
fi

echo "Updating package index"
apt update

echo "Installing build tools"
apt install -y build-essential

echo "Installing OpenMP support"
apt install -y gcc g++ libomp-dev

echo "Installing OpenMPI"
apt install -y openmpi-bin libopenmpi-dev

echo
echo "=== Verification ==="

echo "GCC version:"
gcc --version | head -n 1

echo
echo "OpenMP test (compiler flag check):"
echo 'int main(){return 0;}' | gcc -fopenmp -x c - && echo "OpenMP OK"

echo
echo "MPI version:"
mpirun --version || mpiexec --version

echo
echo "MPI compiler wrappers:"
which mpicc
which mpicxx

echo
echo "=== Installation Complete ==="
echo "Node is ready for OpenMP and MPI workloads."
