`timescale 1ns/1ps
`default_nettype none

// ==============================================================================
// High-Frequency Pipelined DOT4 Hardware Accelerator
// Features:
// 1. Dual-Mode (INT8 / INT16) Vector Dot Products
// 2. Multicycle Multipliers (MCP = 2 Cycles) + Pipelined Adder Tree
// 3. Designed for 350 - 400 MHz Timing Closure in TSMC 180nm
// ==============================================================================
module dot4_accel_top #(
    parameter [31:0] BASE_ADDR = 32'h8000_0000
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        bus_valid,
    input  wire        bus_write,
    input  wire [31:0] bus_addr,
    input  wire [31:0] bus_wdata,
    output reg  [31:0] bus_rdata,
    output wire        bus_ready,
    output wire        accel_done_irq
);

    localparam [31:0] A_CTRL      = BASE_ADDR + 32'h00;
    localparam [31:0] A_STATUS    = BASE_ADDR + 32'h04;
    localparam [31:0] A_OPA       = BASE_ADDR + 32'h08;
    localparam [31:0] A_OPB       = BASE_ADDR + 32'h0c;
    localparam [31:0] A_RESULT    = BASE_ADDR + 32'h10;
    localparam [31:0] A_CYCLE_CNT = BASE_ADDR + 32'h14;

    // FSM States
    localparam [2:0] IDLE          = 3'd0,
                     CAPTURE       = 3'd1,
                     COMPUTE_MULT1 = 3'd2,
                     COMPUTE_MULT2 = 3'd3,
                     COMPUTE_ADD   = 3'd4,
                     DONE          = 3'd5;

    reg [2:0] state;
    reg [31:0] opa_reg, opb_reg;
    reg        mode_reg; // 0 = INT8 mode, 1 = INT16 mode

    // Pipeline Registers
    reg [31:0] active_opa, active_opb;
    reg        active_mode;
    reg        pipe_valid;
    wire signed [31:0] datapath_result;
    reg signed  [31:0] result_reg;

    // Backward-compatible alias for testbenches and monitoring
    wire signed [31:0] pipe_datapath_result = datapath_result;

    // Hardware Cycle Counter
    reg [31:0] cycle_cnt;

    wire wr_hit, rd_hit, accepted_start;

    assign bus_ready = 1'b1;
    assign wr_hit = bus_valid && bus_write;
    assign rd_hit = bus_valid && !bus_write;
    assign accepted_start = wr_hit && (bus_addr == A_CTRL) && bus_wdata[0] && (state == IDLE || state == DONE);

    // Hardware Interrupt Generation (Deasserts immediately on start command)
    assign accel_done_irq = (state == DONE) && !accepted_start;

    // Cycle Counter
    always @(posedge clk) begin
        if (rst) cycle_cnt <= 32'd0;
        else     cycle_cnt <= cycle_cnt + 32'd1;
    end

    // MMIO Read Interface
    always @(*) begin
        bus_rdata = 32'h0000_0000;
        if (rd_hit) begin
            case (bus_addr)
                A_STATUS:    bus_rdata = {29'b0, mode_reg, (state != IDLE && state != DONE), (state == DONE && !accepted_start)};
                A_RESULT:    bus_rdata = result_reg;
                A_CYCLE_CNT: bus_rdata = cycle_cnt;
                default:     bus_rdata = 32'h0000_0000;
            endcase
        end
    end

    // Instantiation of Pipelined Datapath
    dot4_datapath_pipelined u_piped_datapath (
        .clk(clk),
        .rst(rst),
        .mode_in(active_mode),
        .opa_in(active_opa),
        .opb_in(active_opb),
        .valid_in(pipe_valid),
        .result_out(datapath_result)
    );

    // Accelerator Control FSM
    always @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            opa_reg     <= 32'b0;
            opb_reg     <= 32'b0;
            mode_reg    <= 1'b0;
            active_opa  <= 32'b0;
            active_opb  <= 32'b0;
            active_mode <= 1'b0;
            pipe_valid  <= 1'b0;
            result_reg  <= 32'b0;
        end else begin
            // MMIO Register Writes
            if (wr_hit && (state == IDLE || state == DONE)) begin
                if (bus_addr == A_OPA)  opa_reg  <= bus_wdata;
                if (bus_addr == A_OPB)  opb_reg  <= bus_wdata;
                if (bus_addr == A_CTRL) mode_reg <= bus_wdata[1];
            end

            case (state)
                IDLE, DONE: begin
                    pipe_valid <= 1'b0;
                    if (accepted_start) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    // Latch Operands into Datapath Inputs
                    active_opa  <= opa_reg;
                    active_opb  <= opb_reg;
                    active_mode <= mode_reg;
                    pipe_valid  <= 1'b0;
                    state       <= COMPUTE_MULT1;
                end

                COMPUTE_MULT1: begin
                    // Multiplier Cycle 1: Inputs active_opa/b are stable and driving multipliers
                    pipe_valid <= 1'b1; // Assert clock enable for upcoming clock edge
                    state      <= COMPUTE_MULT2;
                end

                COMPUTE_MULT2: begin
                    // Multiplier Cycle 2: Datapath latches multiplier products into p0_reg/p16_reg
                    pipe_valid <= 1'b0;
                    state      <= COMPUTE_ADD;
                end

                COMPUTE_ADD: begin
                    // Adder Tree finishes combinational sum; latch final result
                    result_reg <= datapath_result;
                    state      <= DONE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
`default_nettype wire
