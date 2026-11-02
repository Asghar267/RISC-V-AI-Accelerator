`timescale 1ns/1ps
`default_nettype none

// Dual-Mode (INT8 / INT16) Pipelined Vector Dot-Product Datapath
// Stage 1: Parallel Signed Multiplications (Multiplier stage with 2-cycle MCP)
// Stage 2: Adder Tree & Mode Selection (Combinational output to result_out)
module dot4_datapath_pipelined (
    input  wire        clk,
    input  wire        rst,
    input  wire        mode_in,
    input  wire [31:0] opa_in,
    input  wire [31:0] opb_in,
    input  wire        valid_in,
    output wire signed [31:0] result_out
);

    // ----------------------------------------------------
    // STAGE 1: Unpack and Multiply
    // ----------------------------------------------------
    wire signed [7:0] a0 = opa_in[7:0];
    wire signed [7:0] a1 = opa_in[15:8];
    wire signed [7:0] a2 = opa_in[23:16];
    wire signed [7:0] a3 = opa_in[31:24];

    wire signed [7:0] b0 = opb_in[7:0];
    wire signed [7:0] b1 = opb_in[15:8];
    wire signed [7:0] b2 = opb_in[23:16];
    wire signed [7:0] b3 = opb_in[31:24];

    wire signed [15:0] a16_0 = opa_in[15:0];
    wire signed [15:0] a16_1 = opa_in[31:16];
    wire signed [15:0] b16_0 = opb_in[15:0];
    wire signed [15:0] b16_1 = opb_in[31:16];

    // Pipeline Registers between Mult and Add
    reg        mode_pipe;
    reg signed [15:0] p0_reg, p1_reg, p2_reg, p3_reg;
    reg signed [31:0] p16_0_reg, p16_1_reg;

    always @(posedge clk) begin
        if (rst) begin
            mode_pipe  <= 1'b0;
            p0_reg     <= 16'sd0;
            p1_reg     <= 16'sd0;
            p2_reg     <= 16'sd0;
            p3_reg     <= 16'sd0;
            p16_0_reg  <= 32'sd0;
            p16_1_reg  <= 32'sd0;
        end else if (valid_in) begin
            mode_pipe  <= mode_in;
            // INT8 products
            p0_reg     <= a0 * b0;
            p1_reg     <= a1 * b1;
            p2_reg     <= a2 * b2;
            p3_reg     <= a3 * b3;
            // INT16 products
            p16_0_reg  <= a16_0 * b16_0;
            p16_1_reg  <= a16_1 * b16_1;
        end
    end

    // ----------------------------------------------------
    // STAGE 2: Adder Tree & Output (Combinational)
    // Delay: ~1.1 ns (Registered cleanly by top-level result_reg)
    // ----------------------------------------------------
    wire signed [16:0] sum01 = p0_reg + p1_reg;
    wire signed [16:0] sum23 = p2_reg + p3_reg;
    wire signed [17:0] final_sum8 = sum01 + sum23;
    wire signed [31:0] result8 = {{14{final_sum8[17]}}, final_sum8};

    wire signed [31:0] result16 = p16_0_reg + p16_1_reg;

    assign result_out = mode_pipe ? result16 : result8;

endmodule
`default_nettype wire
