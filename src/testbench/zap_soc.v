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
        // Clk and rst
        input wire          SYS_CLK,
        input wire          SYS_RST,

`ifdef SYNTHESIS
        output wire         led_0,
        output wire         led_1,
        output wire         led_2,
        output wire         led_3,
`endif

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
              .dat_o(ethmac_ram_dat_o),
              .cyc_i(ethmac_ram_cyc),
              .stb_i(ethmac_ram_stb),
              .ack_o(ethmac_ram_ack),
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
endmodule // zap_soc
