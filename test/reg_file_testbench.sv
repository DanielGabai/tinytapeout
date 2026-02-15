`timescale 1ns / 1ps

module reg_file_testbench;

    // ═══════════════════════════════════════════════════════════
    // Parameters
    // ═══════════════════════════════════════════════════════════
    localparam CLK_PERIOD = 10;  // 100MHz clock (10ns period)

    // ═══════════════════════════════════════════════════════════
    // DUT Signals
    // ═══════════════════════════════════════════════════════════
    logic       clk;
    logic       we;
    logic [2:0] in_reg;
    logic [2:0] in_sel;
    logic [2:0] out_reg;
    logic [2:0] out_sel;

    // ═══════════════════════════════════════════════════════════
    // Testbench Variables
    // ═══════════════════════════════════════════════════════════
    integer test_count;
    integer pass_count;
    integer fail_count;

    // ═══════════════════════════════════════════════════════════
    // Device Under Test (DUT)
    // ═══════════════════════════════════════════════════════════
    reg_file uut (
        .clk     (clk),
        .we      (we),
        .in_reg  (in_reg),
        .in_sel  (in_sel),
        .out_reg (out_reg),
        .out_sel (out_sel)
    );

    // ═══════════════════════════════════════════════════════════
    // Clock Generation
    // ═══════════════════════════════════════════════════════════
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ═══════════════════════════════════════════════════════════
    // Helper Tasks
    // ═══════════════════════════════════════════════════════════

    // Check expected vs actual value
    task check_value(
        input string signal_name,
        input logic [2:0] expected,
        input logic [2:0] actual
    );
        begin
            test_count++;
            if (actual === expected) begin
                pass_count++;
                $display("  PASS: %s = 0x%01h (expected 0x%01h)", signal_name, actual, expected);
            end else begin
                fail_count++;
                $display("  FAIL: %s = 0x%01h (expected 0x%01h)", signal_name, actual, expected);
            end
        end
    endtask

    // Write a value to a register and wait one clock cycle
    task write_reg(input logic [2:0] sel, input logic [2:0] data);
        begin
            @(posedge clk);
            in_sel = sel;
            in_reg = data;
            we = 1'b1;
            @(posedge clk);  // data latched on this edge
            we = 1'b0;
        end
    endtask

    // Read a register (combinational, just set out_sel and sample)
    task read_reg(input logic [2:0] sel, output logic [2:0] data);
        begin
            out_sel = sel;
            #1;
            data = out_reg;
        end
    endtask

    // Wait N clock cycles
    task wait_cycles(input integer n);
        repeat (n) @(posedge clk);
    endtask

    // ═══════════════════════════════════════════════════════════
    // Main Test Sequence
    // ═══════════════════════════════════════════════════════════
    initial begin
        // Setup waveform dumping
        $dumpfile("logs/reg_file_testbench.vcd");
        $dumpvars(0, reg_file_testbench);

        // Initialize
        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        // Initialize signals
        in_reg  = 3'd0;
        in_sel  = 3'd0;
        out_sel = 3'd0;
        we      = 1'b0;

        $display("\n============================================");
        $display("  reg_file Testbench");
        $display("============================================\n");

        // ───────────────────────────────────────────────────────
        // TEST 1: Single Write and Read
        // ───────────────────────────────────────────────────────
        $display("[TEST 1] Single Write and Read");
        write_reg(3'd0, 3'h5);
        begin
            logic [2:0] rdata;
            read_reg(3'd0, rdata);
            check_value("reg[0] after write 0x5", 3'h5, rdata);
        end
        $display("");

        // ───────────────────────────────────────────────────────
        // TEST 2: Write and Read All 8 Registers
        // ───────────────────────────────────────────────────────
        $display("[TEST 2] Write and Read All 8 Registers");
        // Write a unique value to each register
        for (int i = 0; i < 8; i++) begin
            write_reg(i[2:0], (i[2:0] + 3'd1) & 3'h7);
        end
        // Read back and verify each register
        for (int i = 0; i < 8; i++) begin
            logic [2:0] rdata;
            read_reg(i[2:0], rdata);
            check_value($sformatf("reg[%0d]", i), (i[2:0] + 3'd1) & 3'h7, rdata);
        end
        $display("");

        // ───────────────────────────────────────────────────────
        // TEST 3: Overwrite a Register
        // ───────────────────────────────────────────────────────
        $display("[TEST 3] Overwrite a Register");
        write_reg(3'd5, 3'h6);
        begin
            logic [2:0] rdata;
            read_reg(3'd5, rdata);
            check_value("reg[5] first write 0x6", 3'h6, rdata);
        end
        // Overwrite with a new value
        write_reg(3'd5, 3'h3);
        begin
            logic [2:0] rdata;
            read_reg(3'd5, rdata);
            check_value("reg[5] overwrite 0x3", 3'h3, rdata);
        end
        $display("");

        // ───────────────────────────────────────────────────────
        // TEST 4: Write Does Not Affect Other Registers
        // ───────────────────────────────────────────────────────
        $display("[TEST 4] Write Does Not Affect Other Registers");
        // Write known values to reg[0] and reg[1]
        write_reg(3'd0, 3'h5);
        write_reg(3'd1, 3'h2);
        // Overwrite reg[0], verify reg[1] is unchanged
        write_reg(3'd0, 3'h7);
        begin
            logic [2:0] rdata;
            read_reg(3'd1, rdata);
            check_value("reg[1] unchanged after reg[0] write", 3'h2, rdata);
            read_reg(3'd0, rdata);
            check_value("reg[0] updated to 0x7", 3'h7, rdata);
        end
        $display("");

        // ───────────────────────────────────────────────────────
        // TEST 5: Boundary Values
        // ───────────────────────────────────────────────────────
        $display("[TEST 5] Boundary Values (min/max data)");
        // Write 0x0 (all zeros)
        write_reg(3'd3, 3'h0);
        begin
            logic [2:0] rdata;
            read_reg(3'd3, rdata);
            check_value("reg[3] = 0x0", 3'h0, rdata);
        end
        // Write 0x7 (all ones)
        write_reg(3'd3, 3'h7);
        begin
            logic [2:0] rdata;
            read_reg(3'd3, rdata);
            check_value("reg[3] = 0x7", 3'h7, rdata);
        end
        $display("");

        // ───────────────────────────────────────────────────────
        // TEST 6: Boundary Register Addresses (first and last)
        // ───────────────────────────────────────────────────────
        $display("[TEST 6] Boundary Register Addresses");
        write_reg(3'd0, 3'h4);
        write_reg(3'd7, 3'h6);
        begin
            logic [2:0] rdata;
            read_reg(3'd0, rdata);
            check_value("reg[0] (first)", 3'h4, rdata);
            read_reg(3'd7, rdata);
            check_value("reg[7] (last)", 3'h6, rdata);
        end
        $display("");

        // ───────────────────────────────────────────────────────
        // TEST 7: Write Enable Deasserted (no write)
        // ───────────────────────────────────────────────────────
        $display("[TEST 7] Write Enable Deasserted");
        write_reg(3'd2, 3'h5);
        // Attempt write with we=0
        @(posedge clk);
        in_sel = 3'd2;
        in_reg = 3'h3;
        we = 1'b0;
        @(posedge clk);
        begin
            logic [2:0] rdata;
            read_reg(3'd2, rdata);
            check_value("reg[2] unchanged (we=0)", 3'h5, rdata);
        end
        $display("");

        // ───────────────────────────────────────────────────────
        // Final Summary
        // ───────────────────────────────────────────────────────
        $display("\n============================================");
        $display("  Test Summary");
        $display("--------------------------------------------");
        $display("  Total Tests: %3d", test_count);
        $display("  Passed:      %3d", pass_count);
        $display("  Failed:      %3d", fail_count);
        $display("--------------------------------------------");

        if (fail_count == 0) begin
            $display("  Result:  ALL TESTS PASSED");
        end else begin
            $display("  Result:  SOME TESTS FAILED");
        end

        $display("============================================\n");

        $finish;
    end

    // ═══════════════════════════════════════════════════════════
    // Timeout Watchdog
    // ═══════════════════════════════════════════════════════════
    initial begin
        #1000000;  // 1ms timeout
        $display("\n ERROR: Simulation timeout!");
        $finish;
    end

endmodule
