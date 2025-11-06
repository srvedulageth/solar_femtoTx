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
  repeat(50) @(posedge i_clk);
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
reg [STRING_LENGTH*8-1:0]  uart_string = "H";
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

//EthMAC
//Tx
wire              mtx_clk_pad_i; // Transmit clock (from PHY)
wire [3:0]        mtxd_pad_o;    // Transmit nibble (to PHY)
wire              mtxen_pad_o;   // Transmit enable (to PHY)
wire              mtxerr_pad_o;  // Transmit error (to PHY)

//Rx
wire              mrx_clk_pad_i; // Receive clock (from PHY)
wire [3:0]        mrxd_pad_i;    // Receive nibble (from PHY)
wire              mrxdv_pad_i;   // Receive data valid (from PHY)
wire              mrxerr_pad_i;  // Receive data error (from PHY)

//Common Tx and Rx
wire              mcoll_pad_i;   // Collision (from PHY)
wire              mcrs_pad_i;    // Carrier sense (from PHY)

//Phy Reference Clock and Reset ...
wire              eth_ref_clk;
wire              eth_rstn;

// MIIM MII Management interface
wire              mdc_pad_o;     // MII Management data clock (to PHY)
wire              mdio_pad_io;

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

        //EthMAC
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
  
        //Phy Reference Clock and Reset ...
        .eth_ref_clk(eth_ref_clk),
        .eth_rstn(eth_rstn),

        // MIIM
        .mdc_pad_o(mdc_pad_o),
        .mdio_pad_io(mdio_pad_io),

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

integer phy_log_file_desc;
initial begin
  phy_log_file_desc = $fopen("./eth_tb_phy.log");
end

eth_phy eth_phy (
  // WISHBONE reset
  .m_rst_n_i(!i_reset),

  // MAC TX
  .mtx_clk_o(mtx_clk_pad_i),    .mtxd_i(mtxd_pad_o),    .mtxen_i(mtxen_pad_o),    .mtxerr_i(mtxerr_pad_o),

  // MAC RX
  .mrx_clk_o(mrx_clk_pad_i),    .mrxd_o(mrxd_pad_i),    .mrxdv_o(mrxdv_pad_i),    .mrxerr_o(mrxdv_pad_i),
  .mcoll_o(mcoll_pad_i),        .mcrs_o(mcrs_pad_i),

  // MIIM
  .mdc_i(mdc_pad_o),          .md_io(mdio_pad_io),

  // SYSTEM
  .phy_log(phy_log_file_desc)
  //.phy_log() //Not connected
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

initial begin
  #50000ns;
  eth_phy.link_up_down(1);
end

task set_rx_packet;
  input  [31:0] rxpnt;
  input  [15:0] len;
  input         plus_dribble_nibble; // if length is longer for one nibble
  input  [47:0] eth_dest_addr;
  input  [47:0] eth_source_addr;
  input  [15:0] eth_type_len;
  input  [7:0]  eth_start_data;
  integer       i, sd;
  reg    [47:0] dest_addr;
  reg    [47:0] source_addr;
  reg    [15:0] type_len;
  reg    [21:0] buffer;
  reg           delta_t;
begin
  buffer = rxpnt[21:0];
  dest_addr = eth_dest_addr;
  source_addr = eth_source_addr;
  type_len = eth_type_len;
  sd = eth_start_data;
  delta_t = 0;
  for(i = 0; i < len; i = i + 1) 
  begin
    if (i < 6)
    begin
      eth_phy.rx_mem[buffer] = dest_addr[47:40];
      dest_addr = dest_addr << 8;
    end
    else if (i < 12)
    begin
      eth_phy.rx_mem[buffer] = source_addr[47:40];
      source_addr = source_addr << 8;
    end
    else if (i < 14)
    begin
      eth_phy.rx_mem[buffer] = type_len[15:8];
      type_len = type_len << 8;
    end
    else
    begin
      eth_phy.rx_mem[buffer] = sd[7:0];
      sd = sd + 1;
    end
    buffer = buffer + 1;
  end
  delta_t = !delta_t;
  if (plus_dribble_nibble)
    eth_phy.rx_mem[buffer] = {4'h0, 4'hD /*sd[3:0]*/};
  delta_t = !delta_t;
end
endtask // set_rx_packet

task append_rx_crc;
  input  [31:0] rxpnt_phy; // source
  input  [15:0] len; // length in bytes without CRC
  input         plus_dribble_nibble; // if length is longer for one nibble
  input         negated_crc; // if appended CRC is correct or not
  reg    [31:0] crc;
  reg    [7:0]  tmp;
  reg    [31:0] addr_phy;
  reg           delta_t;
begin
  addr_phy = rxpnt_phy + len;
  delta_t = 0;
  // calculate CRC from prepared packet
  paralel_crc_phy_rx(rxpnt_phy, {16'h0, len}, plus_dribble_nibble, crc);
  if (negated_crc)
    crc = ~crc;
  delta_t = !delta_t;

  if (plus_dribble_nibble)
  begin
    tmp = eth_phy.rx_mem[addr_phy];
    eth_phy.rx_mem[addr_phy]     = {crc[27:24], tmp[3:0]};
    eth_phy.rx_mem[addr_phy + 1] = {crc[19:16], crc[31:28]};
    eth_phy.rx_mem[addr_phy + 2] = {crc[11:8], crc[23:20]};
    eth_phy.rx_mem[addr_phy + 3] = {crc[3:0], crc[15:12]};
    eth_phy.rx_mem[addr_phy + 4] = {4'h0, crc[7:4]};
  end
  else
  begin
    eth_phy.rx_mem[addr_phy]     = crc[31:24];
    eth_phy.rx_mem[addr_phy + 1] = crc[23:16];
    eth_phy.rx_mem[addr_phy + 2] = crc[15:8];
    eth_phy.rx_mem[addr_phy + 3] = crc[7:0];
  end
end
endtask // append_rx_crc

// paralel CRC calculating for PHY RX
task paralel_crc_phy_rx;
  input  [31:0] start_addr; // start address
  input  [31:0] len; // length of frame in Bytes without CRC length
  input         plus_dribble_nibble; // if length is longer for one nibble
  output [31:0] crc_out;
  reg    [21:0] addr_cnt; // only 22 address lines
  integer       word_cnt;
  integer       nibble_cnt;
  reg    [31:0] load_reg;
  reg           delta_t;
  reg    [31:0] crc_next;
  reg    [31:0] crc;
  reg           crc_error;
  reg     [3:0] data_in;
  integer       i;
begin
  #1 addr_cnt = start_addr[21:0];
  word_cnt = 24; // 27; // start of the frame - nibble granularity (MSbit first)
  crc = 32'hFFFF_FFFF; // INITIAL value
  delta_t = 0;
  // length must include 4 bytes of ZEROs, to generate CRC
  // get number of nibbles from Byte length (2^1 = 2)
  if (plus_dribble_nibble)
    nibble_cnt = ((len + 4) << 1) + 1'b1; // one nibble longer
  else
    nibble_cnt = ((len + 4) << 1);
  // because of MAGIC NUMBER nibbles are swapped [3:0] -> [0:3]
  load_reg[31:24] = eth_phy.rx_mem[addr_cnt];
  addr_cnt = addr_cnt + 1;
  load_reg[23:16] = eth_phy.rx_mem[addr_cnt];
  addr_cnt = addr_cnt + 1;
  load_reg[15: 8] = eth_phy.rx_mem[addr_cnt];
  addr_cnt = addr_cnt + 1;
  load_reg[ 7: 0] = eth_phy.rx_mem[addr_cnt];
  addr_cnt = addr_cnt + 1;
  while (nibble_cnt > 0)
  begin
    // wait for delta time
    delta_t = !delta_t;
    // shift data in

    if(nibble_cnt <= 8) // for additional 8 nibbles shift ZEROs in!
      data_in[3:0] = 4'h0;
    else

      data_in[3:0] = {load_reg[word_cnt], load_reg[word_cnt+1], load_reg[word_cnt+2], load_reg[word_cnt+3]};
    crc_next[0]  = (data_in[0] ^ crc[28]);
    crc_next[1]  = (data_in[1] ^ data_in[0] ^ crc[28]    ^ crc[29]);
    crc_next[2]  = (data_in[2] ^ data_in[1] ^ data_in[0] ^ crc[28]  ^ crc[29] ^ crc[30]);
    crc_next[3]  = (data_in[3] ^ data_in[2] ^ data_in[1] ^ crc[29]  ^ crc[30] ^ crc[31]);
    crc_next[4]  = (data_in[3] ^ data_in[2] ^ data_in[0] ^ crc[28]  ^ crc[30] ^ crc[31]) ^ crc[0];
    crc_next[5]  = (data_in[3] ^ data_in[1] ^ data_in[0] ^ crc[28]  ^ crc[29] ^ crc[31]) ^ crc[1];
    crc_next[6]  = (data_in[2] ^ data_in[1] ^ crc[29]    ^ crc[30]) ^ crc[ 2];
    crc_next[7]  = (data_in[3] ^ data_in[2] ^ data_in[0] ^ crc[28]  ^ crc[30] ^ crc[31]) ^ crc[3];
    crc_next[8]  = (data_in[3] ^ data_in[1] ^ data_in[0] ^ crc[28]  ^ crc[29] ^ crc[31]) ^ crc[4];
    crc_next[9]  = (data_in[2] ^ data_in[1] ^ crc[29]    ^ crc[30]) ^ crc[5];
    crc_next[10] = (data_in[3] ^ data_in[2] ^ data_in[0] ^ crc[28]  ^ crc[30] ^ crc[31]) ^ crc[6];
    crc_next[11] = (data_in[3] ^ data_in[1] ^ data_in[0] ^ crc[28]  ^ crc[29] ^ crc[31]) ^ crc[7];
    crc_next[12] = (data_in[2] ^ data_in[1] ^ data_in[0] ^ crc[28]  ^ crc[29] ^ crc[30]) ^ crc[8];
    crc_next[13] = (data_in[3] ^ data_in[2] ^ data_in[1] ^ crc[29]  ^ crc[30] ^ crc[31]) ^ crc[9];
    crc_next[14] = (data_in[3] ^ data_in[2] ^ crc[30]    ^ crc[31]) ^ crc[10];
    crc_next[15] = (data_in[3] ^ crc[31])   ^ crc[11];
    crc_next[16] = (data_in[0] ^ crc[28])   ^ crc[12];
    crc_next[17] = (data_in[1] ^ crc[29])   ^ crc[13];
    crc_next[18] = (data_in[2] ^ crc[30])   ^ crc[14];
    crc_next[19] = (data_in[3] ^ crc[31])   ^ crc[15];
    crc_next[20] =  crc[16];
    crc_next[21] =  crc[17];
    crc_next[22] = (data_in[0] ^ crc[28])   ^ crc[18];
    crc_next[23] = (data_in[1] ^ data_in[0] ^ crc[29]    ^ crc[28]) ^ crc[19];
    crc_next[24] = (data_in[2] ^ data_in[1] ^ crc[30]    ^ crc[29]) ^ crc[20];
    crc_next[25] = (data_in[3] ^ data_in[2] ^ crc[31]    ^ crc[30]) ^ crc[21];
    crc_next[26] = (data_in[3] ^ data_in[0] ^ crc[31]    ^ crc[28]) ^ crc[22];
    crc_next[27] = (data_in[1] ^ crc[29])   ^ crc[23];
    crc_next[28] = (data_in[2] ^ crc[30])   ^ crc[24];
    crc_next[29] = (data_in[3] ^ crc[31])   ^ crc[25];
    crc_next[30] =  crc[26];
    crc_next[31] =  crc[27];

    crc = crc_next;
    crc_error = crc[31:0] != 32'hc704dd7b;  // CRC not equal to magic number
    case (nibble_cnt)
    9: crc_out = {!crc[24], !crc[25], !crc[26], !crc[27], !crc[28], !crc[29], !crc[30], !crc[31],
                  !crc[16], !crc[17], !crc[18], !crc[19], !crc[20], !crc[21], !crc[22], !crc[23],
                  !crc[ 8], !crc[ 9], !crc[10], !crc[11], !crc[12], !crc[13], !crc[14], !crc[15],
                  !crc[ 0], !crc[ 1], !crc[ 2], !crc[ 3], !crc[ 4], !crc[ 5], !crc[ 6], !crc[ 7]};
    default: crc_out = crc_out;
    endcase
    // wait for delta time
    delta_t = !delta_t;
    // increment address and load new data
    if ((word_cnt+3) == 7)//4)
    begin
      // because of MAGIC NUMBER nibbles are swapped [3:0] -> [0:3]
      load_reg[31:24] = eth_phy.rx_mem[addr_cnt];
      addr_cnt = addr_cnt + 1;
      load_reg[23:16] = eth_phy.rx_mem[addr_cnt];
      addr_cnt = addr_cnt + 1;
      load_reg[15: 8] = eth_phy.rx_mem[addr_cnt];
      addr_cnt = addr_cnt + 1;
      load_reg[ 7: 0] = eth_phy.rx_mem[addr_cnt];
      addr_cnt = addr_cnt + 1;
    end
    // set new load bit position
    if((word_cnt+3) == 31)
      word_cnt = 16;
    else if ((word_cnt+3) == 23)
      word_cnt = 8;
    else if ((word_cnt+3) == 15)
      word_cnt = 0;
    else if ((word_cnt+3) == 7)
      word_cnt = 24;
    else
      word_cnt = word_cnt + 4;// - 4;
    // decrement nibble counter
    nibble_cnt = nibble_cnt - 1;
    // wait for delta time
    delta_t = !delta_t;
  end // while
  #1;
end
endtask // paralel_crc_phy_rx

integer loop_count;
initial begin
  while(1) begin
    #100ns;
    wait(u_chip_top.ethmac.txethmac1.TxDone == 'b 0);
    #100ns;
    wait(u_chip_top.ethmac.txethmac1.TxDone == 'b 1);
    #20000ns;
    //Start Rx ...
    $display("Rx Begin");
    set_rx_packet(0, 'h 5FC, 1'b0, 48'hAA02_0304_0506, 48'h0708_090A_0B0C, 16'h0D0E, 8'h0F); // length without CRC
    append_rx_crc (0, 'h 3c, 1'b0, 1'b0);
    #1 eth_phy.send_rx_packet(64'h0055_5555_5555_5555, 4'h7, 8'hD5, 0, 'h 40, 1'b0);
    repeat(10000) @(posedge i_clk);
    $display("Rx Done");
  end
end

always @(posedge UART_SR_DAV_0) begin
  $display("Transmitted UART Data = %h", UART_SR_0);
end
endmodule //zap_test
