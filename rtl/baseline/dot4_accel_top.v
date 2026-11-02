`timescale 1ns/1ps
`default_nettype none

// RISC-V MMIO Wrapper Top Module for Dual-Mode (INT8/INT16) Pipelined Accelerator
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
    output wire        accel_done_irq // <--- NAYA PIN: Hardware Interrupt Signal
);
    localparam [31:0] A_CTRL      = BASE_ADDR + 32'h00;
    localparam [31:0] A_STATUS    = BASE_ADDR + 32'h04;
    localparam [31:0] A_OPA       = BASE_ADDR + 32'h08;
    localparam [31:0] A_OPB       = BASE_ADDR + 32'h0c;
    localparam [31:0] A_RESULT    = BASE_ADDR + 32'h10;
    localparam [31:0] A_CYCLE_CNT = BASE_ADDR + 32'h14;

    localparam [2:0] IDLE         = 3'd0,
                     CAPTURE      = 3'd1,
                     COMPUTE      = 3'd2,
                     WRITE_RESULT = 3'd3,
                     DONE         = 3'd4;

    reg [2:0] state;
    reg [31:0] opa_reg, opb_reg;
    reg        mode_reg; // 0 = INT8 mode, 1 = INT16 mode

    // Pipeline Stage 1 Registers
    reg [31:0] active_opa, active_opb;
    reg        active_mode;

    // Pipeline Stage 2 Registers
    reg signed [31:0] pipe_datapath_result;
    reg signed [31:0] result_reg;

    // Hardware Cycle Counter (Point 4)
    reg [31:0] cycle_cnt;

    wire signed [31:0] datapath_result;
    wire wr_hit, rd_hit, accepted_start;

    assign bus_ready = 1'b1;
    assign wr_hit = bus_valid && bus_write;
    assign rd_hit = bus_valid && !bus_write;
    assign accepted_start = wr_hit && (bus_addr == A_CTRL) && bus_wdata[0] && (state == IDLE || state == DONE);

    // ---------------------------------------------------------
    // NAYA ADDITION: Interrupt Signal Generation
    // Jab accelerator DONE state mein ho, toh interrupt High (1) ho jayega
    // ---------------------------------------------------------
    assign accel_done_irq = (state == DONE);

    // Hardware Cycle Counter Logic
    always @(posedge clk) begin
        if (rst) begin
            cycle_cnt <= 32'd0;
        end else begin
            cycle_cnt <= cycle_cnt + 32'd1;
        end
    end

    // MMIO Read Decoder Interface
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

    // Instantiation of Dual-Mode Datapath Unit
    dot4_datapath datapath (
        .mode(active_mode),
        .opa(active_opa),
        .opb(active_opb),
        .result(datapath_result)
    );

    // Accelerator Control & Pipelined Execution FSM
    always @(posedge clk) begin
        if (rst) begin
            state                <= IDLE;
            opa_reg              <= 32'b0;
            opb_reg              <= 32'b0;
            mode_reg             <= 1'b0;
            active_opa           <= 32'b0;
            active_opb           <= 32'b0;
            active_mode          <= 1'b0;
            pipe_datapath_result <= 32'b0;
            result_reg           <= 32'b0;
        end else begin
            if (wr_hit && (state == IDLE || state == DONE)) begin
                if (bus_addr == A_OPA) opa_reg  <= bus_wdata;
                if (bus_addr == A_OPB) opb_reg  <= bus_wdata;
                if (bus_addr == A_CTRL) mode_reg <= bus_wdata[1]; // Bit 1 = Mode (0=INT8, 1=INT16)
            end
            case (state)
                IDLE, DONE: begin
                    if (accepted_start) state <= CAPTURE;
                end
                CAPTURE: begin
                    // Pipeline Stage 1: Latch Input Vectors & Mode
                    active_opa  <= opa_reg;
                    active_opb  <= opb_reg;
                    active_mode <= mode_reg;
                    state       <= COMPUTE;
                end
                COMPUTE: begin
                    // Pipeline Stage 2: Latch Combinational Datapath Multiplier/Adder Tree Result
                    pipe_datapath_result <= datapath_result;
                    state                <= WRITE_RESULT;
                end
                WRITE_RESULT: begin
                    // Pipeline Stage 3: Latch Final Output Result Register
                    $display("[Accel Trace] WRITE_RESULT (Mode=%0d): opa=0x%08x, opb=0x%08x, datapath_result=%0d (0x%08x)", active_mode, active_opa, active_opb, pipe_datapath_result, pipe_datapath_result);
                    result_reg <= pipe_datapath_result;
                    state      <= DONE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire