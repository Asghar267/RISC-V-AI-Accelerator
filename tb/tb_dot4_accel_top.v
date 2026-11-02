`timescale 1ns/1ps
`default_nettype none

module tb_dot4_accel_top;
    reg clk;
    reg rst;
    reg bus_valid;
    reg bus_write;
    reg [31:0] bus_addr;
    reg [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    wire bus_ready;
    integer tests;
    integer seed;

    localparam [31:0] BASE      = 32'h8000_0000;
    localparam [31:0] CTRL      = BASE + 32'h00;
    localparam [31:0] STATUS    = BASE + 32'h04;
    localparam [31:0] OPA       = BASE + 32'h08;
    localparam [31:0] OPB       = BASE + 32'h0c;
    localparam [31:0] RESULT    = BASE + 32'h10;
    localparam [31:0] CYCLE_CNT = BASE + 32'h14;

    wire accel_irq;

    dot4_accel_top dut (
        .clk(clk),
        .rst(rst),
        .bus_valid(bus_valid),
        .bus_write(bus_write),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready),
        .accel_done_irq(accel_irq)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    function [31:0] pack4;
        input integer x0, x1, x2, x3;
        begin
            pack4 = {x3[7:0], x2[7:0], x1[7:0], x0[7:0]};
        end
    endfunction

    function [31:0] pack2_16;
        input integer x0, x1;
        begin
            pack2_16 = {x1[15:0], x0[15:0]};
        end
    endfunction

    function integer s8;
        input [7:0] x;
        begin
            s8 = x[7] ? x - 256 : x;
        end
    endfunction

    function integer s16;
        input [15:0] x;
        begin
            s16 = x[15] ? x - 65536 : x;
        end
    endfunction

    function integer refdot8;
        input [31:0] aa;
        input [31:0] bb;
        begin
            refdot8 = s8(aa[7:0])*s8(bb[7:0]) + s8(aa[15:8])*s8(bb[15:8]) +
                      s8(aa[23:16])*s8(bb[23:16]) + s8(aa[31:24])*s8(bb[31:24]);
        end
    endfunction

    function integer refdot16;
        input [31:0] aa;
        input [31:0] bb;
        begin
            refdot16 = s16(aa[15:0])*s16(bb[15:0]) + s16(aa[31:16])*s16(bb[31:16]);
        end
    endfunction

    task write32;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(negedge clk);
            bus_valid = 1'b1;
            bus_write = 1'b1;
            bus_addr  = addr;
            bus_wdata = data;
            @(negedge clk);
            bus_valid = 1'b0;
            bus_write = 1'b0;
            bus_addr  = 32'b0;
            bus_wdata = 32'b0;
        end
    endtask

    task read32;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(negedge clk);
            bus_valid = 1'b1;
            bus_write = 1'b0;
            bus_addr  = addr;
            #1;
            data = bus_rdata;
            @(negedge clk);
            bus_valid = 1'b0;
            bus_addr  = 32'b0;
        end
    endtask

    task check;
        input integer got;
        input integer want;
        input [255:0] name;
        begin
            tests = tests + 1;
            if (got !== want) begin
                $display("FAIL %s: got %0d (0x%08x), want %0d (0x%08x)", name, got, got, want, want);
                $finish;
            end
        end
    endtask

    task run_job8;
        input [31:0] aa;
        input [31:0] bb;
        reg [31:0] r;
        integer guard;
        begin
            write32(OPA, aa);
            write32(OPB, bb);
            write32(CTRL, 32'h0); // Mode 0 = INT8
            write32(CTRL, 32'h1); // Start bit = 1
            guard = 0;
            repeat (10) begin
                read32(STATUS, r);
                if (r[0]) guard = 1;
            end
            if (!guard) begin
                $display("FAIL: DONE timeout");
                $finish;
            end
            read32(RESULT, r);
            check($signed(r), refdot8(aa, bb), "INT8 transaction");
        end
    endtask

    task run_job16;
        input [31:0] aa;
        input [31:0] bb;
        reg [31:0] r;
        integer guard;
        begin
            write32(OPA, aa);
            write32(OPB, bb);
            write32(CTRL, 32'h2); // Mode 1 (Bit 1=1) = INT16
            write32(CTRL, 32'h3); // Mode 1 + Start bit = 1
            guard = 0;
            repeat (10) begin
                read32(STATUS, r);
                if (r[0]) guard = 1;
            end
            if (!guard) begin
                $display("FAIL: DONE timeout");
                $finish;
            end
            read32(RESULT, r);
            check($signed(r), refdot16(aa, bb), "INT16 transaction");
        end
    endtask

    integer i;
    integer x0, x1, x2, x3;
    integer y0, y1, y2, y3;
    reg [31:0] aa, bb, r, c1, c2;

    initial begin
        clk = 1'b0;
        tests = 0;
        seed = 32'h260828;
        bus_valid = 1'b0;
        bus_write = 1'b0;
        bus_addr  = 32'b0;
        bus_wdata = 32'b0;
        rst       = 1'b1;

        repeat(2) @(negedge clk);
        rst = 1'b0;

        read32(STATUS, r); check(r, 0, "reset status");
        read32(RESULT, r); check(r, 0, "reset result");
        
        // Check Hardware Cycle Counter (Point 4)
        read32(CYCLE_CNT, c1);
        repeat(5) @(negedge clk);
        read32(CYCLE_CNT, c2);
        if (c2 <= c1) begin
            $display("FAIL: Cycle counter not incrementing!");
            $finish;
        end

        // INT8 Mode Tests
        run_job8(pack4(1,2,3,4), pack4(5,6,7,8));
        run_job8(pack4(-1,-2,-3,-4), pack4(1,2,3,4));
        run_job8(pack4(127,127,127,127), pack4(127,127,127,127));
        run_job8(pack4(-128,-128,-128,-128), pack4(-128,-128,-128,-128));

        // INT16 Mode Tests (Point 1)
        run_job16(pack2_16(100, 200), pack2_16(300, 400)); // 100*300 + 200*400 = 30000 + 80000 = 110000
        run_job16(pack2_16(-1000, 500), pack2_16(200, -300)); // -1000*200 + 500*-300 = -200000 - 150000 = -350000

        // Random Test Loops for INT8 and INT16
        for (i = 0; i < 100; i = i + 1) begin
            x0 = $random(seed) % 256; if (x0 < 0) x0 = -x0;
            x1 = $random(seed) % 256; if (x1 < 0) x1 = -x1;
            x2 = $random(seed) % 256; if (x2 < 0) x2 = -x2;
            x3 = $random(seed) % 256; if (x3 < 0) x3 = -x3;
            y0 = $random(seed) % 256; if (y0 < 0) y0 = -y0;
            y1 = $random(seed) % 256; if (y1 < 0) y1 = -y1;
            y2 = $random(seed) % 256; if (y2 < 0) y2 = -y2;
            y3 = $random(seed) % 256; if (y3 < 0) y3 = -y3;
            aa = pack4(x0 - 128, x1 - 128, x2 - 128, x3 - 128);
            bb = pack4(y0 - 128, y1 - 128, y2 - 128, y3 - 128);
            run_job8(aa, bb);
        end

        for (i = 0; i < 100; i = i + 1) begin
            x0 = $random(seed) % 65536; if (x0 < 0) x0 = -x0;
            x1 = $random(seed) % 65536; if (x1 < 0) x1 = -x1;
            y0 = $random(seed) % 65536; if (y0 < 0) y0 = -y0;
            y1 = $random(seed) % 65536; if (y1 < 0) y1 = -y1;
            aa = pack2_16(x0 - 32768, x1 - 32768);
            bb = pack2_16(y0 - 32768, y1 - 32768);
            run_job16(aa, bb);
        end

        $display("PASS: %0d checks (INT8 + INT16 Dual-Mode + Cycle Counter), seed=0x%08x", tests, seed);
        $finish;
    end
endmodule
`default_nettype wire
