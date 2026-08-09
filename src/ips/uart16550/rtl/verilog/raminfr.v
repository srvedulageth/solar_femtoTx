
`ifndef SYNTHESIS
`include "timescale.v"
`endif

module raminfr
        (clk, we, a, dpra, di, dpo);

parameter addr_width = 4;
parameter data_width = 8;
parameter depth = 16;

input clk;
input we;
input  [addr_width-1:0] a;
input  [addr_width-1:0] dpra;
input  [data_width-1:0] di;
//output [data_width-1:0] spo;
output [data_width-1:0] dpo;
reg    [data_width-1:0] ram [depth-1:0];

wire [data_width-1:0] dpo;
wire  [data_width-1:0] di;
wire  [addr_width-1:0] a;
wire  [addr_width-1:0] dpra;

  always @(posedge clk) begin
    if (we)
      ram[a] <= di;
  end
//  assign spo = ram[a];
  assign dpo = ram[dpra];
endmodule
