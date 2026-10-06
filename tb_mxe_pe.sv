`timescale 1ns/1ps

import pkg::*;

module tb_mxe_pe;

    // ========================================================
    // DUT signals
    // ========================================================

    logic clk;
    logic rst_n;

    logic clear_acc;
    logic mac_enable;

    data_t q_in;
    logic  q_valid_in;
    data_t q_out;
    logic  q_valid_out;

    data_t k_in;
    logic  k_valid_in;
    data_t k_out;
    logic  k_valid_out;

    acc_t acc_out;

    // ========================================================
    // Testbench reference
    // ========================================================

    int signed ref_acc;
    int errors;
    int checks;

    // ========================================================
    // DUT
    // ========================================================

    mxe_pe dut (
        .clk         (clk),
        .rst_n       (rst_n),

        .clear_acc   (clear_acc),
        .mac_enable  (mac_enable),

        .q_in        (q_in),
        .q_valid_in  (q_valid_in),
        .q_out       (q_out),
        .q_valid_out (q_valid_out),

        .k_in        (k_in),
        .k_valid_in  (k_valid_in),
        .k_out       (k_out),
        .k_valid_out (k_valid_out),

        .acc_out     (acc_out)
    );

    // ========================================================
    // Clock: 100 MHz
    // ========================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ========================================================
    // Drive one PE cycle and check result
    //
    // Inputs are applied on negedge so they are stable before
    // the DUT samples them on the next posedge.
    // ========================================================

    task automatic drive_and_check (
        input int signed q_value,
        input int signed k_value,
        input logic      q_valid,
        input logic      k_valid,
        input logic      mac_en,
        input logic      clr,
        input string     test_name
    );

        int signed expected_product;

        begin
            @(negedge clk);

            q_in       = data_t'(q_value);
            k_in       = data_t'(k_value);

            q_valid_in = q_valid;
            k_valid_in = k_valid;

            mac_enable = mac_en;
            clear_acc  = clr;

            // Reference model
            expected_product = q_value * k_value;

            if (clr)
                ref_acc = 0;
            else if (mac_en && q_valid && k_valid)
                ref_acc = ref_acc + expected_product;

            @(posedge clk);
            #1;

            // Q forwarding
            checks++;
            if (q_out !== data_t'(q_value)) begin
                errors++;
                $error("[%s] q_out mismatch: expected=%0d actual=%0d",
                       test_name, q_value, $signed(q_out));
            end

            // K forwarding
            checks++;
            if (k_out !== data_t'(k_value)) begin
                errors++;
                $error("[%s] k_out mismatch: expected=%0d actual=%0d",
                       test_name, k_value, $signed(k_out));
            end

            // Q valid forwarding
            checks++;
            if (q_valid_out !== q_valid) begin
                errors++;
                $error("[%s] q_valid_out mismatch: expected=%0b actual=%0b",
                       test_name, q_valid, q_valid_out);
            end

            // K valid forwarding
            checks++;
            if (k_valid_out !== k_valid) begin
                errors++;
                $error("[%s] k_valid_out mismatch: expected=%0b actual=%0b",
                       test_name, k_valid, k_valid_out);
            end

            // Accumulator
            checks++;
            if (acc_out !== acc_t'(ref_acc)) begin
                errors++;
                $error("[%s] ACC mismatch: expected=%0d actual=%0d",
                       test_name, ref_acc, $signed(acc_out));
            end
        end

    endtask

    // ========================================================
    // Clear accumulator
    // ========================================================

    task automatic clear_pe;
        begin
            drive_and_check(
                0,          // q
                0,          // k
                1'b0,       // q_valid
                1'b0,       // k_valid
                1'b0,       // mac_enable
                1'b1,       // clear_acc
                "CLEAR"
            );
        end
    endtask

    // ========================================================
    // Main test
    // ========================================================

    initial begin

        int i;
        int signed rand_q;
        int signed rand_k;
        logic rand_q_valid;
        logic rand_k_valid;
        logic rand_mac;
        logic rand_clear;

        errors  = 0;
        checks  = 0;
        ref_acc = 0;

        rst_n       = 1'b0;
        clear_acc   = 1'b0;
        mac_enable  = 1'b0;

        q_in        = '0;
        q_valid_in  = 1'b0;

        k_in        = '0;
        k_valid_in  = 1'b0;

        // ====================================================
        // TEST 0: Reset
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 0: Reset");
        $display("--------------------------------------------------");

        repeat (2) @(posedge clk);
        #1;

        if (q_out !== '0 ||
            k_out !== '0 ||
            q_valid_out !== 1'b0 ||
            k_valid_out !== 1'b0 ||
            acc_out !== '0) begin

            errors++;
            $error("Reset test FAILED");

        end
        else begin
            $display("Reset test PASS");
        end

        @(negedge clk);
        rst_n = 1'b1;

        // ====================================================
        // TEST 1: Forwarding only
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 1: Q/K forwarding");
        $display("--------------------------------------------------");

        drive_and_check(
            25, -13,
            1'b1, 1'b1,
            1'b0,
            1'b0,
            "FORWARD"
        );

        // acc must remain zero
        if ($signed(acc_out) != 0) begin
            errors++;
            $error("Accumulator changed while mac_enable=0");
        end

        // ====================================================
        // TEST 2: 127 x 127
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 2: +127 x +127");
        $display("--------------------------------------------------");

        clear_pe();

        drive_and_check(
            127, 127,
            1'b1, 1'b1,
            1'b1,
            1'b0,
            "127x127"
        );

        // expected = 16129

        // ====================================================
        // TEST 3: -128 x 127
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 3: -128 x +127");
        $display("--------------------------------------------------");

        clear_pe();

        drive_and_check(
            -128, 127,
            1'b1, 1'b1,
            1'b1,
            1'b0,
            "-128x127"
        );

        // expected = -16256

        // ====================================================
        // TEST 4: -128 x -128
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 4: -128 x -128");
        $display("--------------------------------------------------");

        clear_pe();

        drive_and_check(
            -128, -128,
            1'b1, 1'b1,
            1'b1,
            1'b0,
            "-128x-128"
        );

        // expected = 16384

        // ====================================================
        // TEST 5: Sequential MAC
        //
        // Q = [2, -1, 3, 4]
        // K = [5,  2,-2, 1]
        //
        // result:
        // 2*5 + (-1)*2 + 3*(-2) + 4*1
        // = 6
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 5: Sequential MAC");
        $display("--------------------------------------------------");

        clear_pe();

        drive_and_check( 2,  5, 1, 1, 1, 0, "MAC_0");
        drive_and_check(-1,  2, 1, 1, 1, 0, "MAC_1");
        drive_and_check( 3, -2, 1, 1, 1, 0, "MAC_2");
        drive_and_check( 4,  1, 1, 1, 1, 0, "MAC_3");

        if ($signed(acc_out) != 6) begin
            errors++;
            $error("Sequential MAC expected 6, actual=%0d",
                   $signed(acc_out));
        end
        else begin
            $display("Sequential MAC result = 6 PASS");
        end

        // ====================================================
        // TEST 6: mac_enable gating
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 6: mac_enable gating");
        $display("--------------------------------------------------");

        clear_pe();

        drive_and_check(
            10, 10,
            1'b1, 1'b1,
            1'b0,              // MAC disabled
            1'b0,
            "MAC_DISABLED"
        );

        drive_and_check(
            10, 10,
            1'b1, 1'b1,
            1'b1,
            1'b0,
            "MAC_ENABLED"
        );

        // Only one multiply must be accumulated -> 100

        if ($signed(acc_out) != 100) begin
            errors++;
            $error("mac_enable test expected 100, actual=%0d",
                   $signed(acc_out));
        end

        // ====================================================
        // TEST 7: q_valid gating
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 7: q_valid gating");
        $display("--------------------------------------------------");

        clear_pe();

        drive_and_check(
            20, 5,
            1'b0,              // Q invalid
            1'b1,
            1'b1,
            1'b0,
            "Q_INVALID"
        );

        if ($signed(acc_out) != 0) begin
            errors++;
            $error("Accumulator changed with q_valid=0");
        end

        // ====================================================
        // TEST 8: k_valid gating
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 8: k_valid gating");
        $display("--------------------------------------------------");

        drive_and_check(
            20, 5,
            1'b1,
            1'b0,              // K invalid
            1'b1,
            1'b0,
            "K_INVALID"
        );

        if ($signed(acc_out) != 0) begin
            errors++;
            $error("Accumulator changed with k_valid=0");
        end

        // Both valid -> MAC
        drive_and_check(
            20, 5,
            1'b1,
            1'b1,
            1'b1,
            1'b0,
            "BOTH_VALID"
        );

        if ($signed(acc_out) != 100) begin
            errors++;
            $error("Valid gating expected 100, actual=%0d",
                   $signed(acc_out));
        end

        // ====================================================
        // TEST 9: clear_acc priority
        //
        // Even if valid and mac_enable are high,
        // clear_acc must force ACC to zero.
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 9: clear_acc priority");
        $display("--------------------------------------------------");

        drive_and_check(
            127, 127,
            1'b1,
            1'b1,
            1'b1,
            1'b1,              // clear has priority
            "CLEAR_PRIORITY"
        );

        if ($signed(acc_out) != 0) begin
            errors++;
            $error("clear_acc did not have priority");
        end

        // ====================================================
        // TEST 10: Random regression
        // ====================================================

        $display("--------------------------------------------------");
        $display("TEST 10: Random regression");
        $display("--------------------------------------------------");

        clear_pe();

        // Fixed seed -> reproducible test
        i = $urandom(32'h5A17_2026);

        for (i = 0; i < 100; i++) begin

            rand_q = $urandom_range(255, 0) - 128;
            rand_k = $urandom_range(255, 0) - 128;

            rand_q_valid = $urandom_range(1, 0);
            rand_k_valid = $urandom_range(1, 0);
            rand_mac     = $urandom_range(1, 0);

            // Occasionally test clear priority
            rand_clear = ((i % 23) == 0);

            drive_and_check(
                rand_q,
                rand_k,
                rand_q_valid,
                rand_k_valid,
                rand_mac,
                rand_clear,
                "RANDOM"
            );
        end

        // ====================================================
        // Final report
        // ====================================================

        @(negedge clk);

        q_valid_in = 1'b0;
        k_valid_in = 1'b0;
        mac_enable = 1'b0;
        clear_acc  = 1'b0;

        $display("");
        $display("==================================================");
        $display("         MXE PE VERIFICATION SUMMARY");
        $display("==================================================");
        $display("Checks : %0d", checks);
        $display("Errors : %0d", errors);

        if (errors == 0) begin
            $display("RESULT : PASS");
            $display("MXE PE is functionally correct.");
        end
        else begin
            $display("RESULT : FAIL");
            $display("MXE PE contains verification errors.");
        end

        $display("==================================================");
        $display("");

        if (errors != 0)
            $fatal(1, "tb_mxe_pe FAILED with %0d errors", errors);

        $finish;

    end

endmodule