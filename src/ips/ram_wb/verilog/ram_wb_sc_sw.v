
`ifndef SYNTHESIS
`include "timescale.v"
`endif

module ram (clk, dat_i, dat_o, adr_i, we_i );
  parameter dat_width = 32;
  parameter adr_width = 16;
  parameter mem_size  = 65536;
  //parameter string MEMFILE  = "";
  parameter [1023:0] MEMFILE = "";

  input [dat_width-1:0]      dat_i;
  input [adr_width-1:0]      adr_i;
  input 		      we_i;
  output wire [dat_width-1:0] dat_o;
  input 		      clk;   

  reg [dat_width-1:0] ram [0:mem_size - 1]; 
  //string filename;
  
  initial begin
    if (MEMFILE != "") begin
      $display("Loading RAM from %s", MEMFILE);
      $readmemh(MEMFILE, ram);
    end else begin
      $display("No MEMFILE specified, skipping init");
    end
  end

  assign dat_o = ram[adr_i];
  always @ (posedge clk) begin 
    if (we_i) begin
      ram[adr_i] <= dat_i;
    end
  end 
endmodule // ram
