/*
*/

module timer #(

        // Register addresses.
        parameter       [31:0]  TIMER_ENABLE_REGISTER = 32'h0,
        parameter       [31:0]  TIMER_LIMIT_REGISTER  = 32'h4,
        parameter       [31:0]  TIMER_INTACK_REGISTER = 32'h8,
        parameter       [31:0]  TIMER_START_REGISTER  = 32'hC

) (

// Clock and reset.
input wire                  i_clk,
input wire                  i_rst,

// Wishbone interface.
input wire  [31:0]          i_wb_dat,
input wire   [3:0]          i_wb_adr,
input wire                  i_wb_stb,
input wire                  i_wb_cyc,
input wire                  i_wb_wen,
input wire  [3:0]           i_wb_sel,
output reg [31:0]           o_wb_dat,
output reg                  o_wb_ack,


// Interrupt output. Level interrupt.
output  reg                 o_irq

);

// Timer registers.
reg [31:0] DEVEN;
reg [31:0] DEVPR;
reg [31:0] DEVAK;
reg [31:0] DEVST;

`define DEVEN TIMER_ENABLE_REGISTER
`define DEVPR TIMER_LIMIT_REGISTER
`define DEVAK TIMER_INTACK_REGISTER
`define DEVST TIMER_START_REGISTER

// Timer core.
reg [31:0] ctr;         // Core counter.
reg        start;       // Pulse to start the timer. Done signal is cleared.
reg        done;        // Asserted when timer is done.
reg        clr;         // Clears the done signal.
reg [31:0] state;       // State
reg        enable;      // 1 to enable the timer.
reg [31:0] finalval;    // Final value to count.
reg [31:0] wbstate;

localparam IDLE         = 0;
localparam COUNTING     = 1;
localparam DONE         = 2;

localparam WBIDLE       = 0;
localparam WBREAD       = 1;
localparam WBWRITE      = 2;
localparam WBACK        = 3;
localparam WBDONE       = 4;

always @ (*)
        o_irq    = done;

always @ (*)
begin
        start    = DEVST[0];
        enable   = DEVEN[0];
        finalval = DEVPR;
        clr      = DEVAK[0];
end

always @ ( posedge i_clk )
begin
        DEVST <= 0;

        if ( i_rst )
        begin
                DEVEN <= 0;
                DEVPR <= 0;
                DEVAK <= 0;
                DEVST <= 0;
                wbstate  <= WBIDLE;
                o_wb_dat <= 0;
                o_wb_ack <= 0;
        end
        else
        begin
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
                                `DEVEN: // DEVEN
                                begin
                                        if ( i_wb_sel[0] ) DEVEN[7:0]   <= i_wb_dat >> 0;
                                        if ( i_wb_sel[1] ) DEVEN[15:8]  <= i_wb_dat >> 8;
                                        if ( i_wb_sel[2] ) DEVEN[23:16] <= i_wb_dat >> 16;
                                        if ( i_wb_sel[3] ) DEVEN[31:24] <= i_wb_dat >> 24;
                                end

                                `DEVPR: // DEVPR
                                begin
                                        if ( i_wb_sel[0] ) DEVPR[7:0]   <= i_wb_dat >> 0;
                                        if ( i_wb_sel[1] ) DEVPR[15:8]  <= i_wb_dat >> 8;
                                        if ( i_wb_sel[2] ) DEVPR[23:16] <= i_wb_dat >> 16;
                                        if ( i_wb_sel[3] ) DEVPR[31:24] <= i_wb_dat >> 24;

                                end

                                `DEVAK: // DEVAK
                                begin
                                        if ( i_wb_sel[0] ) DEVPR[7:0]   <= i_wb_dat >> 0;
                                        if ( i_wb_sel[1] ) DEVPR[15:8]  <= i_wb_dat >> 8;
                                        if ( i_wb_sel[2] ) DEVPR[23:16] <= i_wb_dat >> 16;
                                        if ( i_wb_sel[3] ) DEVPR[31:24] <= i_wb_dat >> 24;
                                end

                                `DEVST: // DEVST
                                begin
                                        if ( i_wb_sel[0] ) DEVST[7:0]   <= i_wb_dat >> 0;
                                        if ( i_wb_sel[1] ) DEVST[15:8]  <= i_wb_dat >> 8;
                                        if ( i_wb_sel[2] ) DEVST[23:16] <= i_wb_dat >> 16;
                                        if ( i_wb_sel[3] ) DEVST[31:24] <= i_wb_dat >> 24;
                                end

                                default:
                                begin
                                        $display($time, " Error : Illegal register write in %m.");
                                        $finish;
                                end

                                endcase

                                wbstate <= WBACK;
                        end

                        WBREAD:
                        begin
                                case(i_wb_adr)
                                `DEVEN: o_wb_dat <= DEVEN;
                                `DEVPR: o_wb_dat <= DEVPR;
                                `DEVAK: o_wb_dat <= done;
                                `DEVST: o_wb_dat <= 32'd0;
                               default:
                                        begin
                                                $display($time, " Error : Illegal register read in %m.");
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
                                o_wb_ack  <= 1'd0;
                                wbstate   <= IDLE;
                        end
                endcase
        end
end

always @ (posedge i_clk)
begin
        if ( i_rst || !enable )
        begin
                ctr     <= 0;
                done    <= 0;
                state   <= IDLE;
        end
        else // if enabled
        begin
                case(state)
                IDLE:
                begin
                        if ( start )
                        begin
                                state <= COUNTING;
                        end
                end

                COUNTING:
                begin
                        ctr <= ctr + 1;

                        if ( ctr == finalval )
                        begin
                                state <= DONE;
                        end
                end

                DONE:
                begin
                        done <= 1;

                        if ( start )
                        begin
                                done  <= 0;
                                state <= COUNTING;
                                ctr   <= 0;
                        end
                        else if ( clr ) // Acknowledge.
                        begin
                                done  <= 0;
                                state <= IDLE;
                                ctr   <= 0;
                        end
                end
                endcase
        end
end

endmodule
