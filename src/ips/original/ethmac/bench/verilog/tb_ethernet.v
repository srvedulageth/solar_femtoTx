
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
//  forever #5 wb_clk = ~wb_clk;  // 2*5 ns -> 100.0 MHz    
//  forever #10 wb_clk = ~wb_clk;  // 2*10 ns -> 50.0 MHz    
//  forever #12.5 wb_clk = ~wb_clk;  // 2*12.5 ns -> 40 MHz    
  forever #15 wb_clk = ~wb_clk;  // 2*10 ns -> 33.3 MHz    
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
  test_access_to_mac_reg(0, 4);           // 0 - 4

  //test_mii(0, 17);                        // 0 - 17
  //$display("");
  //$display("===========================================================================");
  //$display("PHY generates ideal Carrier sense and Collision signals for following tests");
  //$display("===========================================================================");
  //test_note("PHY generates ideal Carrier sense and Collision signals for following tests");
  //eth_phy.carrier_sense_real_delay(0);
  //test_mac_full_duplex_transmit(0, 23);    // 0 - 23
  //test_mac_full_duplex_receive(0, 15);     // 0 - 15
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
endmodule
