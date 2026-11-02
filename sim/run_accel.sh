#!/bin/bash
set -e

# Directory setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "================================================================================"
echo "⚡ Running Standalone DOT4 Accelerator Simulation in Cadence Xcelium (xrun)..."
echo "================================================================================"

xrun -64bit \
     -access +rwc \
     -timescale 1ns/1ps \
     -top tb_dot4_accel_top \
     ../rtl/baseline/dot4_datapath.v \
     ../rtl/baseline/dot4_accel_top.v \
     ../tb/tb_dot4_accel_top.v \
     "$@"

