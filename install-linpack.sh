#!/bin/bash
# =============================================================================
# HPL (Linpack) Setup Script for Cluster Nodes
# Run this as a sudo-capable user (NOT mpiuser).
# HPL will be built and installed into mpiuser's home directory.
# Usage: bash setup_linpack.sh [headnode|compute]
# =============================================================================

set -e  # Exit on error

ROLE=${1:-"compute"}   # Default to compute if no argument given
MPI_USER="mpiuser"
HPL_VERSION="2.3"
HPL_DIR="/home/${MPI_USER}/hpl-${HPL_VERSION}"
HPL_ARCHIVE="hpl-${HPL_VERSION}.tar.gz"
HPL_URL="https://www.netlib.org/benchmark/hpl/${HPL_ARCHIVE}"

# Must be run as root
if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo ./setup_linpack.sh [headnode|compute]"
    exit 1
fi

# Verify mpiuser exists
if ! id "$MPI_USER" &>/dev/null; then
    echo "ERROR: User '$MPI_USER' does not exist on this machine."
    exit 1
fi

echo "=============================================="
echo " HPL Linpack Setup"
echo " Role: $ROLE"
echo " Date: $(date)"
echo "=============================================="

# ------------------------------------------------------------------------------
# Step 1: Install dependencies (all nodes)
# ------------------------------------------------------------------------------
echo ""
echo "[1/4] Installing dependencies..."

if command -v apt-get &>/dev/null; then
    apt-get update -q
    apt-get install -y libopenblas-dev build-essential wget gfortran
elif command -v yum &>/dev/null; then
    yum install -y openblas-devel gcc gcc-gfortran make wget
else
    echo "ERROR: Unsupported package manager. Install libopenblas-dev and build tools manually."
    exit 1
fi

echo "  Dependencies installed."

# ------------------------------------------------------------------------------
# Step 2: Download and build HPL (headnode only - NFS shares to compute nodes)
# ------------------------------------------------------------------------------
if [ "$ROLE" == "headnode" ]; then
    echo ""
    echo "[2/4] Downloading HPL ${HPL_VERSION} as ${MPI_USER}..."

    # Download into mpiuser's home
    sudo -u "$MPI_USER" bash -c "
        cd /home/${MPI_USER}
        if [ ! -f '${HPL_ARCHIVE}' ]; then
            wget -q '${HPL_URL}' -O '${HPL_ARCHIVE}'
            echo '  Downloaded ${HPL_ARCHIVE}'
        else
            echo '  Archive already exists, skipping download.'
        fi

        if [ ! -d '${HPL_DIR}' ]; then
            tar -xzf '${HPL_ARCHIVE}'
            echo '  Extracted to ${HPL_DIR}'
        else
            echo '  HPL directory already exists, skipping extraction.'
        fi
    "

    # --------------------------------------------------------------------------
    # Step 3: Configure and build HPL
    # --------------------------------------------------------------------------
    echo ""
    echo "[3/4] Configuring and building HPL as ${MPI_USER}..."

    # Detect paths as current user (mpirun/openblas should be system-wide)
    MPI_DIR=$(dirname $(dirname $(which mpirun 2>/dev/null || echo "/usr/bin/mpirun")))
    OPENBLAS_LIB=$(find /usr -name "libopenblas*" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || echo "/usr/lib/x86_64-linux-gnu")
    ARCH="linux_openblas"
    CORES=$(nproc)

    echo "  MPI dir:      $MPI_DIR"
    echo "  OpenBLAS lib: $OPENBLAS_LIB"

    # Write Make config and build as mpiuser
    sudo -u "$MPI_USER" bash -c "
        cd ${HPL_DIR}

        cat > Make.${ARCH} << 'MAKEFILE'
SHELL        = /bin/sh
CD           = cd
CP           = cp
LN_S         = ln -fs
MKDIR        = mkdir -p
RM           = /bin/rm -f
TOUCH        = touch

ARCH         = ${ARCH}
TOPdir       = ${HPL_DIR}
INCdir       = \$(TOPdir)/include
BINdir       = \$(TOPdir)/bin/\$(ARCH)
LIBdir       = \$(TOPdir)/lib/\$(ARCH)
HPLlib       = \$(LIBdir)/libhpl.a

MPdir        = ${MPI_DIR}
MPinc        = -I\$(MPdir)/include
MPlib        = -L\$(MPdir)/lib -lmpi

LAdir        = ${OPENBLAS_LIB}
LAinc        =
LAlib        = -L\$(LAdir) -lopenblas

F2CDEFS      = -DAdd__ -DF77_INTEGER=int -DStringSunStyle

HPL_INCLUDES = -I\$(INCdir) -I\$(INCdir)/\$(ARCH) \$(LAinc) \$(MPinc)
HPL_LIBS     = \$(HPLlib) \$(LAlib) \$(MPlib) -lm

HPL_OPTS     = -DHPL_PROGRESS_INTERVAL=60

HPL_DEFS     = \$(F2CDEFS) \$(HPL_OPTS) \$(HPL_INCLUDES)

CC           = mpicc
CCNOOPT      = \$(HPL_DEFS)
CCFLAGS      = \$(HPL_DEFS) -O3 -march=native -funroll-loops

LINKER       = mpicc
LINKFLAGS    = \$(CCFLAGS)

ARCHIVER     = ar
ARFLAGS      = r
RANLIB       = echo
MAKEFILE

        make arch=${ARCH} -j${CORES} 2>&1 | tail -5
    "

    if sudo -u "$MPI_USER" test -f "${HPL_DIR}/bin/${ARCH}/xhpl"; then
        echo "  Build successful: ${HPL_DIR}/bin/${ARCH}/xhpl"
    else
        echo "ERROR: Build failed. Check output above."
        exit 1
    fi

    # --------------------------------------------------------------------------
    # Step 4: Generate HPL.dat config file
    # --------------------------------------------------------------------------
    echo ""
    echo "[4/4] Generating HPL.dat as ${MPI_USER}..."

    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_BYTES=$((TOTAL_MEM_KB * 1024))
    USABLE_MEM=$(echo "$TOTAL_MEM_BYTES * 0.80" | bc | cut -d. -f1)
    N=$(echo "scale=0; sqrt($USABLE_MEM / 8)" | bc)
    N=$(( (N / 1000) * 1000 ))

    echo "  Detected ${CORES} cores and ~$((TOTAL_MEM_KB / 1024 / 1024)) GB RAM on this node"
    echo "  Suggested N=$N (tune this based on total cluster RAM)"

    sudo -u "$MPI_USER" bash -c "cat > ${HPL_DIR}/bin/${ARCH}/HPL.dat << 'EOF'
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out      output file name (if any)
6            device out (6=stdout,7=stderr,file)
1            # of problems sizes (N)
${N}         Ns
1            # of NBs
256          NBs
0            PMAP process mapping (0=Row-,1=Column-major)
1            # of process grids (P x Q)
2            Ps
2            Qs
16.0         threshold
1            # of panel fact
2            PFACTs (0=left, 1=Crout, 2=Right)
1            # of recursive stopping criterium
4            NBMINs (>= 1)
1            # of panels in recursion
2            NDIVs
1            # of recursive panel fact.
1            RFACTs (0=left, 1=Crout, 2=Right)
1            # of broadcast
1            BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
1            # of lookahead depth
1            DEPTHs (>=0)
2            SWAP (0=bin-exch,1=long,2=mix)
64           swapping threshold
0            L1 in (0=transposed,1=no-transposed) form
0            U  in (0=transposed,1=no-transposed) form
1            Equilibration (0=no,1=yes)
8            memory alignment in double (> 0)
EOF"

    echo "  HPL.dat written to ${HPL_DIR}/bin/${ARCH}/HPL.dat"
    echo ""
    echo "=============================================="
    echo " Headnode setup complete!"
    echo ""
    echo " IMPORTANT: Edit HPL.dat before running:"
    echo "   - Set P x Q so that P*Q = total MPI processes"
    echo "   - Increase N to use more of your cluster RAM"
    echo "     (current N=$N is based on this node only)"
    echo ""
    echo " To run (as mpiuser, from ${HPL_DIR}/bin/${ARCH}/):"
    echo "   sudo -u ${MPI_USER} bash"
    echo "   mpirun -np <P*Q> --hostfile ~/hostfile ./xhpl"
    echo "=============================================="

else
    # Compute nodes: only need dependencies, HPL binary comes via NFS
    echo ""
    echo "[2/4] Skipping HPL build (NFS shared home handles this)."
    echo "[3/4] Skipping HPL.dat generation (handled by headnode)."
    echo "[4/4] Verifying MPI is available..."

    if command -v mpirun &>/dev/null; then
        echo "  mpirun found at: $(which mpirun)"
    else
        echo "  WARNING: mpirun not found! Make sure OpenMPI is installed and in PATH."
    fi

    echo ""
    echo "=============================================="
    echo " Compute node setup complete!"
    echo " Dependencies installed. HPL binary is"
    echo " accessible via NFS shared home directory."
    echo "=============================================="
fi
