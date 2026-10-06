// mxe_systolic_array.sv
// Output-stationary systolic array for Attention MXE
//
// Current use: M2 - QK^T
// - BR x BC Processing Elements
// - Q propagates west -> east
// - K propagates north -> south
// - each PE keeps one INT32 output accumulator
//
// Input streams must already be skewed by the feeder.
// ============================================================

import pkg::*;

module mxe_systolic_array #(
    parameter int PE_ROWS = 2,
    parameter int PE_COLS = 2
)(
    input  logic clk,
    input  logic rst_n,

    input  logic clear_acc,
    input  logic mac_enable,

    // Q enters from west, one stream per PE row
    input  data_t q_west       [0:PE_ROWS-1],
    input  logic  q_valid_west [0:PE_ROWS-1],

    // K enters from north, one stream per PE column
    input  data_t k_north       [0:PE_COLS-1],
    input  logic  k_valid_north [0:PE_COLS-1],

    // Output-stationary accumulator matrix
    output acc_t acc_matrix [0:PE_ROWS-1][0:PE_COLS-1],

    // Boundary outputs, for debug 
    output data_t q_east       [0:PE_ROWS-1],
    output logic  q_valid_east [0:PE_ROWS-1],

    output data_t k_south       [0:PE_COLS-1],
    output logic  k_valid_south [0:PE_COLS-1]
);

    // Q pipeline:
    // q_pipe[r][0] enters from west.
    // q_pipe[r][c+1] is output of PE[r][c].
    data_t q_pipe       [0:PE_ROWS-1][0:PE_COLS];
    logic  q_valid_pipe [0:PE_ROWS-1][0:PE_COLS];

    // K pipeline:
    // k_pipe[0][c] enters from north.
    // k_pipe[r+1][c] is output of PE[r][c].
    data_t k_pipe       [0:PE_ROWS][0:PE_COLS-1];
    logic  k_valid_pipe [0:PE_ROWS][0:PE_COLS-1];

    // West boundary: inject Q streams
    generate
        for (genvar r = 0; r < PE_ROWS; r++) begin : gen_q_input
            assign q_pipe[r][0]       = q_west[r];
            assign q_valid_pipe[r][0] = q_valid_west[r];
        end
    endgenerate

    // North boundary: inject K streams
    generate
        for (genvar c = 0; c < PE_COLS; c++) begin : gen_k_input
            assign k_pipe[0][c]       = k_north[c];
            assign k_valid_pipe[0][c] = k_valid_north[c];
        end
    endgenerate

    // PE array
    generate
        for (genvar r = 0; r < PE_ROWS; r++) begin : gen_pe_row
            for (genvar c = 0; c < PE_COLS; c++) begin : gen_pe_col

                mxe_pe u_pe (
                    .clk         (clk),
                    .rst_n       (rst_n),

                    .clear_acc   (clear_acc),
                    .mac_enable  (mac_enable),

                    // Q: west -> east
                    .q_in        (q_pipe[r][c]),
                    .q_valid_in  (q_valid_pipe[r][c]),
                    .q_out       (q_pipe[r][c+1]),
                    .q_valid_out (q_valid_pipe[r][c+1]),

                    // K: north -> south
                    .k_in        (k_pipe[r][c]),
                    .k_valid_in  (k_valid_pipe[r][c]),
                    .k_out       (k_pipe[r+1][c]),
                    .k_valid_out (k_valid_pipe[r+1][c]),

                    // Local output-stationary accumulator
                    .acc_out     (acc_matrix[r][c])
                );

            end
        end
    endgenerate

    // East boundary
    generate
        for (genvar r = 0; r < PE_ROWS; r++) begin : gen_q_output
            assign q_east[r]       = q_pipe[r][PE_COLS];
            assign q_valid_east[r] = q_valid_pipe[r][PE_COLS];
        end
    endgenerate

    // South boundary
    generate
        for (genvar c = 0; c < PE_COLS; c++) begin : gen_k_output
            assign k_south[c]       = k_pipe[PE_ROWS][c];
            assign k_valid_south[c] = k_valid_pipe[PE_ROWS][c];
        end
    endgenerate

endmodule
