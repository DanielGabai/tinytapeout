`timescale 1ns / 1ps

module MODULE_NAME_testbench;

    // ═══════════════════════════════════════════════════════════
    // Parameters
    // ═══════════════════════════════════════════════════════════
    localparam CLK_PERIOD = 10;  // 100MHz clock (10ns period)

    // ═══════════════════════════════════════════════════════════
    // DUT Signals
    // ═══════════════════════════════════════════════════════════
    logic       clk;
    logic       rst_n;
    // Add your module's inputs/outputs here:
    // logic       enable;
    // logic [7:0] data_in;
    // logic [7:0] data_out;
    // logic       valid;

    // ═══════════════════════════════════════════════════════════
    // Testbench Variables
    // ═══════════════════════════════════════════════════════════
    integer test_count;
    integer pass_count;
    integer fail_count;

    // ═══════════════════════════════════════════════════════════
    // Device Under Test (DUT)
    // ═══════════════════════════════════════════════════════════
    MODULE_NAME uut (
        .clk   (clk),
        .rst_n (rst_n)
        // Connect your module's ports here
    );

    // ═══════════════════════════════════════════════════════════
    // Clock Generation
    // ═══════════════════════════════════════════════════════════
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ═══════════════════════════════════════════════════════════
    // Helper Tasks
    // ═══════════════════════════════════════════════════════════
    
    // Reset the DUT (synchronous reset)
    task reset_dut();
        begin
            @(posedge clk);
            rst_n = 0;
            repeat (3) @(posedge clk);
            rst_n = 1;
            @(posedge clk);
            $display("[%0t] Reset complete", $time);
        end
    endtask

    // Check expected vs actual value
    task check_value(
        input string signal_name,
        input logic [31:0] expected,
        input logic [31:0] actual
    );
        begin
            test_count++;
            if (actual === expected) begin
                pass_count++;
                $display("  ✓ PASS: %s = %0d (expected %0d)", signal_name, actual, expected);
            end else begin
                fail_count++;
                $display("  ✗ FAIL: %s = %0d (expected %0d)", signal_name, actual, expected);
            end
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
        $dumpfile("logs/MODULE_NAME_testbench.vcd");
        $dumpvars(0, MODULE_NAME_testbench);

        // Initialize
        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        // Initialize signals
        rst_n = 1;
        // Set your initial signal values here

        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  MODULE_NAME Testbench                            ║");
        $display("╚════════════════════════════════════════════════════╝\n");

        // ───────────────────────────────────────────────────────
        // TEST 1: Reset Verification
        // ───────────────────────────────────────────────────────
        $display("[TEST 1] Reset Verification");
        reset_dut();
        // Check reset state of your outputs here
        $display("");

        // ───────────────────────────────────────────────────────
        // TEST 2: Basic Functionality
        // ───────────────────────────────────────────────────────
        $display("[TEST 2] Basic Functionality");
        // Add your test logic here
        $display("");

        // ───────────────────────────────────────────────────────
        // TEST 3: Edge Cases
        // ───────────────────────────────────────────────────────
        $display("[TEST 3] Edge Cases");
        // Test boundary conditions
        $display("");

        // ───────────────────────────────────────────────────────
        // Final Summary
        // ───────────────────────────────────────────────────────
        $display("\n╔════════════════════════════════════════════════════╗");
        $display("║  Test Summary                                      ║");
        $display("╠════════════════════════════════════════════════════╣");
        $display("║  Total Tests: %3d                                  ║", test_count);
        $display("║  Passed:      %3d                                  ║", pass_count);
        $display("║  Failed:      %3d                                  ║", fail_count);
        $display("╠════════════════════════════════════════════════════╣");
        
        if (fail_count == 0) begin
            $display("║  Result:  ALL TESTS PASSED                       ║");
        end else begin
            $display("║  Result:  SOME TESTS FAILED                      ║");
        end
        
        $display("╚════════════════════════════════════════════════════╝\n");

        $finish;
    end

    // ═══════════════════════════════════════════════════════════
    // Optional: Timeout Watchdog
    // ═══════════════════════════════════════════════════════════
    initial begin
        #1000000;  // 1ms timeout
        $display("\n ERROR: Simulation timeout!");
        $finish;
    end

endmodule