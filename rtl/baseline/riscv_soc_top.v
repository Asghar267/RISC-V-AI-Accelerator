`timescale 1ns/1ps
`default_nettype none

// RISC-V System-on-Chip (SoC) Top Module
// Integrates RV32I Core + RAM + DOT4 Accelerator Peripheral + UART Serial + ILA Mark Debug
module riscv_soc_top (
    input  wire        clk,
    input  wire        rst,
    output reg  [31:0] host_out,
    output reg         host_valid,
    output wire        uart_tx_out
);

    // CPU Interconnect Wires
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_mem_wdata;
    wire [31:0] cpu_mem_rdata;
    wire        cpu_mem_valid;
    wire        cpu_mem_write;
    wire [3:0]  cpu_mem_wstrb;
    wire        cpu_mem_ready;

    // Hardware Interrupt Signal between Accelerator and CPU
    wire        accel_irq;

    // Peripheral Selection Decodes
    wire ram_sel   = cpu_mem_valid && (cpu_mem_addr[31:16] == 16'h0000);
    wire dot4_sel  = cpu_mem_valid && (cpu_mem_addr[31:16] == 16'h8000);
    wire host_sel  = cpu_mem_valid && (cpu_mem_addr[31:16] == 16'h9000) && cpu_mem_write;

    // Individual Read Data & Ready
    wire [31:0] ram_rdata;
    wire        ram_ready;
    wire [31:0] dot4_rdata;
    wire        dot4_ready;

    // UART Wires
    wire       uart_ready;

    // Multiplex CPU Read Data & Ready Signals
    assign cpu_mem_rdata = dot4_sel ? dot4_rdata : ram_rdata;
    assign cpu_mem_ready = dot4_sel ? dot4_ready : (ram_sel ? ram_ready : 1'b1);

    // Instantiate RV32I Processor Core
    rv32i_core cpu (
        .clk(clk),
        .rst(rst),
        .irq_in(accel_irq),
        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_rdata(cpu_mem_rdata),
        .mem_valid(cpu_mem_valid),
        .mem_write(cpu_mem_write),
        .mem_wstrb(cpu_mem_wstrb),
        .mem_ready(cpu_mem_ready)
    );

    // Instantiate RAM Memory (0x0000_0000 - 0x0000_1FFF)
    ram #(.MEM_SIZE(8192)) main_memory (
        .clk(clk),
        .mem_valid(ram_sel),
        .mem_write(cpu_mem_write),
        .mem_wstrb(cpu_mem_wstrb),
        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_rdata(ram_rdata),
        .mem_ready(ram_ready)
    );

    // Instantiate DOT4 Accelerator Peripheral (0x8000_0000 - 0x8000_0010)
    dot4_accel_top dot4_accelerator (
        .clk(clk),
        .rst(rst),
        .bus_valid(dot4_sel),
        .bus_write(cpu_mem_write),
        .bus_addr(cpu_mem_addr),
        .bus_wdata(cpu_mem_wdata),
        .bus_rdata(dot4_rdata),
        .bus_ready(dot4_ready),
        .accel_done_irq(accel_irq)
    );

    // Instantiate UART Transmitter (115200 Baud)
    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) u_uart (
        .clk(clk),
        .rst(rst),
        .tx_data(cpu_mem_wdata[7:0]),
        .tx_valid(host_sel),
        .tx_ready(uart_ready),
        .tx_out(uart_tx_out)
    );

    // Host Pass/Fail Output Register (0x9000_0000)
    always @(posedge clk) begin
        if (rst) begin
            host_out   <= 32'd0;
            host_valid <= 1'b0;
        end else begin
            if (host_sel) begin
                host_out   <= cpu_mem_wdata;
                host_valid <= 1'b1;
            end
        end
    end

endmodule
`default_nettype wire