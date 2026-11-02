`timescale 1ns/1ps
`default_nettype none

// Simple 115200 Baud UART Transmitter Module for 100MHz System Clock
module uart_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_ready,
    output reg        tx_out
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // 868 cycles

    localparam [1:0] IDLE  = 2'd0,
                     START = 2'd1,
                     DATA  = 2'd2,
                     STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  tx_shift;

    always @(posedge clk) begin
        if (rst) begin
            state    <= IDLE;
            tx_out   <= 1'b1;
            tx_ready <= 1'b1;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            tx_shift <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx_out   <= 1'b1;
                    tx_ready <= 1'b1;
                    clk_cnt  <= 16'd0;
                    bit_idx  <= 3'd0;
                    if (tx_valid) begin
                        tx_shift <= tx_data;
                        tx_ready <= 1'b0;
                        state    <= START;
                    end
                end

                START: begin
                    tx_out <= 1'b0; // Start bit (0)
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        state   <= DATA;
                    end
                end

                DATA: begin
                    tx_out <= tx_shift[bit_idx];
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt <= 16'd0;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 3'd1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_out <= 1'b1; // Stop bit (1)
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end else begin
                        clk_cnt  <= 16'd0;
                        tx_ready <= 1'b1;
                        state    <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
