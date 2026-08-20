//
// (C)2016-2024 Revanth Kamaraj (krevanth)
//
// Wishbone merger for ZAP I-cache and D-cache.
//
// Changes/fixes:
//
// 1. Current owner is registered.
// 2. ACK/ERR are routed ONLY to the current registered owner.
// 3. ERR is NOT converted into ACK.
// 4. D-cache request is remembered while I-cache owns the bus.
// 5. I-cache request is remembered while D-cache owns the bus.
// 6. A full GAP cycle with CYC=0/STB=0 is inserted when ownership changes.
// 7. Once DATA has been promised after CODE, CODE cannot steal the bus
//    again during the GAP cycle.
// 8. For ONLY_CORE=0, common Wishbone outputs remain REGISTERED,
//    preserving the original ZAP NXT-port timing.
//

`ifndef SYNTHESIS
`include "timescale.v"
`endif

module zap_wb_merger #(
    //
    // ONLY_CORE = 0:
    //      Inputs come from cache NXT ports.
    //      Common Wishbone outputs are registered.
    //
    // ONLY_CORE = 1:
    //      Inputs are already registered CPU ports.
    //      Common Wishbone outputs are combinational.
    //
    parameter logic ONLY_CORE = 1'b0
)
(
    // ------------------------------------------------------------
    // Clock / Reset
    // ------------------------------------------------------------

    input  logic        i_clk,
    input  logic        i_reset,

    // ------------------------------------------------------------
    // I-cache Wishbone
    // ------------------------------------------------------------

    input  logic        i_c_wb_stb,
    input  logic        i_c_wb_cyc,
    input  logic        i_c_wb_wen,
    input  logic [3:0]  i_c_wb_sel,
    input  logic [31:0] i_c_wb_dat,
    input  logic [31:0] i_c_wb_adr,
    input  logic [2:0]  i_c_wb_cti,

    output logic        o_c_wb_ack,
    output logic        o_c_wb_err,

    // ------------------------------------------------------------
    // D-cache Wishbone
    // ------------------------------------------------------------

    input  logic        i_d_wb_stb,
    input  logic        i_d_wb_cyc,
    input  logic        i_d_wb_wen,
    input  logic [3:0]  i_d_wb_sel,
    input  logic [31:0] i_d_wb_dat,
    input  logic [31:0] i_d_wb_adr,
    input  logic [2:0]  i_d_wb_cti,

    output logic        o_d_wb_ack,
    output logic        o_d_wb_err,

    // ------------------------------------------------------------
    // Shared Wishbone
    // ------------------------------------------------------------

    output logic        o_wb_cyc,
    output logic        o_wb_stb,
    output logic        o_wb_wen,
    output logic [3:0]  o_wb_sel,
    output logic [31:0] o_wb_dat,
    output logic [31:0] o_wb_adr,
    output logic [2:0]  o_wb_cti,

    input  logic        i_wb_ack,
    input  logic        i_wb_err
);

    `include "zap_defines.svh"
    `include "zap_localparams.svh"

    // ============================================================
    // Arbitration state
    // ============================================================

    typedef enum logic [1:0]
    {
        IDLE = 2'b00,
        CODE = 2'b01,
        DATA = 2'b10,
        GAP  = 2'b11
    } state_t;

    state_t state_ff;
    state_t state_nxt;

    // ============================================================
    // Pending request tracking
    // ============================================================

    logic data_pending_ff;
    logic code_pending_ff;

    //
    // During GAP, remember which side was explicitly promised
    // the bus.
    //
    // 1 = DATA gets bus after GAP
    // 0 = CODE gets bus after GAP
    //
    logic gap_to_data_ff;
    logic gap_to_data_nxt;

    // ============================================================
    // Request detection
    // ============================================================

    logic code_req;
    logic data_req;

    assign code_req = i_c_wb_cyc && i_c_wb_stb;
    assign data_req = i_d_wb_cyc && i_d_wb_stb;

    // ============================================================
    // Wishbone termination
    // ============================================================

    logic wb_term;
    logic wb_eob;

    //
    // IMPORTANT:
    //
    // Do NOT qualify this with o_wb_cyc/o_wb_stb.
    //
    // In your system i_wb_ack becomes asserted on the falling edge,
    // and o_wb_cyc may be changing around the same time.
    //
    assign wb_term = i_wb_ack || i_wb_err;

    //
    // Only switch owners at end-of-burst.
    //
    assign wb_eob =
            wb_term &&
            (o_wb_cti == CTI_EOB);

    // ============================================================
    // Remember requests waiting behind current owner
    // ============================================================

    always_ff @(posedge i_clk)
    begin
        if (i_reset)
        begin
            data_pending_ff <= 1'b0;
            code_pending_ff <= 1'b0;
        end
        else
        begin
            // ----------------------------------------------------
            // DATA waiting while CODE currently owns bus
            // ----------------------------------------------------

            if ((state_ff == CODE) && data_req)
                data_pending_ff <= 1'b1;

            //
            // Once DATA actually becomes owner, its pending
            // request has been granted.
            //
            if (state_ff == DATA)
                data_pending_ff <= 1'b0;


            // ----------------------------------------------------
            // CODE waiting while DATA currently owns bus
            // ----------------------------------------------------

            if ((state_ff == DATA) && code_req)
                code_pending_ff <= 1'b1;

            //
            // Once CODE actually becomes owner, clear it.
            //
            if (state_ff == CODE)
                code_pending_ff <= 1'b0;
        end
    end

    // ============================================================
    // Arbitration FSM
    // ============================================================

    always_comb
    begin
        state_nxt       = state_ff;
        gap_to_data_nxt = gap_to_data_ff;

        case (state_ff)

        // ========================================================
        // IDLE
        //
        // Initial arbitration gives I-cache priority.
        // ========================================================

        IDLE:
        begin
            if (code_req)
            begin
                state_nxt = CODE;
            end
            else if (data_req)
            begin
                state_nxt = DATA;
            end
        end


        // ========================================================
        // CODE owns Wishbone
        // ========================================================

        CODE:
        begin
            //
            // Current CODE transaction/burst completed.
            //
            if (wb_eob)
            begin
                //
                // DATA was already waiting.
                //
                // IMPORTANT:
                // Give DATA next turn even if CODE has already
                // asserted another request.
                //
                if (data_pending_ff || data_req)
                begin
                    state_nxt       = GAP;
                    gap_to_data_nxt = 1'b1;
                end

                //
                // Nobody waiting on DATA side.
                // CODE may continue.
                //
                else if (code_req)
                begin
                    state_nxt = CODE;
                end

                else
                begin
                    state_nxt = IDLE;
                end
            end

            //
            // CODE request disappeared without an ACK.
            //
            // Normally Wishbone master should hold CYC/STB until
            // termination, but handle this safely.
            //
            else if (!code_req)
            begin
                if (data_pending_ff || data_req)
                begin
                    state_nxt       = GAP;
                    gap_to_data_nxt = 1'b1;
                end
                else
                begin
                    state_nxt = IDLE;
                end
            end
        end


        // ========================================================
        // DATA owns Wishbone
        // ========================================================

        DATA:
        begin
            //
            // Current DATA transaction/burst completed.
            //
            if (wb_eob)
            begin
                //
                // CODE waiting gets next turn.
                //
                if (code_pending_ff || code_req)
                begin
                    state_nxt       = GAP;
                    gap_to_data_nxt = 1'b0;
                end

                //
                // No CODE waiting; DATA may continue.
                //
                else if (data_req)
                begin
                    state_nxt = DATA;
                end

                else
                begin
                    state_nxt = IDLE;
                end
            end

            //
            // DATA request disappeared without termination.
            //
            else if (!data_req)
            begin
                if (code_pending_ff || code_req)
                begin
                    state_nxt       = GAP;
                    gap_to_data_nxt = 1'b0;
                end
                else
                begin
                    state_nxt = IDLE;
                end
            end
        end


        // ========================================================
        // Mandatory dead bus cycle
        //
        // CYC/STB are forced low.
        //
        // VERY IMPORTANT:
        // Do not re-arbitrate here with CODE priority.
        //
        // The owner was already selected before entering GAP.
        // ========================================================

        GAP:
        begin
            if (gap_to_data_ff)
            begin
                //
                // DATA was promised this bus turn.
                //
                if (data_req || data_pending_ff)
                begin
                    state_nxt = DATA;
                end
                else if (code_req || code_pending_ff)
                begin
                    //
                    // DATA vanished while waiting.
                    //
                    state_nxt = CODE;
                end
                else
                begin
                    state_nxt = IDLE;
                end
            end
            else
            begin
                //
                // CODE was promised this bus turn.
                //
                if (code_req || code_pending_ff)
                begin
                    state_nxt = CODE;
                end
                else if (data_req || data_pending_ff)
                begin
                    state_nxt = DATA;
                end
                else
                begin
                    state_nxt = IDLE;
                end
            end
        end


        default:
        begin
            state_nxt       = IDLE;
            gap_to_data_nxt = 1'b0;
        end

        endcase
    end

    // ============================================================
    // Registered arbiter state
    // ============================================================

    always_ff @(posedge i_clk)
    begin
        if (i_reset)
        begin
            state_ff       <= IDLE;
            gap_to_data_ff <= 1'b0;
        end
        else
        begin
            state_ff       <= state_nxt;
            gap_to_data_ff <= gap_to_data_nxt;
        end
    end

    // ============================================================
    // ACK / ERR routing
    //
    // RESPONSE ALWAYS BELONGS TO CURRENT REGISTERED OWNER.
    //
    // NEVER use state_nxt here.
    //
    // NEVER gate ACK with o_wb_cyc.
    //
    // NEVER convert ERR into ACK.
    // ============================================================

    always_comb
    begin
        o_c_wb_ack = 1'b0;
        o_c_wb_err = 1'b0;

        o_d_wb_ack = 1'b0;
        o_d_wb_err = 1'b0;

        case (state_ff)

        CODE:
        begin
            o_c_wb_ack = i_wb_ack;
            o_c_wb_err = i_wb_err;
        end

        DATA:
        begin
            o_d_wb_ack = i_wb_ack;
            o_d_wb_err = i_wb_err;
        end

        default:
        begin
            //
            // IDLE / GAP:
            // no master accepts an ACK.
            //
        end

        endcase
    end

    // ============================================================
    // Wishbone common output generation
    // ============================================================

    generate

        // ========================================================
        // Cache configuration
        //
        // Original ZAP cache NXT ports -> registered WB outputs.
        // ========================================================

        if (!ONLY_CORE)
        begin : g_cache_mode

            always_ff @(posedge i_clk)
            begin
                if (i_reset)
                begin
                    o_wb_cyc <= 1'b0;
                    o_wb_stb <= 1'b0;
                    o_wb_wen <= 1'b0;

                    o_wb_sel <= 4'b0000;
                    o_wb_dat <= 32'h0000_0000;
                    o_wb_adr <= 32'h0000_0000;

                    o_wb_cti <= CTI_EOB;
                end
                else
                begin
                    //
                    // IMPORTANT:
                    //
                    // state_nxt is used here intentionally because
                    // cache ports are NXT values and common WB
                    // signals themselves are flops.
                    //
                    case (state_nxt)

                    CODE:
                    begin
                        o_wb_cyc <= i_c_wb_cyc;
                        o_wb_stb <= i_c_wb_stb;
                        o_wb_wen <= i_c_wb_wen;

                        o_wb_sel <= i_c_wb_sel;
                        o_wb_dat <= i_c_wb_dat;
                        o_wb_adr <= i_c_wb_adr;

                        o_wb_cti <= i_c_wb_cti;
                    end


                    DATA:
                    begin
                        o_wb_cyc <= i_d_wb_cyc;
                        o_wb_stb <= i_d_wb_stb;
                        o_wb_wen <= i_d_wb_wen;

                        o_wb_sel <= i_d_wb_sel;
                        o_wb_dat <= i_d_wb_dat;
                        o_wb_adr <= i_d_wb_adr;

                        o_wb_cti <= i_d_wb_cti;
                    end


                    //
                    // IDLE / GAP
                    //
                    // Force a true dead Wishbone cycle.
                    //
                    default:
                    begin
                        o_wb_cyc <= 1'b0;
                        o_wb_stb <= 1'b0;
                        o_wb_wen <= 1'b0;

                        o_wb_sel <= 4'b0000;
                        o_wb_dat <= 32'h0000_0000;
                        o_wb_adr <= 32'h0000_0000;

                        o_wb_cti <= CTI_EOB;
                    end

                    endcase
                end
            end

        end


        // ========================================================
        // ONLY_CORE configuration
        //
        // Source buses are already registered.
        // ========================================================

        else
        begin : g_core_mode

            always_comb
            begin
                //
                // Defaults = idle bus.
                //
                o_wb_cyc = 1'b0;
                o_wb_stb = 1'b0;
                o_wb_wen = 1'b0;

                o_wb_sel = 4'b0000;
                o_wb_dat = 32'h0000_0000;
                o_wb_adr = 32'h0000_0000;

                o_wb_cti = CTI_EOB;

                case (state_ff)

                CODE:
                begin
                    o_wb_cyc = i_c_wb_cyc;
                    o_wb_stb = i_c_wb_stb;
                    o_wb_wen = i_c_wb_wen;

                    o_wb_sel = i_c_wb_sel;
                    o_wb_dat = i_c_wb_dat;
                    o_wb_adr = i_c_wb_adr;

                    o_wb_cti = i_c_wb_cti;
                end


                DATA:
                begin
                    o_wb_cyc = i_d_wb_cyc;
                    o_wb_stb = i_d_wb_stb;
                    o_wb_wen = i_d_wb_wen;

                    o_wb_sel = i_d_wb_sel;
                    o_wb_dat = i_d_wb_dat;
                    o_wb_adr = i_d_wb_adr;

                    o_wb_cti = i_d_wb_cti;
                end


                default:
                begin
                    //
                    // IDLE / GAP:
                    // defaults already drive bus inactive.
                    //
                end

                endcase
            end

        end

    endgenerate


    // ============================================================
    // Simulation assertions / debug
    // ============================================================

`ifndef SYNTHESIS

    //
    // Never acknowledge both caches simultaneously.
    //
    always_ff @(posedge i_clk)
    begin
        if (!i_reset)
        begin
            assert (!(o_c_wb_ack && o_d_wb_ack))
            else
                $error(
                    "zap_wb_merger: CODE and DATA both received ACK"
                );
        end
    end


    //
    // GAP must produce an inactive common Wishbone bus.
    //
    // Because ONLY_CORE=0 outputs are registered using state_nxt,
    // inspect this along with state_ff/state_nxt in waveform.
    //
    always_ff @(posedge i_clk)
    begin
        if (!i_reset && (state_ff == GAP))
        begin
            assert (!o_wb_cyc)
            else
                $error(
                    "zap_wb_merger: o_wb_cyc active during GAP"
                );

            assert (!o_wb_stb)
            else
                $error(
                    "zap_wb_merger: o_wb_stb active during GAP"
                );
        end
    end


    //
    // Useful starvation diagnostic.
    //
    always_ff @(posedge i_clk)
    begin
        if (!i_reset &&
            state_ff == CODE &&
            data_pending_ff &&
            wb_eob)
        begin
            assert (state_nxt == GAP)
            else
                $error(
                    "zap_wb_merger: DATA waiting but CODE did not yield"
                );
        end
    end

`endif

endmodule : zap_wb_merger
