/*
*/

module uart_tx_dumper ( input wire i_clk, input wire i_line,
                        output reg UART_SR_DAV = 1'd0, output reg [7:0] UART_SR = 1'd0 );

localparam UART_WAIT_FOR_START = 0;
localparam UART_RX             = 1;
localparam UART_STOP_BIT       = 2;

integer                 uart_state   = UART_WAIT_FOR_START;
integer                 uart_ctr     = 0;
integer                 uart_bit_ctr = 0;
reg [7:0]               uart_sr      = 0;
wire                    uart;
integer signed          fh;

assign uart = i_line;

always @ ( posedge i_clk )
begin
        UART_SR_DAV <= 1'd0;

        case ( uart_state )
                UART_WAIT_FOR_START:
                begin
                        if ( !uart )
                        begin
                                uart_ctr <= uart_ctr + 1;
                        end

                        if ( !uart && (uart_ctr + 1 == 16) )
                        begin
                                uart_state   <= UART_RX;
                                uart_ctr     <= 0;
                                uart_bit_ctr <= 0;
                        end
                end

                UART_RX:
                begin
                        uart_ctr <= uart_ctr + 1;

                        if ( uart_ctr + 1 == 2 )
                                uart_sr <= uart_sr >> 1 | i_line << 7;

                        if ( uart_ctr + 1 == 16 )
                        begin
                                uart_bit_ctr <= uart_bit_ctr + 1;
                                uart_ctr     <= 0;

                                if ( uart_bit_ctr + 1 == 8 )
                                begin
                                        uart_state  <= UART_STOP_BIT;
                                        UART_SR     <= uart_sr;
                                        UART_SR_DAV <= 1'd1;
                                        uart_ctr    <= 0;
                                        uart_bit_ctr<= 0;
                                end
                        end
                end

                UART_STOP_BIT:
                begin
                        uart_ctr <= uart_ctr + 1;

                        if ( uart && (uart_ctr + 1 == 16) ) // Stop bit.
                        begin
                                uart_state      <= UART_WAIT_FOR_START;
                                uart_bit_ctr    <= 0;
                                uart_ctr        <= 0;
                        end
                end
        endcase
end

endmodule // uart_tx_dumper
