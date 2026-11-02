#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Ensure program.hex is present in simulation directory
if [ ! -f "program.hex" ]; then
    cp ../program.hex .
fi

echo "================================================================================"
echo "📐 Launching Cadence Xcelium SimVision with Schematic Tracer Window..."
echo "================================================================================"

xrun -64bit \
     -gui \
     -simvisargs "-schematic" \
     -access +rwc \
     -timescale 1ns/1ps \
     -top tb_riscv_soc_top \
     ../rtl/baseline/dot4_datapath.v \
     ../rtl/baseline/dot4_accel_top.v \
     ../rtl/baseline/rv32i_core.v \
     ../rtl/baseline/uart_tx.v \
     ../rtl/baseline/ram.v \
     ../rtl/baseline/riscv_soc_top.v \
     ../tb/tb_riscv_soc_top.v \
     "$@"

