`timescale 1ns/1ps
`default_nettype none

// Memory-Mapped Bus Interconnect & Address Decoder
// Connects RV32I Processor to DOT4 Accelerator Peripheral and External Memory Bus
module bus_interconnect (
    input  wire        clk,
    input  wire        rst,

    // Upstream: CPU Master Bus Interface
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    output wire [31:0] cpu_rdata,
    input  wire        cpu_valid,
    input  wire        cpu_write,
    input  wire [3:0]  cpu_wstrb,
    output wire        cpu_ready,

    // Downstream Port 0: External Memory Bus Interface
    output wire [31:0] ext_mem_addr,
    output wire [31:0] ext_mem_wdata,
    input  wire [31:0] ext_mem_rdata,
    output wire        ext_mem_valid,
    output wire        ext_mem_write,
    output wire [3:0]  ext_mem_wstrb,
    input  wire        ext_mem_ready,

    // Downstream Port 1: DOT4 Accelerator MMIO Interface (0x8000_0000 - 0x8000_0014)
    output wire [31:0] dot4_addr,
    output wire [31:0] dot4_wdata,
    input  wire [31:0] dot4_rdata,
    output wire        dot4_valid,
    output wire        dot4_write,
    input  wire        dot4_ready,

    // Downstream Port 2: Host Output Status Register (0x9000_0000)
    output reg  [31:0] host_out,
    output reg         host_valid
);

    // Address Decoding (Based on upper 16 bits)
    wire sel_dot4 = cpu_valid && (cpu_addr[31:16] == 16'h8000);
    wire sel_host = cpu_valid && (cpu_addr[31:16] == 16'h9000) && cpu_write;
    wire sel_mem  = cpu_valid && (cpu_addr[31:16] == 16'h0000);

    // Route to External Memory
    assign ext_mem_addr  = cpu_addr;
    assign ext_mem_wdata = cpu_wdata;
    assign ext_mem_wstrb = cpu_wstrb;
    assign ext_mem_write = cpu_write;
    assign ext_mem_valid = sel_mem;

    // Route to DOT4 Accelerator
    assign dot4_addr  = cpu_addr;
    assign dot4_wdata = cpu_wdata;
    assign dot4_write = cpu_write;
    assign dot4_valid = sel_dot4;

    // Multiplex Read Data & Ready back to CPU
    assign cpu_rdata = sel_dot4 ? dot4_rdata : ext_mem_rdata;
    assign cpu_ready = sel_dot4 ? dot4_ready : (sel_mem ? ext_mem_ready : 1'b1);

    // Host Status Register (0x9000_0000)
    always @(posedge clk) begin
        if (rst) begin
            host_out   <= 32'd0;
            host_valid <= 1'b0;
        end else begin
            if (sel_host) begin
                host_out   <= cpu_wdata;
                host_valid <= 1'b1;
            end
        end
    end

endmodule
`default_nettype wire

