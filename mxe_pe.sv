// ============================================================
// mxe_pe.sv
// Processing Element for Attention MXE
//
// Current use: M2 - QK^T
// - signed INT8 x INT8 multiply
// - signed INT32 accumulation
// - Q propagates west -> east
// - K propagates north -> south
// - output-stationary accumulator
//
// Operation:
//   acc <= acc + q_in * k_in
// ============================================================

import pkg::*;

module mxe_pe (
    input  logic clk,
    input  logic rst_n,//asynchronous active-low

    input  logic clear_acc,
    input  logic mac_enable,

    // Q path: west -> east
    input  data_t q_in,
    input  logic  q_valid_in,
    output data_t q_out,
    output logic  q_valid_out,

    // K path: north -> south
    input  data_t k_in,
    input  logic  k_valid_in,
    output data_t k_out,
    output logic  k_valid_out,

    // Output-stationary partial sum
    output acc_t acc_out
);

    product_t product;
    acc_t     product_ext;

    // Signed INT8 x INT8 -> INT16
    always_comb begin
//        product = $signed(q_in) * $signed(k_in);
    end

    // Sign-extend product to accumulator width
    always_comb begin
        product_ext = {
            {(ACC_W-PROD_W){product[PROD_W-1]}},
            product
        };
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_out       <= '0;
            q_valid_out <= 1'b0;
            k_out       <= '0;
            k_valid_out <= 1'b0;
            acc_out     <= '0;
        end
        else begin
            // Systolic forwarding
            q_out       <= q_in;
            q_valid_out <= q_valid_in;
            k_out       <= k_in;
            k_valid_out <= k_valid_in;

            // Output-stationary MAC
            if (clear_acc)
                acc_out <= '0;
            else if (mac_enable && q_valid_in && k_valid_in)
                acc_out <= acc_out + product_ext;
        end
    end
endmodule