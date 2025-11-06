// Reset debouncer + synchronizer
module reset_sync_debounce #(
    parameter integer DEBOUNCE_CYCLES = 2_000_000  // ~20 ms @ 100 MHz
)(
    input  wire clk,          // your SYS_CLK (e.g., 100 MHz)
    input  wire rst_n_in,     // asynchronous, active-LOW external reset
    output wire rst_sync      // synchronous, active-HIGH reset for fabric
);

    // 1) Synchronize the raw pin (avoid metastability)
    reg [1:0] rst_sync_ff;
    always @(posedge clk or negedge rst_n_in) begin
        if (!rst_n_in)
            rst_sync_ff <= 2'b00;         // async assert path
        else
            rst_sync_ff <= {rst_sync_ff[0], 1'b1};
    end
    wire rst_n_sync = rst_sync_ff[1];     // synchronized, active-LOW

    // 2) Debounce: require the synchronized level to be stable for N cycles
    reg        debounced_n = 1'b1;        // start deasserted
    reg [31:0] cnt = 32'd0;

    always @(posedge clk) begin
        if (rst_n_sync == debounced_n) begin
            cnt <= 32'd0;                 // stable; counter idle
        end else begin
            cnt <= cnt + 1;
            if (cnt >= DEBOUNCE_CYCLES) begin
                debounced_n <= rst_n_sync; // accept the new level
                cnt <= 32'd0;
            end
        end
    end

    // 3) Active-high, synchronous reset for the rest of the design
    //    (async assertion behavior already handled in synchronizer)
    assign rst_sync = ~debounced_n;

endmodule
