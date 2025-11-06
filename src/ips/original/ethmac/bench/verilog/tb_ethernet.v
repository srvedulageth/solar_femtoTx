
`include "eth_phy_defines.v"
`include "wb_model_defines.v"
`include "tb_eth_defines.v"
`include "ethmac_defines.v"
`include "timescale.v"
`define VCD
module tb_ethernet();


reg           wb_clk;
reg           wb_rst;
wire          wb_int;

wire          mtx_clk;  // This goes to PHY
wire          mrx_clk;  // This goes to PHY

wire   [3:0]  MTxD;
wire          MTxEn;
wire          MTxErr;

wire   [3:0]  MRxD;     // This goes to PHY
wire          MRxDV;    // This goes to PHY
wire          MRxErr;   // This goes to PHY
wire          MColl;    // This goes to PHY
wire          MCrs;     // This goes to PHY

wire          Mdi_I;
wire          Mdo_O;
wire          Mdo_OE;
tri           Mdio_IO;
wire          Mdc_O;


parameter Tp = 1;


// Ethernet Slave Interface signals
wire [31:0] eth_sl_wb_adr;
wire [31:0] eth_sl_wb_adr_i, eth_sl_wb_dat_o, eth_sl_wb_dat_i;
wire  [3:0] eth_sl_wb_sel_i;
wire        eth_sl_wb_we_i, eth_sl_wb_cyc_i, eth_sl_wb_stb_i, eth_sl_wb_ack_o, eth_sl_wb_err_o;

// Ethernet Master Interface signals
wire [31:0] eth_ma_wb_adr_o, eth_ma_wb_dat_i, eth_ma_wb_dat_o;
wire  [3:0] eth_ma_wb_sel_o;
wire        eth_ma_wb_we_o, eth_ma_wb_cyc_o, eth_ma_wb_stb_o, eth_ma_wb_ack_i, eth_ma_wb_err_i;

wire  [2:0] eth_ma_wb_cti_o;
wire  [1:0] eth_ma_wb_bte_o;


// Connecting Ethernet top module
ethmac eth_top
(
  // WISHBONE common
  .wb_clk_i(wb_clk),              .wb_rst_i(wb_rst), 

  // WISHBONE slave
  .wb_adr_i(eth_sl_wb_adr_i[11:2]), .wb_sel_i(eth_sl_wb_sel_i),   .wb_we_i(eth_sl_wb_we_i), 
  .wb_cyc_i(eth_sl_wb_cyc_i),       .wb_stb_i(eth_sl_wb_stb_i),   .wb_ack_o(eth_sl_wb_ack_o), 
  .wb_err_o(eth_sl_wb_err_o),       .wb_dat_i(eth_sl_wb_dat_i),   .wb_dat_o(eth_sl_wb_dat_o), 
 	
  // WISHBONE master
  .m_wb_adr_o(eth_ma_wb_adr_o),     .m_wb_sel_o(eth_ma_wb_sel_o), .m_wb_we_o(eth_ma_wb_we_o), 
  .m_wb_dat_i(eth_ma_wb_dat_i),     .m_wb_dat_o(eth_ma_wb_dat_o), .m_wb_cyc_o(eth_ma_wb_cyc_o), 
  .m_wb_stb_o(eth_ma_wb_stb_o),     .m_wb_ack_i(eth_ma_wb_ack_i), .m_wb_err_i(eth_ma_wb_err_i), 

`ifdef ETH_WISHBONE_B3
  .m_wb_cti_o(eth_ma_wb_cti_o),     .m_wb_bte_o(eth_ma_wb_bte_o),
`endif

  //TX
  .mtx_clk_pad_i(mtx_clk), .mtxd_pad_o(MTxD), .mtxen_pad_o(MTxEn), .mtxerr_pad_o(MTxErr),

  //RX
  .mrx_clk_pad_i(mrx_clk), .mrxd_pad_i(MRxD), .mrxdv_pad_i(MRxDV), .mrxerr_pad_i(MRxErr), 
  .mcoll_pad_i(MColl),    .mcrs_pad_i(MCrs), 
  
  // MIIM
  .mdc_pad_o(Mdc_O), .md_pad_i(Mdi_I), .md_pad_o(Mdo_O), .md_padoe_o(Mdo_OE),
  
  .int_o(wb_int)

  // Bist
`ifdef ETH_BIST
  ,
  .mbist_si_i       (1'b0),
  .mbist_so_o       (),
  .mbist_ctrl_i       (3'b001) // {enable, clock, reset}
`endif
);



// Connecting Ethernet PHY Module
assign Mdio_IO = Mdo_OE ? Mdo_O : 1'bz ;
assign Mdi_I   = Mdio_IO;
integer phy_log_file_desc;

eth_phy eth_phy
(
  // WISHBONE reset
  .m_rst_n_i(!wb_rst),

  // MAC TX
  .mtx_clk_o(mtx_clk),    .mtxd_i(MTxD),    .mtxen_i(MTxEn),    .mtxerr_i(MTxErr),

  // MAC RX
  .mrx_clk_o(mrx_clk),    .mrxd_o(MRxD),    .mrxdv_o(MRxDV),    .mrxerr_o(MRxErr),
  .mcoll_o(MColl),        .mcrs_o(MCrs),

  // MIIM
  .mdc_i(Mdc_O),          .md_io(Mdio_IO),

  // SYSTEM
  .phy_log(phy_log_file_desc)
);



// Connecting WB Master as Host Interface
integer host_log_file_desc;

WB_MASTER_BEHAVIORAL wb_master
(
    .CLK_I(wb_clk),
    .RST_I(wb_rst),
    .TAG_I({`WB_TAG_WIDTH{1'b0}}),
    .TAG_O(),
    .ACK_I(eth_sl_wb_ack_o),
    .ADR_O(eth_sl_wb_adr), // only eth_sl_wb_adr_i[11:2] used
    .CYC_O(eth_sl_wb_cyc_i),
    .DAT_I(eth_sl_wb_dat_o),
    .DAT_O(eth_sl_wb_dat_i),
    .ERR_I(eth_sl_wb_err_o),
    .RTY_I(1'b0),  // inactive (1'b0)
    .SEL_O(eth_sl_wb_sel_i),
    .STB_O(eth_sl_wb_stb_i),
    .WE_O (eth_sl_wb_we_i),
    .CAB_O()       // NOT USED for now!
);

assign eth_sl_wb_adr_i = {20'h0, eth_sl_wb_adr[11:2], 2'h0};



// Connecting WB Slave as Memory Interface Module
integer memory_log_file_desc;

WB_SLAVE_BEHAVIORAL wb_slave
(
    .CLK_I(wb_clk),
    .RST_I(wb_rst),
    .ACK_O(eth_ma_wb_ack_i),
    .ADR_I(eth_ma_wb_adr_o),
    .CYC_I(eth_ma_wb_cyc_o),
    .DAT_O(eth_ma_wb_dat_i),
    .DAT_I(eth_ma_wb_dat_o),
    .ERR_O(eth_ma_wb_err_i),
    .RTY_O(),      // NOT USED for now!
    .SEL_I(eth_ma_wb_sel_o),
    .STB_I(eth_ma_wb_stb_o),
    .WE_I (eth_ma_wb_we_o),
    .CAB_I(1'b0)
);



// Connecting WISHBONE Bus Monitors to ethernet master and slave interfaces
integer wb_s_mon_log_file_desc ;
integer wb_m_mon_log_file_desc ;

WB_BUS_MON wb_eth_slave_bus_mon
(
  // WISHBONE common
  .CLK_I(wb_clk),
  .RST_I(wb_rst),

  // WISHBONE slave
  .ACK_I(eth_sl_wb_ack_o),
  .ADDR_O({20'h0, eth_sl_wb_adr_i[11:2], 2'b0}),
  .CYC_O(eth_sl_wb_cyc_i),
  .DAT_I(eth_sl_wb_dat_o),
  .DAT_O(eth_sl_wb_dat_i),
  .ERR_I(eth_sl_wb_err_o),
  .RTY_I(1'b0),
  .SEL_O(eth_sl_wb_sel_i),
  .STB_O(eth_sl_wb_stb_i),
  .WE_O (eth_sl_wb_we_i),
  .TAG_I({`WB_TAG_WIDTH{1'b0}}),
`ifdef ETH_WISHBONE_B3
  .TAG_O({eth_ma_wb_cti_o, eth_ma_wb_bte_o}),
`else
  .TAG_O(5'h0),
`endif
  .CAB_O(1'b0),
`ifdef ETH_WISHBONE_B3
  .check_CTI          (1'b1),
`else
  .check_CTI          (1'b0),
`endif
  .log_file_desc (wb_s_mon_log_file_desc)
);

WB_BUS_MON wb_eth_master_bus_mon
(
  // WISHBONE common
  .CLK_I(wb_clk),
  .RST_I(wb_rst),

  // WISHBONE master
  .ACK_I(eth_ma_wb_ack_i),
  .ADDR_O(eth_ma_wb_adr_o),
  .CYC_O(eth_ma_wb_cyc_o),
  .DAT_I(eth_ma_wb_dat_i),
  .DAT_O(eth_ma_wb_dat_o),
  .ERR_I(eth_ma_wb_err_i),
  .RTY_I(1'b0),
  .SEL_O(eth_ma_wb_sel_o),
  .STB_O(eth_ma_wb_stb_o),
  .WE_O (eth_ma_wb_we_o),
  .TAG_I({`WB_TAG_WIDTH{1'b0}}),
  .TAG_O(5'h0),
  .CAB_O(1'b0),
  .check_CTI(1'b0), // NO need
  .log_file_desc(wb_m_mon_log_file_desc)
);


//initial $display("I am here");

reg         StartTB;
integer     tb_log_file;

initial
begin
  tb_log_file = $fopen("../log/eth_tb.log");
  if (tb_log_file < 2)
  begin
    $display("*E Could not open/create testbench log file in ../log/ directory!");
    $finish;
  end
  $fdisplay(tb_log_file, "========================== ETHERNET IP Core Testbench results ===========================");
  $fdisplay(tb_log_file, " ");

  phy_log_file_desc = $fopen("../log/eth_tb_phy.log");
  if (phy_log_file_desc < 2)
  begin
    $fdisplay(tb_log_file, "*E Could not open/create eth_tb_phy.log file in ../log/ directory!");
    $finish;
  end
  $fdisplay(phy_log_file_desc, "================ PHY Module  Testbench access log ================");
  $fdisplay(phy_log_file_desc, " ");

  memory_log_file_desc = $fopen("../log/eth_tb_memory.log");
  if (memory_log_file_desc < 2)
  begin
    $fdisplay(tb_log_file, "*E Could not open/create eth_tb_memory.log file in ../log/ directory!");
    $finish;
  end
  $fdisplay(memory_log_file_desc, "=============== MEMORY Module Testbench access log ===============");
  $fdisplay(memory_log_file_desc, " ");

  host_log_file_desc = $fopen("../log/eth_tb_host.log");
  if (host_log_file_desc < 2)
  begin
    $fdisplay(tb_log_file, "*E Could not open/create eth_tb_host.log file in ../log/ directory!");
    $finish;
  end
  $fdisplay(host_log_file_desc, "================ HOST Module Testbench access log ================");
  $fdisplay(host_log_file_desc, " ");

  wb_s_mon_log_file_desc = $fopen("../log/eth_tb_wb_s_mon.log");
  if (wb_s_mon_log_file_desc < 2)
  begin
    $fdisplay(tb_log_file, "*E Could not open/create eth_tb_wb_s_mon.log file in ../log/ directory!");
    $finish;
  end
  $fdisplay(wb_s_mon_log_file_desc, "============== WISHBONE Slave Bus Monitor error log ==============");
  $fdisplay(wb_s_mon_log_file_desc, " ");
  $fdisplay(wb_s_mon_log_file_desc, "   Only ERRONEOUS conditions are logged !");
  $fdisplay(wb_s_mon_log_file_desc, " ");

  wb_m_mon_log_file_desc = $fopen("../log/eth_tb_wb_m_mon.log");
  if (wb_m_mon_log_file_desc < 2)
  begin
    $fdisplay(tb_log_file, "*E Could not open/create eth_tb_wb_m_mon.log file in ../log/ directory!");
    $finish;
  end
  $fdisplay(wb_m_mon_log_file_desc, "============= WISHBONE Master Bus Monitor  error log =============");
  $fdisplay(wb_m_mon_log_file_desc, " ");
  $fdisplay(wb_m_mon_log_file_desc, "   Only ERRONEOUS conditions are logged !");
  $fdisplay(wb_m_mon_log_file_desc, " ");

`ifdef VCD
   $dumpfile("./ethmac.vcd");
   $dumpvars(0);
`endif
  // Reset pulse
  wb_rst =  1'b1;
  #423 wb_rst =  1'b0;

  // Clear memories
  clear_memories;
  clear_buffer_descriptors;

  #423 StartTB  =  1'b1;
end

// Generating wb_clk clock
initial
begin
  wb_clk=0;
//  forever #2.5 wb_clk = ~wb_clk;  // 2*2.5 ns -> 200.0 MHz    
  forever #5 wb_clk = ~wb_clk;  // 2*5 ns -> 100.0 MHz    
//  forever #10 wb_clk = ~wb_clk;  // 2*10 ns -> 50.0 MHz    
//  forever #12.5 wb_clk = ~wb_clk;  // 2*12.5 ns -> 40 MHz    
//  forever #15 wb_clk = ~wb_clk;  // 2*10 ns -> 33.3 MHz    
//  forever #20 wb_clk = ~wb_clk;  // 2*20 ns -> 25 MHz    
//  forever #25 wb_clk = ~wb_clk;  // 2*25 ns -> 20.0 MHz
//  forever #31.25 wb_clk = ~wb_clk;  // 2*31.25 ns -> 16.0 MHz    
//  forever #50 wb_clk = ~wb_clk;  // 2*50 ns -> 10.0 MHz
//  forever #55 wb_clk = ~wb_clk;  // 2*55 ns ->  9.1 MHz    
end

task clear_memories;
  reg    [22:0]  adr_i;
  reg            delta_t;
begin
  for (adr_i = 0; adr_i < 4194304; adr_i = adr_i + 1)
  begin
    eth_phy.rx_mem[adr_i[21:0]] = 0;
    eth_phy.tx_mem[adr_i[21:0]] = 0;
    wb_slave.wb_memory[adr_i[21:2]] = 0;
  end
end
endtask // clear_memories

task clear_buffer_descriptors;
  reg    [8:0]  adr_i;
  reg            delta_t;
begin
  delta_t = 0;
  for (adr_i = 0; adr_i < 256; adr_i = adr_i + 1)
  begin
    //wbm_write((`TX_BD_BASE + {adr_i[7:0], 2'b0}), 32'h0, 4'hF, 1, 4'h1, 4'h1);
    delta_t = !delta_t;
  end
end
endtask // clear_buffer_descriptors

//////////////////////////////////////////////////////////////
// WB Behavioral Models Basic tasks
//////////////////////////////////////////////////////////////

integer      tests_successfull;
integer      tests_failed;
reg [799:0]  test_name; // used for tb_log_file

reg   [3:0]  wbm_init_waits; // initial wait cycles between CYC_O and STB_O of WB Master
reg   [3:0]  wbm_subseq_waits; // subsequent wait cycles between STB_Os of WB Master
reg   [3:0]  wbs_waits; // wait cycles befor WB Slave responds
reg   [7:0]  wbs_retries; // if RTY response, then this is the number of retries before ACK

reg          wbm_working; // tasks wbm_write and wbm_read set signal when working and reset it when stop working

initial
begin
  wait(StartTB);  // Start of testbench

  // Initial global values
  tests_successfull = 0;
  tests_failed = 0;
  
  wbm_working = 0;

  wbm_init_waits = 4'h1;
  wbm_subseq_waits = 4'h3;
  wbs_waits = 4'h1;
  wbs_retries = 8'h2; 
  wb_slave.cycle_response(`ACK_RESPONSE, wbs_waits, wbs_retries);

  // set DIFFERENT mrx_clk to mtx_clk!
  //  eth_phy.set_mrx_equal_mtx = 1'b0;

  //  Call tests
  //  ----------
  //test_access_to_mac_reg(0, 4);           // 0 - 4

  //test_mii(0, 17);                        // 0 - 17
  //$display("");
  //$display("===========================================================================");
  //$display("PHY generates ideal Carrier sense and Collision signals for following tests");
  //$display("===========================================================================");
  //test_note("PHY generates ideal Carrier sense and Collision signals for following tests");
  //eth_phy.carrier_sense_real_delay(0);
  //test_mac_full_duplex_transmit(2, 2);    // 0 - 23
  //simple_transmit;
  test_mac_full_duplex_receive(4, 4);     // 0 - 15
  //simple_receive;
  //test_mac_full_duplex_flow_control(0, 5); // 0 - 5

  //// Tests not working, yet.
  //// test_mac_half_duplex_flow(0, 5);  // 0, 1, 2, 3, 4, 5 These tests need to be fixed !!!

  //$display("");
  //$display("===========================================================================");
  //$display("PHY generates 'real delayed' Carrier sense and Collision signals for following tests");
  //$display("===========================================================================");
  //test_note("PHY generates 'real delayed' Carrier sense and Collision signals for following tests");
  //eth_phy.carrier_sense_real_delay(1);
  //test_mac_full_duplex_transmit(0, 23);    // 0 - 23
  //test_mac_full_duplex_receive(0, 15);     // 0 - 15
  //test_mac_full_duplex_flow_control(0, 5); // 0 - 5
  ////test_mac_half_duplex_flow(0, 5);
 
 
  // Finish test's logs
  test_summary;
  $display("\n\n END of SIMULATION");
  $fclose(tb_log_file | phy_log_file_desc | memory_log_file_desc | host_log_file_desc);
  $fclose(wb_s_mon_log_file_desc | wb_m_mon_log_file_desc);

  $stop;
end

task test_access_to_mac_reg;
  input  [31:0]  start_task;
  input  [31:0]  end_task;
  integer        bit_start_1;
  integer        bit_end_1;
  integer        bit_start_2;
  integer        bit_end_2;
  integer        num_of_reg;
  integer        i_addr;
  integer        i_data;
  integer        i_length;
  integer        tmp_data;
  reg    [31:0]  tx_bd_num;
  reg    [((`MAX_BLK_SIZE * 32) - 1):0] burst_data;
  reg    [((`MAX_BLK_SIZE * 32) - 1):0] burst_tmp_data;
  integer        i;
  integer        i1;
  integer        i2;
  integer        i3;
  integer        fail;
  integer        test_num;
  reg    [31:0]  addr;
  reg    [31:0]  data;
  reg     [3:0]  sel;
  reg     [3:0]  rand_sel;
  reg    [31:0]  data_max;
begin
// ACCESS TO MAC REGISTERS TEST
test_heading("ACCESS TO MAC REGISTERS TEST");
$display(" ");
$display("ACCESS TO MAC REGISTERS TEST");
fail = 0;

// reset MAC registers
hard_reset;


//////////////////////////////////////////////////////////////////////
////                                                              ////
////  test_access_to_mac_reg:                                     ////
////                                                              ////
////  0: Byte selects on 3 32-bit RW registers.                   ////
////  1: Walking 1 with single cycles across MAC regs.            ////
////  2: Walking 1 with single cycles across MAC buffer descript. ////
////  3: Test max reg. values and reg. values after writing       ////
////     inverse reset values and hard reset of the MAC           ////
////  4: Test buffer desc. RAM preserving values after hard reset ////
////     of the MAC and resetting the logic                       ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
for (test_num = start_task; test_num <= end_task; test_num = test_num + 1)
begin

  ////////////////////////////////////////////////////////////////////
  ////                                                            ////
  ////  Byte selects on 4 32-bit RW registers.                    ////
  ////                                                            ////
  ////////////////////////////////////////////////////////////////////
  if (test_num == 0) //
  begin
    // TEST 0: BYTE SELECTS ON 3 32-BIT READ-WRITE REGISTERS ( VARIOUS BUS DELAYS )
    test_name   = "TEST 0: BYTE SELECTS ON 3 32-BIT READ-WRITE REGISTERS ( VARIOUS BUS DELAYS )";
    `TIME; $display("  TEST 0: BYTE SELECTS ON 3 32-BIT READ-WRITE REGISTERS ( VARIOUS BUS DELAYS )");
    
    data = 0;
    rand_sel = 0;
    sel = 0;
    for (i = 1; i <= 3; i = i + 1) // num of active byte selects at each register
    begin
      wbm_init_waits = 0;
      wbm_subseq_waits = {$random} % 5; // it is not important for single accesses
      case (i)
      1:       i_addr = `ETH_MAC_ADDR0;
      2:       i_addr = `ETH_HASH_ADDR0;
      default: i_addr = `ETH_HASH_ADDR1;
      endcase
      addr = `ETH_BASE + i_addr;
      sel = 4'hF;
      wbm_read(addr, tmp_data, sel, 1, wbm_init_waits, wbm_subseq_waits);
      if (tmp_data !== 32'h0)
      begin
        fail = fail + 1;
        test_fail_num("Register default value is not ZERO", i_addr);
        `TIME;
        $display("Register default value is not ZERO - addr %h, tmp_data %h", addr, tmp_data);
      end
      for (i1 = 0; i1 <= 3; i1 = i1 + 1) // position of first active byte select
      begin
        case ({i, i1})
        10:      sel = 4'b0001; // data = 32'hFFFF_FF00;
        11:      sel = 4'b0010; // data = 32'hFFFF_00FF;
        12:      sel = 4'b0100; // data = 32'hFF00_FFFF;
        13:      sel = 4'b1000; // data = 32'h00FF_FFFF;
        20:      sel = 4'b0011; // data = 32'hFFFF_0000;
        21:      sel = 4'b0110; // data = 32'hFF00_00FF;
        22:      sel = 4'b1100; // data = 32'h0000_FFFF;
        23:      sel = 4'b1001; // data = 32'h00FF_FF00;
        30:      sel = 4'b0111; // data = 32'hFF00_0000;
        31:      sel = 4'b1110; // data = 32'h0000_00FF;
        32:      sel = 4'b1101; // data = 32'h0000_FF00;
        default: sel = 4'b1011; // data = 32'h00FF_0000;
        endcase
        // set value to 32'hFFFF_FFFF
        data = 32'hFFFF_FFFF;
        wbm_write(addr, data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        wait (wbm_working == 0);
        wbm_read(addr, tmp_data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        if (tmp_data !== data)
        begin
          fail = fail + 1;
          test_fail_num("Register could not be written to FFFF_FFFF", i_addr);
          `TIME;
          $display("Register could not be written to FFFF_FFFF - addr %h, tmp_data %h", addr, tmp_data);
        end
        // write appropriate byte(s) to 0
        data = 32'h0;
        wbm_write(addr, data, sel, 1, wbm_init_waits, wbm_subseq_waits);
        wait (wbm_working == 0);
        if (i1[0])
          wbm_read(addr, tmp_data, sel, 1, wbm_init_waits, wbm_subseq_waits);
        else
          wbm_read(addr, tmp_data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        data = {({8{~sel[3]}}), ({8{~sel[2]}}), ({8{~sel[1]}}), ({8{~sel[0]}})};
        if (tmp_data !== data)
        begin
          fail = fail + 1;
          test_fail_num("Wrong data read out from register", i_addr);
          `TIME;
          $display("Wrong data read out from register - addr %h, data %h, tmp_data %h, sel %b", 
                   addr, data, tmp_data, sel);
        end
      end
    end
    if(fail == 0)
      test_ok;
    else
      fail = 0;    // Errors were reported previously
  end


  ////////////////////////////////////////////////////////////////////
  ////                                                            ////
  ////  Walking 1 with single cycles across MAC regs.             ////
  ////                                                            ////
  ////////////////////////////////////////////////////////////////////
  if (test_num == 1) //
  begin
    // TEST 1: 'WALKING ONE' WITH SINGLE CYCLES ACROSS MAC REGISTERS ( VARIOUS BUS DELAYS )
    test_name   = "TEST 1: 'WALKING ONE' WITH SINGLE CYCLES ACROSS MAC REGISTERS ( VARIOUS BUS DELAYS )";
    `TIME; $display("  TEST 1: 'WALKING ONE' WITH SINGLE CYCLES ACROSS MAC REGISTERS ( VARIOUS BUS DELAYS )");
    
    data = 0;
    rand_sel = 0;
    sel = 0;
    for (i_addr = 0; i_addr <= {22'h0, `ETH_TX_CTRL_ADR, 2'h0}; i_addr = i_addr + 4) // register address
    begin
      if (i_addr[6:4] < 5)
        wbm_init_waits = i_addr[6:4];
      else
        wbm_init_waits = 4;
      wbm_subseq_waits = {$random} % 5; // it is not important for single accesses
      addr = `ETH_BASE + i_addr;
      // set ranges of R/W bits
      case (addr)
      `ETH_MODER:
      begin
        bit_start_1 = 0;
        bit_end_1   = 16;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_INT: // READONLY - tested within INT test
      begin
        bit_start_1 = 32; // not used
        bit_end_1   = 32; // not used
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_INT_MASK:
      begin
        bit_start_1 = 0;
        bit_end_1   = 6;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_IPGT:
      begin
        bit_start_1 = 0;
        bit_end_1   = 6;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_IPGR1:
      begin
        bit_start_1 = 0;
        bit_end_1   = 6;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_IPGR2:
      begin
        bit_start_1 = 0;
        bit_end_1   = 6;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_PACKETLEN:
      begin
        bit_start_1 = 0;
        bit_end_1   = 31;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_COLLCONF:
      begin
        bit_start_1 = 0;
        bit_end_1   = 5;
        bit_start_2 = 16; 
        bit_end_2   = 19; 
      end
      `ETH_TX_BD_NUM: 
      begin
        bit_start_1 = 0;
        bit_end_1   = 7;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_CTRLMODER:
      begin
        bit_start_1 = 0;
        bit_end_1   = 2;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_MIIMODER:
      begin
        bit_start_1 = 0;
        bit_end_1   = 8;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_MIICOMMAND: // "WRITEONLY" - tested within MIIM test - 3 LSBits are not written here!!!
      begin
        bit_start_1 = 32; // not used
        bit_end_1   = 32; // not used
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_MIIADDRESS:
      begin
        bit_start_1 = 0;
        bit_end_1   = 4;
        bit_start_2 = 8; 
        bit_end_2   = 12;
      end
      `ETH_MIITX_DATA:
      begin
        bit_start_1 = 0;
        bit_end_1   = 15;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_MIIRX_DATA: // READONLY - tested within MIIM test
      begin
        bit_start_1 = 32; // not used
        bit_end_1   = 32; // not used
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_MIISTATUS: // READONLY - tested within MIIM test
      begin
        bit_start_1 = 32; // not used
        bit_end_1   = 32; // not used
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_MAC_ADDR0:
      begin
        bit_start_1 = 0;
        bit_end_1   = 31;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_MAC_ADDR1:
      begin
        bit_start_1 = 0;
        bit_end_1   = 15;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_HASH_ADDR0:
      begin
        bit_start_1 = 0;
        bit_end_1   = 31;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      `ETH_HASH_ADDR1:
      begin
        bit_start_1 = 0;
        bit_end_1   = 31;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      default: // `ETH_TX_CTRL_ADR:
      begin
        bit_start_1 = 0;
        bit_end_1   = 16;
        bit_start_2 = 32; // not used
        bit_end_2   = 32; // not used
      end
      endcase
      
      for (i_data = 0; i_data <= 31; i_data = i_data + 1) // the position of walking one
      begin
        data = 1'b1 << i_data;
        if ( (addr == `ETH_MIICOMMAND)/* && (i_data <= 2)*/ ) // DO NOT WRITE to 3 LSBits of MIICOMMAND !!!
          ;
        else
        begin
          rand_sel[2:0] = {$random} % 8;
          if ((i_data >= 0) && (i_data < 8))
            sel = {rand_sel[2:0], 1'b1};
          else if ((i_data >= 8) && (i_data < 16))
            sel = {rand_sel[2:1], 1'b1, rand_sel[0]};
          else if ((i_data >= 16) && (i_data < 24))
            sel = {rand_sel[2], 1'b1, rand_sel[1:0]};
          else // if ((i_data >= 24) && (i_data < 32))
            sel = {1'b1, rand_sel[2:0]};
          wbm_write(addr, data, sel, 1, wbm_init_waits, wbm_subseq_waits);
          wait (wbm_working == 0);
          wbm_read(addr, tmp_data, sel, 1, wbm_init_waits, wbm_subseq_waits);
          if ( ((i_data >= bit_start_1) && (i_data <= bit_end_1)) ||
               ((i_data >= bit_start_2) && (i_data <= bit_end_2)) ) // data should be equal to tmp_data
          begin
            if ( ((tmp_data[31:24] !== data[31:24]) && sel[3]) || ((tmp_data[23:16] !== data[23:16]) && sel[2]) ||
                 ((tmp_data[15: 8] !== data[15: 8]) && sel[1]) || ((tmp_data[ 7: 0] !== data[ 7: 0]) && sel[0]) )
            begin
              fail = fail + 1;
              test_fail_num("RW bit of the MAC register was not written or not read", i_addr);
              `TIME;
              $display("Wrong RW bit - wbm_init_waits %d, addr %h, data %h, tmp_data %h, sel %b", 
                        wbm_init_waits, addr, data, tmp_data, sel);
            end
          end
          else // data should not be equal to tmp_data
          begin
            if ( ((tmp_data[31:24] === data[31:24]) && sel[3]) && ((tmp_data[23:16] === data[23:16]) && sel[2]) &&
                 ((tmp_data[15: 8] === data[15: 8]) && sel[1]) && ((tmp_data[ 7: 0] === data[ 7: 0]) && sel[0]) )
            begin
              fail = fail + 1;
              test_fail_num("NON RW bit of the MAC register was written, but it shouldn't be", i_addr);
              `TIME;
              $display("Wrong NON RW bit - wbm_init_waits %d, addr %h, data %h, tmp_data %h, sel %b",
                        wbm_init_waits, addr, data, tmp_data, sel);
            end
          end
        end
      end
    end
    // INTERMEDIATE DISPLAYS (The only one)
    $display("    ->registers tested with 0, 1, 2, 3 and 4 bus delay cycles");
    if(fail == 0)
      test_ok;
    else
      fail = 0;    // Errors were reported previously
  end
        
        
  ////////////////////////////////////////////////////////////////////
  ////                                                            ////
  ////  Walking 1 with single cycles across MAC buffer descript.  ////
  ////                                                            ////
  ////////////////////////////////////////////////////////////////////
  if (test_num == 2) //
  begin
    // TEST 2: 'WALKING ONE' WITH SINGLE CYCLES ACROSS MAC BUFFER DESC. ( VARIOUS BUS DELAYS )
    test_name   = "TEST 2: 'WALKING ONE' WITH SINGLE CYCLES ACROSS MAC BUFFER DESC. ( VARIOUS BUS DELAYS )";
    `TIME; $display("  TEST 2: 'WALKING ONE' WITH SINGLE CYCLES ACROSS MAC BUFFER DESC. ( VARIOUS BUS DELAYS )");
        
    data = 0;
    rand_sel = 0;
    sel = 0;
    // set TX and RX buffer descriptors
    tx_bd_num = 32'h40;
    wbm_write(`ETH_TX_BD_NUM, tx_bd_num, 4'hF, 1, 0, 0);
    for (i_addr = 32'h400; i_addr <= 32'h7FC; i_addr = i_addr + 4) // buffer descriptor address
    begin
      if (i_addr[11:8] < 8)
        wbm_init_waits = i_addr[10:8] - 3'h4;
      else
        wbm_init_waits = 3;
      wbm_subseq_waits = {$random} % 5; // it is not important for single accesses
      addr = `ETH_BASE + i_addr;
      if (i_addr < (32'h400 + (tx_bd_num << 3))) // TX buffer descriptors
      begin
        // set ranges of R/W bits
        case (addr[3])
          1'b0: // buffer control bits
          begin
            bit_start_1 = 0;
            bit_end_1   = 31; // 8;
            bit_start_2 = 11;
            bit_end_2   = 31;
          end
          default: // 1'b1: // buffer pointer
          begin
            bit_start_1 = 0;
            bit_end_1   = 31;
            bit_start_2 = 32; // not used
            bit_end_2   = 32; // not used
          end
        endcase
      end
      else // RX buffer descriptors
      begin
        // set ranges of R/W bits
        case (addr[3])
          1'b0: // buffer control bits
          begin
            bit_start_1 = 0;
            bit_end_1   = 31; // 7;
            bit_start_2 = 13;
            bit_end_2   = 31;
          end
          default: // 1'b1: // buffer pointer
          begin
            bit_start_1 = 0;
            bit_end_1   = 31;
            bit_start_2 = 32; // not used
            bit_end_2   = 32; // not used
          end
        endcase
      end
      
      for (i_data = 0; i_data <= 31; i_data = i_data + 1) // the position of walking one
      begin
        data = 1'b1 << i_data;
        if ( (addr[3] == 0) && (i_data == 15) ) // DO NOT WRITE to this bit !!!
          ;
        else
        begin
          rand_sel[2:0] = {$random} % 8;
          if ((i_data >= 0) && (i_data < 8))
            sel = {rand_sel[2:0], 1'b1};
          else if ((i_data >= 8) && (i_data < 16))
            sel = {rand_sel[2:1], 1'b1, rand_sel[0]};
          else if ((i_data >= 16) && (i_data < 24))
            sel = {rand_sel[2], 1'b1, rand_sel[1:0]};
          else // if ((i_data >= 24) && (i_data < 32))
            sel = {1'b1, rand_sel[2:0]};
          wbm_write(addr, data, sel, 1, wbm_init_waits, wbm_subseq_waits);
          wbm_read(addr, tmp_data, sel, 1, wbm_init_waits, wbm_subseq_waits);
          if ( ((i_data >= bit_start_1) && (i_data <= bit_end_1)) ||
               ((i_data >= bit_start_2) && (i_data <= bit_end_2)) ) // data should be equal to tmp_data
          begin
            if ( ((tmp_data[31:24] !== data[31:24]) && sel[3]) || ((tmp_data[23:16] !== data[23:16]) && sel[2]) ||
                 ((tmp_data[15: 8] !== data[15: 8]) && sel[1]) || ((tmp_data[ 7: 0] !== data[ 7: 0]) && sel[0]) )
            begin
              fail = fail + 1;
              test_fail("RW bit of the MAC buffer descriptors was not written or not read");
              `TIME;
              $display("Wrong RW bit - wbm_init_waits %d, addr %h, data %h, tmp_data %h, sel %b", 
                        wbm_init_waits, addr, data, tmp_data, sel);
            end
          end
          else // data should not be equal to tmp_data
          begin
            if ( ((tmp_data[31:24] === data[31:24]) && sel[3]) && ((tmp_data[23:16] === data[23:16]) && sel[2]) &&
                 ((tmp_data[15: 8] === data[15: 8]) && sel[1]) && ((tmp_data[ 7: 0] === data[ 7: 0]) && sel[0]) )
            begin
              fail = fail + 1;
              test_fail("NON RW bit of the MAC buffer descriptors was written, but it shouldn't be");
              `TIME;
              $display("Wrong NON RW bit - wbm_init_waits %d, addr %h, data %h, tmp_data %h, sel %b",
                        wbm_init_waits, addr, data, tmp_data, sel);
            end
          end
        end
      end
      // INTERMEDIATE DISPLAYS
      if (i_addr[11:0] == 12'h500)
        $display("    ->buffer descriptors tested with 0 bus delay");
      else if (i_addr[11:0] == 12'h600)
        $display("    ->buffer descriptors tested with 1 bus delay cycle");
      else if (i_addr[11:0] == 12'h700)
        $display("    ->buffer descriptors tested with 2 bus delay cycles");
    end
    $display("    ->buffer descriptors tested with 3 bus delay cycles");
    if(fail == 0)
      test_ok;
    else
      fail = 0;
  end
        
        
  ////////////////////////////////////////////////////////////////////
  ////                                                            ////
  ////  Test max reg. values and reg. values after writing        ////
  ////  inverse reset values and hard reset of the MAC            ////
  ////                                                            ////
  ////////////////////////////////////////////////////////////////////
  if (test_num == 3) //
  begin
    // TEST 3: MAX REG. VALUES AND REG. VALUES AFTER WRITING INVERSE RESET VALUES AND HARD RESET OF THE MAC
    test_name   = 
      "TEST 3: MAX REG. VALUES AND REG. VALUES AFTER WRITING INVERSE RESET VALUES AND HARD RESET OF THE MAC";
    `TIME; $display(
      "  TEST 3: MAX REG. VALUES AND REG. VALUES AFTER WRITING INVERSE RESET VALUES AND HARD RESET OF THE MAC");
        
    // reset MAC registers
    hard_reset;
    for (i = 0; i <= 4; i = i + 1) // 0, 2 - WRITE; 1, 3, 4 - READ
    begin
      for (i_addr = 0; i_addr <= {22'h0, `ETH_TX_CTRL_ADR, 2'h0}; i_addr = i_addr + 4) // register address
      begin
        addr = `ETH_BASE + i_addr;
        // set ranges of R/W bits
        case (addr)
        `ETH_MODER:
        begin
          data = 32'h0000_A000; // bit 11 not used any more
          data_max = 32'h0001_FFFF;
        end
        `ETH_INT: // READONLY - tested within INT test
        begin
          data = 32'h0000_0000;
          data_max = 32'h0000_0000;
        end
        `ETH_INT_MASK:
        begin
          data = 32'h0000_0000;
          data_max = 32'h0000_007F;
        end
        `ETH_IPGT:
        begin
          data = 32'h0000_0012;
          data_max = 32'h0000_007F;
        end
        `ETH_IPGR1:
        begin
          data = 32'h0000_000C;
          data_max = 32'h0000_007F;
        end
        `ETH_IPGR2:
        begin
          data = 32'h0000_0012;
          data_max = 32'h0000_007F;
        end
        `ETH_PACKETLEN:
        begin
          data = 32'h0040_0600;
          data_max = 32'hFFFF_FFFF;
        end
        `ETH_COLLCONF:
        begin
          data = 32'h000F_003F;
          data_max = 32'h000F_003F;
        end
        `ETH_TX_BD_NUM: 
        begin
          data = 32'h0000_0040;
          data_max = 32'h0000_0080;
        end
        `ETH_CTRLMODER:
        begin
          data = 32'h0000_0000;
          data_max = 32'h0000_0007;
        end
        `ETH_MIIMODER:
        begin
          data = 32'h0000_0064;
          data_max = 32'h0000_01FF;
        end
        `ETH_MIICOMMAND: // "WRITEONLY" - tested within MIIM test - 3 LSBits are not written here!!!
        begin
          data = 32'h0000_0000;
          data_max = 32'h0000_0000;
        end
        `ETH_MIIADDRESS:
        begin
          data = 32'h0000_0000;
          data_max = 32'h0000_1F1F;
        end
        `ETH_MIITX_DATA:
        begin
          data = 32'h0000_0000;
          data_max = 32'h0000_FFFF;
        end
        `ETH_MIIRX_DATA: // READONLY - tested within MIIM test
        begin
          data = 32'h0000_0000;
          data_max = 32'h0000_0000;
        end
        `ETH_MIISTATUS: // READONLY - tested within MIIM test
        begin
          data = 32'h0000_0000;
          data_max = 32'h0000_0000;
        end
        `ETH_MAC_ADDR0:
        begin
          data = 32'h0000_0000;
          data_max = 32'hFFFF_FFFF;
        end
        `ETH_MAC_ADDR1:
        begin
          data = 32'h0000_0000;
          data_max = 32'h0000_FFFF;
        end
        `ETH_HASH_ADDR0:
        begin
          data = 32'h0000_0000;
          data_max = 32'hFFFF_FFFF;
        end
        `ETH_HASH_ADDR1:
        begin
          data = 32'h0000_0000;
          data_max = 32'hFFFF_FFFF;
        end
        default: // `ETH_TX_CTRL_ADR:
        begin
          data = 32'h0000_0000;
          data_max = 32'h0000_FFFF;
        end
        endcase
        
        wbm_init_waits = {$random} % 3;
        wbm_subseq_waits = {$random} % 5; // it is not important for single accesses
        if (i == 0)
        begin
          if (addr == `ETH_MIICOMMAND) // DO NOT WRITE to 3 LSBits of MIICOMMAND !!!
            ;
          else
          wbm_write(addr, ~data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        end
        else if (i == 2)
        begin
          if (addr == `ETH_MIICOMMAND) // DO NOT WRITE to 3 LSBits of MIICOMMAND !!!
            ;
          else
          wbm_write(addr, 32'hFFFFFFFF, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        end
        else if ((i == 1) || (i == 4))
        begin
          wbm_read(addr, tmp_data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
          if (tmp_data !== data)
          begin
            fail = fail + 1;
            test_fail("RESET value of the MAC register is not correct");
            `TIME;
            $display("  addr %h, data %h, tmp_data %h", addr, data, tmp_data);
          end
        end
        else // check maximum values
        begin
          wbm_read(addr, tmp_data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
          if (addr == `ETH_TX_BD_NUM) // previous data should remain in this register
          begin
            if (tmp_data !== data)
            begin
              fail = fail + 1;
              test_fail("Previous value of the TX_BD_NUM register did not remain");
              `TIME;
              $display("  addr %h, data_max %h, tmp_data %h", addr, data_max, tmp_data);
            end
            // try maximum (80)
            wbm_write(addr, data_max, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
            wbm_read(addr, tmp_data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
            if (tmp_data !== data_max)
            begin
              fail = fail + 1;
              test_fail("MAX value of the TX_BD_NUM register is not correct");
              `TIME;
              $display("  addr %h, data_max %h, tmp_data %h", addr, data_max, tmp_data);
            end
            // try one less than maximum (80)
            wbm_write(addr, (data_max - 1), 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
            wbm_read(addr, tmp_data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
            if (tmp_data !== (data_max - 1))
            begin
              fail = fail + 1;
              test_fail("ONE less than MAX value of the TX_BD_NUM register is not correct");
              `TIME;
              $display("  addr %h, data_max %h, tmp_data %h", addr, data_max, tmp_data);
            end
            // try one more than maximum (80)
            wbm_write(addr, (data_max + 1), 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
            wbm_read(addr, tmp_data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
            if (tmp_data !== (data_max - 1)) // previous data should remain in this register
            begin
              fail = fail + 1;
              test_fail("Previous value of the TX_BD_NUM register did not remain");
              `TIME;
              $display("  addr %h, data_max %h, tmp_data %h", addr, data_max, tmp_data);
            end
          end
          else
          begin
            if (tmp_data !== data_max)
            begin
              fail = fail + 1;
              test_fail("MAX value of the MAC register is not correct");
              `TIME;
              $display("  addr %h, data_max %h, tmp_data %h", addr, data_max, tmp_data);
            end
          end
        end
      end
      // reset MAC registers
      if ((i == 0) || (i == 3))
        hard_reset;
    end
    if(fail == 0)
      test_ok;
    else
      fail = 0;
  end


  ////////////////////////////////////////////////////////////////////
  ////                                                            ////
  ////  Test buffer desc. ram preserving values after hard reset  ////
  ////  of the mac and reseting the logic                         ////
  ////                                                            ////
  ////////////////////////////////////////////////////////////////////
  if (test_num == 4) //
  begin
    // TEST 4: BUFFER DESC. RAM PRESERVING VALUES AFTER HARD RESET OF THE MAC AND RESETING THE LOGIC
    test_name   = "TEST 4: BUFFER DESC. RAM PRESERVING VALUES AFTER HARD RESET OF THE MAC AND RESETING THE LOGIC";
    `TIME; 
    $display("  TEST 4: BUFFER DESC. RAM PRESERVING VALUES AFTER HARD RESET OF THE MAC AND RESETING THE LOGIC");
        
    // reset MAC registers
    hard_reset;
    for (i = 0; i <= 3; i = i + 1) // 0, 2 - WRITE; 1, 3 - READ
    begin
      for (i_addr = 32'h400; i_addr <= 32'h7FC; i_addr = i_addr + 4) // buffer descriptor address
      begin
        addr = `ETH_BASE + i_addr;
        
        wbm_init_waits = {$random} % 3;
        wbm_subseq_waits = {$random} % 5; // it is not important for single accesses
        if (i == 0)
        begin
          data = 32'hFFFFFFFF;
          wbm_write(addr, 32'hFFFFFFFF, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        end
        else if (i == 2)
        begin
          data = 32'h00000000;
          wbm_write(addr, 32'h00000000, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        end
        else
        begin
          wbm_read(addr, tmp_data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
          if (tmp_data !== data)
          begin
            fail = fail + 1;
            test_fail("PRESERVED value of the MAC buffer descriptors is not correct");
            `TIME;
            $display("  addr %h, data %h, tmp_data %h", addr, data, tmp_data);
          end
        end
      end
      if ((i == 0) || (i == 2))
      begin
        // reset MAC registers
        hard_reset;
      end
    end
    if(fail == 0)
      test_ok;
    else
    fail = 0;
  end


  if (test_num == 5) //
  begin
        /*  // TEST 5: 'WALKING ONE' WITH BURST CYCLES ACROSS MAC REGISTERS ( VARIOUS BUS DELAYS )
          test_name   = "TEST 5: 'WALKING ONE' WITH BURST CYCLES ACROSS MAC REGISTERS ( VARIOUS BUS DELAYS )";
          `TIME; $display("  TEST 5: 'WALKING ONE' WITH BURST CYCLES ACROSS MAC REGISTERS ( VARIOUS BUS DELAYS )");
        
          data = 0;
          burst_data = 0;
          burst_tmp_data = 0;
          i_length = 10; // two bursts for length 20
          for (i = 0; i <= 4; i = i + 1) // for initial wait cycles on WB bus
          begin
            for (i1 = 0; i1 <= 4; i1 = i1 + 1) // for initial wait cycles on WB bus
            begin
              wbm_init_waits = i;
              wbm_subseq_waits = i1; 
              #1;
              for (i_data = 0; i_data <= 31; i_data = i_data + 1) // the position of walking one
              begin
                data = 1'b1 << i_data;
                #1;
                for (i2 = 32'h4C; i2 >= 0; i2 = i2 - 4)
                begin
                  burst_data = burst_data << 32;
                  // DO NOT WRITE to 3 LSBits of MIICOMMAND !!!
                  if ( ((`ETH_BASE + i2) == `ETH_MIICOMMAND) && (i_data <= 2) ) 
                  begin
                    #1 burst_data[31:0] = 0;
                  end
                  else
                  begin
                    #1 burst_data[31:0] = data;
                  end
                end
                #1;
                // 2 burst writes
                addr = `ETH_BASE; // address of a first burst
                wbm_write(addr, burst_data[(32 * 10 - 1):0], 4'hF, i_length, wbm_init_waits, wbm_subseq_waits);
                burst_tmp_data = burst_data >> (32 * i_length);
                addr = addr + 32'h28; // address of a second burst
                wbm_write(addr, burst_tmp_data[(32 * 10 - 1):0], 4'hF, i_length, wbm_init_waits, wbm_subseq_waits);
                #1;
                // 2 burst reads
                addr = `ETH_BASE; // address of a first burst
                wbm_read(addr, burst_tmp_data[(32 * 10 - 1):0], 4'hF, i_length, 
                         wbm_init_waits, wbm_subseq_waits); // first burst
                burst_tmp_data = burst_tmp_data << (32 * i_length);
                addr = addr + 32'h28; // address of a second burst
                wbm_read(addr, burst_tmp_data[(32 * 10 - 1):0], 4'hF, i_length,
                         wbm_init_waits, wbm_subseq_waits); // second burst
                #1;
                for (i2 = 0; i2 <= 32'h4C; i2 = i2 + 4)
                begin
                  // set ranges of R/W bits
                  case (`ETH_BASE + i2)
                  `ETH_MODER:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 16;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_INT: // READONLY - tested within INT test
                    begin
                      bit_start_1 = 32; // not used
                      bit_end_1   = 32; // not used
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_INT_MASK:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 6;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_IPGT:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 6;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_IPGR1:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 6;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_IPGR2:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 6;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_PACKETLEN:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 31;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_COLLCONF:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 5;
                      bit_start_2 = 16; 
                      bit_end_2   = 19; 
                    end
                  `ETH_TX_BD_NUM: 
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 7;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_CTRLMODER:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 2;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_MIIMODER:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 9;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_MIICOMMAND: // "WRITEONLY" - tested within MIIM test - 3 LSBits are not written here!!!
                    begin
                      bit_start_1 = 32; // not used
                      bit_end_1   = 32; // not used
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_MIIADDRESS:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 4;
                      bit_start_2 = 8; 
                      bit_end_2   = 12;
                    end
                  `ETH_MIITX_DATA:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 15;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_MIIRX_DATA: // READONLY - tested within MIIM test
                    begin
                      bit_start_1 = 32; // not used
                      bit_end_1   = 32; // not used
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_MIISTATUS: // READONLY - tested within MIIM test
                    begin
                      bit_start_1 = 32; // not used
                      bit_end_1   = 32; // not used
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_MAC_ADDR0:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 31;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_MAC_ADDR1:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 15;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  `ETH_HASH_ADDR0:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 31;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  default: // `ETH_HASH_ADDR1:
                    begin
                      bit_start_1 = 0;
                      bit_end_1   = 31;
                      bit_start_2 = 32; // not used
                      bit_end_2   = 32; // not used
                    end
                  endcase
                  #1;
                  // 3 LSBits of MIICOMMAND are NOT written !!!
                  if ( ((`ETH_BASE + i2) == `ETH_MIICOMMAND) && (i_data <= 2) )
                  begin
                    if (burst_tmp_data[31:0] !== burst_data[31:0])
                    begin
                      fail = fail + 1;
                      test_fail("NON WR bit of the MAC MIICOMMAND register was wrong written or read");
                      `TIME;
                      $display("wbm_init_waits %d, wbm_subseq_waits %d, addr %h, data %h, tmp_data %h",
                                wbm_init_waits, wbm_subseq_waits, i2, burst_data[31:0], burst_tmp_data[31:0]);
                    end
                  end
                  else
                  begin
                    if ( ((i_data >= bit_start_1) && (i_data <= bit_end_1)) ||
                         ((i_data >= bit_start_2) && (i_data <= bit_end_2)) ) // data should be equal to tmp_data
                    begin
                      if (burst_tmp_data[31:0] !== burst_data[31:0])
                      begin
                        fail = fail + 1;
                        test_fail("RW bit of the MAC register was not written or not read");
                        `TIME;
                        $display("wbm_init_waits %d, wbm_subseq_waits %d, addr %h, data %h, tmp_data %h", 
                                  wbm_init_waits, wbm_subseq_waits, i2, burst_data[31:0], burst_tmp_data[31:0]);
                      end
                    end
                    else // data should not be equal to tmp_data
                    begin
                      if (burst_tmp_data[31:0] === burst_data[31:0])
                      begin
                        fail = fail + 1;
                        test_fail("NON RW bit of the MAC register was written, but it shouldn't be");
                        `TIME;
                        $display("wbm_init_waits %d, wbm_subseq_waits %d, addr %h, data %h, tmp_data %h", 
                                  wbm_init_waits, wbm_subseq_waits, i2, burst_data[31:0], burst_tmp_data[31:0]);
                      end
                    end
                  end
                  burst_tmp_data = burst_tmp_data >> 32;
                  burst_data = burst_data >> 32;
                end
              end
            end
          end
          if(fail == 0)
            test_ok;
          else
            fail = 0;*/
  end

end

end
endtask // test_access_to_mac_reg



task test_mac_full_duplex_transmit;
  input  [31:0]  start_task;
  input  [31:0]  end_task;
  integer        bit_start_1;
  integer        bit_end_1;
  integer        bit_start_2;
  integer        bit_end_2;
  integer        num_of_reg;
  integer        num_of_frames;
  integer        num_of_bd;
  integer        i_addr;
  integer        i_data;
  integer        i_length;
  integer        tmp_len;
  integer        tmp_bd;
  integer        tmp_bd_num;
  integer        tmp_data;
  integer        tmp_ipgt;
  integer        test_num;
  reg    [31:0]  tx_bd_num;
  reg    [((`MAX_BLK_SIZE * 32) - 1):0] burst_data;
  reg    [((`MAX_BLK_SIZE * 32) - 1):0] burst_tmp_data;
  integer        i;
  integer        i1;
  integer        i2;
  integer        i3;
  integer        fail;
  integer        speed;
  reg            no_underrun;
  reg            frame_started;
  reg            frame_ended;
  reg            wait_for_frame;
  reg    [31:0]  addr;
  reg    [31:0]  data;
  reg    [31:0]  tmp;
  reg    [ 7:0]  st_data;
  reg    [15:0]  max_tmp;
  reg    [15:0]  min_tmp;

begin
// MAC FULL DUPLEX TRANSMIT TEST
test_heading("MAC FULL DUPLEX TRANSMIT TEST");
$display(" ");
$display("MAC FULL DUPLEX TRANSMIT TEST");
fail = 0;

// reset MAC registers
hard_reset;
// set wb slave response
wb_slave.cycle_response(`ACK_RESPONSE, wbs_waits, wbs_retries);

  /*
  TASKS for set and control TX buffer descriptors (also send packet - set_tx_bd_ready):
  -------------------------------------------------------------------------------------
  set_tx_bd 
    (tx_bd_num_start[6:0], tx_bd_num_end[6:0], len[15:0], irq, pad, crc, txpnt[31:0]);
  set_tx_bd_wrap 
    (tx_bd_num_end[6:0]);
  set_tx_bd_ready 
    (tx_bd_num_start[6:0], tx_bd_num_end[6:0]);
  check_tx_bd 
    (tx_bd_num_start[6:0], tx_bd_status[31:0]);
  clear_tx_bd 
    (tx_bd_num_start[6:0], tx_bd_num_end[6:0]);

  TASKS for set and control RX buffer descriptors:
  ------------------------------------------------
  set_rx_bd 
    (rx_bd_num_strat[6:0], rx_bd_num_end[6:0], irq, rxpnt[31:0]);
  set_rx_bd_wrap 
    (rx_bd_num_end[6:0]);
  set_rx_bd_empty 
    (rx_bd_num_strat[6:0], rx_bd_num_end[6:0]);
  check_rx_bd 
    (rx_bd_num_end[6:0], rx_bd_status);
  clear_rx_bd 
    (rx_bd_num_strat[6:0], rx_bd_num_end[6:0]);

  TASKS for set and check TX packets:
  -----------------------------------
  set_tx_packet 
    (txpnt[31:0], len[15:0], eth_start_data[7:0]);
  check_tx_packet 
    (txpnt_wb[31:0], txpnt_phy[31:0], len[15:0], failure[31:0]);

  TASKS for set and check RX packets:
  -----------------------------------
  set_rx_packet 
    (rxpnt[31:0], len[15:0], plus_nibble, d_addr[47:0], s_addr[47:0], type_len[15:0], start_data[7:0]);
  check_rx_packet 
    (rxpnt_phy[31:0], rxpnt_wb[31:0], len[15:0], plus_nibble, successful_nibble, failure[31:0]);

  TASKS for append and check CRC to/of TX packet:
  -----------------------------------------------
  append_tx_crc 
    (txpnt_wb[31:0], len[15:0], negated_crc);
  check_tx_crc 
    (txpnt_phy[31:0], len[15:0], negated_crc, failure[31:0]); 

  TASK for append CRC to RX packet (CRC is checked together with check_rx_packet):
  --------------------------------------------------------------------------------
  append_rx_crc 
    (rxpnt_phy[31:0], len[15:0], plus_nibble, negated_crc);
  */

//////////////////////////////////////////////////////////////////////
////                                                              ////
////  test_mac_full_duplex_transmit:                              ////
////                                                              ////
////  0: Test no transmit when all buffers are RX ( 10Mbps ).     ////
////  1: Test no transmit when all buffers are RX ( 100Mbps ).    ////
////  2: Test transmit packets from MINFL to MAXFL sizes at       ////
////     one TX buffer decriptor ( 10Mbps ).                      ////
////  3: Test transmit packets from MINFL to MAXFL sizes at       ////
////     one TX buffer decriptor ( 100Mbps ).                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
for (test_num = start_task; test_num <= end_task; test_num = test_num + 1)
begin

  ////////////////////////////////////////////////////////////////////
  ////                                                            ////
  ////  Test transmit packets from MINFL to MAXFL sizes at        ////
  ////  one TX buffer decriptor ( 10Mbps ).                       ////
  ////                                                            ////
  ////////////////////////////////////////////////////////////////////
  if (test_num == 2) //
  begin
    // TEST 2: TRANSMIT PACKETS FROM MINFL TO MAXFL SIZES AT ONE TX BD ( 10Mbps )
    test_name = "TEST 2: TRANSMIT PACKETS FROM MINFL TO MAXFL SIZES AT ONE TX BD ( 10Mbps )";
    `TIME; $display("  TEST 2: TRANSMIT PACKETS FROM MINFL TO MAXFL SIZES AT ONE TX BD ( 10Mbps )");
  
    max_tmp = 0;
    min_tmp = 0;
    // set one TX buffer descriptor - must be set before TX enable
    wait (wbm_working == 0);
    wbm_write(`ETH_TX_BD_NUM, 32'h1, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    // enable TX, set full-duplex mode, NO padding and CRC appending
    wait (wbm_working == 0);
    wbm_write(`ETH_MODER, `ETH_MODER_TXEN | `ETH_MODER_FULLD | `ETH_MODER_CRCEN,
              4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    // prepare two packets of MAXFL length
    wait (wbm_working == 0);
    wbm_read(`ETH_PACKETLEN, tmp, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    max_tmp = tmp[15:0]; // 18 bytes consists of 6B dest addr, 6B source addr, 2B type/len, 4B CRC
    min_tmp = tmp[31:16];
    st_data = 8'h01;
    set_tx_packet(`MEMORY_BASE, (max_tmp), st_data); // length without CRC
    st_data = 8'h10;
    set_tx_packet((`MEMORY_BASE + max_tmp), (max_tmp), st_data); // length without CRC
    // check WB INT signal
    if (wb_int !== 1'b0)
    begin
      test_fail("WB INT signal should not be set");
      fail = fail + 1;
    end
  
    // write to phy's control register for 10Mbps
    #Tp eth_phy.control_bit14_10 = 5'b00000; // bit 13 reset - speed 10
    #Tp eth_phy.control_bit8_0   = 9'h1_00;  // bit 6 reset  - (10/100), bit 8 set - FD
    speed = 10;
  
    i_length = (min_tmp - 4);
    //i_length = (max_tmp - 4); //Vedula ...
    while (i_length <= (max_tmp - 4))
    begin
      // choose generating carrier sense and collision for first and last 64 lengths of frames
      case (i_length[1:0])
      2'h0: // Interrupt is generated
      begin
        // enable interrupt generation
        set_tx_bd(0, 0, i_length, 1'b1, 1'b1, 1'b1, (`MEMORY_BASE + i_length[1:0]));
        // unmask interrupts
        wait (wbm_working == 0);
        wbm_write(`ETH_INT_MASK, `ETH_INT_TXB | `ETH_INT_TXE | `ETH_INT_RXB | `ETH_INT_RXE | `ETH_INT_BUSY |
                                 `ETH_INT_TXC | `ETH_INT_RXC, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        // not detect carrier sense in FD and no collision
        eth_phy.carrier_sense_tx_fd_detect(0);
        eth_phy.collision(0);
      end
      2'h1: // Interrupt is not generated
      begin
        // enable interrupt generation
        set_tx_bd(0, 0, i_length, 1'b1, 1'b1, 1'b1, ((`MEMORY_BASE + i_length[1:0]) + max_tmp));
        // mask interrupts
        wait (wbm_working == 0);
        wbm_write(`ETH_INT_MASK, 32'h0, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        // detect carrier sense in FD and no collision
        eth_phy.carrier_sense_tx_fd_detect(1);
        eth_phy.collision(0);
      end
      2'h2: // Interrupt is not generated
      begin
        // disable interrupt generation
        set_tx_bd(0, 0, i_length, 1'b0, 1'b1, 1'b1, (`MEMORY_BASE + i_length[1:0]));
        // unmask interrupts
        wait (wbm_working == 0);
        wbm_write(`ETH_INT_MASK, `ETH_INT_TXB | `ETH_INT_TXE | `ETH_INT_RXB | `ETH_INT_RXE | `ETH_INT_BUSY |
                                 `ETH_INT_TXC | `ETH_INT_RXC, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        // not detect carrier sense in FD and set collision
        eth_phy.carrier_sense_tx_fd_detect(0);
        eth_phy.collision(1);
      end
      default: // 2'h3: // Interrupt is not generated
      begin
        // disable interrupt generation
        set_tx_bd(0, 0, i_length, 1'b0, 1'b1, 1'b1, ((`MEMORY_BASE + i_length[1:0]) + max_tmp));
        // mask interrupts
        wait (wbm_working == 0);
        wbm_write(`ETH_INT_MASK, 32'h0, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        // detect carrier sense in FD and set collision
        eth_phy.carrier_sense_tx_fd_detect(1);
        eth_phy.collision(1);
      end
      endcase
      eth_phy.set_tx_mem_addr(max_tmp);
      // set wrap bit
      set_tx_bd_wrap(0);
      set_tx_bd_ready(0, 0);
      #1 check_tx_bd(0, data);


      if (i_length < min_tmp) // just first four
      begin
        while (data[15] === 1)
        begin
          #1 check_tx_bd(0, data);
          @(posedge wb_clk);
        end
        repeat (1) @(posedge wb_clk);
      end
      else if (i_length > (max_tmp - 8)) // just last four
      begin
        tmp = 0;
        wait (MTxEn === 1'b1); // start transmit
        while (tmp < (i_length - 20))
        begin
          #1 tmp = tmp + 1;
          @(posedge wb_clk);
        end
        #1 check_tx_bd(0, data);
        while (data[15] === 1)
        begin
          #1 check_tx_bd(0, data);
          @(posedge wb_clk);
        end
        repeat (1) @(posedge wb_clk);
      end
      else
      begin
        wait (MTxEn === 1'b1); // start transmit
        #1 check_tx_bd(0, data);
        if (data[15] !== 1)
        begin
          test_fail("Wrong buffer descriptor's ready bit read out from MAC");
          fail = fail + 1;
        end
        wait (MTxEn === 1'b0); // end transmit
        while (data[15] === 1)
        begin
          #1 check_tx_bd(0, data);
          @(posedge wb_clk);
        end
        repeat (1) @(posedge wb_clk);
      end

      repeat(5) @(posedge mtx_clk);  // Wait some time so PHY stores the CRC

      // check length of a PACKET
      if (eth_phy.tx_len != (i_length + 4))
      begin
        test_fail("Wrong length of the packet out from MAC");
        fail = fail + 1;
      end
      // checking in the following if statement is performed only for first and last 64 lengths
      if ( ((i_length + 4) <= (min_tmp + 64)) || ((i_length + 4) > (max_tmp - 64)) )
      begin
        // check transmitted TX packet data
        if (i_length[0] == 0)
        begin
          check_tx_packet((`MEMORY_BASE + i_length[1:0]), max_tmp, i_length, tmp);
        end
        else
        begin
          check_tx_packet(((`MEMORY_BASE + i_length[1:0]) + max_tmp), max_tmp, i_length, tmp);
        end
        if (tmp > 0)
        begin
          test_fail("Wrong data of the transmitted packet");
          fail = fail + 1;
        end
        // check transmited TX packet CRC
        check_tx_crc(max_tmp, i_length, 1'b0, tmp); // length without CRC

        if (tmp > 0)
        begin
          test_fail("Wrong CRC of the transmitted packet");
          fail = fail + 1;
        end
      end
      // check WB INT signal
      if (i_length[1:0] == 2'h0)
      begin
        if (wb_int !== 1'b1)
        begin
          `TIME; $display("*E WB INT signal should be set");
          test_fail("WB INT signal should be set");
          fail = fail + 1;
        end
      end
      else
      begin
        if (wb_int !== 1'b0)
        begin
          `TIME; $display("*E WB INT signal should not be set");
          test_fail("WB INT signal should not be set");
          fail = fail + 1;
        end
      end
      // check TX buffer descriptor of a packet
      check_tx_bd(0, data);
      if (i_length[1] == 1'b0) // interrupt enabled
      begin
        if (data[15:0] !== 16'h7800)
        begin
          `TIME; $display("*E TX buffer descriptor status is not correct: %0h", data[15:0]);
          test_fail("TX buffer descriptor status is not correct");
          fail = fail + 1;
        end
      end
      else // interrupt not enabled
      begin
        if (data[15:0] !== 16'h3800)
        begin
          `TIME; $display("*E TX buffer descriptor status is not correct: %0h", data[15:0]);
          test_fail("TX buffer descriptor status is not correct");
          fail = fail + 1;
        end
      end
      // clear TX buffer descriptor
      clear_tx_bd(0, 0);
      // check interrupts
      wait (wbm_working == 0);
      wbm_read(`ETH_INT, data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
      if ((i_length[1:0] == 2'h0) || (i_length[1:0] == 2'h1))
      begin
        if ((data & `ETH_INT_TXB) !== 1'b1)
        begin
          `TIME; $display("*E Interrupt Transmit Buffer was not set, interrupt reg: %0h", data);
          test_fail("Interrupt Transmit Buffer was not set");
          fail = fail + 1;
        end
        if ((data & (~`ETH_INT_TXB)) !== 0)
        begin
          `TIME; $display("*E Other interrupts (except Transmit Buffer) were set, interrupt reg: %0h", data);
          test_fail("Other interrupts (except Transmit Buffer) were set");
          fail = fail + 1;
        end
      end
      else
      begin
        if (data !== 0)
        begin
          `TIME; $display("*E Any of interrupts (except Transmit Buffer) was set, interrupt reg: %0h, len: %0h", data, i_length[1:0]);
          test_fail("Any of interrupts (except Transmit Buffer) was set");
          fail = fail + 1;
        end
      end
      // clear interrupts
      wait (wbm_working == 0);
      wbm_write(`ETH_INT, data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
      // check WB INT signal
      if (wb_int !== 1'b0)
      begin
        test_fail("WB INT signal should not be set");
        fail = fail + 1;
      end
      // INTERMEDIATE DISPLAYS
      if ((i_length + 4) == (min_tmp + 64))
      begin
        // starting length is min_tmp, ending length is (min_tmp + 64)
        $display("    pads appending to packets is NOT selected");
        $display("    ->packets with lengths from %0d (MINFL) to %0d are checked (length increasing by 1 byte)",
                 min_tmp, (min_tmp + 64));
        // set padding, remain the rest
        wait (wbm_working == 0);
        wbm_write(`ETH_MODER, `ETH_MODER_TXEN | `ETH_MODER_FULLD | `ETH_MODER_PAD | `ETH_MODER_CRCEN,
                  4'hF, 1, wbm_init_waits, wbm_subseq_waits);
      end
      else if ((i_length + 4) == (max_tmp - 16))
      begin
        // starting length is for +128 longer than previous ending length, while ending length is tmp_data
        $display("    pads appending to packets is selected");
        $display("    ->packets with lengths from %0d to %0d are checked (length increasing by 128 bytes)",
                 (min_tmp + 64 + 128), tmp_data); 
        // reset padding, remain the rest
        wait (wbm_working == 0);
        wbm_write(`ETH_MODER, `ETH_MODER_TXEN | `ETH_MODER_FULLD | `ETH_MODER_CRCEN,
                  4'hF, 1, wbm_init_waits, wbm_subseq_waits);
      end
      else if ((i_length + 4) == max_tmp)
      begin
        $display("    pads appending to packets is NOT selected");
        $display("    ->packets with lengths from %0d to %0d (MAXFL) are checked (length increasing by 1 byte)",
                 (max_tmp - (4 + 16)), max_tmp);
      end

      // set length (loop variable)
      if ((i_length + 4) < (min_tmp + 64))
        i_length = i_length + 1;
      else if ( ((i_length + 4) >= (min_tmp + 64)) && ((i_length + 4) <= (max_tmp - 256)) )
      begin
        i_length = i_length + 128;
        tmp_data = i_length + 4; // last tmp_data is ending length
      end
      else if ( ((i_length + 4) > (max_tmp - 256)) && ((i_length + 4) < (max_tmp - 16)) )
        i_length = max_tmp - (4 + 16);
      else if ((i_length + 4) >= (max_tmp - 16))
        i_length = i_length + 1;
      else
      begin
        $display("*E TESTBENCH ERROR - WRONG PARAMETERS IN TESTBENCH");
        #10 $stop;
      end
    end // while (i_length <= (max_tmp - 4))

    // disable TX
    wait (wbm_working == 0);
    wbm_write(`ETH_MODER, `ETH_MODER_FULLD | `ETH_MODER_PAD | `ETH_MODER_CRCEN,
              4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    if(fail == 0)
      test_ok;
    else
      fail = 0;
  end




end   //  for (test_num=start_task; test_num <= end_task; test_num=test_num+1)

end
endtask // test_mac_full_duplex_transmit

task test_mac_full_duplex_receive;
  input  [31:0]  start_task;
  input  [31:0]  end_task;
  integer        bit_start_1;
  integer        bit_end_1;
  integer        bit_start_2;
  integer        bit_end_2;
  integer        num_of_reg;
  integer        num_of_frames;
  integer        num_of_bd;
  integer        i_addr;
  integer        i_data;
  integer        i_length;
  integer        tmp_len;
  integer        tmp_bd;
  integer        tmp_bd_num;
  integer        tmp_data;
  integer        tmp_ipgt;
  integer        test_num;
  integer        loop_count;
  reg    [31:0]  tx_bd_num;
  reg    [((`MAX_BLK_SIZE * 32) - 1):0] burst_data;
  reg    [((`MAX_BLK_SIZE * 32) - 1):0] burst_tmp_data;
  integer        i;
  integer        i1;
  integer        i2;
  integer        i3;
  integer        fail;
  integer        speed;
  reg            frame_started;
  reg            frame_ended;
  reg            wait_for_frame;
  reg            check_frame;
  reg            stop_checking_frame;
  reg            first_fr_received;
  reg    [31:0]  addr;
  reg    [31:0]  data;
  reg    [31:0]  tmp;
  reg    [ 7:0]  st_data;
  reg    [15:0]  max_tmp;
  reg    [15:0]  min_tmp;
begin
// MAC FULL DUPLEX RECEIVE TEST
test_heading("MAC FULL DUPLEX RECEIVE TEST");
$display(" ");
$display("MAC FULL DUPLEX RECEIVE TEST");
fail = 0;

// reset MAC registers
hard_reset;
// set wb slave response
wb_slave.cycle_response(`ACK_RESPONSE, wbs_waits, wbs_retries);

  /*
  TASKS for set and control TX buffer descriptors (also send packet - set_tx_bd_ready):
  -------------------------------------------------------------------------------------
  set_tx_bd 
    (tx_bd_num_start[6:0], tx_bd_num_end[6:0], len[15:0], irq, pad, crc, txpnt[31:0]);
  set_tx_bd_wrap 
    (tx_bd_num_end[6:0]);
  set_tx_bd_ready 
    (tx_bd_num_start[6:0], tx_bd_num_end[6:0]);
  check_tx_bd 
    (tx_bd_num_start[6:0], tx_bd_status[31:0]);
  clear_tx_bd 
    (tx_bd_num_start[6:0], tx_bd_num_end[6:0]);

  TASKS for set and control RX buffer descriptors:
  ------------------------------------------------
  set_rx_bd 
    (rx_bd_num_strat[6:0], rx_bd_num_end[6:0], irq, rxpnt[31:0]);
  set_rx_bd_wrap 
    (rx_bd_num_end[6:0]);
  set_rx_bd_empty 
    (rx_bd_num_strat[6:0], rx_bd_num_end[6:0]);
  check_rx_bd 
    (rx_bd_num_end[6:0], rx_bd_status);
  clear_rx_bd 
    (rx_bd_num_strat[6:0], rx_bd_num_end[6:0]);

  TASKS for set and check TX packets:
  -----------------------------------
  set_tx_packet 
    (txpnt[31:0], len[15:0], eth_start_data[7:0]);
  check_tx_packet 
    (txpnt_wb[31:0], txpnt_phy[31:0], len[15:0], failure[31:0]);

  TASKS for set and check RX packets:
  -----------------------------------
  set_rx_packet 
    (rxpnt[31:0], len[15:0], plus_nibble, d_addr[47:0], s_addr[47:0], type_len[15:0], start_data[7:0]);
  check_rx_packet 
    (rxpnt_phy[31:0], rxpnt_wb[31:0], len[15:0], plus_nibble, successful_nibble, failure[31:0]);

  TASKS for append and check CRC to/of TX packet:
  -----------------------------------------------
  append_tx_crc 
    (txpnt_wb[31:0], len[15:0], negated_crc);
  check_tx_crc 
    (txpnt_phy[31:0], len[15:0], negated_crc, failure[31:0]); 

  TASK for append CRC to RX packet (CRC is checked together with check_rx_packet):
  --------------------------------------------------------------------------------
  append_rx_crc 
    (rxpnt_phy[31:0], len[15:0], plus_nibble, negated_crc);
  */

//////////////////////////////////////////////////////////////////////
////                                                              ////
////  test_mac_full_duplex_receive:                               ////
////                                                              ////
////  0: Test no receive when all buffers are TX ( 10Mbps ).      ////
////  1: Test no receive when all buffers are TX ( 100Mbps ).     ////
////  2: Test receive packet synchronization with receive         ////
////     disable/enable ( 10Mbps ).                               ////
////  3: Test receive packet synchronization with receive         ////
////     disable/enable ( 100Mbps ).                              ////
////  4: Test receive packets from MINFL to MAXFL sizes at        ////
////     one RX buffer decriptor ( 10Mbps ).                      ////
////  5: Test receive packets from MINFL to MAXFL sizes at        ////
////     one RX buffer decriptor ( 100Mbps ).                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
for (test_num = start_task; test_num <= end_task; test_num = test_num + 1)
begin

  ////////////////////////////////////////////////////////////////////
  ////                                                            ////
  ////  Test receive packets from MINFL to MAXFL sizes at         ////
  ////  one RX buffer decriptor ( 10Mbps ).                       ////
  ////                                                            ////
  ////////////////////////////////////////////////////////////////////
  if (test_num == 4) // 
  begin
    // TEST 4: RECEIVE PACKETS FROM MINFL TO MAXFL SIZES AT ONE RX BD ( 10Mbps )
    test_name   = "TEST 4: RECEIVE PACKETS FROM MINFL TO MAXFL SIZES AT ONE RX BD ( 10Mbps )";
    `TIME; $display("  TEST 4: RECEIVE PACKETS FROM MINFL TO MAXFL SIZES AT ONE RX BD ( 10Mbps )");

    // unmask interrupts
    wait (wbm_working == 0);
    wbm_write(`ETH_INT_MASK, `ETH_INT_TXB | `ETH_INT_TXE | `ETH_INT_RXB | `ETH_INT_RXE | `ETH_INT_BUSY |
                             `ETH_INT_TXC | `ETH_INT_RXC, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    // set 1 RX buffer descriptor (8'h80 - 1) - must be set before RX enable
    wait (wbm_working == 0);
    wbm_write(`ETH_TX_BD_NUM, 32'h7F, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    // enable RX, set full-duplex mode, NO receive small, NO correct IFG
    wait (wbm_working == 0);
    wbm_write(`ETH_MODER, `ETH_MODER_RXEN | `ETH_MODER_FULLD | `ETH_MODER_IFG | 
              `ETH_MODER_PRO,// | `ETH_MODER_BRO, 
              4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    // prepare two packets of MAXFL length
    wait (wbm_working == 0);
    wbm_read(`ETH_PACKETLEN, tmp, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    max_tmp = tmp[15:0]; // 18 bytes consists of 6B dest addr, 6B source addr, 2B type/len, 4B CRC
    min_tmp = tmp[31:16];
    st_data = 8'h0F;
    set_rx_packet(0, (max_tmp - 4), 1'b0, 48'hAA02_0304_0506, 48'h0708_090A_0B0C, 16'h0D0E, st_data); // length without CRC
    st_data = 8'h1A;
    set_rx_packet((max_tmp), (max_tmp - 4), 1'b0, 48'h1234_5678_8765, 48'hA1B2_C3D4_E5F6, 16'hE77E, st_data); 
    // check WB INT signal
    if (wb_int !== 1'b0)
    begin
      test_fail("WB INT signal should not be set");
      fail = fail + 1;
    end
  
    // write to phy's control register for 10Mbps
    #Tp eth_phy.control_bit14_10 = 5'b00000; // bit 13 reset - speed 10
    #Tp eth_phy.control_bit8_0   = 9'h1_00;  // bit 6 reset  - (10/100), bit 8 set - FD
    speed = 10;

    i_length = (min_tmp - 4);
    //i_length = (max_tmp - 8);
    $display("RX i_length == %h", i_length);
    //while (i_length <= (max_tmp - 4))
    for(loop_count = 0; loop_count < 10; loop_count = loop_count + 1)
    begin
      i_length = (min_tmp - 4);
      // choose generating carrier sense and collision for first and last 64 lengths of frames
      case (i_length[1:0])
      2'h0: // Interrupt is generated
      begin
        // enable interrupt generation
        set_rx_bd(127, 127, 1'b1, (`MEMORY_BASE + i_length[1:0]));
        // unmask interrupts
        wait (wbm_working == 0);
        wbm_write(`ETH_INT_MASK, `ETH_INT_TXB | `ETH_INT_TXE | `ETH_INT_RXB | `ETH_INT_RXE | `ETH_INT_BUSY |
                                 `ETH_INT_TXC | `ETH_INT_RXC, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        // not detect carrier sense in FD and no collision
        eth_phy.no_carrier_sense_rx_fd_detect(0);
        eth_phy.collision(0);
      end
      2'h1: // Interrupt is not generated
      begin
        // enable interrupt generation
        set_rx_bd(127, 127, 1'b1, ((`MEMORY_BASE + i_length[1:0]) + max_tmp));
        // mask interrupts
        wait (wbm_working == 0);
        wbm_write(`ETH_INT_MASK, 32'h0, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        // detect carrier sense in FD and no collision
        eth_phy.no_carrier_sense_rx_fd_detect(1);
        eth_phy.collision(0);
      end
      2'h2: // Interrupt is not generated
      begin
        // disable interrupt generation
        set_rx_bd(127, 127, 1'b0, (`MEMORY_BASE + i_length[1:0]));
        // unmask interrupts
        wait (wbm_working == 0);
        wbm_write(`ETH_INT_MASK, `ETH_INT_TXB | `ETH_INT_TXE | `ETH_INT_RXB | `ETH_INT_RXE | `ETH_INT_BUSY |
                                 `ETH_INT_TXC | `ETH_INT_RXC, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        // not detect carrier sense in FD and set collision
        eth_phy.no_carrier_sense_rx_fd_detect(0);
        eth_phy.collision(1);
      end
      default: // 2'h3: // Interrupt is not generated
      begin
        // disable interrupt generation
        set_rx_bd(127, 127, 1'b0, ((`MEMORY_BASE + i_length[1:0]) + max_tmp));
        // mask interrupts
        wait (wbm_working == 0);
        wbm_write(`ETH_INT_MASK, 32'h0, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
        // detect carrier sense in FD and set collision
        eth_phy.no_carrier_sense_rx_fd_detect(1);
        eth_phy.collision(1);
      end
      endcase
      if (i_length[0] == 1'b0)
        append_rx_crc (0, i_length, 1'b0, 1'b0);
      else
        append_rx_crc (max_tmp, i_length, 1'b0, 1'b0);
      // set wrap bit
      set_rx_bd_wrap(127);
      set_rx_bd_empty(127, 127);
      fork
        begin
          if (i_length[0] == 1'b0)
            #1 eth_phy.send_rx_packet(64'h0055_5555_5555_5555, 4'h7, 8'hD5, 0, (i_length + 4), 1'b0);
          else
            #1 eth_phy.send_rx_packet(64'h0055_5555_5555_5555, 4'h7, 8'hD5, max_tmp, (i_length + 4), 1'b0);
          repeat(10) @(posedge mrx_clk);
        end
        begin
          #1 check_rx_bd(127, data);
          if (i_length < min_tmp) // just first four
          begin
            while (data[15] === 1)
            begin
              #1 check_rx_bd(127, data);
              @(posedge wb_clk);
            end
            repeat (1) @(posedge wb_clk);
          end
          else
          begin
            wait (MRxDV === 1'b1); // start transmit
            #1 check_rx_bd(127, data);
            if (data[15] !== 1)
            begin
              test_fail("Wrong buffer descriptor's ready bit read out from MAC");
              fail = fail + 1;
            end
            wait (MRxDV === 1'b0); // end transmit
            while (data[15] === 1)
            begin
              #1 check_rx_bd(127, data);
              @(posedge wb_clk);
            end
            repeat (1) @(posedge wb_clk);
          end
        end
      join
      // check length of a PACKET
      if (data[31:16] != (i_length + 4))
      begin
        `TIME; $display("*E Wrong length of the packet out from PHY (%0d instead of %0d)", 
                        data[31:16], (i_length + 4));
        test_fail("Wrong length of the packet out from PHY");
        fail = fail + 1;
      end
      // checking in the following if statement is performed only for first and last 64 lengths
      // check received RX packet data and CRC
      if (i_length[0] == 1'b0)
      begin
        check_rx_packet(0, (`MEMORY_BASE + i_length[1:0]), (i_length + 4), 1'b0, 1'b0, tmp);
      end
      else
      begin
        check_rx_packet(max_tmp, ((`MEMORY_BASE + i_length[1:0]) + max_tmp), (i_length + 4), 1'b0, 1'b0, tmp);
      end
      if (tmp > 0)
      begin
        `TIME; $display("*E Wrong data of the received packet");
        test_fail("Wrong data of the received packet");
        fail = fail + 1;
      end
      // check WB INT signal
      if (i_length[1:0] == 2'h0)
      begin
        if (wb_int !== 1'b1)
        begin
          `TIME; $display("*E WB INT signal should be set");
          test_fail("WB INT signal should be set");
          fail = fail + 1;
        end
      end
      else
      begin
        if (wb_int !== 1'b0)
        begin
          `TIME; $display("*E WB INT signal should not be set");
          test_fail("WB INT signal should not be set");
          fail = fail + 1;
        end
      end
      // check RX buffer descriptor of a packet
      check_rx_bd(127, data);
      if (i_length[1] == 1'b0) // interrupt enabled no_carrier_sense_rx_fd_detect
      begin
        if ( ((data[15:0] !== 16'h6080) && (i_length[0] == 1'b0)) ||
             ((data[15:0] !== 16'h6080) && (i_length[0] == 1'b1)) )
        begin
          `TIME; $display("*E RX buffer descriptor status is not correct: %0h", data[15:0]);
          test_fail("RX buffer descriptor status is not correct");
          fail = fail + 1;
        end
      end
      else // interrupt not enabled
      begin
        if ( ((data[15:0] !== 16'h2080) && (i_length[0] == 1'b0)) ||
             ((data[15:0] !== 16'h2080) && (i_length[0] == 1'b1)) )
        begin
          `TIME; $display("*E RX buffer descriptor status is not correct: %0h", data[15:0]);
          test_fail("RX buffer descriptor status is not correct");
          fail = fail + 1;
        end
      end
      // clear RX buffer descriptor for first 4 frames
      if (i_length < min_tmp)
        clear_rx_bd(127, 127);
      // check interrupts
      wait (wbm_working == 0);
      wbm_read(`ETH_INT, data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
      if ((i_length[1:0] == 2'h0) || (i_length[1:0] == 2'h1))
      begin
        if ((data & `ETH_INT_RXB) !== `ETH_INT_RXB)
        begin
          `TIME; $display("*E Interrupt Receive Buffer was not set, interrupt reg: %0h", data);
          test_fail("Interrupt Receive Buffer was not set");
          fail = fail + 1;
        end
        if ((data & (~`ETH_INT_RXB)) !== 0)
        begin
          `TIME; $display("*E Other interrupts (except Receive Buffer) were set, interrupt reg: %0h", data);
          test_fail("Other interrupts (except Receive Buffer) were set");
          fail = fail + 1;
        end
      end
      else
      begin
        if (data !== 0)
        begin
          `TIME; $display("*E Any of interrupts (except Receive Buffer) was set, interrupt reg: %0h, len: %0h", data, i_length[1:0]);
          test_fail("Any of interrupts (except Receive Buffer) was set");
          fail = fail + 1;
        end
      end
      // clear interrupts
      wait (wbm_working == 0);
      wbm_write(`ETH_INT, data, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
      // check WB INT signal
      if (wb_int !== 1'b0)
      begin
        test_fail("WB INT signal should not be set");
        fail = fail + 1;
      end
      // INTERMEDIATE DISPLAYS
      if ((i_length + 4) == (min_tmp + 64))
      begin
        // starting length is min_tmp, ending length is (min_tmp + 64)
        $display("    receive small packets is NOT selected");
        $display("    ->packets with lengths from %0d (MINFL) to %0d are checked (length increasing by 1 byte)",
                 min_tmp, (min_tmp + 64));
        // set receive small, remain the rest
        wait (wbm_working == 0);
        wbm_write(`ETH_MODER, `ETH_MODER_RXEN | `ETH_MODER_FULLD | `ETH_MODER_RECSMALL | `ETH_MODER_IFG | 
                  `ETH_MODER_PRO | `ETH_MODER_BRO, 
                  4'hF, 1, wbm_init_waits, wbm_subseq_waits);
      end
      else if ((i_length + 4) == (max_tmp - 16))
      begin
        // starting length is for +128 longer than previous ending length, while ending length is tmp_data
        $display("    receive small packets is selected");
        $display("    ->packets with lengths from %0d to %0d are checked (length increasing by 128 bytes)",
                 (min_tmp + 64 + 128), tmp_data); 
        // reset receive small, remain the rest
        wait (wbm_working == 0);
        wbm_write(`ETH_MODER, `ETH_MODER_RXEN | `ETH_MODER_FULLD | `ETH_MODER_IFG | 
                  `ETH_MODER_PRO | `ETH_MODER_BRO, 
                  4'hF, 1, wbm_init_waits, wbm_subseq_waits);
      end
      else if ((i_length + 4) == max_tmp)
      begin
        $display("    receive small packets is NOT selected");
        $display("    ->packets with lengths from %0d to %0d (MAXFL) are checked (length increasing by 1 byte)",
                 (max_tmp - (4 + 16)), max_tmp);
      end
      // set length (loop variable)
      if ((i_length + 4) < (min_tmp + 64))
        i_length = i_length + 1;
      else if ( ((i_length + 4) >= (min_tmp + 64)) && ((i_length + 4) <= (max_tmp - 256)) )
      begin
        i_length = i_length + 128;
        tmp_data = i_length + 4; // last tmp_data is ending length
      end
      else if ( ((i_length + 4) > (max_tmp - 256)) && ((i_length + 4) < (max_tmp - 16)) )
        i_length = max_tmp - (4 + 16);
      else if ((i_length + 4) >= (max_tmp - 16))
        i_length = i_length + 1;
      else
      begin
        $display("*E TESTBENCH ERROR - WRONG PARAMETERS IN TESTBENCH");
        #10 $stop;
      end
    end
    // disable RX
    wait (wbm_working == 0);
    wbm_write(`ETH_MODER, `ETH_MODER_FULLD | `ETH_MODER_RECSMALL | `ETH_MODER_IFG | 
              `ETH_MODER_PRO | `ETH_MODER_BRO,
              4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    if(fail == 0)
      test_ok;
    else
      fail = 0;
  end
end   //  for (test_num=start_task; test_num <= end_task; test_num=test_num+1)

end
endtask // test_mac_full_duplex_receive

task wbm_write;
  input  [31:0] address_i;
  input  [((`MAX_BLK_SIZE * 32) - 1):0] data_i;
  input  [3:0]  sel_i;
  input  [31:0] size_i;
  input  [3:0]  init_waits_i;
  input  [3:0]  subseq_waits_i;

  reg `WRITE_STIM_TYPE write_data;
  reg `WB_TRANSFER_FLAGS flags;
  reg `WRITE_RETURN_TYPE write_status;
  integer i;
begin
  wbm_working = 1;
  
  write_status = 0;

  flags                    = 0;
  flags`WB_TRANSFER_SIZE   = size_i;
  flags`INIT_WAITS         = init_waits_i;
  flags`SUBSEQ_WAITS       = subseq_waits_i;

  write_data               = 0;
  write_data`WRITE_DATA    = data_i[31:0];
  write_data`WRITE_ADDRESS = address_i;
  write_data`WRITE_SEL     = sel_i;

  for (i = 0; i < size_i; i = i + 1)
  begin
    wb_master.blk_write_data[i] = write_data;
    data_i                      = data_i >> 32;
    write_data`WRITE_DATA       = data_i[31:0];
    write_data`WRITE_ADDRESS    = write_data`WRITE_ADDRESS + 4;
  end

  wb_master.wb_block_write(flags, write_status);

  if (write_status`CYC_ACTUAL_TRANSFER !== size_i)
  begin
    `TIME;
    $display("*E WISHBONE Master was unable to complete the requested write operation to MAC!");
  end

  @(posedge wb_clk);
  #3;
  wbm_working = 0;
  #1;
end
endtask // wbm_write

task wbm_read;
  input  [31:0] address_i;
  output [((`MAX_BLK_SIZE * 32) - 1):0] data_o;
  input  [3:0]  sel_i;
  input  [31:0] size_i;
  input  [3:0]  init_waits_i;
  input  [3:0]  subseq_waits_i;

  reg `READ_RETURN_TYPE read_data;
  reg `WB_TRANSFER_FLAGS flags;
  reg `READ_RETURN_TYPE read_status;
  integer i;
begin
  wbm_working = 1;

  read_status = 0;
  data_o      = 0;

  flags                  = 0;
  flags`WB_TRANSFER_SIZE = size_i;
  flags`INIT_WAITS       = init_waits_i;
  flags`SUBSEQ_WAITS     = subseq_waits_i;

  read_data              = 0;
  read_data`READ_ADDRESS = address_i;
  read_data`READ_SEL     = sel_i;

  for (i = 0; i < size_i; i = i + 1)
  begin
    wb_master.blk_read_data_in[i] = read_data;
    read_data`READ_ADDRESS        = read_data`READ_ADDRESS + 4;
  end

  wb_master.wb_block_read(flags, read_status);

  if (read_status`CYC_ACTUAL_TRANSFER !== size_i)
  begin
    `TIME;
    $display("*E WISHBONE Master was unable to complete the requested read operation from MAC!");
  end

  for (i = 0; i < size_i; i = i + 1)
  begin
    data_o       = data_o << 32;
    read_data    = wb_master.blk_read_data_out[(size_i - 1) - i]; // [31 - i];
    data_o[31:0] = read_data`READ_DATA;
  end

  @(posedge wb_clk);
  #3;
  wbm_working = 0;
  #1;
end
endtask // wbm_read

task hard_reset; //  MAC registers
begin
  // reset MAC registers
  @(posedge wb_clk);
  #2 wb_rst = 1'b1;
  repeat(2) @(posedge wb_clk);
  #2 wb_rst = 1'b0;
end
endtask // hard_reset

task test_heading;
  input [799:0] test_heading ;
  reg   [799:0] display_test ;
begin
  display_test = test_heading;
  while ( display_test[799:792] == 0 )
    display_test = display_test << 8 ;
  $fdisplay( tb_log_file, "  ***************************************************************************************" ) ;
  $fdisplay( tb_log_file, "  ***************************************************************************************" ) ;
  $fdisplay( tb_log_file, "  Heading: %s", display_test ) ;
  $fdisplay( tb_log_file, "  ***************************************************************************************" ) ;
  $fdisplay( tb_log_file, "  ***************************************************************************************" ) ;
  $fdisplay( tb_log_file, " " ) ;
end
endtask // test_heading

task test_fail ;
  input [7999:0] failure_reason ;
//  reg   [8007:0] display_failure ;
  reg   [7999:0] display_failure ;
  reg   [799:0] display_test ;
begin
  tests_failed = tests_failed + 1 ;

  display_failure = failure_reason; // {failure_reason, "!"} ;
  while ( display_failure[7999:7992] == 0 )
    display_failure = display_failure << 8 ;

  display_test = test_name ;
  while ( display_test[799:792] == 0 )
    display_test = display_test << 8 ;

  $fdisplay( tb_log_file, "    *************************************************************************************" ) ;
  $fdisplay( tb_log_file, "    At time: %t ", $time ) ;
  $fdisplay( tb_log_file, "    Test: %s", display_test ) ;
  $fdisplay( tb_log_file, "    *FAILED* because") ;
  $fdisplay( tb_log_file, "    %s", display_failure ) ;
  $fdisplay( tb_log_file, "    *************************************************************************************" ) ;
  $fdisplay( tb_log_file, " " ) ;

 `ifdef STOP_ON_FAILURE
    #20 $stop ;
 `endif
end
endtask // test_fail


task test_fail_num ;
  input [7999:0] failure_reason ;
  input [31:0]   number ;
//  reg   [8007:0] display_failure ;
  reg   [7999:0] display_failure ;
  reg   [799:0] display_test ;
begin
  tests_failed = tests_failed + 1 ;

  display_failure = failure_reason; // {failure_reason, "!"} ;
  while ( display_failure[7999:7992] == 0 )
    display_failure = display_failure << 8 ;

  display_test = test_name ;
  while ( display_test[799:792] == 0 )
    display_test = display_test << 8 ;

  $fdisplay( tb_log_file, "    *************************************************************************************" ) ;
  $fdisplay( tb_log_file, "    At time: %t ", $time ) ;
  $fdisplay( tb_log_file, "    Test: %s", display_test ) ;
  $fdisplay( tb_log_file, "    *FAILED* because") ;
  $fdisplay( tb_log_file, "    %s; %d", display_failure, number ) ;
  $fdisplay( tb_log_file, "    *************************************************************************************" ) ;
  $fdisplay( tb_log_file, " " ) ;

 `ifdef STOP_ON_FAILURE
    #20 $stop ;
 `endif
end
endtask // test_fail_num


task test_ok ;
  reg [799:0] display_test ;
begin
  tests_successfull = tests_successfull + 1 ;

  display_test = test_name ;
  while ( display_test[799:792] == 0 )
    display_test = display_test << 8 ;

  $fdisplay( tb_log_file, "    *************************************************************************************" ) ;
  $fdisplay( tb_log_file, "    At time: %t ", $time ) ;
  $fdisplay( tb_log_file, "    Test: %s", display_test ) ;
  $fdisplay( tb_log_file, "    reported *SUCCESSFULL*! ") ;
  $fdisplay( tb_log_file, "    *************************************************************************************" ) ;
  $fdisplay( tb_log_file, " " ) ;
end
endtask // test_ok


task test_summary;
begin
  $fdisplay(tb_log_file, "**************************** Ethernet MAC test summary **********************************") ;
  $fdisplay(tb_log_file, "Tests performed:   %d", tests_successfull + tests_failed) ;
  $fdisplay(tb_log_file, "Failed tests   :   %d", tests_failed) ;
  $fdisplay(tb_log_file, "Successfull tests: %d", tests_successfull) ;
  $fdisplay(tb_log_file, "**************************** Ethernet MAC test summary **********************************") ;
  $fclose(tb_log_file) ;
end
endtask // test_summary

task set_tx_packet;
  input  [31:0] txpnt;
  input  [15:0] len;
  input  [7:0]  eth_start_data;
  integer       i, sd;
  integer       buffer;
  reg           delta_t;
begin
  buffer = txpnt;
  sd = eth_start_data;
  delta_t = 0;

  // First write might not be word allign.
  if(buffer[1:0] == 1)  
  begin
    wb_slave.wr_mem(buffer - 1, {8'h0, sd[7:0], sd[7:0] + 3'h1, sd[7:0] + 3'h2}, 4'h7);
    sd = sd + 3;
    i = 3;
  end
  else if(buffer[1:0] == 2)  
  begin
    wb_slave.wr_mem(buffer - 2, {16'h0, sd[7:0], sd[7:0] + 3'h1}, 4'h3);
    sd = sd + 2;
    i = 2;
  end      
  else if(buffer[1:0] == 3)
  begin
    wb_slave.wr_mem(buffer - 3, {24'h0, sd[7:0]}, 4'h1);
    sd = sd + 1;
    i = 1;
  end
  else
    i = 0;
  delta_t = !delta_t;

  for(i = i; i < (len - 4); i = i + 4) // Last 0-3 bytes are not written
  begin  
    wb_slave.wr_mem(buffer + i, {sd[7:0], sd[7:0] + 3'h1, sd[7:0] + 3'h2, sd[7:0] + 3'h3}, 4'hF);
    sd = sd + 4;
  end
  delta_t = !delta_t;
  
  // Last word
  if((len - i) == 3)
  begin
    wb_slave.wr_mem(buffer + i, {sd[7:0], sd[7:0] + 3'h1, sd[7:0] + 3'h2, 8'h0}, 4'hE);
  end
  else if((len - i) == 2)
  begin
    wb_slave.wr_mem(buffer + i, {sd[7:0], sd[7:0] + 3'h1, 16'h0}, 4'hC);
  end
  else if((len - i) == 1)
  begin
    wb_slave.wr_mem(buffer + i, {sd[7:0], 24'h0}, 4'h8);
  end
  else if((len - i) == 4)
  begin
    wb_slave.wr_mem(buffer + i, {sd[7:0], sd[7:0] + 3'h1, sd[7:0] + 3'h2, sd[7:0] + 3'h3}, 4'hF);
  end
  else
    $display("(%0t)(%m) ERROR", $time);
  delta_t = !delta_t;
end
endtask // set_tx_packet

task check_tx_packet;
  input  [31:0] txpnt_wb;  // source
  input  [31:0] txpnt_phy; // destination
  input  [15:0] len;
  output [31:0] failure;
  integer       i, data_wb, data_phy;
  reg    [31:0] addr_wb, addr_phy;
  reg    [31:0] failure;
  reg           delta_t;
begin
  addr_wb = txpnt_wb;
  addr_phy = txpnt_phy;
  delta_t = 0;
  failure = 0;
  #1;
  // First write might not be word allign.
  if(addr_wb[1:0] == 1)
  begin
    wb_slave.rd_mem(addr_wb - 1, data_wb, 4'h7);
    data_phy[31:24] = 0;
    data_phy[23:16] = eth_phy.tx_mem[addr_phy[21:0]];
    data_phy[15: 8] = eth_phy.tx_mem[addr_phy[21:0] + 1];
    data_phy[ 7: 0] = eth_phy.tx_mem[addr_phy[21:0] + 2];
    i = 3;
    if (data_phy[23:0] !== data_wb[23:0])
    begin
      //`TIME;
      //$display("*E Wrong 1. word (3 bytes) of TX packet! phy: %0h, wb: %0h", data_phy[23:0], data_wb[23:0]);
      //$display("     address phy: %0h, address wb: %0h", addr_phy, addr_wb);
      failure = 1;
    end
  end
  else if (addr_wb[1:0] == 2)
  begin
    wb_slave.rd_mem(addr_wb - 2, data_wb, 4'h3);
    data_phy[31:16] = 0;
    data_phy[15: 8] = eth_phy.tx_mem[addr_phy[21:0]];
    data_phy[ 7: 0] = eth_phy.tx_mem[addr_phy[21:0] + 1];
    i = 2;
    if (data_phy[15:0] !== data_wb[15:0])
    begin
      //`TIME;
      //$display("*E Wrong 1. word (2 bytes) of TX packet! phy: %0h, wb: %0h", data_phy[15:0], data_wb[15:0]);
      //$display("     address phy: %0h, address wb: %0h", addr_phy, addr_wb);
      failure = 1;
    end
  end
  else if (addr_wb[1:0] == 3)
  begin
    wb_slave.rd_mem(addr_wb - 3, data_wb, 4'h1);
    data_phy[31: 8] = 0;
    data_phy[ 7: 0] = eth_phy.tx_mem[addr_phy[21:0]];
    i = 1;
    if (data_phy[7:0] !== data_wb[7:0])
    begin
      //`TIME;
      //$display("*E Wrong 1. word (1 byte) of TX packet! phy: %0h, wb: %0h", data_phy[7:0], data_wb[7:0]);
      //$display("     address phy: %0h, address wb: %0h", addr_phy, addr_wb);
      failure = 1;
    end
  end
  else
    i = 0;
  delta_t = !delta_t;
  #1;
  for(i = i; i < (len - 4); i = i + 4) // Last 0-3 bytes are not checked
  begin
    wb_slave.rd_mem(addr_wb + i, data_wb, 4'hF);
    data_phy[31:24] = eth_phy.tx_mem[addr_phy[21:0] + i];
    data_phy[23:16] = eth_phy.tx_mem[addr_phy[21:0] + i + 1];
    data_phy[15: 8] = eth_phy.tx_mem[addr_phy[21:0] + i + 2];
    data_phy[ 7: 0] = eth_phy.tx_mem[addr_phy[21:0] + i + 3];

    if (data_phy[31:0] !== data_wb[31:0])
    begin
      //`TIME;
      //$display("*E Wrong %d. word (4 bytes) of TX packet! phy: %0h, wb: %0h", ((i/4)+1), data_phy[31:0], data_wb[31:0]);
      //$display("     address phy: %0h, address wb: %0h", addr_phy, addr_wb);
      failure = failure + 1;
    end
  end
  delta_t = !delta_t;
  #1;
  // Last word
  if((len - i) == 3)
  begin
    wb_slave.rd_mem(addr_wb + i, data_wb, 4'hE);
    data_phy[31:24] = eth_phy.tx_mem[addr_phy[21:0] + i];
    data_phy[23:16] = eth_phy.tx_mem[addr_phy[21:0] + i + 1];
    data_phy[15: 8] = eth_phy.tx_mem[addr_phy[21:0] + i + 2];
    data_phy[ 7: 0] = 0;
    if (data_phy[31:8] !== data_wb[31:8])
    begin
      //`TIME;
      //$display("*E Wrong %d. word (3 bytes) of TX packet! phy: %0h, wb: %0h", ((i/4)+1), data_phy[31:8], data_wb[31:8]);
      //$display("     address phy: %0h, address wb: %0h", addr_phy, addr_wb);
      failure = failure + 1;
    end
  end
  else if((len - i) == 2)
  begin
    wb_slave.rd_mem(addr_wb + i, data_wb, 4'hC);
    data_phy[31:24] = eth_phy.tx_mem[addr_phy[21:0] + i];
    data_phy[23:16] = eth_phy.tx_mem[addr_phy[21:0] + i + 1];
    data_phy[15: 8] = 0;
    data_phy[ 7: 0] = 0;
    if (data_phy[31:16] !== data_wb[31:16])
    begin
      //`TIME;
      //$display("*E Wrong %d. word (2 bytes) of TX packet! phy: %0h, wb: %0h", ((i/4)+1), data_phy[31:16], data_wb[31:16]);
      //$display("     address phy: %0h, address wb: %0h", addr_phy, addr_wb);
      failure = failure + 1;
    end
  end
  else if((len - i) == 1)
  begin
    wb_slave.rd_mem(addr_wb + i, data_wb, 4'h8);
    data_phy[31:24] = eth_phy.tx_mem[addr_phy[21:0] + i];
    data_phy[23:16] = 0;
    data_phy[15: 8] = 0;
    data_phy[ 7: 0] = 0;
    if (data_phy[31:24] !== data_wb[31:24])
    begin
      //`TIME;
      //$display("*E Wrong %d. word (1 byte) of TX packet! phy: %0h, wb: %0h", ((i/4)+1), data_phy[31:24], data_wb[31:24]);
      //$display("     address phy: %0h, address wb: %0h", addr_phy, addr_wb);
      failure = failure + 1;
    end
  end
  else if((len - i) == 4)
  begin
    wb_slave.rd_mem(addr_wb + i, data_wb, 4'hF);
    data_phy[31:24] = eth_phy.tx_mem[addr_phy[21:0] + i];
    data_phy[23:16] = eth_phy.tx_mem[addr_phy[21:0] + i + 1];
    data_phy[15: 8] = eth_phy.tx_mem[addr_phy[21:0] + i + 2];
    data_phy[ 7: 0] = eth_phy.tx_mem[addr_phy[21:0] + i + 3];
    if (data_phy[31:0] !== data_wb[31:0])
    begin
      //`TIME;
      //$display("*E Wrong %d. word (4 bytes) of TX packet! phy: %0h, wb: %0h", ((i/4)+1), data_phy[31:0], data_wb[31:0]);
      //$display("     address phy: %0h, address wb: %0h", addr_phy, addr_wb);
      failure = failure + 1;
    end
  end
  else
    $display("(%0t)(%m) ERROR", $time);
  delta_t = !delta_t;
end
endtask // check_tx_packet

task set_tx_bd;
  input  [6:0]  tx_bd_num_start;
  input  [6:0]  tx_bd_num_end;
  input  [15:0] len;
  input         irq;
  input         pad;
  input         crc;
  input  [31:0] txpnt;

  integer       i;
  integer       bd_status_addr, bd_ptr_addr;
//  integer       buf_addr;
begin
  for(i = tx_bd_num_start; i <= tx_bd_num_end; i = i + 1) 
  begin
//    buf_addr = `TX_BUF_BASE + i * 32'h600;
    bd_status_addr = `TX_BD_BASE + i * 8;
    bd_ptr_addr = bd_status_addr + 4;
    // initialize BD - status
    wait (wbm_working == 0);
    $display("Vedula : BD_Address: %h, BD_0 = %h, BD_1 = %h", bd_status_addr, {len, 1'b0, irq, 1'b0, pad, crc, 11'h0}, txpnt);
    wbm_write(bd_status_addr, {len, 1'b0, irq, 1'b0, pad, crc, 11'h0}, 
              4'hF, 1, wbm_init_waits, wbm_subseq_waits); // IRQ + PAD + CRC
    // initialize BD - pointer
    wait (wbm_working == 0);
    wbm_write(bd_ptr_addr, txpnt, 4'hF, 1, wbm_init_waits, wbm_subseq_waits); // Initializing BD-pointer
  end
end
endtask // set_tx_bd
task check_tx_bd;
  input  [6:0]  tx_bd_num_end;
  output [31:0] tx_bd_status;
  integer       bd_status_addr, tmp;
begin
  bd_status_addr = `TX_BD_BASE + tx_bd_num_end * 8;
  wait (wbm_working == 0);
  wbm_read(bd_status_addr, tmp, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
  tx_bd_status = tmp;
end
endtask // check_tx_bd

task clear_tx_bd;
  input  [6:0]  tx_nd_num_strat;
  input  [6:0]  tx_bd_num_end;
  integer       i;
  integer       bd_status_addr, bd_ptr_addr;
begin
  for(i = tx_nd_num_strat; i <= tx_bd_num_end; i = i + 1)
  begin
    bd_status_addr = `TX_BD_BASE + i * 8;
    bd_ptr_addr = bd_status_addr + 4;
    // clear BD - status
    wait (wbm_working == 0);
    wbm_write(bd_status_addr, 32'h0, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    // clear BD - pointer
    wait (wbm_working == 0);
    wbm_write(bd_ptr_addr, 32'h0, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
  end
end
endtask // clear_tx_bd

task check_tx_crc; // used to check crc added to TX packets by MAC
  input  [31:0] txpnt_phy; // destination
  input  [15:0] len; // length in bytes without CRC
  input         negated_crc; // if appended CRC is correct or not
  output [31:0] failure;
  reg    [31:0] failure;
  reg    [31:0] crc_calc;
  reg    [31:0] crc;
  reg    [31:0] addr_phy;
  reg           delta_t;
begin
  addr_phy = txpnt_phy;
  failure = 0;
  // calculate CRC from sent packet
//  serial_crc_phy_tx(addr_phy, {16'h0, len}, 1'b0, crc_calc);
//#10;
  paralel_crc_phy_tx(addr_phy, {16'h0, len}, 1'b0, crc_calc);
  #1;
  addr_phy = addr_phy + len;
  // Read CRC - BIG endian
  crc[31:24] = eth_phy.tx_mem[addr_phy[21:0]];
  crc[23:16] = eth_phy.tx_mem[addr_phy[21:0] + 1];
  crc[15: 8] = eth_phy.tx_mem[addr_phy[21:0] + 2];
  crc[ 7: 0] = eth_phy.tx_mem[addr_phy[21:0] + 3];

  delta_t = !delta_t;
  if (negated_crc)
  begin
    if ((~crc_calc) !== crc)
    begin
      `TIME;
      $display("*E Negated CRC was not successfuly transmitted!");
      failure = failure + 1;
    end
  end
  else
  begin
    if (crc_calc !== crc)
    begin
      `TIME;
      $display("*E Transmitted CRC was not correct; crc_calc: %0h, crc_mem: %0h", crc_calc, crc);
      failure = failure + 1;
    end
  end
  delta_t = !delta_t;
end
endtask // check_tx_crc

task set_tx_bd_wrap;
  input  [6:0]  tx_bd_num_end;
  integer       bd_status_addr, tmp;
begin
  bd_status_addr = `TX_BD_BASE + tx_bd_num_end * 8;
  wait (wbm_working == 0);
  wbm_read(bd_status_addr, tmp, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
  // set wrap bit to this BD - this BD should be last-one
  wait (wbm_working == 0);
  wbm_write(bd_status_addr, (`ETH_TX_BD_WRAP | tmp), 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
end
endtask // set_tx_bd_wrap

task set_tx_bd_ready;
  input  [6:0]  tx_nd_num_strat;
  input  [6:0]  tx_bd_num_end;
  integer       i;
  integer       bd_status_addr, tmp;
begin
  for(i = tx_nd_num_strat; i <= tx_bd_num_end; i = i + 1)
  begin
    bd_status_addr = `TX_BD_BASE + i * 8;
    wait (wbm_working == 0);
    wbm_read(bd_status_addr, tmp, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    // set empty bit to this BD - this BD should be ready
    wait (wbm_working == 0);
    wbm_write(bd_status_addr, (`ETH_TX_BD_READY | tmp), 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
  end
end
endtask // set_tx_bd_ready

// paralel CRC checking for PHY TX
task paralel_crc_phy_tx;
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
  load_reg[31:24] = eth_phy.tx_mem[addr_cnt];
  addr_cnt = addr_cnt + 1;
  load_reg[23:16] = eth_phy.tx_mem[addr_cnt];
  addr_cnt = addr_cnt + 1;
  load_reg[15: 8] = eth_phy.tx_mem[addr_cnt];
  addr_cnt = addr_cnt + 1;
  load_reg[ 7: 0] = eth_phy.tx_mem[addr_cnt];
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
      load_reg[31:24] = eth_phy.tx_mem[addr_cnt];
      addr_cnt = addr_cnt + 1;
      load_reg[23:16] = eth_phy.tx_mem[addr_cnt];
      addr_cnt = addr_cnt + 1;
      load_reg[15: 8] = eth_phy.tx_mem[addr_cnt];
      addr_cnt = addr_cnt + 1;
      load_reg[ 7: 0] = eth_phy.tx_mem[addr_cnt];
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
endtask // paralel_crc_phy_tx

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

//set_rx_bd(127, 127, 1'b1, (`MEMORY_BASE + i_length[1:0]));
task set_rx_bd;
  input  [6:0]  rx_bd_num_strat;
  input  [6:0]  rx_bd_num_end;
  input         irq;
  input  [31:0] rxpnt;
//  input  [6:0]  rxbd_num;
  integer       i;
  integer       bd_status_addr, bd_ptr_addr;
//  integer       buf_addr;
begin
  for(i = rx_bd_num_strat; i <= rx_bd_num_end; i = i + 1) 
  begin
//    buf_addr = `RX_BUF_BASE + i * 32'h600;
//    bd_status_addr = `RX_BD_BASE + i * 8;
//    bd_ptr_addr = bd_status_addr + 4; 
    bd_status_addr = `TX_BD_BASE + i * 8;
    bd_ptr_addr = bd_status_addr + 4;
    
    // initialize BD - status
    wait (wbm_working == 0);
//    wbm_write(bd_status_addr, 32'h0000c000, 4'hF, 1, wbm_init_waits, wbm_subseq_waits); // IRQ + PAD + CRC
    wbm_write(bd_status_addr, {17'h0, irq, 14'h0}, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);

    // initialize BD - pointer
    wait (wbm_working == 0);
//    wbm_write(bd_ptr_addr, buf_addr, 4'hF, 1, wbm_init_waits, wbm_subseq_waits); // Initializing BD-pointer
    wbm_write(bd_ptr_addr, rxpnt, 4'hF, 1, wbm_init_waits, wbm_subseq_waits); // Initializing BD-pointer
  end
end
endtask // set_rx_bd

task set_rx_bd_wrap;
  input  [6:0]  rx_bd_num_end;
  integer       bd_status_addr, tmp;
begin
//  bd_status_addr = `RX_BD_BASE + rx_bd_num_end * 8;
  bd_status_addr = `TX_BD_BASE + rx_bd_num_end * 8;
  wait (wbm_working == 0);
  wbm_read(bd_status_addr, tmp, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
  // set wrap bit to this BD - this BD should be last-one
  wait (wbm_working == 0);
  wbm_write(bd_status_addr, (`ETH_RX_BD_WRAP | tmp), 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
end
endtask // set_rx_bd_wrap

task set_rx_bd_empty;
  input  [6:0]  rx_bd_num_strat;
  input  [6:0]  rx_bd_num_end;
  integer       i;
  integer       bd_status_addr, tmp;
begin
  for(i = rx_bd_num_strat; i <= rx_bd_num_end; i = i + 1)
  begin
//    bd_status_addr = `RX_BD_BASE + i * 8;
    bd_status_addr = `TX_BD_BASE + i * 8;
    wait (wbm_working == 0);
    wbm_read(bd_status_addr, tmp, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    // set empty bit to this BD - this BD should be ready
    wait (wbm_working == 0);
    wbm_write(bd_status_addr, (`ETH_RX_BD_EMPTY | tmp), 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
  end
end
endtask // set_rx_bd_empty

task check_rx_bd;
  input  [6:0]  rx_bd_num_end;
  output [31:0] rx_bd_status;
  integer       bd_status_addr, tmp;
begin
//  bd_status_addr = `RX_BD_BASE + rx_bd_num_end * 8;
  bd_status_addr = `TX_BD_BASE + rx_bd_num_end * 8;
  wait (wbm_working == 0);
  wbm_read(bd_status_addr, tmp, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
  rx_bd_status = tmp;
end
endtask // check_rx_bd

task clear_rx_bd;
  input  [6:0]  rx_bd_num_strat;
  input  [6:0]  rx_bd_num_end;
  integer       i;
  integer       bd_status_addr, bd_ptr_addr;
begin
  for(i = rx_bd_num_strat; i <= rx_bd_num_end; i = i + 1)
  begin
//    bd_status_addr = `RX_BD_BASE + i * 8;
    bd_status_addr = `TX_BD_BASE + i * 8;
    bd_ptr_addr = bd_status_addr + 4;
    // clear BD - status
    wait (wbm_working == 0);
    wbm_write(bd_status_addr, 32'h0, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
    // clear BD - pointer
    wait (wbm_working == 0);
    wbm_write(bd_ptr_addr, 32'h0, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
  end
end
endtask // clear_rx_bd

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

task append_rx_crc_delayed;
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
  paralel_crc_phy_rx(rxpnt_phy+4, {16'h0, len}-4, plus_dribble_nibble, crc);
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
endtask // append_rx_crc_delayed

task check_rx_packet;
  input  [31:0] rxpnt_phy; // source
  input  [31:0] rxpnt_wb;  // destination
  input  [15:0] len;
  input         plus_dribble_nibble; // if length is longer for one nibble
  input         successful_dribble_nibble; // if additional nibble is stored into memory
  output [31:0] failure;
  integer       i, data_wb, data_phy;
  reg    [31:0] addr_wb, addr_phy;
  reg    [31:0] failure;
  reg    [21:0] buffer;
  reg           delta_t;
begin
  addr_phy = rxpnt_phy;
  addr_wb = rxpnt_wb;
  delta_t = 0;
  failure = 0;

  // First write might not be word allign.
  if(addr_wb[1:0] == 1)
  begin
    wb_slave.rd_mem(addr_wb[21:0] - 1, data_wb, 4'h7);
    data_phy[31:24] = 0;
    data_phy[23:16] = eth_phy.rx_mem[addr_phy[21:0]];
    data_phy[15: 8] = eth_phy.rx_mem[addr_phy[21:0] + 1];
    data_phy[ 7: 0] = eth_phy.rx_mem[addr_phy[21:0] + 2];
    i = 3;
    if (data_phy[23:0] !== data_wb[23:0])
    begin
      //`TIME;
      //$display("   addr_phy = %h, addr_wb = %h", rxpnt_phy, rxpnt_wb);
      //$display("*E Wrong 1. word (3 bytes) of RX packet! phy = %h, wb = %h", data_phy[23:0], data_wb[23:0]);
      failure = 1;
    end
  end
  else if (addr_wb[1:0] == 2)
  begin
    wb_slave.rd_mem(addr_wb[21:0] - 2, data_wb, 4'h3);
    data_phy[31:16] = 0;
    data_phy[15: 8] = eth_phy.rx_mem[addr_phy[21:0]];
    data_phy[ 7: 0] = eth_phy.rx_mem[addr_phy[21:0] + 1];
    i = 2;
    if (data_phy[15:0] !== data_wb[15:0])
    begin
      //`TIME;
      //$display("   addr_phy = %h, addr_wb = %h", rxpnt_phy, rxpnt_wb);
      //$display("*E Wrong 1. word (2 bytes) of RX packet! phy = %h, wb = %h", data_phy[15:0], data_wb[15:0]);
      failure = 1;
    end
  end
  else if (addr_wb[1:0] == 3)
  begin
    wb_slave.rd_mem(addr_wb[21:0] - 3, data_wb, 4'h1);
    data_phy[31: 8] = 0;
    data_phy[ 7: 0] = eth_phy.rx_mem[addr_phy[21:0]];
    i = 1;
    if (data_phy[7:0] !== data_wb[7:0])
    begin
      //`TIME;
      //$display("   addr_phy = %h, addr_wb = %h", rxpnt_phy, rxpnt_wb);
      //$display("*E Wrong 1. word (1 byte) of RX packet! phy = %h, wb = %h", data_phy[7:0], data_wb[7:0]);
      failure = 1;
    end
  end
  else
    i = 0;
  delta_t = !delta_t;

  for(i = i; i < (len - 4); i = i + 4) // Last 0-3 bytes are not checked
  begin
    wb_slave.rd_mem(addr_wb[21:0] + i, data_wb, 4'hF);
    data_phy[31:24] = eth_phy.rx_mem[addr_phy[21:0] + i];
    data_phy[23:16] = eth_phy.rx_mem[addr_phy[21:0] + i + 1];
    data_phy[15: 8] = eth_phy.rx_mem[addr_phy[21:0] + i + 2];
    data_phy[ 7: 0] = eth_phy.rx_mem[addr_phy[21:0] + i + 3];
    if (data_phy[31:0] !== data_wb[31:0])
    begin
      //`TIME;
      //if (i == 0)
      //  $display("   addr_phy = %h, addr_wb = %h", rxpnt_phy, rxpnt_wb);
      //$display("*E Wrong %0d. word (4 bytes) of RX packet! phy = %h, wb = %h", ((i/4)+1), data_phy[31:0], data_wb[31:0]);
      failure = failure + 1;
    end
  end
  delta_t = !delta_t;

  // Last word
  if((len - i) == 3)
  begin
    wb_slave.rd_mem(addr_wb[21:0] + i, data_wb, 4'hF);
    data_phy[31:24] = eth_phy.rx_mem[addr_phy[21:0] + i];
    data_phy[23:16] = eth_phy.rx_mem[addr_phy[21:0] + i + 1];
    data_phy[15: 8] = eth_phy.rx_mem[addr_phy[21:0] + i + 2];
    if (plus_dribble_nibble)
      data_phy[ 7: 0] = eth_phy.rx_mem[addr_phy[21:0] + i + 3];
    else
      data_phy[ 7: 0] = 0;
    if (data_phy[31:8] !== data_wb[31:8])
    begin
      //`TIME;
      //$display("*E Wrong %0d. word (3 bytes) of RX packet! phy = %h, wb = %h", ((i/4)+1), data_phy[31:8], data_wb[31:8]);
      failure = failure + 1;
    end
    if (plus_dribble_nibble && successful_dribble_nibble)
    begin
      if (data_phy[3:0] !== data_wb[3:0])
      begin
        //`TIME;
        //$display("*E Wrong dribble nibble in %0d. word (3 bytes) of RX packet!", ((i/4)+1));
        failure = failure + 1;
      end
    end
    else if (plus_dribble_nibble && !successful_dribble_nibble)
    begin
      if (data_phy[3:0] === data_wb[3:0])
      begin
        //`TIME;
        //$display("*E Wrong dribble nibble in %0d. word (3 bytes) of RX packet!", ((i/4)+1));
        failure = failure + 1;
      end
    end
  end
  else if((len - i) == 2)
  begin
    wb_slave.rd_mem(addr_wb[21:0] + i, data_wb, 4'hE);
    data_phy[31:24] = eth_phy.rx_mem[addr_phy[21:0] + i];
    data_phy[23:16] = eth_phy.rx_mem[addr_phy[21:0] + i + 1];
    if (plus_dribble_nibble)
      data_phy[15: 8] = eth_phy.rx_mem[addr_phy[21:0] + i + 2];
    else
      data_phy[15: 8] = 0;
    data_phy[ 7: 0] = 0;
    if (data_phy[31:16] !== data_wb[31:16])
    begin
      //`TIME;
      //$display("*E Wrong %0d. word (2 bytes) of RX packet! phy = %h, wb = %h", ((i/4)+1), data_phy[31:16], data_wb[31:16]);
      failure = failure + 1;
    end
    if (plus_dribble_nibble && successful_dribble_nibble)
    begin
      if (data_phy[11:8] !== data_wb[11:8])
      begin
        //`TIME;
        //$display("*E Wrong dribble nibble in %0d. word (2 bytes) of RX packet!", ((i/4)+1));
        failure = failure + 1;
      end
    end
    else if (plus_dribble_nibble && !successful_dribble_nibble)
    begin
      if (data_phy[11:8] === data_wb[11:8])
      begin
        //`TIME;
        //$display("*E Wrong dribble nibble in %0d. word (2 bytes) of RX packet!", ((i/4)+1));
        failure = failure + 1;
      end
    end
  end
  else if((len - i) == 1)
  begin
    wb_slave.rd_mem(addr_wb[21:0] + i, data_wb, 4'hC);
    data_phy[31:24] = eth_phy.rx_mem[addr_phy[21:0] + i];
    if (plus_dribble_nibble)
      data_phy[23:16] = eth_phy.rx_mem[addr_phy[21:0] + i + 1];
    else
      data_phy[23:16] = 0;
    data_phy[15: 8] = 0;
    data_phy[ 7: 0] = 0;
    if (data_phy[31:24] !== data_wb[31:24])
    begin
      //`TIME;
      //$display("*E Wrong %0d. word (1 byte) of RX packet! phy = %h, wb = %h", ((i/4)+1), data_phy[31:24], data_wb[31:24]);
      failure = failure + 1;
    end
    if (plus_dribble_nibble && successful_dribble_nibble)
    begin
      if (data_phy[19:16] !== data_wb[19:16])
      begin
        //`TIME;
        //$display("*E Wrong dribble nibble in %0d. word (1 byte) of RX packet!", ((i/4)+1));
        failure = failure + 1;
      end
    end
    else if (plus_dribble_nibble && !successful_dribble_nibble)
    begin
      if (data_phy[19:16] === data_wb[19:16])
      begin
        //`TIME;
        //$display("*E Wrong dribble nibble in %0d. word (1 byte) of RX packet!", ((i/4)+1));
        failure = failure + 1;
      end
    end
  end
  else if((len - i) == 4)
  begin
    wb_slave.rd_mem(addr_wb[21:0] + i, data_wb, 4'hF);
    data_phy[31:24] = eth_phy.rx_mem[addr_phy[21:0] + i];
    data_phy[23:16] = eth_phy.rx_mem[addr_phy[21:0] + i + 1];
    data_phy[15: 8] = eth_phy.rx_mem[addr_phy[21:0] + i + 2];
    data_phy[ 7: 0] = eth_phy.rx_mem[addr_phy[21:0] + i + 3];
    if (data_phy[31:0] !== data_wb[31:0])
    begin
      //`TIME;
      //$display("*E Wrong %0d. word (4 bytes) of RX packet! phy = %h, wb = %h", ((i/4)+1), data_phy[31:0], data_wb[31:0]);
      failure = failure + 1;
    end
    if (plus_dribble_nibble)
    begin
      wb_slave.rd_mem(addr_wb[21:0] + i + 4, data_wb, 4'h8);
      data_phy[31:24] = eth_phy.rx_mem[addr_phy[21:0] + i + 4];
      if (successful_dribble_nibble)
      begin
        if (data_phy[27:24] !== data_wb[27:24])
        begin
          //`TIME;
          //$display("*E Wrong dribble nibble in %0d. word (0 bytes) of RX packet!", ((i/4)+2));
          failure = failure + 1;
        end
      end
      else
      begin
        if (data_phy[27:24] === data_wb[27:24])
        begin
          //`TIME;
          //$display("*E Wrong dribble nibble in %0d. word (0 bytes) of RX packet!", ((i/4)+2));
          failure = failure + 1;
        end
      end
    end
  end
  else
    $display("(%0t)(%m) ERROR", $time);
  delta_t = !delta_t;
end
endtask // check_rx_packet

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

task simple_transmit;
reg    [ 7:0]  st_data;
reg    [15:0]  max_tmp;
reg    [15:0]  min_tmp;
integer        i_length;
reg    [31:0]  tmp;

begin
  // reset MAC registers
  hard_reset;
  // set wb slave response
  wb_slave.cycle_response(`ACK_RESPONSE, wbs_waits, wbs_retries);

  max_tmp = 0;
  min_tmp = 0;

  wait (wbm_working == 0);
  wbm_write(`ETH_TX_BD_NUM, 32'h1, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);

  wait (wbm_working == 0);
  wbm_write(`ETH_MODER, `ETH_MODER_TXEN | `ETH_MODER_FULLD | `ETH_MODER_CRCEN, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);

  wait (wbm_working == 0);
  wbm_read(`ETH_PACKETLEN, tmp, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
  max_tmp = tmp[15:0]; // 18 bytes consists of 6B dest addr, 6B source addr, 2B type/len, 4B CRC
  min_tmp = tmp[31:16];
  //i_length = (max_tmp - 4); //Vedula ...
  i_length = (min_tmp - 4); //Vedula ...
  $display("i_length == %h", i_length);

  st_data = 8'h01;
  set_tx_packet(`MEMORY_BASE, (max_tmp), st_data); // length without CRC

  set_tx_bd(0, 0, i_length, 1'b1, 1'b1, 1'b1, (`MEMORY_BASE + i_length[1:0]));

  wait (wbm_working == 0);
  wbm_write(`ETH_INT_MASK, `ETH_INT_TXB | `ETH_INT_TXE | `ETH_INT_RXB | `ETH_INT_RXE | `ETH_INT_BUSY |
                           `ETH_INT_TXC | `ETH_INT_RXC, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);

  set_tx_bd_wrap(0);
  set_tx_bd_ready(0, 0);

  wait (MTxEn === 1'b1); // start transmit
  repeat(100) @(posedge wb_clk);
  wait (MTxEn === 1'b0); // end transmit
  repeat(100) @(posedge wb_clk);
end
endtask //simple_transmit

task simple_receive;
reg    [ 7:0]  st_data;
reg    [15:0]  max_tmp;
reg    [15:0]  min_tmp;
integer        i_length;
reg    [31:0]  tmp;
reg    [31:0]  data;
integer        fail;

begin
  // reset MAC registers
  hard_reset;
  // set wb slave response
  wb_slave.cycle_response(`ACK_RESPONSE, wbs_waits, wbs_retries);

  max_tmp = 0;
  min_tmp = 0;

  wait (wbm_working == 0);
  wbm_write(`ETH_TX_BD_NUM, 32'h7F, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);

  wait (wbm_working == 0);
  wbm_write(`ETH_INT_MASK, `ETH_INT_TXB | `ETH_INT_TXE | `ETH_INT_RXB | `ETH_INT_RXE | `ETH_INT_BUSY |
                           `ETH_INT_TXC | `ETH_INT_RXC, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);

  wait (wbm_working == 0);
  wbm_write(`ETH_MODER, `ETH_MODER_RXEN | `ETH_MODER_FULLD | `ETH_MODER_IFG | 
            `ETH_MODER_PRO | `ETH_MODER_BRO, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);

  wait (wbm_working == 0);
  wbm_read(`ETH_PACKETLEN, tmp, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);
  max_tmp = tmp[15:0]; // 18 bytes consists of 6B dest addr, 6B source addr, 2B type/len, 4B CRC
  min_tmp = tmp[31:16];
  //i_length = (max_tmp - 4); //Vedula ...
  i_length = (min_tmp - 4); //Vedula ...
  $display("RX i_length == %h", i_length);
  $display("RX max_tmp == %h", max_tmp-4);

  st_data = 8'h0F;
  set_rx_packet(0, (max_tmp - 4), 1'b0, 48'hAA02_0304_0506, 48'h0708_090A_0B0C, 16'h0D0E, st_data); // length without CRC

  set_rx_bd(127, 127, 1'b1, (`MEMORY_BASE + i_length[1:0]));
  wait (wbm_working == 0);
  wbm_write(`ETH_INT_MASK, `ETH_INT_TXB | `ETH_INT_TXE | `ETH_INT_RXB | `ETH_INT_RXE | `ETH_INT_BUSY |
                           `ETH_INT_TXC | `ETH_INT_RXC, 4'hF, 1, wbm_init_waits, wbm_subseq_waits);

  if(i_length[0] == 1'b0)
    append_rx_crc (0, i_length, 1'b0, 1'b0);
  else
    append_rx_crc (max_tmp, i_length, 1'b0, 1'b0);

  // set wrap bit
  set_rx_bd_wrap(127);
  set_rx_bd_empty(127, 127);

  fork
    begin
      if (i_length[0] == 1'b0)
        #1 eth_phy.send_rx_packet(64'h0055_5555_5555_5555, 4'h7, 8'hD5, 0, (i_length + 4), 1'b0);
      else
        #1 eth_phy.send_rx_packet(64'h0055_5555_5555_5555, 4'h7, 8'hD5, max_tmp, (i_length + 4), 1'b0);
      repeat(10) @(posedge mrx_clk);
    end
    begin
      #1 check_rx_bd(127, data);
      if (i_length < min_tmp) // just first four
      begin
        while (data[15] === 1)
        begin
          #1 check_rx_bd(127, data);
          @(posedge wb_clk);
        end
        repeat (1) @(posedge wb_clk);
      end
      else
      begin
        wait (MRxDV === 1'b1); // start transmit
        #1 check_rx_bd(127, data);
        if (data[15] !== 1)
        begin
          test_fail("Wrong buffer descriptor's ready bit read out from MAC");
          fail = fail + 1;
        end
        wait (MRxDV === 1'b0); // end transmit
        while (data[15] === 1)
        begin
          #1 check_rx_bd(127, data);
          @(posedge wb_clk);
        end
        repeat (1) @(posedge wb_clk);
      end
    end
  join

  repeat(10000) @(posedge wb_clk);
end
endtask //simple_receive

endmodule
