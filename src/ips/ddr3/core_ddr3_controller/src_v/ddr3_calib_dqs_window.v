/*
   1. Writes a known 128-bit pattern once to a fixed DDR address
   2. For each DQS tap = 0..31:
   3. Programs IDELAY to that tap (via LD + INC pulses)
   4. Reads back and compares to the pattern (optionally multiple reads per tap)
   5. Records PASS/FAIL in a 32-bit bitmap
   6. After the sweep, it finds the longest contiguous PASS window
   7. Picks the midpoint of that window as best_tap
   8. Programs the PHY to best_tap, asserts cal_done_o, and exports the result
*/

`ifndef SYNTHESIS
`include "timescale.v"
`endif

module ddr3_calib_dqs_window #(
    // Set RDSEL/RDLAT to your known-good values
    parameter [3:0]  FIXED_RDSEL       = 4'd15,
    parameter [2:0]  FIXED_RDLAT       = 3'd5,

    // Sweep range
    parameter integer TAP_MIN          = 0,
    parameter integer TAP_MAX          = 31,

    // Where to write/read (must be 16B aligned for the 128b port)
    parameter [31:0]  CAL_ADDR         = 32'h1002_0000,

    // Repeat reads per tap (stability). 1 is fastest.
    parameter integer READ_REPEATS     = 2
)(
    input  wire        clk,
    input  wire        rst,

    // Your init_done_o (controller init complete)
    input  wire        ddr_init_done_i,

    // -------- PHY cfg port -> ddr3_dfi_phy --------
    output reg         cfg_valid_o,
    output reg [31:0]  cfg_data_o,

    // -------- DDR core inport (128b) --------
    output reg [15:0]  inport_wr_o,          // 16 byte strobes
    output reg         inport_rd_o,
    output reg [31:0]  inport_addr_o,
    output reg [127:0] inport_write_data_o,
    output reg [15:0]  inport_req_id_o,

    input  wire        inport_accept_i,
    input  wire        inport_ack_i,
    input  wire        inport_error_i,
    input  wire [127:0]inport_read_data_i,

    // -------- Results --------
    output reg         cal_done_o,
    output reg         cal_pass_o,
    output reg [5:0]   cal_best_tap_o,
    output reg [31:0]  cal_pass_bitmap_o,

    output wire [3:0]   state
);

    // Bitfields from your ddr3_dfi_phy.v
    localparam integer CFG_RDSEL_L   = 0;
    localparam integer CFG_RDSEL_H   = 3;
    localparam integer CFG_RDLAT_L   = 8;
    localparam integer CFG_RDLAT_H   = 10;
    localparam integer CFG_DQS_RST_L = 16;
    localparam integer CFG_DQS_RST_H = 17;
    localparam integer CFG_DQS_INC_L = 18;
    localparam integer CFG_DQS_INC_H = 19;

    // Known busy pattern (any non-trivial pattern is fine)
    wire [127:0] PATTERN = 128'h0123_4567_89AB_CDEF_FEDC_BA98_7654_3210;

    // Full line write
    localparam [15:0] FULL_STB = 16'hFFFF;

    // Build cfg word
    function [31:0] make_cfg;
        input [3:0] rdsel;
        input [2:0] rdlat;
        input [1:0] dqs_rst;
        input [1:0] dqs_inc;
        reg [31:0] x;
        begin
            x = 32'b0;
            x[CFG_RDSEL_H:CFG_RDSEL_L]   = rdsel;
            x[CFG_RDLAT_H:CFG_RDLAT_L]   = rdlat;
            x[CFG_DQS_RST_H:CFG_DQS_RST_L] = dqs_rst;
            x[CFG_DQS_INC_H:CFG_DQS_INC_L] = dqs_inc;
            make_cfg = x;
        end
    endfunction

    // FSM
    localparam ST_RESET        = 0;
    localparam ST_WAIT_INIT    = 1;
    localparam ST_PROG_FIXED   = 2;

    localparam ST_WRITE_SEND   = 3;
    localparam ST_WRITE_WAIT   = 4;

    localparam ST_TAP_RST      = 5;
    localparam ST_TAP_INC      = 6;

    localparam ST_READ_SEND    = 7;
    localparam ST_READ_WAIT    = 8;
    localparam ST_READ_CHECK   = 9;

    localparam ST_NEXT_TAP     = 10;
    localparam ST_ANALYZE      = 11;
    localparam ST_PROG_BEST    = 12;
    localparam ST_DONE         = 13;

    reg [3:0]  state_q;

    reg [15:0] req_id_q;

    // Sweep counters
    reg [5:0]  tap_q;
    reg [5:0]  inc_count_q;
    reg [3:0]  rep_q;

    // Pass bitmap for taps 0..31 (we’ll store at index tap_q)
    reg [31:0] pass_bm_q;

    // Analysis regs
    reg [5:0] best_start_q, best_len_q;
    reg [5:0] cur_start_q,  cur_len_q;
    reg [5:0] i_q;

    // Defaults each clock
    always @(posedge clk) begin
        if (rst) begin
            state_q           <= ST_RESET;
            cfg_valid_o       <= 1'b0;
            cfg_data_o        <= 32'b0;

            inport_wr_o       <= 16'h0000;
            inport_rd_o       <= 1'b0;
            inport_addr_o     <= 32'b0;
            inport_write_data_o <= 128'b0;
            inport_req_id_o   <= 16'b0;

            cal_done_o        <= 1'b0;
            cal_pass_o        <= 1'b0;
            cal_best_tap_o    <= 0;
            cal_pass_bitmap_o <= 32'b0;

            req_id_q          <= 16'h0001;

            tap_q             <= TAP_MIN[5:0];
            inc_count_q       <= 0;
            rep_q             <= 0;

            pass_bm_q         <= 32'b0;

            best_start_q      <= 0;
            best_len_q        <= 0;
            cur_start_q       <= 0;
            cur_len_q         <= 0;
            i_q               <= 0;
        end else begin
            // one-cycle defaults
            cfg_valid_o <= 1'b0;
            inport_wr_o <= 16'h0000;
            inport_rd_o <= 1'b0;

            case (state_q)

                ST_RESET: begin
                    cal_done_o        <= 1'b0;
                    cal_pass_o        <= 1'b0;
                    cal_best_tap_o    <= 0;
                    pass_bm_q         <= 32'b0;
                    tap_q             <= TAP_MIN[5:0];
                    state_q           <= ST_WAIT_INIT;
                end

                ST_WAIT_INIT: begin
                    if (ddr_init_done_i) begin
                        state_q <= ST_PROG_FIXED;
                    end
                end

                // Program fixed RDSEL/RDLAT
                ST_PROG_FIXED: begin
                    cfg_data_o  <= make_cfg(FIXED_RDSEL, FIXED_RDLAT, 2'b00, 2'b00);
                    cfg_valid_o <= 1'b1;
                    state_q     <= ST_WRITE_SEND;
                end

                // Write pattern once
                ST_WRITE_SEND: begin
                    inport_addr_o       <= CAL_ADDR;
                    inport_req_id_o     <= req_id_q;
                    inport_write_data_o <= PATTERN;
                    inport_wr_o         <= FULL_STB;

                    if (inport_accept_i) begin
`ifdef SYNTHESIS
                        inport_wr_o       <= 16'h0000;
`endif
                        req_id_q <= req_id_q + 1;
                        state_q  <= ST_WRITE_WAIT;
                    end
                end

                ST_WRITE_WAIT: begin
                    if (inport_ack_i) begin
                        // start sweep at TAP_MIN
                        tap_q       <= TAP_MIN[5:0];
                        pass_bm_q   <= 32'b0;
                        state_q     <= ST_TAP_RST;
                    end
                end

                // Reset DQS delay (LD baseline)
                ST_TAP_RST: begin
                    cfg_data_o  <= make_cfg(FIXED_RDSEL, FIXED_RDLAT, 2'b11, 2'b00); // reset both DQS lanes
                    cfg_valid_o <= 1'b1;
                    inc_count_q <= 0;
                    state_q     <= (tap_q == 0) ? ST_READ_SEND : ST_TAP_INC;
                end

                // INC DQS delay until inc_count_q == tap_q-1
                ST_TAP_INC: begin
                    cfg_data_o  <= make_cfg(FIXED_RDSEL, FIXED_RDLAT, 2'b00, 2'b11); // inc both DQS lanes
                    cfg_valid_o <= 1'b1;

                    if (inc_count_q == tap_q - 1) begin
                        // done positioning
                        rep_q   <= 0;
                        state_q <= ST_READ_SEND;
                    end else begin
                        inc_count_q <= inc_count_q + 1;
                    end
                end

                // Read pattern
                ST_READ_SEND: begin
                    inport_addr_o   <= CAL_ADDR;
                    inport_req_id_o <= req_id_q;
                    inport_rd_o     <= 1'b1;

                    if (inport_accept_i) begin
                        inport_rd_o         <= 1'b0;

                        req_id_q <= req_id_q + 1;
                        state_q  <= ST_READ_WAIT;
                    end
                end

                ST_READ_WAIT: begin
                    if (inport_ack_i) begin
                        state_q <= ST_READ_CHECK;
                    end
                end

                ST_READ_CHECK: begin
                    // Treat any error or mismatch as fail for this repeat
                    if (inport_error_i || (inport_read_data_i != PATTERN)) begin
                        // mark fail at this tap
                        if (tap_q <= 31)
                            pass_bm_q[tap_q[4:0]] <= 1'b0;
                        state_q <= ST_NEXT_TAP;
                    end else begin
                        // match
                        if (rep_q == READ_REPEATS-1) begin
                            if (tap_q <= 31)
                                pass_bm_q[tap_q[4:0]] <= 1'b1;
                            state_q <= ST_NEXT_TAP;
                        end else begin
                            rep_q   <= rep_q + 1;
                            state_q <= ST_READ_SEND; // another read for stability
                        end
                    end
                end

                ST_NEXT_TAP: begin
                    if (tap_q == TAP_MAX[5:0]) begin
                        // finished sweep
                        cal_pass_bitmap_o <= pass_bm_q;
                        // setup analysis
                        best_start_q <= 0;
                        best_len_q   <= 0;
                        cur_start_q  <= 0;
                        cur_len_q    <= 0;
                        i_q          <= 0;
                        state_q      <= ST_ANALYZE;
                    end else begin
                        tap_q   <= tap_q + 1;
                        state_q <= ST_TAP_RST;
                    end
                end

                // Find longest contiguous run of 1s in pass_bm_q[0..31]
                ST_ANALYZE: begin
                    if (i_q == 0) begin
                        // init
                        best_start_q <= 0;
                        best_len_q   <= 0;
                        cur_start_q  <= 0;
                        cur_len_q    <= 0;
                    end

                    if (pass_bm_q[i_q[4:0]]) begin
                        if (cur_len_q == 0)
                            cur_start_q <= i_q;
                        cur_len_q <= cur_len_q + 1;

                        // update best if needed
                        if ((cur_len_q + 1) > best_len_q) begin
                            best_len_q   <= (cur_len_q + 1);
                            best_start_q <= (cur_len_q == 0) ? i_q : cur_start_q;
                        end
                    end else begin
                        cur_len_q <= 0;
                    end

                    if (i_q == 31) begin
                        // Choose midpoint
                        if (best_len_q != 0) begin
                            cal_best_tap_o <= best_start_q + (best_len_q >> 1);
                            cal_pass_o     <= 1'b1;
                            state_q        <= ST_PROG_BEST;
                        end else begin
                            cal_best_tap_o <= 0;
                            cal_pass_o     <= 1'b0;
                            state_q        <= ST_DONE;
                        end
                    end else begin
                        i_q <= i_q + 1;
                    end
                end

                // Program best tap (reset then inc best_tap)
                ST_PROG_BEST: begin
                    // first do a reset
                    cfg_data_o  <= make_cfg(FIXED_RDSEL, FIXED_RDLAT, 2'b11, 2'b00);
                    cfg_valid_o <= 1'b1;
                    inc_count_q <= 0;
                    state_q     <= (cal_best_tap_o == 0) ? ST_DONE : ST_PROG_BEST + 1; // fallthrough trick
                end

/*
                // (implicit) state 13: increment up to best_tap
                13: begin
                    // inc step
                    cfg_data_o  <= make_cfg(FIXED_RDSEL, FIXED_RDLAT, 2'b00, 2'b11);
                    cfg_valid_o <= 1'b1;

                    if (inc_count_q == cal_best_tap_o - 1) begin
                        state_q <= ST_DONE;
                    end else begin
                        inc_count_q <= inc_count_q + 1;
                    end
                end
*/

                ST_DONE: begin
                    cal_done_o <= 1'b1;
                    cfg_valid_o <= 1'b0;
                    state_q    <= ST_DONE;
                end

                default: state_q <= ST_RESET;
            endcase
        end
    end
assign state = state_q;
endmodule //module ddr3_calib_dqs_window #(
