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

        // UART 0
        input  wire         UART0_RXD,
        output wire         UART0_TXD,

        // UART 1
        input  wire         UART1_RXD,
        output wire         UART1_TXD,

        // Interrupt sel..
        input wire          int_sel,

        // Remaining IRQs to the interrupt controller.
        input   wire [27:0] I_IRQ,

        // Single FIQ input directly to ZAP CPU.
        input   wire        I_FIQ,

        // External Wishbone Connection (for RAMs etc).
        output reg          O_WB_STB,
        output reg          O_WB_CYC,
        output wire [31:0]  O_WB_DAT,
        output wire [31:0]  O_WB_ADR,
        output wire [3:0]   O_WB_SEL,
        output wire         O_WB_WE,
        output wire [2:0]   O_WB_CTI,
        input  wire         I_WB_ACK,
        input  wire [31:0]  I_WB_DAT
);

// Peripheral addresses.
localparam UART0_LO                     = 32'hFFFFFFE0;
localparam UART0_HI                     = 32'hFFFFFFFF;
localparam TIMER0_LO                    = 32'hFFFFFFC0;
localparam TIMER0_HI                    = 32'hFFFFFFDF;
localparam VIC_LO                       = 32'hFFFFFFA0;
localparam VIC_HI                       = 32'hFFFFFFBF;
localparam UART1_LO                     = 32'hFFFFFF80;
localparam UART1_HI                     = 32'hFFFFFF9F;
localparam TIMER1_LO                    = 32'hFFFFFF60;
localparam TIMER1_HI                    = 32'hFFFFFF7F;

// Internal signals.
wire            i_clk    = SYS_CLK;
wire            i_reset  = SYS_RST;

wire [1:0]      uart_in;
wire [1:0]      uart_out;

assign          {UART1_TXD, UART0_TXD} = uart_out;
assign          uart_in = {UART1_RXD, UART0_RXD};

wire            data_wb_cyc;
wire            data_wb_stb;
reg [31:0]      data_wb_din;
reg             data_wb_ack;
reg             data_wb_cyc_uart [1:0], data_wb_cyc_timer [1:0], data_wb_cyc_vic;
reg             data_wb_stb_uart [1:0], data_wb_stb_timer [1:0], data_wb_stb_vic;
wire [31:0]     data_wb_din_uart [1:0], data_wb_din_timer [1:0], data_wb_din_vic;
wire            data_wb_ack_uart [1:0], data_wb_ack_timer [1:0], data_wb_ack_vic;
wire [3:0]      data_wb_sel;
wire            data_wb_we;
wire [31:0]     data_wb_dout;
wire [31:0]     data_wb_adr;
wire [2:0]      data_wb_cti; // Cycle Type Indicator.
wire            global_irq;
wire [1:0]      uart_irq;
wire [1:0]      timer_irq;

// Common WB signals to output.
assign        O_WB_ADR        = data_wb_adr;
assign        O_WB_WE         = data_wb_we;
assign        O_WB_DAT        = data_wb_dout;
assign        O_WB_SEL        = data_wb_sel;
assign        O_WB_CTI        = data_wb_cti;

// Wishbone fabric.
always @*
begin:blk1
        integer ii;

        for(ii=0;ii<=1;ii=ii+1)
        begin
                data_wb_cyc_uart [ii]  = 0;
                data_wb_stb_uart [ii]  = 0;
                data_wb_cyc_timer[ii] = 0;
                data_wb_stb_timer[ii] = 0;
        end

        data_wb_cyc_vic   = 0;
        data_wb_stb_vic   = 0;

        O_WB_CYC          = 0;
        O_WB_STB          = 0;

        if ( data_wb_adr >= UART0_LO && data_wb_adr <= UART0_HI )        // UART0 access
        begin
                data_wb_cyc_uart[0] = data_wb_cyc;
                data_wb_stb_uart[0] = data_wb_stb;
                data_wb_ack        = data_wb_ack_uart[0];
                data_wb_din        = data_wb_din_uart[0];
        end
        else if ( data_wb_adr >= TIMER0_LO && data_wb_adr <= TIMER0_HI )  // Timer0 access
        begin
                data_wb_cyc_timer[0] = data_wb_cyc;
                data_wb_stb_timer[0] = data_wb_stb;
                data_wb_ack          = data_wb_ack_timer[0];
                data_wb_din          = data_wb_din_timer[0];
        end
        else if ( data_wb_adr >= VIC_LO && data_wb_adr <= VIC_HI )        // VIC access.
        begin
                data_wb_cyc_vic   = data_wb_cyc;
                data_wb_stb_vic   = data_wb_stb;
                data_wb_ack       = data_wb_ack_vic;
                data_wb_din       = data_wb_din_vic;
        end
        else if ( data_wb_adr >= UART1_LO && data_wb_adr <= UART1_HI )    // UART1 access
        begin
                data_wb_cyc_uart[1] = data_wb_cyc;
                data_wb_stb_uart[1] = data_wb_stb;
                data_wb_ack        = data_wb_ack_uart[1];
                data_wb_din        = data_wb_din_uart[1];
        end
        else if ( data_wb_adr >= TIMER1_LO && data_wb_adr <= TIMER1_HI )  // Timer1 access
        begin
                data_wb_cyc_timer[1] = data_wb_cyc;
                data_wb_stb_timer[1] = data_wb_stb;
                data_wb_ack          = data_wb_ack_timer[1];
                data_wb_din          = data_wb_din_timer[1];
        end
        else // External WB access.
        begin
                O_WB_CYC         = data_wb_cyc;
                O_WB_STB         = data_wb_stb;
                data_wb_ack      = I_WB_ACK;
                data_wb_din      = I_WB_DAT;
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
        .i_irq    (int_sel == 1'd0 ? global_irq : I_FIQ),
        .i_fiq    (int_sel == 1'd1 ? global_irq : I_FIQ),
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

);

// ===============================
// 2 x UART + 2 x Timer
// ===============================

genvar gi;
generate
        for(gi=0;gi<=1;gi=gi+1)
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
        .i_irq({I_IRQ, timer_irq[1], uart_irq[1], timer_irq[0], uart_irq[0]}), // Concatenate 32 interrupt sources.
        .o_irq(global_irq)                                                     // Interrupt out
);

endmodule // zap_soc
