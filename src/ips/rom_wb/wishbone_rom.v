module wishbone_rom #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter MEM_DEPTH = 1 << ADDR_WIDTH,
    parameter MEM_FILE = "rom_content.mem" // Hex file for initialization
) (
    // Wishbone Slave Interface
    input  wire                 clk_i,
    input  wire                 rst_i,
    input  wire                 cyc_i,
    input  wire                 stb_i,
    input  wire                 we_i,
    input  wire [ADDR_WIDTH-1:0] adr_i,
    output reg  [DATA_WIDTH-1:0] dat_o,
    output reg                  ack_o,
    output reg                  err_o
);

    // Internal ROM storage
    reg [DATA_WIDTH-1:0] rom_data[0 : MEM_DEPTH-1]; // Declares a memory array

    // Initialize ROM from file
    initial begin
        $readmemh(MEM_FILE, rom_data); // Reads hex file into the array
    end

    // Wishbone slave logic
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            ack_o <= 1'b0;
            err_o <= 1'b0;
            dat_o <= {DATA_WIDTH{1'b0}};
        end else begin
            // Default to no acknowledge or error
            ack_o <= 1'b0;
            err_o <= 1'b0;
            dat_o <= {DATA_WIDTH{1'b0}}; // Default output

            // If a Wishbone cycle is in progress and strobe is asserted (for read/write)
            if (cyc_i && stb_i) begin
                if (we_i) begin // Write operation (not supported by ROM)
                    // For a ROM, write attempts might generate an error or be ignored.
                    err_o <= 1'b1; // Signal error for write attempt on ROM
                end else begin // Read operation
                    dat_o <= rom_data[adr_i]; // Output data from ROM based on address
                    ack_o <= 1'b1;           // Signal successful read
                end
            end
        end
    end

endmodule
