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
parameter ONLY_CORE                     = 0,
parameter DATA_CACHE_SIZE               = 4096,
parameter CODE_CACHE_SIZE               = 4096,
parameter CODE_SECTION_TLB_ENTRIES      = 512,
parameter CODE_LPAGE_TLB_ENTRIES        = 512,
parameter CODE_FPAGE_TLB_ENTRIES        = 512,
parameter CODE_SPAGE_TLB_ENTRIES        = 512,
parameter DATA_SECTION_TLB_ENTRIES      = 512,
parameter DATA_LPAGE_TLB_ENTRIES        = 512,
parameter DATA_FPAGE_TLB_ENTRIES        = 512,
parameter DATA_SPAGE_TLB_ENTRIES        = 512,
parameter FIFO_DEPTH                    = 4,
parameter BP_ENTRIES                    = 1024,
parameter BE_32_ENABLE                  = 0

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

`ifdef DDR3_CONTROLLER
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
`endif //`ifdef DDR3_CONTROLLER

        //EthMAC
        //Tx
        input               mtx_clk_pad_i, // Transmit clock (from PHY)
        output wire [3:0]   mtxd_pad_o,    // Transmit nibble (to PHY)
        output              mtxen_pad_o,   // Transmit enable (to PHY)
        //output              mtxerr_pad_o,  // Transmit error (to PHY) //NOT USED ...

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

localparam ETHMAC_BUF_RAM_LO            = 32'h10000000;
localparam ETHMAC_BUF_RAM_HI            = 32'h1FFFFFFF; //Total 256MB, accessed both by processor and ethmac...

// Internal signals.
wire            clk_ddr;
wire            clk_ref;
wire            clk2ddr3;

wire            i_clk    = SYS_CLK;
//wire            i_reset  = ~SYS_RST;
wire            stable_rst_sync;
wire            ddr3_init_done;
wire            dfi_wrdata_en;
wire            dfi_rddata_valid;

// Synchronize SYS_RST (active low) into i_clk domain
(* ASYNC_REG = "TRUE" *) reg rst_meta;
(* ASYNC_REG = "TRUE" *) reg rst_sync;

/*
(* MARK_DEBUG = "true" *) wire mdc_dbg  = mdc_pad_o;   // EthMAC MDC out
(* MARK_DEBUG = "true" *) wire mdio_i_dbg = mdio_pad_io; // MDIO bidir
(* MARK_DEBUG = "true" *) wire mdio_o_dbg = md_pad_o; // MDIO bidir
(* MARK_DEBUG = "true" *) wire mdio_oe_dbg = md_padoe_o; // MDIO bidir

// (optional) keep them from being optimized away
(* DONT_TOUCH = "true" *) wire mdc_dbg_keep     = mdc_dbg;
(* DONT_TOUCH = "true" *) wire mdio_i_dbg_keep  = mdio_i_dbg;
(* DONT_TOUCH = "true" *) wire mdio_o_dbg_keep  = mdio_o_dbg;
(* DONT_TOUCH = "true" *) wire mdio_oe_dbg_keep = mdio_oe_dbg;
*/

// 2-FF synchronizer for reset de-assertion
always @(posedge i_clk or negedge SYS_RST) begin
  if (!SYS_RST) begin
    // Reset asserted (low at input) → drive internal reset high immediately
    rst_meta <= 1'b1;
    rst_sync <= 1'b1;
  end else begin
    // Deassertion synchronized to i_clk
    rst_meta <= 1'b0;
    rst_sync <= rst_meta;
  end
end

// Final internal reset, active high
wire i_reset = rst_sync;
//wire i_reset = stable_rst_sync;

/*
(* MARK_DEBUG = "true" *) wire mtx_clk_pad_dbg  = mtx_clk_pad_i;   // EthMAC MDC out
(* MARK_DEBUG = "true" *) wire [3:0] mtxd_pad_dbg = mtxd_pad_o; // MDIO bidir
(* MARK_DEBUG = "true" *) wire mtxen_pad_dbg = mtxen_pad_o; // MDIO bidir

(* MARK_DEBUG = "true" *) wire [3:0] mrxd_pad_dbg = mrxd_pad_i;
(* MARK_DEBUG = "true" *) wire mrxdv_pad_dbg = mrxdv_pad_i;

(* MARK_DEBUG = "true" *) wire ddr3_1_dbg = ddr3_init_done;
(* MARK_DEBUG = "true" *) wire ddr3_2_dbg = dfi_wrdata_en;
(* MARK_DEBUG = "true" *) wire ddr3_3_dbg = dfi_rddata_valid;
*/

//EthPHY Reference clock, 25MHz ...
wire clk25;
reg             eth_ref_clk_r1, eth_ref_clk_r2;

always @(posedge i_clk) begin
  if (i_reset) begin
    eth_ref_clk_r1 <= 'b 0;
  end else begin
    eth_ref_clk_r1 <= ~eth_ref_clk_r1;
  end
end

always @(posedge eth_ref_clk_r1) begin
  if (i_reset) begin
    eth_ref_clk_r2 <= 'b 0;
  end else begin
    eth_ref_clk_r2 <= ~eth_ref_clk_r2;
  end
end
assign clk25 = eth_ref_clk_r2;

// Drive the PHY reference clock pin
OBUF u_refclk_obuf (
  .I (clk25),
  .O (eth_ref_clk)
);

/*
IBUF u_ibuf_sysclk (
  .I(SYS_CLK),
  .O(sys_clk_ibuf)
);

BUFG u_bufg_sysclk (
  .I(sys_clk_ibuf),
  .O(sys_clk)
);
*/

/*
wire clk25;

// Divide 100 MHz i_clk by 4 → 25 MHz on a global buffer
BUFGCE_DIV #(
  .BUFGCE_DIVIDE(4)
) u_clkdiv_25 (
  .I   (i_clk),
  .CE  (1'b1),
  .CLR (1'b0),
  .O   (clk25)
);

// Drive the PHY REFCLK pin
OBUF u_refclk_obuf (
  .I (clk25),
  .O (eth_ref_clk)
);
*/

assign eth_rstn = ~i_reset;

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
wire [2:0] ethmac_m_wb_cti_o;

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

  .m_wb_cti_o(ethmac_m_wb_cti_o),
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
localparam RAM_ADDR_WIDTH        = 16;
localparam RAM_DATA_WIDTH        = 32;
localparam RAM_MEM_SIZE          = 16384;

ram_wb
      #
        (
          .adr_width(RAM_ADDR_WIDTH-2),
          .dat_width(RAM_DATA_WIDTH),
          .mem_size(RAM_MEM_SIZE),
          .MEMFILE("ethmac_zap.dump")
        )
      ram_wb (
              .clk_i(i_clk),
              .rst_i(i_reset),
              .adr_i(data_wb_adr[RAM_ADDR_WIDTH-1:2]),
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
wire [31:0] ethmac_ram_adr;
wire [31:0] ethmac_ram_dat_i;
wire [31:0] ethmac_ram_dat_o;
wire ethmac_ram_we;
wire [3:0] ethmac_ram_sel;
wire ethmac_ram_cyc;
wire ethmac_ram_stb;
wire [2:0] ethmac_ram_cti;
wire ethmac_ram_ack;

//Wishbone Arbiter ...
wb_arb2 #(
  .ADR_WIDTH(32),
  .DAT_WIDTH(32),
  .PARK_ON_M0(1)      // park on CPU
) u_arb (
  .clk     (i_clk),
  .rst     (i_reset),

  // M0: CPU
  .m0_adr_i(data_wb_adr),
  .m0_dat_i(data_wb_dout),
  .m0_dat_o(data_wb_din_ethmac_ram),
  .m0_we_i (data_wb_we),
  .m0_sel_i(data_wb_sel),
  .m0_cyc_i(data_wb_cyc_ethmac_ram),
  .m0_stb_i(data_wb_stb_ethmac_ram),
  .m0_cti_i(data_wb_cti),
  .m0_ack_o(data_wb_ack_ethmac_ram),

  // M1: EthMAC master
  .m1_adr_i(ethmac_m_wb_adr_o),
  .m1_dat_i(ethmac_m_wb_dat_o),
  .m1_dat_o(ethmac_m_wb_dat_i),
  .m1_we_i (ethmac_m_wb_we_o),
  .m1_sel_i(ethmac_m_wb_sel_o),
  .m1_cyc_i(ethmac_m_wb_cyc_o),
  .m1_stb_i(ethmac_m_wb_stb_o),
  .m1_cti_i(ethmac_m_wb_cti_o),
  .m1_ack_o(ethmac_m_wb_ack_i),

  // Slave: 8K RAM
  .s_adr_o (ethmac_ram_adr),
  .s_dat_o (ethmac_ram_dat_i),
  .s_dat_i (ethmac_ram_dat_o),
  .s_we_o  (ethmac_ram_we),
  .s_sel_o (ethmac_ram_sel),
  .s_cyc_o (ethmac_ram_cyc),
  .s_stb_o (ethmac_ram_stb),
  .s_cti_o (ethmac_ram_cti),
  .s_ack_i (ethmac_ram_ack)
);

`ifdef SYNTHESIS
   reg [23:0] count = 0;
   assign led_0 = count[23];
   assign led_1 = count[22];
   //assign led_2 = count[21];
   //assign led_3 = count[20];
   assign led_3 = ~uart_out[0:0];
   always @(posedge i_clk) count <= count + 1;

   reg [23:0] count_1 = 0;
   assign led_2 = count_1[23];
   always @(posedge clk25) count_1 <= count_1 + 1;
`endif

reset_sync_debounce reset_sync_debounce (
    .clk(i_clk),          // your i_clk (e.g., 100 MHz)
    .rst_n_in(SYS_RST),     // asynchronous, active-LOW external reset
    .rst_sync(stable_rst_sync)      // synchronous, active-HIGH reset for fabric
);

`ifdef DDR3_CONTROLLER
//-----------------------------------------------------------------
// PLL
//-----------------------------------------------------------------
wire clk;
//wire clk_ddr;
wire clk_ddr_dqs;
//wire clk_ref;
//wire clk2ddr3;

artix7_pll u_pll
(
    //.clkref_i(osc)
    .clkref_i(i_clk) //100MHz ...

    // Outputs
    //,.clkout0_o(clk)         // 100
    ,.clkout0_o(clk2ddr3)         // 100
    ,.clkout1_o(clk_ddr)     // 400
    ,.clkout2_o(clk_ref)     // 200
    ,.clkout3_o(clk_ddr_dqs) // 400 (phase 90)
);

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------
wire  [ 14:0] dfi_address;
wire  [  2:0] dfi_bank;
wire          dfi_cas_n;
wire          dfi_cke;
wire          dfi_cs_n;
wire          dfi_odt;
wire          dfi_ras_n;
wire          dfi_reset_n;
wire          dfi_we_n;
wire  [ 31:0] dfi_wrdata;
//wire          dfi_wrdata_en;
wire  [  3:0] dfi_wrdata_mask;
wire          dfi_rddata_en;
wire [ 31:0]  dfi_rddata;
//wire          dfi_rddata_valid;
wire [   1:0] dfi_rddata_dnv;

wire  [  3:0] ddr3_command;
wire  [  3:0] ddr3_state_q;

wire          cfg_valid_o;
wire  [31:0]  cfg_data_o;

wire  [15:0]  ddr3_calib_ram_wr;
wire          ddr3_calib_ram_rd;
wire  [31:0]  ddr3_calib_ram_addr;
wire [127:0]  ddr3_calib_ram_write_data;
wire  [15:0]  ddr3_calib_ram_req_id;

wire          ddr3_calib_ram_accept;
wire          ddr3_calib_ram_ack;
wire          ddr3_calib_ram_error;
wire [ 15:0]  ddr3_calib_ram_resp_id;
wire [127:0]  ddr3_calib_ram_read_data;

wire  [ 15:0] ddr3_core_ram_wr;
wire          ddr3_core_ram_rd;
wire  [ 31:0] ddr3_core_ram_addr;
wire  [127:0] ddr3_core_ram_write_data;
wire  [ 15:0] ddr3_core_ram_req_id;

wire          ddr3_core_ram_accept;
wire          ddr3_core_ram_ack;
wire          ddr3_core_ram_error;
wire [ 15:0]  ddr3_core_ram_resp_id;
wire [127:0]  ddr3_core_ram_read_data;

wire          calib_done;
wire          calib_pass;
wire  [3:0]   calib_rdsel;
wire  [5:0]   cal_best_tap;
wire  [31:0]  cal_pass_bitmap;

wire  [3:0]   ddr3_calib_state;

wire  [ 15:0] ddr3_ram_wr;
wire          ddr3_ram_rd;
wire  [ 31:0] ddr3_ram_addr;
wire  [127:0] ddr3_ram_write_data;
wire  [ 15:0] ddr3_ram_req_id;

wire          ddr3_ram_accept;
wire          ddr3_ram_ack;
wire          ddr3_ram_error;
wire [ 15:0]  ddr3_ram_resp_id;
wire [127:0]  ddr3_ram_read_data;

wire [2:0]    wb_ddr3_br_state;

assign ddr3_ram_wr = (calib_done == 0) ? ddr3_calib_ram_wr : ddr3_core_ram_wr;
assign ddr3_ram_rd = (calib_done == 0) ? ddr3_calib_ram_rd : ddr3_core_ram_rd;
assign ddr3_ram_addr = (calib_done == 0) ? ddr3_calib_ram_addr : ddr3_core_ram_addr;
assign ddr3_ram_write_data = (calib_done == 0) ? ddr3_calib_ram_write_data : ddr3_core_ram_write_data;
assign ddr3_ram_req_id = (calib_done == 0) ? ddr3_calib_ram_req_id : ddr3_core_ram_req_id;

//always @(*) if(calib_done == 0) ddr3_calib_ram_accept = ddr3_ram_accept; else ddr3_core_ram_accept = ddr3_ram_accept;
//always @(*) if(calib_done == 0) ddr3_calib_ram_ack = ddr3_ram_ack; else ddr3_core_ram_ack = ddr3_ram_ack;
//always @(*) if(calib_done == 0) ddr3_calib_ram_error = ddr3_ram_error; else ddr3_core_ram_error = ddr3_ram_error;
//always @(*) if(calib_done == 0) ddr3_calib_ram_resp_id = ddr3_ram_resp_id; else ddr3_core_ram_resp_id = ddr3_ram_resp_id;
//always @(*) if(calib_done == 0) ddr3_calib_ram_read_data = ddr3_ram_read_data; else ddr3_core_ram_read_data = ddr3_ram_read_data;

assign ddr3_calib_ram_accept = ((calib_done == 0) & ddr3_ram_accept);
assign ddr3_core_ram_accept = ((calib_done == 1) & ddr3_ram_accept);
assign ddr3_calib_ram_ack = ((calib_done == 0) & ddr3_ram_ack);
assign ddr3_core_ram_ack = ((calib_done == 1) & ddr3_ram_ack);
assign ddr3_calib_ram_error = ((calib_done == 0) & ddr3_ram_error);
assign ddr3_core_ram_error = ((calib_done == 1) & ddr3_ram_error);
assign ddr3_calib_ram_resp_id = (calib_done == 0) ? ddr3_ram_resp_id : 'h 0;
assign ddr3_core_ram_resp_id = (calib_done == 1) ? ddr3_ram_resp_id : 'h 0;
assign ddr3_calib_ram_read_data = (calib_done == 0) ? ddr3_ram_read_data : 'h 0;
assign ddr3_core_ram_read_data = (calib_done == 1) ? ddr3_ram_read_data : 'h 0;

//-----------------------------------------------------------------
// DDR PHY
//-----------------------------------------------------------------
ddr3_dfi_phy
#(
     .DQS_TAP_DELAY_INIT(27)
    ,.DQ_TAP_DELAY_INIT(0)
    ,.TPHY_RDLAT(5)
)
u_phy (
     .clk_i(clk2ddr3)
    ,.clk_ddr_i(clk_ddr)
    ,.clk_ddr90_i(clk_ddr_dqs)
    ,.clk_ref_i(clk_ref)
    ,.rst_i(i_reset)

    //,.cfg_valid_i(1'b 0)
    //,.cfg_i(32'h 0)

    ,.cfg_valid_i(cfg_valid_o)
    ,.cfg_i(cfg_data_o)

    ,.dfi_address_i(dfi_address)
    ,.dfi_bank_i(dfi_bank)
    ,.dfi_cas_n_i(dfi_cas_n)
    ,.dfi_cke_i(dfi_cke)
    ,.dfi_cs_n_i(dfi_cs_n)
    ,.dfi_odt_i(dfi_odt)
    ,.dfi_ras_n_i(dfi_ras_n)
    ,.dfi_reset_n_i(dfi_reset_n)
    ,.dfi_we_n_i(dfi_we_n)

    ,.dfi_wrdata_i(dfi_wrdata)
    ,.dfi_wrdata_en_i(dfi_wrdata_en)
    ,.dfi_wrdata_mask_i(dfi_wrdata_mask)

    ,.dfi_rddata_en_i(dfi_rddata_en)
    ,.dfi_rddata_o(dfi_rddata)
    ,.dfi_rddata_valid_o(dfi_rddata_valid)
    ,.dfi_rddata_dnv_o(dfi_rddata_dnv)

    ,.ddr3_ck_p_o(ddr3_ck_p)
    ,.ddr3_ck_n_o(ddr3_ck_n)
    ,.ddr3_cke_o(ddr3_cke)
    ,.ddr3_reset_n_o(ddr3_reset_n)
    ,.ddr3_ras_n_o(ddr3_ras_n)
    ,.ddr3_cas_n_o(ddr3_cas_n)
    ,.ddr3_we_n_o(ddr3_we_n)
    ,.ddr3_cs_n_o(ddr3_cs_n)
    ,.ddr3_ba_o(ddr3_ba)
    ,.ddr3_addr_o(ddr3_addr)
    ,.ddr3_odt_o(ddr3_odt)
    ,.ddr3_dm_o(ddr3_dm)
    ,.ddr3_dqs_p_io(ddr3_dqs_p)
    ,.ddr3_dqs_n_io(ddr3_dqs_n)
    ,.ddr3_dq_io(ddr3_dq)
); //u_phy (

//-----------------------------------------------------------------
// DDR Core
//-----------------------------------------------------------------
ddr3_core
#(
     .DDR_WRITE_LATENCY(4)
    ,.DDR_READ_LATENCY(4)
    ,.DDR_MHZ(100)
)
u_ddr_core (
     .clk_i(clk2ddr3)
    ,.rst_i(i_reset)

    // Configuration (unused)
    ,.cfg_enable_i(1'b1)
    ,.cfg_stb_i(1'b0)
    ,.cfg_data_i(32'b0)
    ,.cfg_stall_o()

    ,.init_done_o(ddr3_init_done)
    ,.command_o(ddr3_command)
    ,.state_q_o(ddr3_state_q)

    ,.inport_wr_i(ddr3_ram_wr)
    ,.inport_rd_i(ddr3_ram_rd)
    ,.inport_addr_i(ddr3_ram_addr)
    ,.inport_write_data_i(ddr3_ram_write_data)
    ,.inport_req_id_i(ddr3_ram_req_id)

    ,.inport_accept_o(ddr3_ram_accept)
    ,.inport_ack_o(ddr3_ram_ack)
    ,.inport_error_o(ddr3_ram_error)
    ,.inport_resp_id_o(ddr3_ram_resp_id)
    ,.inport_read_data_o(ddr3_ram_read_data)

    ,.dfi_address_o(dfi_address)
    ,.dfi_bank_o(dfi_bank)
    ,.dfi_cas_n_o(dfi_cas_n)
    ,.dfi_cke_o(dfi_cke)
    ,.dfi_cs_n_o(dfi_cs_n)
    ,.dfi_odt_o(dfi_odt)
    ,.dfi_ras_n_o(dfi_ras_n)
    ,.dfi_reset_n_o(dfi_reset_n)
    ,.dfi_we_n_o(dfi_we_n)
    ,.dfi_wrdata_o(dfi_wrdata)
    ,.dfi_wrdata_en_o(dfi_wrdata_en)
    ,.dfi_wrdata_mask_o(dfi_wrdata_mask)
    ,.dfi_rddata_en_o(dfi_rddata_en)
    ,.dfi_rddata_i(dfi_rddata)
    ,.dfi_rddata_valid_i(dfi_rddata_valid)
    ,.dfi_rddata_dnv_i(dfi_rddata_dnv)
); //u_ddr_core (

wb_ddr3_bridge #(
    .ADR_WIDTH(32),          // Wishbone address width
    .DAT_WIDTH(32),          // Must be 32 for this bridge
    .WB_ADDR_IS_WORD(0),     // 0: adr_i is byte address (common WB)
                           // 1: adr_i is word address (adr<<2)
    .ID_INIT(16'h0000)       // starting request id
)
u_wb_ddr3_bridge (
    .clk_i(i_clk),
    .rst_i(i_reset),      // synchronous active-high

    // ---------------- Wishbone Slave ----------------
    .dat_i(ethmac_ram_dat_i),
    .dat_o(ethmac_ram_dat_o),
    .adr_i(ethmac_ram_adr),
    .we_i(ethmac_ram_we),
    .sel_i(ethmac_ram_sel),
    .cyc_i(ethmac_ram_cyc),
    .stb_i(ethmac_ram_stb),
    .cti_i(ethmac_ram_cti),
    .ack_o(ethmac_ram_ack),

    // ---------------- DDR3 core "inport" interface ----------------
    .inport_wr_o(ddr3_core_ram_wr),        // byte strobes (16 bytes)
    .inport_rd_o(ddr3_core_ram_rd),
    .inport_addr_o(ddr3_core_ram_addr),      // byte address
    .inport_write_data_o(ddr3_core_ram_write_data),
    .inport_req_id_o(ddr3_core_ram_req_id),

    .inport_accept_i(ddr3_core_ram_accept),    // 1-cycle pulse when accepted
    .inport_ack_i(ddr3_core_ram_ack),       // 1-cycle pulse when completed
    .inport_error_i(ddr3_core_ram_error),
    .inport_resp_id_i(ddr3_core_ram_resp_id),
    .inport_read_data_i(ddr3_core_ram_read_data),

    .init_done_i(ddr3_init_done),         // optional: tie to 1 if not used

    .state(wb_ddr3_br_state)
); //u_wb_ddr3_bridge (

ddr3_calib_dqs_window
u_ddr3_calib_dqs_window (
    .clk(i_clk),
    .rst(i_reset),

    // Asserted when DDR init sequence is complete (your init_done_o)
    .ddr_init_done_i(ddr3_init_done),

    // ---------------- PHY cfg port (to ddr3_dfi_phy cfg_valid_i/cfg_i) -----------
    .cfg_valid_o(cfg_valid_o),
    .cfg_data_o(cfg_data_o),

    // ---------------- DDR core "inport" application interface -------------------
    .inport_wr_o(ddr3_calib_ram_wr),          // byte strobes (16 bytes)
    .inport_rd_o(ddr3_calib_ram_rd),
    .inport_addr_o(ddr3_calib_ram_addr),        // byte address
    .inport_write_data_o(ddr3_calib_ram_write_data),
    .inport_req_id_o(ddr3_calib_ram_req_id),

    .inport_accept_i(ddr3_calib_ram_accept),
    .inport_ack_i(ddr3_calib_ram_ack),
    .inport_error_i(ddr3_calib_ram_error),
    //.inport_resp_id_i(ddr3_calib_ram_resp_id),
    .inport_read_data_i(ddr3_calib_ram_read_data),

    // ---------------- Status -----------------------------------------------------
    .cal_done_o(calib_done),
    .cal_pass_o(calib_pass),
    .cal_best_tap_o(cal_best_tap),
    .cal_pass_bitmap_o(cal_pass_bitmap),

    .state(ddr3_calib_state)
); //u_ddr3_calib_dqs_window(
`endif //`ifdef DDR3_CONTROLLER

/*
(* MARK_DEBUG = "true" *) wire ddr3_init_done_dbg = ddr3_init_done;
(* MARK_DEBUG = "true" *) wire ethmac_ram_cyc_dbg = ethmac_ram_cyc;
(* MARK_DEBUG = "true" *) wire ethmac_ram_ack_dbg = ethmac_ram_ack;
(* MARK_DEBUG = "true" *) wire [2:0] wb_ddr3_br_state_dbg = wb_ddr3_br_state;

(* MARK_DEBUG = "true" *) wire dfi_rddata_valid_dbg = dfi_rddata_valid;
(* MARK_DEBUG = "true" *) wire [31:0] dfi_rddata_dbg = dfi_rddata;

(* MARK_DEBUG = "true" *) wire [31:0] data_wb_din_ethmac_ram_dbg = data_wb_din_ethmac_ram;
(* MARK_DEBUG = "true" *) wire dfi_wrdata_en_dbg = dfi_wrdata_en;

(* MARK_DEBUG = "true" *) wire ddr3_ram_accept_dbg = ddr3_ram_accept;
(* MARK_DEBUG = "true" *) wire [3:0] ddr3_command_dbg = ddr3_command;
(* MARK_DEBUG = "true" *) wire [3:0] ddr3_state_q_dbg = ddr3_state_q;
(* MARK_DEBUG = "true" *) wire [127:0] ddr3_ram_read_data_dbg = ddr3_ram_read_data;

//wb_ddr3_bridge.v debug signals ...
(* MARK_DEBUG = "true" *) wire wb_ddr3_ram_rd_dbg = ddr3_ram_rd;
(* MARK_DEBUG = "true" *) wire ddr3_ram_accept_dbg = ddr3_ram_accept;
(* MARK_DEBUG = "true" *) wire wb_ddr3_ram_ack_dbg = ddr3_ram_ack;
(* MARK_DEBUG = "true" *) wire [2:0] wb_ddr3_br_state_dbg = wb_ddr3_br_state;

(* MARK_DEBUG = "true" *) wire ethmac_ram_cyc_dbg = ethmac_ram_cyc;
(* MARK_DEBUG = "true" *) wire ethmac_ram_ack_dbg = ethmac_ram_ack;
(* MARK_DEBUG = "true" *) wire dfi_wrdata_en_dbg = dfi_wrdata_en;
(* MARK_DEBUG = "true" *) wire [31:0] dfi_wrdata_dbg = dfi_wrdata;
(* MARK_DEBUG = "true" *) wire dfi_rddata_valid_dbg = dfi_rddata_valid;
(* MARK_DEBUG = "true" *) wire [31:0] dfi_rddata_dbg = dfi_rddata;

(* MARK_DEBUG = "true" *) wire [15:0] ddr3_ram_wr_dbg = ddr3_ram_wr;
(* MARK_DEBUG = "true" *) wire ddr3_ram_accept_dbg = ddr3_ram_accept;
(* MARK_DEBUG = "true" *) wire [2:0] wb_ddr3_br_state_dbg = wb_ddr3_br_state;
(* MARK_DEBUG = "true" *) wire [3:0] ddr3_state_q_dbg = ddr3_state_q;

(* MARK_DEBUG = "true" *) wire [15:0] ddr3_rd_data0_w_dbg = zap_soc.u_phy.rd_data0_w;
(* MARK_DEBUG = "true" *) wire [15:0] ddr3_rd_data1_w_dbg = zap_soc.u_phy.rd_data1_w;
(* MARK_DEBUG = "true" *) wire [15:0] ddr3_rd_data2_w_dbg = zap_soc.u_phy.rd_data2_w;
(* MARK_DEBUG = "true" *) wire [15:0] ddr3_rd_data3_w_dbg = zap_soc.u_phy.rd_data3_w;
*/

(* MARK_DEBUG = "true" *) wire ddr3_init_done_dbg = ddr3_init_done;
(* MARK_DEBUG = "true" *) wire calib_done_dbg = calib_done;
(* MARK_DEBUG = "true" *) wire calib_pass_dbg = calib_pass;
(* MARK_DEBUG = "true" *) wire mmu_en_dbg = zap_soc.u_zap_top.cpu_mmu_en;
(* MARK_DEBUG = "true" *) wire dc_en_dbg = zap_soc.u_zap_top.cpu_dc_en;
(* MARK_DEBUG = "true" *) wire ic_en_dbg = zap_soc.u_zap_top.cpu_ic_en;

endmodule // zap_soc
