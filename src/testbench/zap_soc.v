/*
//
// UART0  address space FFFEFFE0 to FFFEFFFF
// Timer0 address space FFFEFFC0 to FFFEFFDF
// VIC0   address space FFFEFFA0 to FFFEFFBF
// UART1  address space FFFEFF80 to FFFEFF9F
// Timer1 address space FFFEFF60 to FFFEFF7F
//
Rev 2
Added EthMac
*/

`ifndef SYNTHESIS
`include "timescale.v"
`endif

module zap_soc #(

// CPU config.
parameter DATA_SECTION_TLB_ENTRIES      = 4,
parameter DATA_LPAGE_TLB_ENTRIES        = 8,
parameter DATA_SPAGE_TLB_ENTRIES        = 16,
parameter DATA_FPAGE_TLB_ENTRIES        = 32,
parameter DATA_CACHE_SIZE               = 1024,
parameter CODE_SECTION_TLB_ENTRIES      = 4,
parameter CODE_LPAGE_TLB_ENTRIES        = 8,
parameter CODE_SPAGE_TLB_ENTRIES        = 16,
parameter CODE_FPAGE_TLB_ENTRIES        = 32,
parameter CODE_CACHE_SIZE               = 1024,
parameter FIFO_DEPTH                    = 4,
parameter BP_ENTRIES                    = 1024,
parameter BE_32_ENABLE                  = 0,
parameter ONLY_CORE                     = 0

)(
        //Clk and rst
        input wire          SYS_CLK,
        input wire          SYS_RST,

`ifdef SYNTHESIS
        output wire         led_0,
        output wire         led_1,
        output wire         led_2,
        output wire         led_3,
`endif

        //DDR3 SDRAM interface (Arty A7 style, adjust names if needed)
        inout  wire [15:0]  ddr3_dq,
        inout  wire [1:0]   ddr3_dqs_n,
        inout  wire [1:0]   ddr3_dqs_p,

        output wire [13:0]  ddr3_addr,
        output wire [2:0]   ddr3_ba,
        output wire         ddr3_ras_n,
        output wire         ddr3_cas_n,
        output wire         ddr3_we_n,
        output wire [0:0]   ddr3_ck_p,
        output wire [0:0]   ddr3_ck_n,
        output wire [0:0]   ddr3_cke,
        output wire [0:0]   ddr3_cs_n,
        output wire [1:0]   ddr3_dm,
        output wire [0:0]   ddr3_odt,
        output wire         ddr3_reset_n,
    
        input               sys_clk_i,
        input               clk_ref_i,
        input               sys_rst,

        //EthMAC
        //Tx
        input               mtx_clk_pad_i, // Transmit clock (from PHY)
        output wire [3:0]   mtxd_pad_o,    // Transmit nibble (to PHY)
        output              mtxen_pad_o,   // Transmit enable (to PHY)
        output              mtxerr_pad_o,  // Transmit error (to PHY)

        //Rx
        input               mrx_clk_pad_i, // Receive clock (from PHY)
        input [3:0]         mrxd_pad_i,    // Receive nibble (from PHY)
        input               mrxdv_pad_i,   // Receive data valid (from PHY)
        input               mrxerr_pad_i,  // Receive data error (from PHY)

        //Common Tx and Rx
        input               mcoll_pad_i,   // Collision (from PHY)
        input               mcrs_pad_i,    // Carrier sense (from PHY)

        //Phy Reference Clock and Reset ...
        output wire         eth_ref_clk,
        output wire         eth_rstn,

        // MIIM MII Management interface
        inout               mdio_pad_io,
        output wire         mdc_pad_o,     // MII Management data clock (to PHY)

        // UART 0
        input  wire         UART0_RXD,
        output wire         UART0_TXD

`ifdef DUAL_UART
        ,
        // UART 1
        input  wire         UART1_RXD,
        output wire         UART1_TXD
`endif

        // Interrupt sel..
        //input wire          int_sel
);

wire md_pad_i, md_padoe_o, md_pad_o;
assign mdio_pad_io = md_padoe_o ? md_pad_o : 1'bz ;
assign md_pad_i = mdio_pad_io;

wire int_sel;
assign int_sel = 'b 1;

// Peripheral addresses.
`ifdef DUAL_UART
localparam TIMER1_LO                    = 32'hFFFFFF60;
localparam TIMER1_HI                    = 32'hFFFFFF7F;
localparam UART1_LO                     = 32'hFFFFFF80;
localparam UART1_HI                     = 32'hFFFFFF9F;
`else
localparam TIMER0_LO                    = 32'hFFFFFFC0;
localparam TIMER0_HI                    = 32'hFFFFFFDF;
localparam UART0_LO                     = 32'hFFFFFFE0;
localparam UART0_HI                     = 32'hFFFFFFFF;
`endif
localparam VIC_LO                       = 32'hFFFFFFA0;
localparam VIC_HI                       = 32'hFFFFFFBF;
localparam ETHMAC_LO                    = 32'hFFFFE000; //Internal Slave Ram of EthMAC total 2K bytes
localparam ETHMAC_HI                    = 32'hFFFFEFFF;

localparam ETHMAC_BUF_RAM_LO            = 32'h0A000000;
localparam ETHMAC_BUF_RAM_HI            = 32'h0A001FFF; //Total 8K, accessed both by processor and ethmac...

// Internal signals.
wire            i_clk    = SYS_CLK;
wire            i_reset  = SYS_RST;

reg             eth_ref_clk_r1, eth_ref_clk_r2;

always @(posedge SYS_CLK) begin
  if (SYS_RST) begin
    eth_ref_clk_r1 <= 'b 0;
  end else begin
    eth_ref_clk_r1 <= ~eth_ref_clk_r1;
  end
end

always @(posedge eth_ref_clk_r1) begin
  if (SYS_RST) begin
    eth_ref_clk_r2 <= 'b 0;
  end else begin
    eth_ref_clk_r2 <= ~eth_ref_clk_r2;
  end
end
assign eth_ref_clk = eth_ref_clk_r2;
assign eth_rstn = ~SYS_RST;

`ifdef DUAL_UART
wire [1:0]      uart_in;
wire [1:0]      uart_out;
assign          {UART1_TXD, UART0_TXD} = uart_out;
assign          uart_in = {UART1_RXD, UART0_RXD};
`else
wire [0:0]      uart_in;
wire [0:0]      uart_out;
assign          UART0_TXD = uart_out;
assign          uart_in = UART0_RXD;
`endif

wire            data_wb_cyc;
wire            data_wb_stb;
reg [31:0]      data_wb_din;
reg             data_wb_ack;

wire ram_ack_o;

//EthMAC Wishbone Master
wire [31:0] ethmac_m_wb_adr_o;
wire [3:0] ethmac_m_wb_sel_o;
wire ethmac_m_wb_we_o;
wire [31:0] ethmac_m_wb_dat_o;
wire [31:0] ethmac_m_wb_dat_i;
wire ethmac_m_wb_cyc_o;
wire ethmac_m_wb_stb_o;
wire ethmac_m_wb_ack_i;
wire ethmac_m_wb_err_i;

`ifdef DUAL_UART
reg             data_wb_cyc_uart [1:0], data_wb_cyc_timer [1:0];
reg             data_wb_stb_uart [1:0], data_wb_stb_timer [1:0];
wire [31:0]     data_wb_din_uart [1:0], data_wb_din_timer [1:0];
wire            data_wb_ack_uart [1:0], data_wb_ack_timer [1:0];
`else
reg             data_wb_cyc_uart [0:0], data_wb_cyc_timer [0:0];
reg             data_wb_stb_uart [0:0], data_wb_stb_timer [0:0];
wire [31:0]     data_wb_din_uart [0:0], data_wb_din_timer [0:0];
wire            data_wb_ack_uart [0:0], data_wb_ack_timer [0:0];
`endif
reg             data_wb_cyc_ram, data_wb_cyc_vic, data_wb_cyc_ethmac, data_wb_cyc_ethmac_ram;
reg             data_wb_stb_ram, data_wb_stb_vic, data_wb_stb_ethmac, data_wb_stb_ethmac_ram;
wire [31:0]     data_wb_din_ram, data_wb_din_vic, data_wb_din_ethmac, data_wb_din_ethmac_ram;
wire            data_wb_ack_ram, data_wb_ack_vic, data_wb_ack_ethmac, data_wb_ack_ethmac_ram;

wire [3:0]      data_wb_sel;
wire            data_wb_we;
wire [31:0]     data_wb_dout;
wire [31:0]     data_wb_adr;
wire [2:0]      data_wb_cti; // Cycle Type Indicator.
wire            global_irq;

`ifdef DUAL_UART
wire [1:0]      uart_irq;
wire [1:0]      timer_irq;
`else
wire [0:0]      uart_irq;
wire [0:0]      timer_irq;
`endif
wire            ethmac_irq;

// Wishbone fabric.
always @* begin:blk1
  integer ii;

`ifdef DUAL_UART
  for(ii=0;ii<=1;ii=ii+1) begin
`else
  for(ii=0;ii<1;ii=ii+1) begin
`endif
    data_wb_cyc_uart [ii]  = 0;
    data_wb_stb_uart [ii]  = 0;
    data_wb_cyc_timer[ii] = 0;
    data_wb_stb_timer[ii] = 0;
  end

  data_wb_cyc_vic   = 0;
  data_wb_stb_vic   = 0;

  data_wb_cyc_ram   = 0;
  data_wb_stb_ram   = 0;

  data_wb_cyc_ethmac = 0;
  data_wb_stb_ethmac = 0;

  data_wb_cyc_ethmac_ram = 0;
  data_wb_stb_ethmac_ram = 0;

  if(data_wb_adr >= UART0_LO && data_wb_adr <= UART0_HI) begin        // UART0 access
    data_wb_cyc_uart[0] = data_wb_cyc;
    data_wb_stb_uart[0] = data_wb_stb;
    data_wb_ack        = data_wb_ack_uart[0];
    data_wb_din        = data_wb_din_uart[0];
  end
  else if(data_wb_adr >= TIMER0_LO && data_wb_adr <= TIMER0_HI) begin  // Timer0 access
    data_wb_cyc_timer[0] = data_wb_cyc;
    data_wb_stb_timer[0] = data_wb_stb;
    data_wb_ack          = data_wb_ack_timer[0];
    data_wb_din          = data_wb_din_timer[0];
  end
  else if(data_wb_adr >= VIC_LO && data_wb_adr <= VIC_HI) begin       // VIC access.
    data_wb_cyc_vic   = data_wb_cyc;
    data_wb_stb_vic   = data_wb_stb;
    data_wb_ack       = data_wb_ack_vic;
    data_wb_din       = data_wb_din_vic;
  end
`ifdef DUAL_UART
  else if(data_wb_adr >= UART1_LO && data_wb_adr <= UART1_HI) begin    // UART1 access
    data_wb_cyc_uart[1] = data_wb_cyc;
    data_wb_stb_uart[1] = data_wb_stb;
    data_wb_ack        = data_wb_ack_uart[1];
    data_wb_din        = data_wb_din_uart[1];
  end
  else if(data_wb_adr >= TIMER1_LO && data_wb_adr <= TIMER1_HI) begin  // Timer1 access
    data_wb_cyc_timer[1] = data_wb_cyc;
    data_wb_stb_timer[1] = data_wb_stb;
    data_wb_ack          = data_wb_ack_timer[1];
    data_wb_din          = data_wb_din_timer[1];
  end
`endif
  else if(data_wb_adr >= ETHMAC_LO && data_wb_adr <= ETHMAC_HI) begin  // EthMAC 0 Slave Address Space ...
    data_wb_cyc_ethmac = data_wb_cyc;
    data_wb_stb_ethmac = data_wb_stb;
    data_wb_ack        = data_wb_ack_ethmac;
    data_wb_din        = data_wb_din_ethmac;
  end
  else if(data_wb_adr >= ETHMAC_BUF_RAM_LO && data_wb_adr <= ETHMAC_BUF_RAM_HI) begin  // EthMAC 0 Master Address Space ...
    data_wb_cyc_ethmac_ram = data_wb_cyc;
    data_wb_stb_ethmac_ram = data_wb_stb;
    data_wb_ack        = data_wb_ack_ethmac_ram;
    data_wb_din        = data_wb_din_ethmac_ram;
  end
  else begin // External RAM access.
    data_wb_cyc_ram  = data_wb_cyc;
    data_wb_stb_ram  = data_wb_stb;
    data_wb_ack      = data_wb_ack_ram;
    data_wb_din      = data_wb_din_ram;
  end
end

// =========================
// Processor core.
// =========================

zap_top #(
        .CP15_L4_DEFAULT(1'd1),
        .BE_32_ENABLE(BE_32_ENABLE),
        .ONLY_CORE(ONLY_CORE),
        .FIFO_DEPTH(FIFO_DEPTH),
        .BP_ENTRIES(BP_ENTRIES),
        .DATA_SECTION_TLB_ENTRIES(DATA_SECTION_TLB_ENTRIES),
        .DATA_LPAGE_TLB_ENTRIES(DATA_LPAGE_TLB_ENTRIES),
        .DATA_SPAGE_TLB_ENTRIES(DATA_SPAGE_TLB_ENTRIES),
        .DATA_FPAGE_TLB_ENTRIES(DATA_FPAGE_TLB_ENTRIES),
        .DATA_CACHE_SIZE(DATA_CACHE_SIZE),
        .CODE_SECTION_TLB_ENTRIES(CODE_SECTION_TLB_ENTRIES),
        .CODE_LPAGE_TLB_ENTRIES(CODE_LPAGE_TLB_ENTRIES),
        .CODE_SPAGE_TLB_ENTRIES(CODE_SPAGE_TLB_ENTRIES),
        .CODE_FPAGE_TLB_ENTRIES(CODE_FPAGE_TLB_ENTRIES),
        .CODE_CACHE_SIZE(CODE_CACHE_SIZE)
)
u_zap_top
(
        .i_clk    (i_clk),
        .i_reset  (i_reset),
        .i_irq    (int_sel == 1'd0 ? global_irq : 1'b 0),
        .i_fiq    (int_sel == 1'd1 ? global_irq : 1'b 0),
        .o_wb_cyc (data_wb_cyc),
        .o_wb_stb (data_wb_stb),
        .o_wb_adr (data_wb_adr),
        .o_wb_we  (data_wb_we),
        .o_wb_cti (data_wb_cti),
        .i_wb_dat (data_wb_din),
        .o_wb_dat (data_wb_dout),
        .i_wb_ack (data_wb_ack),
        .i_wb_err (1'd0),
        .o_wb_sel (data_wb_sel),
        .o_wb_bte ()             // Always zero (Linear)
`ifndef SYNTHESIS
        ,
        .o_trace(),
        .o_trace_valid(),
        .o_trace_uop_last()
`endif
);

// ===============================
// 2 x UART + 2 x Timer
// ===============================

genvar gi;
generate
`ifdef DUAL_UART
        for(gi=0;gi<=1;gi=gi+1)
`else
        for(gi=0;gi<1;gi=gi+1)
`endif
        begin: uart_gen
                uart_top u_uart_top (

                        // WISHBONE interface
                        .wb_clk_i(i_clk),
                        .wb_rst_i(i_reset),
                        .wb_adr_i(data_wb_adr[4:0]),
                        .wb_dat_i(data_wb_dout),
                        .wb_dat_o(data_wb_din_uart[gi]),
                        .wb_we_i (data_wb_we),
                        .wb_stb_i(data_wb_stb_uart[gi]),
                        .wb_cyc_i(data_wb_cyc_uart[gi]),
                        .wb_sel_i(data_wb_sel),
                        .wb_ack_o(data_wb_ack_uart[gi]),
                        .int_o   (uart_irq[gi]), // Interrupt.

                        // UART signals.
                        .srx_pad_i         (uart_in[gi]),
                        .stx_pad_o         (uart_out[gi]),

                        // Tied or open.
                        .rts_pad_o(),
                        .cts_pad_i(1'd0),
                        .dtr_pad_o(),
                        .dsr_pad_i(1'd0),
                        .ri_pad_i (1'd0),
                        .dcd_pad_i(1'd0)
                );

                timer u_timer (
                        .i_clk(i_clk),
                        .i_rst(i_reset),
                        .i_wb_adr(data_wb_adr[3:0]),
                        .i_wb_dat(data_wb_dout),
                        .i_wb_stb(data_wb_stb_timer[gi]),
                        .i_wb_cyc(data_wb_cyc_timer[gi]),   // From core
                        .i_wb_wen(data_wb_we),
                        .i_wb_sel(data_wb_sel),
                        .o_wb_dat(data_wb_din_timer[gi]),   // To core.
                        .o_wb_ack(data_wb_ack_timer[gi]),
                        .o_irq(timer_irq[gi])               // Interrupt
                );
        end
endgenerate

// ===============================
// VIC
// ===============================

vic #(.SOURCES(32)) u_vic (
        .i_clk   (i_clk),
        .i_rst   (i_reset),
        .i_wb_adr(data_wb_adr[3:0]),
        .i_wb_dat(data_wb_dout),
        .i_wb_stb(data_wb_stb_vic),
        .i_wb_cyc(data_wb_cyc_vic), // From core
        .i_wb_wen(data_wb_we),
        .i_wb_sel(data_wb_sel),
        .o_wb_dat(data_wb_din_vic), // To core.
        .o_wb_ack(data_wb_ack_vic),
`ifdef DUAL_UART
        .i_irq({27'h 0, ethmac_irq, timer_irq[1], uart_irq[1], timer_irq[0], uart_irq[0]}), // Concatenate 32 interrupt sources.
`else
        .i_irq({29'h 0, ethmac_irq, timer_irq[0], uart_irq[0]}), // Concatenate 32 interrupt sources.
`endif
        .o_irq(global_irq)                                                     // Interrupt out
);

// ===============================
// EthMAC
// ===============================

ethmac ethmac(
  // WISHBONE common
  .wb_clk_i(i_clk),
  .wb_rst_i(i_reset),

  // WISHBONE slave
  .wb_adr_i(data_wb_adr[11:2]),
  .wb_sel_i(data_wb_sel),
  .wb_we_i(data_wb_we),
  .wb_cyc_i(data_wb_cyc_ethmac),
  .wb_stb_i(data_wb_stb_ethmac),
  .wb_ack_o(data_wb_ack_ethmac),
  .wb_err_o(), //Not Used
  .wb_dat_i(data_wb_dout),
  .wb_dat_o(data_wb_din_ethmac),

  // WISHBONE master
  .m_wb_adr_o(ethmac_m_wb_adr_o),
  .m_wb_sel_o(ethmac_m_wb_sel_o),
  .m_wb_we_o(ethmac_m_wb_we_o),
  .m_wb_dat_o(ethmac_m_wb_dat_o),
  .m_wb_dat_i(ethmac_m_wb_dat_i),
  .m_wb_cyc_o(ethmac_m_wb_cyc_o),
  .m_wb_stb_o(ethmac_m_wb_stb_o),
  .m_wb_ack_i(ethmac_m_wb_ack_i),

  .m_wb_err_i(1'b 0), //Not Used

  .m_wb_cti_o(), //Not Used
  .m_wb_bte_o(), //Not Used

  //TX
  .mtx_clk_pad_i(mtx_clk_pad_i),
  .mtxd_pad_o(mtxd_pad_o),
  .mtxen_pad_o(mtxen_pad_o),
  .mtxerr_pad_o(mtxerr_pad_o),

  //RX
  .mrx_clk_pad_i(mrx_clk_pad_i),
  .mrxd_pad_i(mrxd_pad_i),
  .mrxdv_pad_i(mrxdv_pad_i),
  .mrxerr_pad_i(mrxerr_pad_i),

  //Common Tx and Rx
  .mcoll_pad_i(mcoll_pad_i),
  .mcrs_pad_i(mcrs_pad_i),
  
  // MIIM
  .mdc_pad_o(mdc_pad_o),
  .md_pad_i(md_pad_i),
  .md_pad_o(md_pad_o),
  .md_padoe_o(md_padoe_o),

  .int_o(ethmac_irq)

  // Bist
`ifdef ETH_BIST
  ,
  // debug chain signals
  mbist_si_i,       // bist scan serial in
  mbist_so_o,       // bist scan serial out
  mbist_ctrl_i        // bist chain shift control
`endif

);

// ===============================
// RAM
// ===============================

//Processor RAM ...
ram_wb
      #
        (
          .adr_width(13),
          .dat_width(32),
          .mem_size(8192),
          .MEMFILE("ethmac_zap.dump")
        )
      ram_wb (
              .clk_i(i_clk),
              .rst_i(i_reset),
              .adr_i(data_wb_adr[12:0]),
              .dat_i(data_wb_dout),
              .we_i(data_wb_we),
              .sel_i(data_wb_sel),
              .dat_o(data_wb_din_ram),
              .cyc_i(data_wb_cyc_ram),
              .stb_i(data_wb_stb_ram),
              .ack_o(data_wb_ack_ram),
              .cti_i(3'b 000)
            );

//EthMAC TX/RX/BDS RAM ...
wire [12:0] ethmac_ram_adr;
wire [31:0] ethmac_ram_dat_i;
wire [31:0] ethmac_ram_dat_o;
wire ethmac_ram_we;
wire [3:0] ethmac_ram_sel;
wire ethmac_ram_cyc;
wire ethmac_ram_stb;
wire ethmac_ram_ack;
wire ethmac_ram_ack_1;
wire [31:0] ethmac_ram_dat_o_1;

ram_wb
      #
        (
          .adr_width(13),
          .dat_width(32),
          .mem_size(8192)
        )
      ram_wb_ethmac (
              .clk_i(i_clk),
              .rst_i(i_reset),
              .adr_i(ethmac_ram_adr),
              .dat_i(ethmac_ram_dat_i),
              .we_i(ethmac_ram_we),
              .sel_i(ethmac_ram_sel),
              .dat_o(ethmac_ram_dat_o_1),
              .cyc_i(ethmac_ram_cyc),
              .stb_i(ethmac_ram_stb),
              .ack_o(ethmac_ram_ack_1),
              .cti_i(3'b 000)
            );

//Wishbone Arbiter ...
wb_arb2 #(
  .ADR_WIDTH(13),
  .DAT_WIDTH(32),
  .PARK_ON_M0(1)      // park on CPU
) u_arb (
  .clk     (i_clk),
  .rst     (i_reset),

  // M0: CPU
  .m0_adr_i(data_wb_adr[12:0]),
  .m0_dat_i(data_wb_dout),
  .m0_dat_o(data_wb_din_ethmac_ram),
  .m0_we_i (data_wb_we),
  .m0_sel_i(data_wb_sel),
  .m0_cyc_i(data_wb_cyc_ethmac_ram),
  .m0_stb_i(data_wb_stb_ethmac_ram),
  .m0_cti_i(3'b 000),
  .m0_ack_o(data_wb_ack_ethmac_ram),

  // M1: EthMAC master
  .m1_adr_i(ethmac_m_wb_adr_o[12:0]),
  .m1_dat_i(ethmac_m_wb_dat_o),
  .m1_dat_o(ethmac_m_wb_dat_i),
  .m1_we_i (ethmac_m_wb_we_o),
  .m1_sel_i(ethmac_m_wb_sel_o),
  .m1_cyc_i(ethmac_m_wb_cyc_o),
  .m1_stb_i(ethmac_m_wb_stb_o),
  .m1_cti_i(3'b 000),
  .m1_ack_o(ethmac_m_wb_ack_i),

  // Slave: 8K RAM
  .s_adr_o (ethmac_ram_adr[12:0]),
  .s_dat_o (ethmac_ram_dat_i),
  .s_dat_i (ethmac_ram_dat_o),
  .s_we_o  (ethmac_ram_we),
  .s_sel_o (ethmac_ram_sel),
  .s_cyc_o (ethmac_ram_cyc),
  .s_stb_o (ethmac_ram_stb),
  .s_cti_o (), //NOT USED
  .s_ack_i (ethmac_ram_ack)
);

`ifdef SYNTHESIS
   reg [23:0] count = 0;
   assign led_0 = count[23];
   assign led_1 = count[22];
   assign led_2 = count[21];
   //assign led_3 = count[20];
   assign led_3 = ~uart_out[0:0];
   always @(posedge SYS_CLK) count <= count + 1;
`endif

//DDR3
// ---------------------------------------------------------------------------
// DDR3 MIG instance wires
// ---------------------------------------------------------------------------
wire        ui_clk;
wire        ui_clk_sync_rst;
wire        init_calib_complete;
wire        [11:0] device_temp;

// AXI4 slave interface from MIG (we'll connect later via WB<->AXI bridge)
wire [3:0]  s_axi_awid;
wire [27:0] s_axi_awaddr;
wire [7:0]  s_axi_awlen;
wire [2:0]  s_axi_awsize;
wire [1:0]  s_axi_awburst;
wire [0:0]  s_axi_awlock;
wire [3:0]  s_axi_awcache;
wire [2:0]  s_axi_awprot;
wire [3:0]  s_axi_awqos;
wire        s_axi_awvalid;
wire        s_axi_awready;

wire [31:0] s_axi_wdata;
wire [3:0]  s_axi_wstrb;
wire        s_axi_wlast;
wire        s_axi_wvalid;
wire        s_axi_wready;

wire [3:0]  s_axi_bid;
wire [1:0]  s_axi_bresp;
wire        s_axi_bvalid;
wire        s_axi_bready;

wire [3:0]  s_axi_arid;
wire [27:0] s_axi_araddr;
wire [7:0]  s_axi_arlen;
wire [2:0]  s_axi_arsize;
wire [1:0]  s_axi_arburst;
wire [0:0]  s_axi_arlock;
wire [3:0]  s_axi_arcache;
wire [2:0]  s_axi_arprot;
wire [3:0]  s_axi_arqos;
wire        s_axi_arvalid;
wire        s_axi_arready;

wire [3:0]  s_axi_rid;
wire [31:0] s_axi_rdata;
wire [1:0]  s_axi_rresp;
wire        s_axi_rlast;
wire        s_axi_rvalid;
wire        s_axi_rready;

reg         aresetn;
always @(posedge i_clk) begin         
  aresetn <= ~ui_clk_sync_rst;                  
end 

// ---------------------------------------------------------------------------
// MIG 7-series DDR3 memory controller
// ---------------------------------------------------------------------------
mig_7series_0 u_mig_7series_0 (
    // DDR3 physical interface
    .ddr3_addr          (ddr3_addr),
    .ddr3_ba            (ddr3_ba),
    .ddr3_cas_n         (ddr3_cas_n),
    .ddr3_ck_n          (ddr3_ck_n),
    .ddr3_ck_p          (ddr3_ck_p),
    .ddr3_cke           (ddr3_cke),
    .ddr3_ras_n         (ddr3_ras_n),
    .ddr3_we_n          (ddr3_we_n),
    .ddr3_dq            (ddr3_dq),
    .ddr3_dqs_n         (ddr3_dqs_n),
    .ddr3_dqs_p         (ddr3_dqs_p),
    .ddr3_reset_n       (ddr3_reset_n),

    // Status
    .init_calib_complete(init_calib_complete),
    .device_temp(device_temp),

    .ddr3_cs_n          (ddr3_cs_n),
    .ddr3_dm            (ddr3_dm),
    .ddr3_odt           (ddr3_odt),

    // User interface clock / reset
    .ui_clk             (ui_clk),
    .ui_clk_sync_rst    (ui_clk_sync_rst),

    // System / reference clocks & reset
    .sys_clk_i          (sys_clk_i),
    .clk_ref_i          (clk_ref_i),
    .sys_rst            (sys_rst),              // MIG expects active-high reset

    // Unused MIG test/debug ports
    .mmcm_locked        (),
    .aresetn            (),
    .app_sr_req         (1'b0),
    .app_ref_req        (1'b0),
    .app_zq_req         (1'b0),
    .app_sr_active      (),
    .app_ref_ack        (),
    .app_zq_ack         (),

    // Slave Interface Write Address Ports
    .s_axi_awid         (s_axi_awid),
    .s_axi_awaddr       (s_axi_awaddr),
    .s_axi_awlen        (s_axi_awlen),
    .s_axi_awsize       (s_axi_awsize),
    .s_axi_awburst      (s_axi_awburst),
    .s_axi_awlock       (s_axi_awlock),
    .s_axi_awcache      (s_axi_awcache),
    .s_axi_awprot       (s_axi_awprot),
    .s_axi_awqos        (s_axi_awqos),
    .s_axi_awvalid      (s_axi_awvalid),
    .s_axi_awready      (s_axi_awready),

    // Slave Interface Write Data Ports
    .s_axi_wdata        (s_axi_wdata),
    .s_axi_wstrb        (s_axi_wstrb),
    .s_axi_wlast        (s_axi_wlast),
    .s_axi_wvalid       (s_axi_wvalid),
    .s_axi_wready       (s_axi_wready),

    // Slave Interface Write Response Ports
    .s_axi_bid          (s_axi_bid),
    .s_axi_bresp        (s_axi_bresp),
    .s_axi_bvalid       (s_axi_bvalid),
    .s_axi_bready       (s_axi_bready),

    // Slave Interface Read Address Ports
    .s_axi_arid         (s_axi_arid),
    .s_axi_araddr       (s_axi_araddr),
    .s_axi_arlen        (s_axi_arlen),
    .s_axi_arsize       (s_axi_arsize),
    .s_axi_arburst      (s_axi_arburst),
    .s_axi_arlock       (s_axi_arlock),
    .s_axi_arcache      (s_axi_arcache),
    .s_axi_arprot       (s_axi_arprot),
    .s_axi_arqos        (s_axi_arqos),
    .s_axi_arvalid      (s_axi_arvalid),
    .s_axi_arready      (s_axi_arready),

    // Slave Interface Read Data Ports
    .s_axi_rid          (s_axi_rid),
    .s_axi_rdata        (s_axi_rdata),
    .s_axi_rresp        (s_axi_rresp),
    .s_axi_rlast        (s_axi_rlast),
    .s_axi_rvalid       (s_axi_rvalid),
    .s_axi_rready       (s_axi_rready)

);
//DDR3

//wbm2axisp
wbm2axisp u_wbm2axisp(
    .i_clk(sys_clk_i),	// System clock
    .i_reset(~sys_rst),	// Reset signal,drives AXI rst

    // AXI write address channel signals
    .o_axi_awvalid(s_axi_awvalid),	// Write address valid
    .i_axi_awready(s_axi_awvalid),   // Slave is ready to accept
    .o_axi_awid(s_axi_awid),	// Write ID
    .o_axi_awaddr(s_axi_awaddr),	// Write address
    .o_axi_awlen(s_axi_awlen),	// Write Burst Length
    .o_axi_awsize(s_axi_awsize),	// Write Burst size
    .o_axi_awburst(s_axi_awburst),	// Write Burst type
    .o_axi_awlock(s_axi_awlock),	// Write lock type
    .o_axi_awcache(s_axi_awcache),	// Write Cache type
    .o_axi_awprot(s_axi_awprot),	// Write Protection type
    .o_axi_awqos(s_axi_awqos),	// Write Quality of Svc

    // AXI write data channel signals
    .o_axi_wvalid(s_axi_wvalid),	// Write valid
    .i_axi_wready(s_axi_wready),    // Write data ready
    .o_axi_wdata(s_axi_wdata),	// Write data
    .o_axi_wstrb(s_axi_wstrb),	// Write strobes
    .o_axi_wlast(s_axi_wlast),	// Last write transaction

    // AXI write response channel signals
    .i_axi_bvalid(s_axi_bvalid),    // Write reponse valid
    .o_axi_bready(s_axi_bready),    // Response ready
    .i_axi_bid(s_axi_bid),	// Response ID
    .i_axi_bresp(s_axi_bresp),	// Write response

    // AXI read address channel signals
    .o_axi_arvalid(s_axi_arvalid),	// Read address valid
    .i_axi_arready(s_axi_arready),	// Read address ready
    .o_axi_arid(s_axi_arid),     // Read ID
    .o_axi_araddr(s_axi_araddr),	// Read address
    .o_axi_arlen(s_axi_arlen),	// Read Burst Length
    .o_axi_arsize(s_axi_arsize),	// Read Burst size
    .o_axi_arburst(s_axi_arburst),	// Read Burst type
    .o_axi_arlock(s_axi_arlock),	// Read lock type
    .o_axi_arcache(s_axi_arcache),	// Read Cache type
    .o_axi_arprot(s_axi_arprot),	// Read Protection type
    .o_axi_arqos(s_axi_arqos),	// Read Protection type

    // AXI read data channel signals
    .i_axi_rvalid(s_axi_rvalid),  // Read reponse valid
    .o_axi_rready(s_axi_rready),  // Read Response ready
    .i_axi_rid(s_axi_rid),     // Response ID
    .i_axi_rdata(s_axi_rdata),    // Read data
    .i_axi_rresp(s_axi_rresp),   // Read response
    .i_axi_rlast(s_axi_rlast),    // Read last

    // We'll share the clock and the reset
    .i_wb_cyc(ethmac_ram_cyc),
    .i_wb_stb(ethmac_ram_stb),
    .i_wb_we(ethmac_ram_we),
    .i_wb_addr({13'h 0, ethmac_ram_adr}),
    .i_wb_data(ethmac_ram_dat_i),
    .o_wb_ack(ethmac_ram_ack),
    .o_wb_data(ethmac_ram_dat_o),
    .i_wb_sel(ethmac_ram_sel),
    .o_wb_stall(),
    .o_wb_err()
);
//wbm2axisp

endmodule // zap_soc
