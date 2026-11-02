# Cadence Xcelium Simulation Makefile for RISC-V DOT4 Accelerator SoC

XRUN = env -u LD_PRELOAD xrun
XRUN_FLAGS = -64bit -access +rwc -timescale 1ns/1ps

RTL_DIR = ../rtl
TB_DIR  = ../tb

BASE_RTL  = $(RTL_DIR)/baseline
OPT_RTL   = $(RTL_DIR)/optimized

ACCEL_RTL = $(BASE_RTL)/dot4_datapath.v $(BASE_RTL)/dot4_accel_top.v
ACCEL_TB  = $(TB_DIR)/tb_dot4_accel_top.v

SOC_RTL   = $(BASE_RTL)/dot4_datapath.v \
            $(BASE_RTL)/dot4_accel_top.v \
            $(BASE_RTL)/rv32i_core.v \
            $(BASE_RTL)/uart_tx.v \
            $(BASE_RTL)/ram.v \
            $(BASE_RTL)/riscv_soc_top.v
SOC_TB    = $(TB_DIR)/tb_riscv_soc_top.v

SYS_RTL   = $(OPT_RTL)/dot4_datapath_pipelined.v \
            $(OPT_RTL)/dot4_accel_top_fast.v \
            $(OPT_RTL)/rv32i_core_fast.v \
            $(OPT_RTL)/bus_interconnect.v \
            $(OPT_RTL)/rv32_dot4_system.v \
            $(OPT_RTL)/ram.v
SYS_TB    = $(TB_DIR)/tb_rv32_dot4_system.v

# Gate-Level Simulation (GLS) Files
PDK_VERILOG = ../pdk/verilog/tsmc18.v
GLS_NETLIST = ../asic/synth/outputs/350mhz/rv32_dot4_system_syn.v
GLS_RAM     = $(OPT_RTL)/ram.v
GLS_TB      = $(TB_DIR)/tb_rv32_dot4_system_gls.v

.PHONY: all accel accel_fast soc system gls gls_sdf gls_gui schematic gui clean help

help:
	@echo "Available targets:"
	@echo "  make gls        : Run Phase 4 Gate-Level Simulation (GLS) in Cadence Xcelium (350 MHz)"
	@echo "  make gls_sdf    : Run Phase 4 GLS with SDF delay back-annotation in Cadence Xcelium"
	@echo "  make gls_gui    : Launch SimVision GUI for Gate-Level Simulation debugging"
	@echo "  make system     : Run Synthesizable 3-Block ASIC System (Option 1) in Cadence Xcelium"
	@echo "  make accel_fast : Run Pipelined MCP DOT4 Accelerator verification in Cadence Xcelium"
	@echo "  make accel      : Run Baseline DOT4 Accelerator verification in Cadence Xcelium"
	@echo "  make soc        : Run Full RISC-V SoC 4x4 Matrix Multiplication in Cadence Xcelium"
	@echo "  make all        : Run both testbenches sequentially"
	@echo "  make schematic  : Launch SimVision GUI with Schematic Tracer window"
	@echo "  make gui        : Launch SimVision GUI for interactive debugging & waveform viewing"
	@echo "  make clean      : Clean simulation work libraries and logs"

all: accel system gls

accel_fast:
	$(XRUN) $(XRUN_FLAGS) -top tb_dot4_accel_top $(OPT_RTL)/dot4_datapath_pipelined.v $(OPT_RTL)/dot4_accel_top_fast.v $(ACCEL_TB)

schematic:
	@if [ ! -f program.hex ]; then cp ../program.hex . ; fi
	$(XRUN) $(XRUN_FLAGS) -gui -simvisargs "-schematic" -top tb_riscv_soc_top $(SOC_RTL) $(SOC_TB)

gui:
	@if [ ! -f program.hex ]; then cp ../program.hex . ; fi
	$(XRUN) $(XRUN_FLAGS) -gui -top tb_riscv_soc_top $(SOC_RTL) $(SOC_TB)

accel:
	@echo "================================================================================"
	@echo " Running Standalone DOT4 Accelerator Testbench..."
	@echo "================================================================================"
	$(XRUN) $(XRUN_FLAGS) -top tb_dot4_accel_top $(ACCEL_RTL) $(ACCEL_TB)

system:
	@echo "================================================================================"
	@echo " Running Synthesizable 3-Block ASIC System Testbench (Option 1)..."
	@echo "================================================================================"
	@if [ ! -f program.hex ]; then cp ../program.hex . ; fi
	$(XRUN) $(XRUN_FLAGS) -top tb_rv32_dot4_system $(SYS_RTL) $(SYS_TB)

soc:
	@echo "================================================================================"
	@echo " Running Full RISC-V SoC Testbench..."
	@echo "================================================================================"
	@if [ ! -f program.hex ]; then cp ../program.hex . ; fi
	$(XRUN) $(XRUN_FLAGS) -top tb_riscv_soc_top $(SOC_RTL) $(SOC_TB)

gls:
	@echo "================================================================================"
	@echo " Running Phase 4: Gate-Level Simulation (GLS) in Cadence Xcelium (350 MHz)..."
	@echo "================================================================================"
	@if [ ! -f program.hex ]; then cp ../program.hex . ; fi
	$(XRUN) $(XRUN_FLAGS) -nospecify -top tb_rv32_dot4_system_gls $(PDK_VERILOG) $(GLS_NETLIST) $(GLS_RAM) $(GLS_TB)

gls_sdf:
	@echo "================================================================================"
	@echo " Running Phase 4: Gate-Level Simulation (GLS) with SDF Timing Back-Annotation..."
	@echo "================================================================================"
	@if [ ! -f program.hex ]; then cp ../program.hex . ; fi
	$(XRUN) $(XRUN_FLAGS) -xminitialize 0 +define+SDF_ANNOTATE -top tb_rv32_dot4_system_gls $(PDK_VERILOG) $(GLS_NETLIST) $(GLS_RAM) $(GLS_TB)

gls_gui:
	@if [ ! -f program.hex ]; then cp ../program.hex . ; fi
	$(XRUN) $(XRUN_FLAGS) -gui -top tb_rv32_dot4_system_gls $(PDK_VERILOG) $(GLS_NETLIST) $(GLS_RAM) $(GLS_TB)

clean:
	rm -rf xcelium.d xrun.log xrun.history xrun.key .simvision waves.shm *.err .bpad

