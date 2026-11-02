#!/bin/bash
set -e

# ==============================================================================
# USTP Capstone: Phase 4 Gate-Level Simulation (GLS) with SDF Timing Back-Annotation
# Simulator: Cadence Xcelium 20.03
# Netlist: asic/synth/outputs/350mhz/rv32_dot4_system_syn.v (TSMC 180nm Mapped Netlist)
# SDF: asic/synth/outputs/350mhz/rv32_dot4_system_gls.sdf
# PDK Models: pdk/verilog/tsmc18.v
# Clock: 350.00 MHz (2.86 ns period)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Source Cadence EDA environment if not already loaded
if ! command -v xrun &> /dev/null; then
    source ../setup_env.sh
fi

# Ensure fresh program.hex is copied to simulation directory
cp -f ../sw/program.hex .

echo "================================================================================"
echo "🚀 Running Phase 4 Gate-Level Simulation (GLS) with Full SDF Timing in Xcelium..."
echo "   Clock Target   : 350.00 MHz (Period = 2.86 ns)"
echo "   Netlist        : asic/synth/outputs/350mhz/rv32_dot4_system_syn.v (12,667 cells)"
echo "   SDF Delays     : asic/synth/outputs/350mhz/rv32_dot4_system_gls.sdf"
echo "   Initialization : -xminitialize 0 (Silicon realistic power-up)"
echo "================================================================================"

env -u LD_PRELOAD xrun -64bit \
     -clean \
     -access +rwc \
     -timescale 1ns/1ps \
     -xminitialize 0 \
     +define+SDF_ANNOTATE \
     -top tb_rv32_dot4_system_gls \
     ../pdk/verilog/tsmc18.v \
     ../asic/synth/outputs/350mhz/rv32_dot4_system_syn.v \
     ../rtl/optimized/ram.v \
     ../tb/tb_rv32_dot4_system_gls.v \
     "$@"

