`timescale 1ns/1ps
`default_nettype none

// High-Performance Pipelined-Execution RV32I Processor Core
// Designed for 300 - 400 MHz ASIC Timing Closure in TSMC 180nm
module rv32i_core (
    input  wire        clk,
    input  wire        rst,
    input  wire        irq_in,

    // Memory Bus Interface
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    output reg         mem_valid,
    output reg         mem_write,
    output reg  [3:0]  mem_wstrb,
    input  wire        mem_ready
);

    // PC & Register File
    reg [31:0] pc;
    reg [31:0] regs [0:31];

    // FSM States
    localparam [2:0] FETCH     = 3'd0,
                     DECODE    = 3'd1,
                     EXECUTE   = 3'd2,
                     MEM_WAIT  = 3'd3,
                     WRITEBACK = 3'd4,
                     WAIT_IRQ  = 3'd5,
                     DECODE2   = 3'd6;

    reg [2:0] state;

    reg [31:0] instr;
    reg [31:0] pc_current;
    reg [31:0] pc_plus4_reg;
    reg [31:0] pc_branch_reg;
    reg [31:0] pc_jal_reg;
    reg [31:0] rval1_reg;
    reg [31:0] rval2_reg;
    reg [31:0] alu_result;
    reg [4:0]  rd_wb;
    reg        rf_we;

    // Fields
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    // Immediates from registered instr
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_u = {instr[31:12], 12'b0};

    // Immediates from incoming mem_rdata for decode-stage precomputation
    wire [31:0] rdata_imm_b = {{19{mem_rdata[31]}}, mem_rdata[31], mem_rdata[7], mem_rdata[30:25], mem_rdata[11:8], 1'b0};
    wire [31:0] rdata_imm_j = {{11{mem_rdata[31]}}, mem_rdata[31], mem_rdata[19:12], mem_rdata[20], mem_rdata[30:21], 1'b0};
    wire [4:0]  rdata_rs1   = mem_rdata[19:15];
    wire [4:0]  rdata_rs2   = mem_rdata[24:20];

    // Branch condition evaluated on registered operands
    reg branch_taken;
    always @(*) begin
        case (funct3)
            3'b000: branch_taken = (rval1_reg == rval2_reg);
            3'b001: branch_taken = (rval1_reg != rval2_reg);
            3'b100: branch_taken = ($signed(rval1_reg) < $signed(rval2_reg));
            3'b101: branch_taken = ($signed(rval1_reg) >= $signed(rval2_reg));
            3'b110: branch_taken = (rval1_reg < rval2_reg);
            3'b111: branch_taken = (rval1_reg >= rval2_reg);
            default: branch_taken = 1'b0;
        endcase
    end

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            pc            <= 32'h0000_0000;
            pc_current    <= 32'h0000_0000;
            instr         <= 32'h0000_0013; // NOP (addi x0, x0, 0)
            state         <= FETCH;
            mem_valid     <= 1'b0;
            mem_write     <= 1'b0;
            mem_wstrb     <= 4'b0000;
            mem_addr      <= 32'd0;
            mem_wdata     <= 32'd0;
            rf_we         <= 1'b0;
            rd_wb         <= 5'd0;
            alu_result    <= 32'd0;
            rval1_reg     <= 32'd0;
            rval2_reg     <= 32'd0;
            pc_plus4_reg  <= 32'd0;
            pc_branch_reg <= 32'd0;
            pc_jal_reg    <= 32'd0;
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'd0;
            end
        end else begin
            case (state)
                FETCH: begin
                    mem_addr   <= pc;
                    mem_valid  <= 1'b1;
                    mem_write  <= 1'b0;
                    mem_wstrb  <= 4'b0000;
                    pc_current <= pc;
                    rf_we      <= 1'b0;
                    state      <= DECODE;
                end

                DECODE: begin
                    // Cycle 1 of 2: wait for fetch data (mem_ready is level-held in
                    // this system). Keep mem_valid asserted and all decode inputs
                    // stable so the capture below can use a 2-cycle multicycle path.
                    if (mem_ready) begin
                        state <= DECODE2;
                    end
                end

                DECODE2: begin
                    // Cycle 2 of 2: capture decode-stage registers. This gives the
                    // fetch-address -> decode-mux -> regfile-read path two clock
                    // periods, matching the SDC multicycle constraints.
                    instr         <= mem_rdata;
                    mem_valid     <= 1'b0;
                    // Decouple register file read muxes into stage registers
                    rval1_reg     <= (rdata_rs1 == 5'd0) ? 32'd0 : regs[rdata_rs1];
                    rval2_reg     <= (rdata_rs2 == 5'd0) ? 32'd0 : regs[rdata_rs2];
                    // Precalculate target addresses
                    pc_plus4_reg  <= pc_current + 32'd4;
                    pc_branch_reg <= pc_current + rdata_imm_b;
                    pc_jal_reg    <= pc_current + rdata_imm_j;
                    state         <= EXECUTE;
                end

                EXECUTE: begin
                    rd_wb <= rd;
                    case (opcode)
                        7'b0110111: begin // LUI
                            alu_result <= imm_u;
                            rf_we      <= 1'b1;
                            pc         <= pc_plus4_reg;
                            state      <= WRITEBACK;
                        end

                        7'b0010111: begin // AUIPC
                            alu_result <= pc_current + imm_u;
                            rf_we      <= 1'b1;
                            pc         <= pc_plus4_reg;
                            state      <= WRITEBACK;
                        end

                        7'b1101111: begin // JAL
                            alu_result <= pc_plus4_reg;
                            rf_we      <= 1'b1;
                            pc         <= pc_jal_reg;
                            state      <= WRITEBACK;
                        end

                        7'b1100111: begin // JALR
                            alu_result <= pc_plus4_reg;
                            rf_we      <= 1'b1;
                            pc         <= (rval1_reg + imm_i) & ~32'd1;
                            state      <= WRITEBACK;
                        end

                        7'b1100011: begin // BRANCH
                            rf_we <= 1'b0;
                            pc    <= branch_taken ? pc_branch_reg : pc_plus4_reg;
                            state <= WRITEBACK;
                        end

                        7'b0010011: begin // OP-IMM
                            rf_we <= 1'b1;
                            pc    <= pc_plus4_reg;
                            case (funct3)
                                3'b000: alu_result <= rval1_reg + imm_i;
                                3'b010: alu_result <= ($signed(rval1_reg) < $signed(imm_i)) ? 32'd1 : 32'd0;
                                3'b011: alu_result <= (rval1_reg < imm_i) ? 32'd1 : 32'd0;
                                3'b100: alu_result <= rval1_reg ^ imm_i;
                                3'b110: alu_result <= rval1_reg | imm_i;
                                3'b111: alu_result <= rval1_reg & imm_i;
                                3'b001: alu_result <= rval1_reg << imm_i[4:0];
                                3'b101: alu_result <= funct7[5] ? ($signed(rval1_reg) >>> imm_i[4:0]) : (rval1_reg >> imm_i[4:0]);
                                default: alu_result <= 32'd0;
                            endcase
                            state <= WRITEBACK;
                        end

                        7'b0110011: begin // OP
                            rf_we <= 1'b1;
                            pc    <= pc_plus4_reg;
                            case (funct3)
                                3'b000: alu_result <= funct7[5] ? (rval1_reg - rval2_reg) : (rval1_reg + rval2_reg);
                                3'b001: alu_result <= rval1_reg << rval2_reg[4:0];
                                3'b010: alu_result <= ($signed(rval1_reg) < $signed(rval2_reg)) ? 32'd1 : 32'd0;
                                3'b011: alu_result <= (rval1_reg < rval2_reg) ? 32'd1 : 32'd0;
                                3'b100: alu_result <= rval1_reg ^ rval2_reg;
                                3'b101: alu_result <= funct7[5] ? ($signed(rval1_reg) >>> rval2_reg[4:0]) : (rval1_reg >> rval2_reg[4:0]);
                                3'b110: alu_result <= rval1_reg | rval2_reg;
                                3'b111: alu_result <= rval1_reg & rval2_reg;
                                default: alu_result <= 32'd0;
                            endcase
                            state <= WRITEBACK;
                        end

                        7'b0000011: begin // LOAD
                            mem_addr  <= rval1_reg + imm_i;
                            mem_valid <= 1'b1;
                            mem_write <= 1'b0;
                            mem_wstrb <= 4'b0000;
                            pc        <= pc_plus4_reg;
                            state     <= MEM_WAIT;
                        end

                        7'b0100011: begin // STORE
                            mem_addr  <= rval1_reg + imm_s;
                            mem_wdata <= rval2_reg;
                            mem_valid <= 1'b1;
                            mem_write <= 1'b1;
                            mem_wstrb <= 4'b1111;
                            pc        <= pc_plus4_reg;
                            rf_we     <= 1'b0;
                            if ((rval1_reg + imm_s) == 32'h8000_0000) begin
                                state <= WAIT_IRQ;
                            end else begin
                                state <= MEM_WAIT;
                            end
                        end

                        default: begin
                            pc    <= pc_plus4_reg;
                            rf_we <= 1'b0;
                            state <= WRITEBACK;
                        end
                    endcase
                end

                MEM_WAIT: begin
                    if (mem_ready) begin
                        mem_valid <= 1'b0;
                        mem_write <= 1'b0;
                        if (opcode == 7'b0000011) begin // LOAD
                            alu_result <= mem_rdata;
                            rf_we      <= 1'b1;
                        end else begin
                            rf_we      <= 1'b0;
                        end
                        state <= WRITEBACK;
                    end
                end

                WAIT_IRQ: begin
                    mem_valid <= 1'b0;
                    mem_write <= 1'b0;
                    if (irq_in) begin
                        state <= WRITEBACK;
                    end
                end

                WRITEBACK: begin
                    if (rf_we && (rd_wb != 5'd0)) begin
                        regs[rd_wb] <= alu_result;
                    end
                    rf_we <= 1'b0;
                    state <= FETCH;
                end

                default: state <= FETCH;
            endcase
        end
    end
endmodule
`default_nettype wire

