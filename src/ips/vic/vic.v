//
// A simple interrupt controller.
//
// Registers:
// 0x0 - INT_STATUS - Interrupt status as reported by peripherals (sticky).
// 0x4 - INT_MASK   - Interrupt mask - setting a bit to 1 masks the interrupt
// 0x8 - INT_CLEAR  - Write 1 to a particular bit to clear the interrupt
//                    status.

module vic #(
        parameter [31:0]        SOURCES                    = 32'd4,
        parameter [31:0]        INTERRUPT_PENDING_REGISTER = 32'h0,
        parameter [31:0]        INTERRUPT_MASK_REGISTER    = 32'h4,
        parameter [31:0]        INTERRUPT_CLEAR_REGISTER   = 32'h8
) (

// Clock and reset.
input  wire                 i_clk,
input  wire                 i_rst,

// Wishbone interface.
input  wire  [31:0]          i_wb_dat,
input  wire   [3:0]          i_wb_adr,
input  wire                  i_wb_stb,
input  wire                  i_wb_cyc,
input  wire                  i_wb_wen,
input  wire  [3:0]           i_wb_sel,
output reg  [31:0]           o_wb_dat,
output reg                   o_wb_ack,

// Interrupt sources in. Concatenate all
// sources together.
input wire   [SOURCES-1:0]       i_irq,

// Interrupt output. Level interrupt.
output  reg                  o_irq


);

`ifndef ZAP_SOC_VIC
`define ZAP_SOC_VIC
        `define INT_STATUS INTERRUPT_PENDING_REGISTER
        `define INT_MASK   INTERRUPT_MASK_REGISTER
        `define INT_CLEAR  INTERRUPT_CLEAR_REGISTER
`endif

reg [31:0] INT_STATUS;
reg [31:0] INT_MASK;
reg [31:0] wbstate;

// Wishbone states.
localparam WBIDLE       = 0;
localparam WBREAD       = 1;
localparam WBWRITE      = 2;
localparam WBACK        = 3;
localparam WBDONE       = 4;

// Send out a global interrupt signal.
always @ (posedge i_clk)
begin
        o_irq <= | ( INT_STATUS & ~INT_MASK );
end

// Wishbone access FSM
always @ ( posedge i_clk )
begin
        if ( i_rst )
        begin
                wbstate         <= WBIDLE;
                o_wb_dat        <= 0;
                o_wb_ack        <= 0;
                INT_MASK        <= 32'hffffffff;
                INT_STATUS      <= 32'h0;
        end
        else
        begin:blk1
                integer i;

                // Normally record interrupts. These are sticky bits.
                for(i=0;i<SOURCES;i=i+1)
                        INT_STATUS[i] <= INT_STATUS[i] == 0 ? i_irq[i] : 1'd1;

                case(wbstate)
                        WBIDLE:
                        begin
                                o_wb_ack <= 1'd0;

                                if ( i_wb_stb && i_wb_cyc )
                                begin
                                        if ( i_wb_wen )
                                                wbstate <= WBWRITE;
                                        else
                                                wbstate <= WBREAD;
                                end
                        end

                        WBWRITE:
                        begin
                                case(i_wb_adr)

                                `INT_MASK: // INT_MASK
                                begin
                                        if ( i_wb_sel[0] ) INT_MASK[7:0]   <= i_wb_dat >> 0;
                                        if ( i_wb_sel[1] ) INT_MASK[15:8]  <= i_wb_dat >> 8;
                                        if ( i_wb_sel[2] ) INT_MASK[23:16] <= i_wb_dat >> 16;
                                        if ( i_wb_sel[3] ) INT_MASK[31:24] <= i_wb_dat >> 24;

                                end

                                `INT_CLEAR: // INT_CLEAR
                                begin: blk22
                                        integer i;

                                        if ( i_wb_sel[0] ) for(i=0; i <=7;i=i+1) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0;
                                        if ( i_wb_sel[1] ) for(i=8; i<=15;i=i+1) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0;
                                        if ( i_wb_sel[2] ) for(i=16;i<=23;i=i+1) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0;
                                        if ( i_wb_sel[3] ) for(i=24;i<=31;i=i+1) if ( i_wb_dat[i] ) INT_STATUS[i] <= 1'd0;
                                end

                                default:
                                begin
                                        $display($time, " Error : Attemting to write to illegal register in %m at address %x", i_wb_adr);
                                        $finish;
                                end

                                endcase

                                wbstate <= WBACK;
                        end

                        WBREAD:
                        begin
                                case(i_wb_adr)
                                `INT_STATUS:            o_wb_dat <= `INT_STATUS;
                                `INT_MASK:              o_wb_dat <= `INT_MASK;

                                default:
                                begin
                                        $display($time, " Error : Attempting to read from illegal register in %m at adress %x", i_wb_adr);
                                        $finish;
                                end
                                endcase

                                wbstate <= WBACK;
                        end

                        WBACK:
                        begin
                                o_wb_ack   <= 1'd1;
                                wbstate    <= WBDONE;
                        end

                        WBDONE:
                        begin
                                o_wb_ack   <= 1'd0;
                                wbstate    <= WBIDLE;
                        end
                endcase
        end
end

endmodule // vic
