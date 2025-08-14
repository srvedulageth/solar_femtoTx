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
//`timescale 1ps/1ps
`include "timescale.v"

module zap_test;

localparam STRING_LENGTH                = 12;

reg i_clk = 0;
initial begin
   forever #5 i_clk = ~i_clk; //100MHz
end

reg clk_baud_19200 = 0;
initial begin
  //forever #2605 clk_baud_19200 = ~clk_baud_19200;
  forever #26040 clk_baud_19200 = ~clk_baud_19200;
end

reg i_reset;
initial begin
  i_reset = 'b 1;
  repeat(10) @(posedge i_clk);
  #1;
  i_reset = 'b 0;
end

`ifdef DUAL_UART
reg [1:0]                  i_uart = 2'b11;
reg [1:0]                  o_uart;
`else
reg [0:0]                  i_uart = 'b1;
reg [0:0]                  o_uart;
`endif

reg [3:0]                  clk_ctr = 4'd0;
//reg [STRING_LENGTH*8-1:0]  uart_string = "DLROW OLLEH ";
reg [STRING_LENGTH*8-1:0]  uart_string = "OLLEH ";
reg [6:0]                  uart_ctr    = 7'd10;
reg [31:0]                 btrace      = 32'd0;
reg                        uart_done = 1'd0;
//reg [8:0]                  uart_init_done = 9'd0;
reg [3:0]                  uart_init_done = 4'd0;

wire            UART_SR_DAV_0;
wire    [7:0]   UART_SR_0;
`ifdef DUAL_UART
wire            UART_SR_DAV_1;
wire    [7:0]   UART_SR_1;
`endif

// Divided clocks.
reg clk_2 = 1'd0, clk_4 = 1'd0, clk_8 = 1'd0, clk_16 = 1'd0;

// Digital clock dividers.
always @ ( posedge i_clk ) clk_2 = clk_2 + 1;
always @ ( posedge clk_2 ) clk_4 = clk_4 + 1;
always @ ( posedge clk_4 ) clk_8 = clk_8 + 1;
always @ ( posedge clk_8 ) clk_16 = clk_16 + 1;

//always @ ( posedge clk_16 )
always @ ( posedge clk_baud_19200 )
begin
        if ( !(&uart_init_done) )
                uart_init_done <= uart_init_done + 1;
end

// UART data into the core.
//always @ ( posedge clk_16 ) if ( !uart_done && (&uart_init_done) )
always @ ( posedge clk_baud_19200 ) if ( !uart_done && (&uart_init_done) )
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

// UART TX related. Data out of core.
//uart_tx_dumper u_uart_tx_dumper_dev0 (  .i_clk(i_clk), .i_line(o_uart[0]),
uart_tx_dumper u_uart_tx_dumper_dev0 (  .i_clk(clk_baud_19200), .i_line(o_uart[0]),
                                        .UART_SR_DAV(UART_SR_DAV_0), .UART_SR(UART_SR_0) );
`ifdef DUAL_UART
uart_tx_dumper u_uart_tx_dumper_dev1 (  .i_clk(i_clk), .i_line(o_uart[1]),
                                        .UART_SR_DAV(UART_SR_DAV_1), .UART_SR(UART_SR_1) );
`endif

// DUT
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
        // Clk and rst
        .SYS_CLK  (i_clk),
        .SYS_RST  (i_reset),

        // UART 0
        .UART0_RXD(i_uart[0]),
        .UART0_TXD(o_uart[0])

`ifdef DUAL_UART
        ,
        // UART 1
        .UART1_RXD(i_uart[1]),
        .UART1_TXD(o_uart[1])
`endif

        //Wishbone External Master Interface
        //.int_sel  ('b 1)
);

initial begin
  $dumpfile("zap.vcd");
  $dumpvars(0);
end

initial begin
  #100;
  wait(uart_done);
  //repeat(1000)  @(posedge clk_16);
  repeat(10)  @(posedge clk_baud_19200);
  $display("Simulation OK");
  $finish;
end

always @(posedge UART_SR_DAV_0) begin
  $display("Transmitted UART Data = %h", UART_SR_0);
end
endmodule //zap_test
