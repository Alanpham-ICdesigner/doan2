// ============================================================
// attention_pkg.sv
// Common definitions for Attention Core
//
// Current stage: M2 - MXE Processing Element
// ============================================================
`ifndef PKG_SV
`define PKG_SV
package pkg;

    // ========================================================
    // PE NUMERIC PARAMETERS
    // ========================================================

    // Q / K input width
    localparam int DATA_W = 8;

    // INT8 x INT8 -> INT16 
    localparam int PROD_W = 2 * DATA_W;

    // Accumulator width
    localparam int ACC_W = 32;


    // ========================================================
    // PE DATA TYPES
    // ========================================================

    // Q / K datatype
    typedef logic signed [DATA_W-1:0] data_t; //INT8

    // Multiplication result datatype
    typedef logic signed [PROD_W-1:0] product_t; //int16

    // Accumulator datatype
    typedef logic signed [ACC_W-1:0] acc_t; //int32

endpackage
`endif