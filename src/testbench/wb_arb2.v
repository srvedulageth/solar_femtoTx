// wb_arb2.v  — 2-master Wishbone arbiter (parks on M0 / CPU)
// Fixed/sticky grant: grant holds while granted master keeps CYC=1.
// Compatible with classic/burst (CTI carried through; no preemption mid-CYC).

`ifndef SYNTHESIS
`include "timescale.v"
`endif

module wb_arb2
#(
  parameter ADR_WIDTH = 13,
  parameter DAT_WIDTH = 32,
  parameter PARK_ON_M0 = 1  // 1: park to M0 (CPU); 0: park to M1
)
(
  input                      clk,
  input                      rst,   // synchronous active-high

  // ---------------- Master 0 (CPU / ZAP) ----------------
  input  [ADR_WIDTH-1:0]     m0_adr_i,
  input  [DAT_WIDTH-1:0]     m0_dat_i,
  output [DAT_WIDTH-1:0]     m0_dat_o,
  input                      m0_we_i,
  input  [3:0]               m0_sel_i,
  input                      m0_cyc_i,
  input                      m0_stb_i,
  input  [2:0]               m0_cti_i,
  output                     m0_ack_o,

  // ---------------- Master 1 (EthMAC) ----------------
  input  [ADR_WIDTH-1:0]     m1_adr_i,
  input  [DAT_WIDTH-1:0]     m1_dat_i,
  output [DAT_WIDTH-1:0]     m1_dat_o,
  input                      m1_we_i,
  input  [3:0]               m1_sel_i,
  input                      m1_cyc_i,
  input                      m1_stb_i,
  input  [2:0]               m1_cti_i,
  output                     m1_ack_o,

  // ----------------
  output wire                ethmac_rd_o,

  // ---------------- Single Slave (RAM) ----------------
  output [ADR_WIDTH-1:0]     s_adr_o,
  output [DAT_WIDTH-1:0]     s_dat_o,
  input  [DAT_WIDTH-1:0]     s_dat_i,
  output                     s_we_o,
  output [3:0]               s_sel_o,
  output                     s_cyc_o,
  output                     s_stb_o,
  output [2:0]               s_cti_o,
  input                      s_ack_i
);

  // ----------------------------------------------------------------
  // Grant state: 0 = M0 (CPU), 1 = M1 (MAC)
  // Sticky while granted master holds CYC=1.
  // Park when idle.
  // ----------------------------------------------------------------
  reg grant;  // 0 or 1

  wire req0 = m0_cyc_i;
  wire req1 = m1_cyc_i;

  wire g_is_m0   = (grant == 1'b0);
  wire g_req     = g_is_m0 ? req0 : req1;      // current granted master's CYC
  wire other_req = g_is_m0 ? req1 : req0;

  // Idle if neither master is asserting CYC
  wire idle_bus = ~req0 & ~req1;

  always @(posedge clk) begin
    if (rst) begin
      grant <= (PARK_ON_M0 ? 1'b0 : 1'b1);
    end else begin
      if (g_req) begin
        // Current master still owns the bus → hold grant
        grant <= grant;
      end else begin
        // Current master released CYC; choose next owner
        if (other_req) begin
          grant <= ~grant; // other master takes over
        end else begin
          // No requests → park
          grant <= (PARK_ON_M0 ? 1'b0 : 1'b1);
        end
      end
    end
  end

  // ----------------------------------------------------------------
  // Mux master → slave
  // ----------------------------------------------------------------
  assign s_adr_o = g_is_m0 ? m0_adr_i : m1_adr_i;
  assign s_dat_o = g_is_m0 ? m0_dat_i : m1_dat_i;
  assign s_we_o  = g_is_m0 ? m0_we_i  : m1_we_i;
  assign s_sel_o = g_is_m0 ? m0_sel_i : m1_sel_i;
  assign s_cyc_o = g_is_m0 ? m0_cyc_i : m1_cyc_i;
  assign s_stb_o = g_is_m0 ? m0_stb_i : m1_stb_i;
  assign s_cti_o = g_is_m0 ? m0_cti_i : m1_cti_i;

  // ----------------------------------------------------------------
  // Demux slave → masters
  // Only the granted master sees ACK/DAT; the other sees ACK=0.
  // ----------------------------------------------------------------
  assign m0_ack_o = (g_is_m0) ? s_ack_i : 1'b0;
  assign m1_ack_o = (g_is_m0) ? 1'b0    : s_ack_i;

  assign m0_dat_o = (g_is_m0) ? s_dat_i : {DAT_WIDTH{1'b0}};
  assign m1_dat_o = (g_is_m0) ? {DAT_WIDTH{1'b0}} : s_dat_i;

  //EthMAC Rds are pipelined i.e. cyc_o is NOT deasserted by the EthMAC controller in between transfers ...
  assign ethmac_rd_o = g_is_m0 ? 1'b 0: ~m1_we_i;
endmodule
