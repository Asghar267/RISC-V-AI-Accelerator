`timescale 1ns/1ps
`default_nettype none

// Dual-Port / Single-Bus Asynchronous Read RAM Module initialized with program.hex
module ram #(
    parameter MEM_SIZE = 8192, // 8KB RAM
    parameter HEX_FILE = "program.hex"
) (
    input  wire        clk,
    input  wire        mem_valid,
    input  wire        mem_write,
    input  wire [3:0]  mem_wstrb,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    output wire [31:0] mem_rdata,
    output wire        mem_ready
);

    localparam NUM_WORDS = 2048;
    reg [31:0] mem [0:NUM_WORDS-1];

    wire [31:0] word_addr = mem_addr[31:2];

    assign mem_ready = (mem_valid === 1'b1);
    assign mem_rdata = (mem_valid === 1'b1 && (^word_addr !== 1'bx) && (word_addr < NUM_WORDS)) ? mem[word_addr] : 32'd0;

    integer i;
    initial begin
        for (i = 0; i < NUM_WORDS; i = i + 1) begin
            mem[i] = 32'h00000000;
        end
        $readmemh("program.hex", mem);
    end

    always @(posedge clk) begin
        if (mem_valid === 1'b1 && mem_write === 1'b1) begin
            if ((^word_addr !== 1'bx) && (word_addr < NUM_WORDS)) begin
                if (mem_wstrb[0]) mem[word_addr][7:0]   <= mem_wdata[7:0];
                if (mem_wstrb[1]) mem[word_addr][15:8]  <= mem_wdata[15:8];
                if (mem_wstrb[2]) mem[word_addr][23:16] <= mem_wdata[23:16];
                if (mem_wstrb[3]) mem[word_addr][31:24] <= mem_wdata[31:24];
            end
        end
    end
endmodule
`default_nettype wire
