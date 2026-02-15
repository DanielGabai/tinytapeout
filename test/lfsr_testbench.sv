`timescale 1ns / 1ps

module lfsr_testbench;

    // Parameters
    localparam CLK_PERIOD = 10;  // 100MHz clock (10ns period)

    // DUT Signals
    logic       clk;
    logic       rst_n;
    logic       load;
    logic [7:0] seed;
    logic [7:0] r_out;

    // Testbench Variables
    integer test_count;
    integer pass_count;
    integer fail_count;

    // Device Under Test (DUT)
    lfsr uut (
        .clk   (clk),
        .rst_n (rst_n),
        .load  (load),
        .seed  (seed),
        .r_out (r_out)
    );

    // Clock Generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Helper Tasks ---

    // Reset the DUT
    task reset_dut();
        begin
            @(posedge clk);
            rst_n = 0;
            load  = 0;
            seed  = 8'd0;
            repeat (3) @(posedge clk);
            rst_n = 1;
            @(posedge clk);
            $display("[%0t] Reset complete", $time);
        end
    endtask

    // Check expected vs actual value
    task check_value(
        input string signal_name,
        input logic [7:0] expected,
        input logic [7:0] actual
    );
        begin
            test_count++;
            if (actual === expected) begin
                pass_count++;
                $display("  PASS: %s = 0x%02h (expected 0x%02h)", signal_name, actual, expected);
            end else begin
                fail_count++;
                $display("  FAIL: %s = 0x%02h (expected 0x%02h)", signal_name, actual, expected);
            end
        end
    endtask

    // Wait N clock cycles
    task wait_cycles(input integer n);
        repeat (n) @(posedge clk);
    endtask

    // --- Main Test Sequence ---
    initial begin
        // Setup waveform dumping
        $dumpfile("logs/lfsr_testbench.vcd");
        $dumpvars(0, lfsr_testbench);

        // Initialize
        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        // Initialize signals
        rst_n = 1;
        load  = 0;
        seed  = 8'd0;

        $display("\n============================================");
        $display("  LFSR Testbench");
        $display("============================================\n");

        // -------------------------------------------------
        // TEST 1: Reset Verification
        // -------------------------------------------------
        $display("[TEST 1] Reset Verification");
        reset_dut();
        // After reset, r_out should be 8'd1
        check_value("r_out after reset", 8'h01, r_out);
        $display("");

        // -------------------------------------------------
        // TEST 2: LFSR Sequence Verification
        //   Starting from 0x01, the expected sequence is:
        //   01 -> 02 -> 05 -> 0A -> 14 -> 29 -> 53 -> A6
        //   Feedback: r_out[7] ^ r_out[5] ^ r_out[4] ^ r_out[1]
        // -------------------------------------------------
        $display("[TEST 2] Free-Running Sequence (8 steps from 0x01)");
        begin
            logic [7:0] expected_seq [0:7];
            expected_seq[0] = 8'h01;  // initial (already verified)
            expected_seq[1] = 8'h02;
            expected_seq[2] = 8'h05;
            expected_seq[3] = 8'h0A;
            expected_seq[4] = 8'h15;
            expected_seq[5] = 8'h2B;
            expected_seq[6] = 8'h56;
            expected_seq[7] = 8'hAC;

            for (int i = 1; i < 8; i++) begin
                @(posedge clk);
                check_value($sformatf("r_out step %0d", i), expected_seq[i], r_out);
            end
        end
        $display("");

        // -------------------------------------------------
        // TEST 3: Seed Load
        // -------------------------------------------------
        $display("[TEST 3] Seed Load");
        // Load a known seed value
        @(posedge clk);
        load = 1;
        seed = 8'hAB;
        @(posedge clk);
        #1;
        check_value("r_out after load 0xAB", 8'hAB, r_out);

        // Deassert load and check LFSR advances from the new seed
        load = 0;
        @(posedge clk);
        #1;
        // From 0xAB = 8'b1010_1011: fb = bit7^bit5^bit4^bit1 = 1^1^1^0 = 1
        // next = {0101011, 1} = 8'b01010111 = 0x57
        check_value("r_out 1 cycle after 0xAB", 8'h57, r_out);
        $display("");

        // -------------------------------------------------
        // TEST 4: Seed = 0 Protection (should load 1 instead)
        // -------------------------------------------------
        $display("[TEST 4] Seed = 0 Protection");
        @(posedge clk);
        load = 1;
        seed = 8'h00;
        @(posedge clk);
        #1;
        check_value("r_out after load 0x00 (expect 0x01)", 8'h01, r_out);
        load = 0;
        $display("");

        // -------------------------------------------------
        // TEST 5: Full Period Test
        //   An 8-bit maximal-length LFSR cycles through 255
        //   unique non-zero states before returning to start.
        // -------------------------------------------------
        $display("[TEST 5] Full Period Test (255 unique states)");
        // Reset to known state 0x01
        reset_dut();
        begin
            logic [7:0] seen [0:254];
            logic       duplicate_found;
            logic       zero_found;
            integer     period;

            duplicate_found = 0;
            zero_found      = 0;
            seen[0]         = r_out;  // should be 0x01
            period          = 0;

            // Run up to 255 cycles
            for (int i = 1; i <= 255; i++) begin
                @(posedge clk);
                #1;

                // Check for zero output (should never happen)
                if (r_out == 8'h00) begin
                    zero_found = 1;
                    $display("  FAIL: r_out reached 0x00 at cycle %0d", i);
                end

                // Check if we returned to initial state
                if (r_out == 8'h01) begin
                    period = i;
                    i = 256;  // break
                end else begin
                    seen[i] = r_out;
                end
            end

            test_count++;
            if (zero_found) begin
                fail_count++;
                $display("  FAIL: LFSR output reached zero (locked up)");
            end else begin
                pass_count++;
                $display("  PASS: LFSR never output zero");
            end

            test_count++;
            if (period == 254) begin
                pass_count++;
                $display("  PASS: Full period = 254 (maximal length)");
            end else if (period > 0) begin
                fail_count++;
                $display("  FAIL: Period = %0d (expected 254)", period);
            end else begin
                fail_count++;
                $display("  FAIL: Did not return to initial state within 254 cycles");
            end
        end
        $display("");

        // -------------------------------------------------
        // TEST 6: Load During Operation
        // -------------------------------------------------
        $display("[TEST 6] Load During Operation");
        // Let LFSR run a few cycles then load a new seed mid-operation
        reset_dut();
        wait_cycles(5);
        @(posedge clk);
        load = 1;
        seed = 8'hFF;
        @(posedge clk);
        #1;
        check_value("r_out after mid-run load 0xFF", 8'hFF, r_out);
        load = 0;

        // Verify it continues from the loaded value
        // 0xFF = 8'b1111_1111: fb = 1^1^1^1 = 0
        // next = {1111111, 0} = 8'b11111110 = 0xFE
        @(posedge clk);
        #1;
        check_value("r_out 1 cycle after 0xFF", 8'hFE, r_out);
        $display("");

        // -------------------------------------------------
        // Final Summary
        // -------------------------------------------------
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

    // Timeout Watchdog
    initial begin
        #1000000;  // 1ms timeout
        $display("\n ERROR: Simulation timeout!");
        $finish;
    end

endmodule
