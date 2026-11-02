    `timescale 1ns/1ps
`default_nettype none

// Clean, Fully Functional RV32I Processor Core with Hardware Interrupt Handshake
module rv32i_core (
    input  wire        clk,
    input  wire        rst,
    input  wire        irq_in,       // <--- NAYA PIN: Hardware Interrupt from Accelerator

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
                    WAIT_IRQ  = 3'd5; // <--- NAYA STATE: Wait for accelerator interrupt

    reg [2:0] state;

    reg [31:0] instr;
    reg [31:0] pc_current;
    reg [31:0] alu_result;
    reg [4:0]  rd_wb;
    reg        rf_we;

    // Fields
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    // Immediates
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // Register Operands
    wire [31:0] rval1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    wire [31:0] rval2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

    // Opcode constants
    localparam OPCODE_LUI    = 7'b0110111;
    localparam OPCODE_AUIPC  = 7'b0010111;
    localparam OPCODE_JAL    = 7'b1101111;
    localparam OPCODE_JALR   = 7'b1100111;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_LOAD   = 7'b0000011;
    localparam OPCODE_STORE  = 7'b0100011;
    localparam OPCODE_OP_IMM = 7'b0010011;
    localparam OPCODE_OP     = 7'b0110011;

    // Branch condition
    reg branch_taken;
    always @(*) begin
        case (funct3)
            3'b000: branch_taken = (rval1 == rval2);
            3'b001: branch_taken = (rval1 != rval2);
            3'b100: branch_taken = ($signed(rval1) < $signed(rval2));
            3'b101: branch_taken = ($signed(rval1) >= $signed(rval2));
            3'b110: branch_taken = (rval1 < rval2);
            3'b111: branch_taken = (rval1 >= rval2);
            default: branch_taken = 1'b0;
        endcase
    end

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            pc         <= 32'h0000_0000;
            state      <= FETCH;
            mem_valid  <= 1'b0;
            mem_write  <= 1'b0;
            mem_wstrb  <= 4'b0000;
            mem_addr   <= 32'd0;
            mem_wdata  <= 32'd0;
            rf_we      <= 1'b0;
            rd_wb      <= 5'd0;
            alu_result <= 32'd0;
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
                    if (mem_ready) begin
                        instr     <= mem_rdata;
                        mem_valid <= 1'b0;
                        state     <= EXECUTE;
                    end
                end

                EXECUTE: begin
                    rd_wb <= rd;
                    case (opcode)
                        7'b0110111: begin // LUI
                            alu_result <= imm_u;
                            rf_we      <= 1'b1;
                            pc         <= pc_current + 32'd4;
                            state      <= WRITEBACK;
                        end

                        7'b0010111: begin // AUIPC
                            alu_result <= pc_current + imm_u;
                            rf_we      <= 1'b1;
                            pc         <= pc_current + 32'd4;
                            state      <= WRITEBACK;
                        end

                        7'b1101111: begin // JAL
                            alu_result <= pc_current + 32'd4;
                            rf_we      <= 1'b1;
                            pc         <= pc_current + imm_j;
                            state      <= WRITEBACK;
                        end

                        7'b1100111: begin // JALR
                            alu_result <= pc_current + 32'd4;
                            rf_we      <= 1'b1;
                            pc         <= (rval1 + imm_i) & ~32'd1;
                            state      <= WRITEBACK;
                        end

                        7'b1100011: begin // BRANCH
                            rf_we <= 1'b0;
                            if (branch_taken) pc <= pc_current + imm_b;
                            else              pc <= pc_current + 32'd4;
                            state <= WRITEBACK;
                        end

                        7'b0010011: begin // OP-IMM
                            rf_we <= 1'b1;
                            pc    <= pc_current + 32'd4;
                            case (funct3)
                                3'b000: alu_result <= rval1 + imm_i; // ADDI
                                3'b010: alu_result <= ($signed(rval1) < $signed(imm_i)) ? 32'd1 : 32'd0; // SLTI
                                3'b011: alu_result <= (rval1 < imm_i) ? 32'd1 : 32'd0; // SLTIU
                                3'b100: alu_result <= rval1 ^ imm_i; // XORI
                                3'b110: alu_result <= rval1 | imm_i; // ORI
                                3'b111: alu_result <= rval1 & imm_i; // ANDI
                                3'b001: alu_result <= rval1 << imm_i[4:0]; // SLLI
                                3'b101: alu_result <= funct7[5] ? ($signed(rval1) >>> imm_i[4:0]) : (rval1 >> imm_i[4:0]); // SRAI/SRLI
                                default: alu_result <= 32'd0;
                            endcase
                            state <= WRITEBACK;
                        end

                        7'b0110011: begin // OP
                            rf_we <= 1'b1;
                            pc    <= pc_current + 32'd4;
                            case (funct3)
                                3'b000: alu_result <= funct7[5] ? (rval1 - rval2) : (rval1 + rval2); // SUB/ADD
                                3'b001: alu_result <= rval1 << rval2[4:0]; // SLL
                                3'b010: alu_result <= ($signed(rval1) < $signed(rval2)) ? 32'd1 : 32'd0; // SLT
                                3'b011: alu_result <= (rval1 < rval2) ? 32'd1 : 32'd0; // SLTU
                                3'b100: alu_result <= rval1 ^ rval2; // XOR
                                3'b101: alu_result <= funct7[5] ? ($signed(rval1) >>> rval2[4:0]) : (rval1 >> rval2[4:0]); // SRA/SRL
                                3'b110: alu_result <= rval1 | rval2; // OR
                                3'b111: alu_result <= rval1 & rval2; // AND
                                default: alu_result <= 32'd0;
                            endcase
                            state <= WRITEBACK;
                        end

                        7'b0000011: begin // LOAD
                            mem_addr  <= rval1 + imm_i;
                            mem_valid <= 1'b1;
                            mem_write <= 1'b0;
                            mem_wstrb <= 4'b0000;
                            pc        <= pc_current + 32'd4;
                            state     <= MEM_WAIT;
                        end

                        7'b0100011: begin // STORE
                            // 🚀 OPTIMIZATION: If storing to Accelerator CTRL (0x8000_0000), use Hardware Wait
                            if ((rval1 + imm_s) == 32'h8000_0000) begin
                                mem_addr  <= rval1 + imm_s;
                                mem_wdata <= rval2;
                                mem_valid <= 1'b1;
                                mem_write <= 1'b1;
                                mem_wstrb <= 4'b1111;
                                pc        <= pc_current + 32'd4;
                                rf_we     <= 1'b0;
                                state     <= WAIT_IRQ; // <--- Jump to WAIT_IRQ instead of MEM_WAIT
                            end else begin
                                mem_addr  <= rval1 + imm_s;
                                mem_wdata <= rval2;
                                mem_valid <= 1'b1;
                                mem_write <= 1'b1;
                                mem_wstrb <= 4'b1111;
                                pc        <= pc_current + 32'd4;
                                rf_we     <= 1'b0;
                                state     <= MEM_WAIT;
                            end
                        end

                        default: begin
                            pc    <= pc_current + 32'd4;
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

                // 🚀 NAYA STATE: Wait for Accelerator Interrupt
                WAIT_IRQ: begin
                    // Drop bus signals to be clean (accelerator already captured the start command in previous cycle)
                    mem_valid <= 1'b0;
                    mem_write <= 1'b0;
                    
                    if (irq_in) begin
                        state <= WRITEBACK; // Interrupt received, proceed to next instruction
                    end
                    // Else: stay in WAIT_IRQ (stall CPU until accelerator is done)
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