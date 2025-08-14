
`ifndef SYNTHESIS
`include "timescale.v"
`endif

module ram (clk, dat_i, dat_o, adr_i, we_i );
  parameter dat_width = 32;
  parameter adr_width = 16;
  parameter mem_size  = 65536;

  input [dat_width-1:0]      dat_i;
  input [adr_width-1:0]      adr_i;
  input 		      we_i;
  output wire [dat_width-1:0] dat_o;
  input 		      clk;   

  reg [dat_width-1:0] ram [0:mem_size - 1]; 
  
  initial begin
    //$readmemh("uart.dump", ram);
    $readmemh("uart.dump_19200_100MHz", ram);
  end

  assign dat_o = ram[adr_i >> 2 ];
  always @ (posedge clk) begin 
    if (we_i) begin
      ram[adr_i >> 2] <= dat_i;
    end
  end 
endmodule // ram
