`timescale 1ns / 1ps

module lfsr_testbench;

    // Parameters
    localparam CLK_PERIOD = 10;  // 100MHz clock (10ns period)

    // DUT Signals
    logic       clk;
    logic       rst_n;
    logic       load;
    logic       en;
    logic [7:0] seed;
    logic [2:0] r_out;

    // Testbench Variables
    integer test_count;
    integer pass_count;
    integer fail_count;

    // Device Under Test (DUT)
    lfsr uut (
        .clk   (clk),
        .rst_n (rst_n),
        .load  (load),
        .en    (en),
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
            en    = 0;
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
        input logic [2:0] expected,
        input logic [2:0] actual
    );
        begin
            test_count++;
            if (actual === expected) begin
                pass_count++;
                $display("  PASS: %s = 3'b%03b (expected 3'b%03b)", signal_name, actual, expected);
            end else begin
                fail_count++;
                $display("  FAIL: %s = 3'b%03b (expected 3'b%03b)", signal_name, actual, expected);
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
        en    = 0;
        seed  = 8'd0;

        $display("\n============================================");
        $display("  LFSR Testbench");
        $display("============================================\n");

        // -------------------------------------------------
        // TEST 1: Reset Verification
        //   After reset, r_store = 8'h01
        //   r_out = {r_store[6], r_store[3], r_store[0]}
        //         = {0, 0, 1} = 3'b001
        // -------------------------------------------------
        $display("[TEST 1] Reset Verification");
        reset_dut();
        check_value("r_out after reset", 3'b001, r_out);
        $display("");

        // -------------------------------------------------
        // TEST 2: LFSR Sequence Verification (en = 1)
        //   Internal state sequence from 0x01:
        //   0x01 -> 0x02 -> 0x05 -> 0x0A -> 0x15 -> 0x2B -> 0x56 -> 0xAC
        //   r_out = {r_store[6], r_store[3], r_store[0]}:
        //   001  ->  000  ->  001  ->  010  ->  001  ->  011  ->  100  ->  010
        // -------------------------------------------------
        $display("[TEST 2] Free-Running Sequence (7 steps from 0x01, en=1)");
        en = 1;
        begin
            logic [2:0] expected_rout [0:7];
            expected_rout[0] = 3'b001;  // 0x01: {0,0,1}
            expected_rout[1] = 3'b000;  // 0x02: {0,0,0}
            expected_rout[2] = 3'b001;  // 0x05: {0,0,1}
            expected_rout[3] = 3'b010;  // 0x0A: {0,1,0}
            expected_rout[4] = 3'b001;  // 0x15: {0,0,1}
            expected_rout[5] = 3'b011;  // 0x2B: {0,1,1}
            expected_rout[6] = 3'b100;  // 0x56: {1,0,0}
            expected_rout[7] = 3'b010;  // 0xAC: {0,1,0}

            for (int i = 1; i < 8; i++) begin
                @(posedge clk);
                #1;
                check_value($sformatf("r_out step %0d", i), expected_rout[i], r_out);
            end
        end
        en = 0;
        $display("");

        // -------------------------------------------------
        // TEST 3: Enable Control (en = 0 holds state)
        // -------------------------------------------------
        $display("[TEST 3] Enable Control (en=0 holds state)");
        begin
            logic [2:0] held_value;
            held_value = r_out;  // capture current output
            en = 0;
            repeat (5) begin
                @(posedge clk);
                #1;
            end
            check_value("r_out held after 5 cycles with en=0", held_value, r_out);
        end
        $display("");

        // -------------------------------------------------
        // TEST 4: Seed Load
        // -------------------------------------------------
        $display("[TEST 4] Seed Load");
        // Load seed 0xAB = 8'b1010_1011
        // r_out = {r_store[6]=0, r_store[3]=1, r_store[0]=1} = 3'b011
        @(posedge clk);
        load = 1;
        seed = 8'hAB;
        @(posedge clk);
        #1;
        check_value("r_out after load 0xAB", 3'b011, r_out);

        // Deassert load, enable LFSR, check it advances from new seed
        // From 0xAB: fb = 1^1^0^1 = 1, next = 0x57 = 8'b0101_0111
        // r_out = {r_store[6]=1, r_store[3]=0, r_store[0]=1} = 3'b101
        load = 0;
        en   = 1;
        @(posedge clk);
        #1;
        check_value("r_out 1 cycle after 0xAB", 3'b101, r_out);
        en = 0;
        $display("");

        // -------------------------------------------------
        // TEST 5: Seed = 0 Protection (should load 1 instead)
        //   r_out for 0x01 = {0,0,1} = 3'b001
        // -------------------------------------------------
        $display("[TEST 5] Seed = 0 Protection");
        @(posedge clk);
        load = 1;
        seed = 8'h00;
        @(posedge clk);
        #1;
        check_value("r_out after load 0x00 (expect 0x01)", 3'b001, r_out);
        load = 0;
        $display("");

        // -------------------------------------------------
        // TEST 6: Full Period Test
        //   An 8-bit maximal-length LFSR cycles through 255
        //   unique internal states. After 255 shifts the
        //   r_out should return to its initial value.
        // -------------------------------------------------
        $display("[TEST 6] Full Period Test (255 cycles back to start)");
        reset_dut();
        begin
            logic [2:0] initial_rout;
            integer     period;
            logic       returned;

            initial_rout = r_out;
            returned     = 0;
            period       = 0;
            en           = 1;

            for (int i = 1; i <= 255; i++) begin
                @(posedge clk);
                #1;
            end

            // After exactly 255 shifts, internal state returns to 0x01
            // r_out should match the initial value
            test_count++;
            if (r_out === initial_rout) begin
                pass_count++;
                $display("  PASS: r_out returned to initial value after 255 cycles");
            end else begin
                fail_count++;
                $display("  FAIL: r_out = 3'b%03b after 255 cycles (expected 3'b%03b)", r_out, initial_rout);
            end
            en = 0;
        end
        $display("");

        // -------------------------------------------------
        // TEST 7: Load During Operation (en must be low)
        // -------------------------------------------------
        $display("[TEST 7] Load During Operation (en=0 required)");
        // Let LFSR run a few cycles then pause and load a new seed
        reset_dut();
        en = 1;
        wait_cycles(5);
        // Pause LFSR, then load 0xFF = 8'b1111_1111
        // r_out = {1, 1, 1} = 3'b111
        en   = 0;
        load = 1;
        seed = 8'hFF;
        @(posedge clk);
        #1;
        check_value("r_out after load 0xFF (en=0)", 3'b111, r_out);
        load = 0;

        // Re-enable and verify it continues from the loaded value
        // 0xFF: fb = 1^1^1^1 = 0, next = 0xFE = 8'b1111_1110
        // r_out = {1, 1, 0} = 3'b110
        en = 1;
        @(posedge clk);
        #1;
        check_value("r_out 1 cycle after 0xFF", 3'b110, r_out);
        en = 0;
        $display("");

        // -------------------------------------------------
        // TEST 8: Enable takes priority over load
        //   When both en and load are high, en wins and
        //   the LFSR shifts instead of loading the seed.
        // -------------------------------------------------
        $display("[TEST 8] Enable Priority Over Load");
        reset_dut();
        // From reset state 0x01, assert both en and load
        // en wins: LFSR shifts, next = 0x02
        // r_out for 0x02 = {0, 0, 0} = 3'b000
        en   = 1;
        load = 1;
        seed = 8'hCA;
        @(posedge clk);
        #1;
        check_value("r_out with en+load (should shift, not load)", 3'b000, r_out);
        load = 0;
        en   = 0;
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
