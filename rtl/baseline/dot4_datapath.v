    `timescale 1ns/1ps
    `default_nettype none
    
    // Dual-Mode (INT8 / INT16) Parallel Vector Dot-Product Datapath
    // Mode 0 (INT8):  OPA = {a3, a2, a1, a0}, OPB = {b3, b2, b1, b0} -> a0*b0 + a1*b1 + a2*b2 + a3*b3
    // Mode 1 (INT16): OPA = {a16_1, a16_0},  OPB = {b16_1, b16_0}  -> a16_0*b16_0 + a16_1*b16_1
    module dot4_datapath (
        input  wire        mode, // 0 = INT8 mode, 1 = INT16 mode
        input  wire [31:0] opa,
        input  wire [31:0] opb,
        output wire signed [31:0] result
    );
        // ----------------------------------------------------
        // Mode 0: INT8 Unpacking & Arithmetic
        // ----------------------------------------------------
        wire signed [7:0] a0 = opa[7:0];
        wire signed [7:0] a1 = opa[15:8];
        wire signed [7:0] a2 = opa[23:16];
        wire signed [7:0] a3 = opa[31:24];
    
        wire signed [7:0] b0 = opb[7:0];
        wire signed [7:0] b1 = opb[15:8];
        wire signed [7:0] b2 = opb[23:16];
        wire signed [7:0] b3 = opb[31:24];
    
        wire signed [15:0] p0 = a0 * b0;
        wire signed [15:0] p1 = a1 * b1;
        wire signed [15:0] p2 = a2 * b2;
        wire signed [15:0] p3 = a3 * b3;
    
        wire signed [16:0] sum01 = p0 + p1;
        wire signed [16:0] sum23 = p2 + p3;
        wire signed [17:0] final_sum8 = sum01 + sum23;
        wire signed [31:0] result8 = {{14{final_sum8[17]}}, final_sum8};
    
        // ----------------------------------------------------
        // Mode 1: INT16 Unpacking & Arithmetic
        // ----------------------------------------------------
        wire signed [15:0] a16_0 = opa[15:0];
        wire signed [15:0] a16_1 = opa[31:16];
    
        wire signed [15:0] b16_0 = opb[15:0];
        wire signed [15:0] b16_1 = opb[31:16];
    
        wire signed [31:0] p16_0 = a16_0 * b16_0;
        wire signed [31:0] p16_1 = a16_1 * b16_1;
    
        wire signed [31:0] result16 = p16_0 + p16_1;
    
        // Output Mode Multiplexer
        assign result = mode ? result16 : result8;
    
    endmodule
    `default_nettype wire
