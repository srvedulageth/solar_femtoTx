//
// (C)2016-2024 Revanth Kamaraj (krevanth) <revanth91kamaraj@gmail.com>
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 3
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
// 02110-1301, USA.
//

//
// UART0  address space FFFFFFE0 to FFFFFFFF
// Timer0 address space FFFFFFC0 to FFFFFFDF
// VIC0   address space FFFFFFA0 to FFFFFFBF
// UART1  address space FFFFFF80 to FFFFFF9F
// Timer1 address space FFFFFF60 to FFFFFF7F
//

module zap_test (
        input  wire            i_clk,
        input  wire            i_reset,
        input  wire            i_int_sel,

        output reg             o_sim_ok = 1'd0,
        output reg             o_sim_err = 1'd0,

        output reg             o_wb_stb,
        output reg             o_wb_cyc,
        output reg     [31:0]  o_wb_adr,
        output reg     [3:0]   o_wb_sel,
        output reg             o_wb_we,
        output reg     [31:0]  o_wb_dat,
        output reg      [2:0]  o_wb_cti,
        input  wire            i_wb_ack,
        input  wire    [31:0]  i_wb_dat,

        input  wire    [7:0]   i_mem [65536-1:0],

        output wire            UART_SR_DAV_0,
        output wire            UART_SR_DAV_1,
        output wire    [7:0]   UART_SR_0,
        output wire    [7:0]   UART_SR_1
);

initial
begin
        $dumpfile("zap.vcd");
        $dumpvars;
end

parameter DATA_SECTION_TLB_ENTRIES      = 4;
parameter DATA_LPAGE_TLB_ENTRIES        = 8;
parameter DATA_SPAGE_TLB_ENTRIES        = 16;
parameter DATA_FPAGE_TLB_ENTRIES        = 32;
parameter DATA_CACHE_SIZE               = 1024;
parameter CODE_SECTION_TLB_ENTRIES      = 4;
parameter CODE_LPAGE_TLB_ENTRIES        = 8;
parameter CODE_SPAGE_TLB_ENTRIES        = 16;
parameter CODE_FPAGE_TLB_ENTRIES        = 32;
parameter CODE_CACHE_SIZE               = 1024;
parameter FIFO_DEPTH                    = 4;
parameter BP_ENTRIES                    = 1024;
parameter ONLY_CORE                     = 0;
parameter BE_32_ENABLE                  = 0;


localparam STRING_LENGTH                = 12;

reg [1:0]                  i_uart = 2'b11;
reg [1:0]                  o_uart;
reg [31:0]                 i;
reg [3:0]                  clk_ctr = 4'd0;
reg [STRING_LENGTH*8-1:0]  uart_string = "DLROW OLLEH ";
reg [6:0]                  uart_ctr    = 6'd10;
reg [31:0]                 btrace      = 32'd0;
reg [31:0]                 mem [65536/4-1:0]; // 16K words.
reg                        uart_done = 1'd0;
reg [8:0]                  uart_init_done = 8'd0;

// Divided clocks.
reg clk_2 = 1'd0, clk_4 = 1'd0, clk_8 = 1'd0, clk_16 = 1'd0;

// Digital clock dividers.
always @ ( posedge i_clk )
        clk_2 = clk_2 + 1;

always @ ( posedge clk_2 )
        clk_4 = clk_4 + 1;

always @ ( posedge clk_4 )
        clk_8 = clk_8 + 1;

always @ ( posedge clk_8 )
        clk_16 = clk_16 + 1;

always @ ( posedge clk_16 )
begin
        if ( !(&uart_init_done) )
                uart_init_done <= uart_init_done + 1;
end

// UART data into the core.
always @ ( posedge clk_16 ) if ( !uart_done && (&uart_init_done) )
begin
        if ( uart_ctr <= 8 )
        begin
                i_uart[0] <= uart_ctr == 0 ? 0 : uart_string[((btrace*8) + uart_ctr - 1)];
                uart_ctr  <= uart_ctr + 1;
        end
        else if ( uart_ctr == 9 )
        begin
                uart_ctr  <= uart_ctr + 1;
                i_uart[0] <= 1'd1;
        end
        else
        begin
                uart_ctr  <= uart_ctr + 1;
                i_uart[0] <= 1'd1;

                if ( &uart_ctr )
                begin
                        btrace <= (btrace == STRING_LENGTH - 1) ? 0 : btrace + 1;

                        if ( btrace == STRING_LENGTH - 1 )
                                uart_done <= 1;
                end
        end
end

// Create memory for easy analysis.
always @ (*)
begin
        for(int i=0;i<65536;i=i+4)
                mem[i/4] = {i_mem[i+3], i_mem[i+2], i_mem[i+1], i_mem[i]};
end

// UART TX related. Data out of core.
uart_tx_dumper u_uart_tx_dumper_dev0 (  .i_clk(i_clk), .i_line(o_uart[0]),
                                        .UART_SR_DAV(UART_SR_DAV_0), .UART_SR(UART_SR_0) );
uart_tx_dumper u_uart_tx_dumper_dev1 (  .i_clk(i_clk), .i_line(o_uart[1]),
                                        .UART_SR_DAV(UART_SR_DAV_1), .UART_SR(UART_SR_1) );

// DUT
zap_soc #(
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
        .CODE_CACHE_SIZE(CODE_CACHE_SIZE),
        .BE_32_ENABLE(BE_32_ENABLE),
        .ONLY_CORE(ONLY_CORE)
) u_chip_top (
        .SYS_CLK  (i_clk),
        .SYS_RST  (i_reset),
        .UART0_RXD(i_uart[0]),
        .UART0_TXD(o_uart[0]),
        .UART1_RXD(i_uart[1]),
        .UART1_TXD(o_uart[1]),
        .int_sel  (i_int_sel),
        .I_IRQ    (28'd0),
        .I_FIQ    (1'd0),
        .O_WB_STB (o_wb_stb),
        .O_WB_CYC (o_wb_cyc),
        .O_WB_DAT (o_wb_dat),
        .O_WB_ADR (o_wb_adr),
        .O_WB_SEL (o_wb_sel),
        .O_WB_WE  (o_wb_we),
        .I_WB_ACK (i_wb_ack),
        .I_WB_DAT (i_wb_dat),
        .O_WB_CTI(o_wb_cti)
);

integer sim_ctr = 0;

always @ ( posedge i_clk )
begin
        sim_ctr <= sim_ctr + 1;

        if ( sim_ctr == `MAX_CLOCK_CYCLES )
        begin
                o_sim_ok <= 1'd1;

                `include "zap_check.vh"
        end
end

// Expose the CPU registers.
wire [31:0] r0   =  `REG_HIER.mem[0];
wire [31:0] r1   =  `REG_HIER.mem[1];
wire [31:0] r2   =  `REG_HIER.mem[2];
wire [31:0] r3   =  `REG_HIER.mem[3];
wire [31:0] r4   =  `REG_HIER.mem[4];
wire [31:0] r5   =  `REG_HIER.mem[5];
wire [31:0] r6   =  `REG_HIER.mem[6];
wire [31:0] r7   =  `REG_HIER.mem[7];
wire [31:0] r8   =  `REG_HIER.mem[8];
wire [31:0] r9   =  `REG_HIER.mem[9];
wire [31:0] r10  =  `REG_HIER.mem[10];
wire [31:0] r11  =  `REG_HIER.mem[11];
wire [31:0] r12  =  `REG_HIER.mem[12];
wire [31:0] r13  =  `REG_HIER.mem[13];
wire [31:0] r14  =  `REG_HIER.mem[14];
wire [31:0] r15  =  `REG_HIER.mem[15];
wire [31:0] r16  =  `REG_HIER.mem[16];
wire [31:0] r17  =  `REG_HIER.mem[17];
wire [31:0] r18  =  `REG_HIER.mem[18];
wire [31:0] r19  =  `REG_HIER.mem[19];
wire [31:0] r20  =  `REG_HIER.mem[20];
wire [31:0] r21  =  `REG_HIER.mem[21];
wire [31:0] r22  =  `REG_HIER.mem[22];
wire [31:0] r23  =  `REG_HIER.mem[23];
wire [31:0] r24  =  `REG_HIER.mem[24];
wire [31:0] r25  =  `REG_HIER.mem[25];
wire [31:0] r26  =  `REG_HIER.mem[26];
wire [31:0] r27  =  `REG_HIER.mem[27];
wire [31:0] r28  =  `REG_HIER.mem[28];
wire [31:0] r29  =  `REG_HIER.mem[29];
wire [31:0] r30  =  `REG_HIER.mem[30];
wire [31:0] r31  =  `REG_HIER.mem[31];
wire [31:0] r32  =  `REG_HIER.mem[32];
wire [31:0] r33  =  `REG_HIER.mem[33];
wire [31:0] r34  =  `REG_HIER.mem[34];
wire [31:0] r35  =  `REG_HIER.mem[35];
wire [31:0] r36  =  `REG_HIER.mem[36];
wire [31:0] r37  =  `REG_HIER.mem[37];
wire [31:0] r38  =  `REG_HIER.mem[38];
wire [31:0] r39  =  `REG_HIER.mem[39];

endmodule //zap_test
