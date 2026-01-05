/* ===========================================================
 *  Module: bus32_to_wide_converter
 *  Description: 
 *      Adapts a 32-bit Slave Bus interface to Wide (N-bit) registers.
 *      - Maps multiple 32-bit addresses to one Wide Register.
 *      - Supports Read (CPU reads wide status) and Write (CPU writes wide config).
 * =========================================================== */
module bus32_to_wide_converter # (
    parameter BUS_WIDTH  = 32,
    parameter WIDE_WIDTH = 256  // Target Data Width (e.g., 128, 256)
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // --- 32-bit Bus Interface (Slave) ---
    input  wire [31:0]           bus_addr_i,
    input  wire [31:0]           bus_data_i,
    input  wire                  bus_we_i,
    input  wire                  bus_req_valid_i,
    output reg                   bus_req_ready_o,
    output reg                   bus_rsp_valid_o,
    output reg  [31:0]           bus_data_o,
    input  wire                  bus_rsp_ready_i,

    // --- Wide Interface (To/From User Core) ---
    // Read Port: Data from User Core -> CPU (e.g. ADC Data, Status)
    input  wire [WIDE_WIDTH-1:0] wide_data_in, 
    // Write Port: Data from CPU -> User Core (e.g. Configuration)
    output reg  [WIDE_WIDTH-1:0] wide_data_out,
    output reg                   wide_data_update // Pulse when writing is done (optional)
);

    // Calculate number of 32-bit chunks needed
    localparam CHUNKS = (WIDE_WIDTH + BUS_WIDTH - 1) / BUS_WIDTH;
    // Calculate address bits needed to select a chunk
    localparam CHUNK_ADDR_BITS = $clog2(CHUNKS);

    // Internal storage for Write path
    reg [31:0] write_buffer [0:CHUNKS-1];
    
    // Address decoding: assumed 4-byte aligned. 
    // Example: 0x00->Chunk0, 0x04->Chunk1, etc.
    // If the base address is handled externally, we just look at lower bits.
    wire [CHUNK_ADDR_BITS-1:0] chunk_idx;
    
    // Use bits [CHUNK_ADDR_BITS+1 : 2] to ignore byte offset (bits 1:0)
    assign chunk_idx = bus_addr_i[CHUNK_ADDR_BITS+1 : 2];

    integer i;

    // --- Bus Handshake Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_req_ready_o <= 1'b0;
            bus_rsp_valid_o <= 1'b0;
            bus_data_o      <= 32'b0;
            wide_data_update <= 1'b0;
            // Reset write buffer
            for (i = 0; i < CHUNKS; i = i + 1) begin
                write_buffer[i] <= 32'b0;
            end
        end else begin
            // Default Handshake
            bus_req_ready_o <= 1'b1; // Always ready to accept in this simple model
            wide_data_update <= 1'b0;

            if (bus_req_valid_i && bus_req_ready_o) begin
                bus_rsp_valid_o <= 1'b1;
                
                // --- WRITE OPERATION (CPU -> Wide Reg) ---
                if (bus_we_i) begin
                    if (chunk_idx < CHUNKS) begin
                        write_buffer[chunk_idx] <= bus_data_i;
                        // Optional: Trigger update when MSB chunk is written
                        // if (chunk_idx == CHUNKS-1) wide_data_update <= 1'b1; 
                        wide_data_update <= 1'b1; // Trigger on every write for simplicity
                    end
                end 
                // --- READ OPERATION (CPU <- Wide Reg) ---
                else begin
                    if (chunk_idx < CHUNKS) begin
                        // Map the specific slice of input wire to bus output
                        // Using indexed part-select is tricky with variable, using loop/mux logic implicit
                        bus_data_o <= wide_data_in[chunk_idx * 32 +: 32]; 
                    end else begin
                        bus_data_o <= 32'hDEAD_BEEF; // Error/Out of bounds
                    end
                end
            end else if (bus_rsp_ready_i) begin
                bus_rsp_valid_o <= 1'b0;
            end
        end
    end

    // Flatten write buffer to output wire
    genvar g;
    generate
        for (g = 0; g < CHUNKS; g = g + 1) begin : gen_flatten
            always @(*) begin
                // Map buffer to output, handling potential partial last chunk if needed
                if ((g * 32 + 32) <= WIDE_WIDTH)
                    wide_data_out[g*32 +: 32] = write_buffer[g];
                else
                    // Handle case where WIDE_WIDTH is not multiple of 32 (rare but possible)
                    wide_data_out[WIDE_WIDTH-1 : g*32] = write_buffer[g][WIDE_WIDTH-(g*32)-1 : 0];
            end
        end
    endgenerate

endmodule
