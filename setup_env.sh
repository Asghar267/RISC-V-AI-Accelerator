#!/bin/bash
# ==============================================================================
# USTP Capstone: Cadence EDA & TSMC 180nm PDK Environment Setup Script
# Usage: source setup_env.sh
# ==============================================================================

echo "=================================================================="
echo " Setting up Cadence EDA Tools & TSMC 180nm Environment..."
echo "=================================================================="

# 0. Clean Environment Conflicts & Set Stack Limit
unset LD_PRELOAD
ulimit -s unlimited 2>/dev/null || true

# 1. Cadence Tool Homes
export CADENCE_BASE=/opt/cadence
export GENUS_HOME=/opt/cadence/GENUS191
export INNOVUS_HOME=/opt/cadence/INNOVUS201
export XCELIUM_HOME=/opt/cadence/XCELIUM2003
export PVS_HOME=/opt/cadence/PVS191
export IC618_HOME=/opt/cadence/IC618
export CDSHOME=/opt/cadence/IC618

# 2. License Setup
export CDS_LIC_FILE=/opt/cadence/license/license.dat
export LM_LICENSE_FILE=/opt/cadence/license/license.dat

# 3. Library Paths
export LD_LIBRARY_PATH=$XCELIUM_HOME/tools/lib64:$LD_LIBRARY_PATH

# 4. Binary Paths
export PATH=$GENUS_HOME/bin:$INNOVUS_HOME/bin:$XCELIUM_HOME/tools/bin:$XCELIUM_HOME/bin:$IC618_HOME/bin:$PVS_HOME/bin:$PATH

# 5. PDK Path Shortcut (Self-contained in project)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export PDK_DIR="$SCRIPT_DIR/pdk"

echo " -> GENUS   : $(which genus 2>/dev/null || echo 'NOT FOUND')"
echo " -> INNOVUS : $(which innovus 2>/dev/null || echo 'NOT FOUND')"
echo " -> XCELIUM : $(which xrun 2>/dev/null || echo 'NOT FOUND')"
echo " -> PDK_DIR : $PDK_DIR"
echo "=================================================================="
echo " Environment setup complete! You are ready to run tools."
echo "=================================================================="

