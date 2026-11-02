`timescale 1ns/1ps
`default_nettype none

// ==============================================================================
// USTP Capstone Project: RV32 RISC-V SoC with Custom DOT4 Accelerator
// Top-Level Synthesizable ASIC System Module (Strictly 3 Principal Blocks)
// Block 1: RV32I Processor Core (rv32i_core_fast.v)
// Block 2: Memory-Mapped Bus Interconnect (bus_interconnect.v)
// Block 3: Dual-Mode Vector Hardware Accelerator (dot4_accel_top.v)
// ==============================================================================
module rv32_dot4_system (
    input  wire        clk,
    input  wire        rst,

    // External Memory Bus Interface (Option 1: Memory outside chip boundary)
    output wire [31:0] ext_mem_addr,
    output wire [31:0] ext_mem_wdata,
    input  wire [31:0] ext_mem_rdata,
    output wire        ext_mem_valid,
    output wire        ext_mem_write,
    output wire [3:0]  ext_mem_wstrb,
    input  wire        ext_mem_ready,

    // Host Status Output (For testbench validation & external observation)
    output wire [31:0] host_out,
    output wire        host_valid,
    output wire        accel_irq
);

    // Internal CPU <-> Interconnect Bus Signals
    wire [31:0] cpu_addr;
    wire [31:0] cpu_wdata;
    wire [31:0] cpu_rdata;
    wire        cpu_valid;
    wire        cpu_write;
    wire [3:0]  cpu_wstrb;
    wire        cpu_ready;

    // Internal Interconnect <-> Accelerator MMIO Signals
    wire [31:0] dot4_bus_addr;
    wire [31:0] dot4_bus_wdata;
    wire [31:0] dot4_bus_rdata;
    wire        dot4_bus_valid;
    wire        dot4_bus_write;
    wire        dot4_bus_ready;

    // Hardware Interrupt wire
    wire        accel_done_irq_wire;
    assign accel_irq = accel_done_irq_wire;

    // -------------------------------------------------------------------------
    // BLOCK 1: RV32I Processor Core (High-Frequency Decoupled Core)
    // -------------------------------------------------------------------------
    rv32i_core u_core (
        .clk(clk),
        .rst(rst),
        .irq_in(accel_done_irq_wire),
        .mem_addr(cpu_addr),
        .mem_wdata(cpu_wdata),
        .mem_rdata(cpu_rdata),
        .mem_valid(cpu_valid),
        .mem_write(cpu_write),
        .mem_wstrb(cpu_wstrb),
        .mem_ready(cpu_ready)
    );

    // -------------------------------------------------------------------------
    // BLOCK 2: Memory-Mapped Bus Interconnect & Address Decoder
    // -------------------------------------------------------------------------
    bus_interconnect u_interconnect (
        .clk(clk),
        .rst(rst),
        // Upstream CPU Interface
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata),
        .cpu_valid(cpu_valid),
        .cpu_write(cpu_write),
        .cpu_wstrb(cpu_wstrb),
        .cpu_ready(cpu_ready),
        // Downstream Port 0: External Memory Bus
        .ext_mem_addr(ext_mem_addr),
        .ext_mem_wdata(ext_mem_wdata),
        .ext_mem_rdata(ext_mem_rdata),
        .ext_mem_valid(ext_mem_valid),
        .ext_mem_write(ext_mem_write),
        .ext_mem_wstrb(ext_mem_wstrb),
        .ext_mem_ready(ext_mem_ready),
        // Downstream Port 1: DOT4 Accelerator MMIO (0x8000_0000 - 0x8000_0014)
        .dot4_addr(dot4_bus_addr),
        .dot4_wdata(dot4_bus_wdata),
        .dot4_rdata(dot4_bus_rdata),
        .dot4_valid(dot4_bus_valid),
        .dot4_write(dot4_bus_write),
        .dot4_ready(dot4_bus_ready),
        // Downstream Port 2: Host Pass/Fail Output
        .host_out(host_out),
        .host_valid(host_valid)
    );

    // -------------------------------------------------------------------------
    // BLOCK 3: Custom DOT4 Vector Hardware Accelerator
    // -------------------------------------------------------------------------
    dot4_accel_top #(
        .BASE_ADDR(32'h8000_0000)
    ) u_accelerator (
        .clk(clk),
        .rst(rst),
        .bus_valid(dot4_bus_valid),
        .bus_write(dot4_bus_write),
        .bus_addr(dot4_bus_addr),
        .bus_wdata(dot4_bus_wdata),
        .bus_rdata(dot4_bus_rdata),
        .bus_ready(dot4_bus_ready),
        .accel_done_irq(accel_done_irq_wire)
    );

endmodule
`default_nettype wire

