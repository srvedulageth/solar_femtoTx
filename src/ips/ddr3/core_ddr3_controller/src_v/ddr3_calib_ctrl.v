`ifndef SYNTHESIS
`include "timescale.v"
`endif

module ddr3_calib_ctrl #(
    parameter integer DQS_TAP_DELAY_INIT = 15,     // must match PHY param
    parameter integer RDLAT_DEFAULT      = 5,      // your working value
    parameter [31:0]  CAL_ADDR           = 32'h1002_0000, // 16B-aligned
    parameter integer REPEAT_READS       = 2       // stability check
)(
    input  wire        clk,
    input  wire        rst,

    // Asserted when DDR init sequence is complete (your init_done_o)
    input  wire        ddr_init_done_i,

    // ---------------- PHY cfg port (to ddr3_dfi_phy cfg_valid_i/cfg_i) -----------
    output reg         cfg_valid_o,
    output reg [31:0]  cfg_data_o,

    // ---------------- DDR core "inport" application interface -------------------
    output reg [15:0]  inport_wr_o,          // byte strobes (16 bytes)
    output reg         inport_rd_o,
    output reg [31:0]  inport_addr_o,        // byte address
    output reg [127:0] inport_write_data_o,
    output reg [15:0]  inport_req_id_o,

    input  wire        inport_accept_i,
    input  wire        inport_ack_i,
    input  wire        inport_error_i,
    input  wire [15:0] inport_resp_id_i,
    input  wire [127:0]inport_read_data_i,

    // ---------------- Status -----------------------------------------------------
    output reg         cal_done_o,
    output reg         cal_pass_o,
    output reg [3:0]   cal_rdsel_o
);

    // Bitfields from ddr3_dfi_phy.v
    localparam [3:0]  CFG_RDSEL_L       = 0;
    localparam [3:0]  CFG_RDSEL_H       = 3;
    localparam [10:0] CFG_RDLAT_L       = 8;
    localparam [10:0] CFG_RDLAT_H       = 10;
    localparam [17:0] CFG_DQS_RST_L     = 16;
    localparam [17:0] CFG_DQS_RST_H     = 17;
    localparam [19:0] CFG_DQS_INC_L     = 18;
    localparam [19:0] CFG_DQS_INC_H     = 19;
    localparam [21:0] CFG_DQ_RST_L      = 20;
    localparam [21:0] CFG_DQ_RST_H      = 21;
    localparam [23:0] CFG_DQ_INC_L      = 22;
    localparam [23:0] CFG_DQ_INC_H      = 23;

    // Known pattern (any “busy” pattern is good)
    wire [127:0] PATTERN = 128'h0123_4567_89AB_CDEF_FEDC_BA98_7654_3210;

    // Simple request id
    reg [15:0] req_id_q;

    // Sweep
    reg [3:0]  rdsel_q;
    reg [5:0]  tap_count_q;      // enough for 0..63 if you want later
    reg [3:0]  repeat_q;

    // FSM
    localparam ST_RESET      = 0;
    localparam ST_WAIT_INIT  = 1;
    localparam ST_SET_RDSEL  = 2;
    localparam ST_DQS_LD     = 3;
    localparam ST_DQS_INC    = 4;
    localparam ST_WR_SEND    = 5;
    localparam ST_WR_WAIT    = 6;
    localparam ST_RD_SEND    = 7;
    localparam ST_RD_WAIT    = 8;
    localparam ST_CHECK      = 9;
    localparam ST_NEXT       = 10;
    localparam ST_DONE       = 11;

    reg [3:0] state_q;

    // Build cfg word helper
    function [31:0] make_cfg;
        input [3:0]  rdsel;
        input [2:0]  rdlat;
        input [1:0]  dqs_rst;
        input [1:0]  dqs_inc;
        input [1:0]  dq_rst;
        input [1:0]  dq_inc;
        reg [31:0] x;
        begin
            x = 32'b0;
            x[CFG_RDSEL_H:CFG_RDSEL_L]   = rdsel;
            x[CFG_RDLAT_H:CFG_RDLAT_L]   = rdlat;
            x[CFG_DQS_RST_H:CFG_DQS_RST_L] = dqs_rst;
            x[CFG_DQS_INC_H:CFG_DQS_INC_L] = dqs_inc;
            x[CFG_DQ_RST_H:CFG_DQ_RST_L] = dq_rst;
            x[CFG_DQ_INC_H:CFG_DQ_INC_L] = dq_inc;
            make_cfg = x;
        end
    endfunction

    // Default strobes: full 16B line write
    localparam [15:0] FULL_STB = 16'hFFFF;

    always @(posedge clk) begin
        if (rst) begin
            state_q            <= ST_RESET;
            cfg_valid_o        <= 1'b0;
            cfg_data_o         <= 32'b0;

            inport_wr_o        <= 16'h0000;
            inport_rd_o        <= 1'b0;
            inport_addr_o      <= 32'b0;
            inport_write_data_o<= 128'b0;
            inport_req_id_o    <= 16'b0;

            cal_done_o         <= 1'b0;
            cal_pass_o         <= 1'b0;
            cal_rdsel_o        <= 4'h0;

            req_id_q           <= 16'h0001;
            rdsel_q            <= 4'h0;
            tap_count_q        <= 0;
            repeat_q           <= 0;
        end else begin
            // defaults
            cfg_valid_o   <= 1'b0;
            inport_wr_o   <= 16'h0000;
            inport_rd_o   <= 1'b0;

            case (state_q)
                ST_RESET: begin
                    cal_done_o <= 1'b0;
                    cal_pass_o <= 1'b0;
                    rdsel_q    <= 4'h0;
                    repeat_q   <= 0;
                    state_q    <= ST_WAIT_INIT;
                end

                ST_WAIT_INIT: begin
                    if (ddr_init_done_i) begin
                        state_q <= ST_SET_RDSEL;
                    end
                end

                // Program RDSEL/RDLAT (no delay moves yet)
                ST_SET_RDSEL: begin
                    cfg_data_o  <= make_cfg(rdsel_q, RDLAT_DEFAULT[2:0],
                                            2'b00, 2'b00, 2'b00, 2'b00);
                    cfg_valid_o <= 1'b1;
                    // Next: load DQS delay baseline
                    tap_count_q <= 0;
                    state_q     <= ST_DQS_LD;
                end

                // LD the IDELAY to DQS_TAP_DELAY_INIT (PHY uses IDELAY_VALUE + LD)
                ST_DQS_LD: begin
                    cfg_data_o  <= make_cfg(rdsel_q, RDLAT_DEFAULT[2:0],
                                            2'b11, 2'b00, 2'b00, 2'b00); // reset both DQS lanes
                    cfg_valid_o <= 1'b1;
                    tap_count_q <= 0;
                    state_q     <= (DQS_TAP_DELAY_INIT == 0) ? ST_WR_SEND : ST_DQS_INC;
                end

                // Increment DQS delay DQS_TAP_DELAY_INIT times (optional, keeps you aligned w/ your param)
                ST_DQS_INC: begin
                    cfg_data_o  <= make_cfg(rdsel_q, RDLAT_DEFAULT[2:0],
                                            2'b00, 2'b11, 2'b00, 2'b00); // inc both DQS lanes
                    cfg_valid_o <= 1'b1;

                    if (tap_count_q == DQS_TAP_DELAY_INIT-1) begin
                        state_q <= ST_WR_SEND;
                    end
                    tap_count_q <= tap_count_q + 1;
                end

                // WRITE known pattern
                ST_WR_SEND: begin
                    inport_addr_o       <= CAL_ADDR;
                    inport_req_id_o     <= req_id_q;
                    inport_write_data_o <= PATTERN;
                    inport_wr_o         <= FULL_STB;

                    if (inport_accept_i) begin
                        req_id_q <= req_id_q + 1;
                        state_q  <= ST_WR_WAIT;
                    end
                end

                ST_WR_WAIT: begin
                    if (inport_ack_i) begin
                        // proceed to read
                        state_q <= ST_RD_SEND;
                    end
                end

                // READ back
                ST_RD_SEND: begin
                    inport_addr_o   <= CAL_ADDR;
                    inport_req_id_o <= req_id_q;
                    inport_rd_o     <= 1'b1;

                    if (inport_accept_i) begin
                        req_id_q <= req_id_q + 1;
                        state_q  <= ST_RD_WAIT;
                    end
                end

                ST_RD_WAIT: begin
                    if (inport_ack_i) begin
                        state_q <= ST_CHECK;
                    end
                end

                ST_CHECK: begin
                    if (inport_error_i) begin
                        // treat as fail
                        repeat_q <= 0;
                        state_q  <= ST_NEXT;
                    end else if (inport_read_data_i == PATTERN) begin
                        if (repeat_q == REPEAT_READS-1) begin
                            cal_pass_o  <= 1'b1;
                            cal_done_o  <= 1'b1;
                            cal_rdsel_o <= rdsel_q;
                            state_q     <= ST_DONE;
                        end else begin
                            repeat_q <= repeat_q + 1;
                            state_q  <= ST_RD_SEND; // another read for stability
                        end
                    end else begin
                        repeat_q <= 0;
                        state_q  <= ST_NEXT;
                    end
                end

                ST_NEXT: begin
                    if (rdsel_q == 4'hF) begin
                        cal_pass_o <= 1'b0;
                        cal_done_o <= 1'b1;
                        state_q    <= ST_DONE;
                    end else begin
                        rdsel_q  <= rdsel_q + 1;
                        repeat_q <= 0;
                        state_q  <= ST_SET_RDSEL;
                    end
                end

                ST_DONE: begin
                    // hold results
                    state_q <= ST_DONE;
                end

                default: state_q <= ST_RESET;
            endcase
        end
    end

endmodule //ddr3_calib_ctrl #(
