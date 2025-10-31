module ucie_rx_deserializer #(parameter NUM_LANES = 64) (
    input wire clk, reset_n,
    input wire [NUM_LANES-1:0] data_in,
    input wire valid_in,
    output reg [NUM_LANES*8-1:0] data_out,
    output reg valid_out
);
    reg [2:0] bit_count;
    reg [NUM_LANES*8-1:0] shift_reg;
    reg [NUM_LANES*8-1:0] complete_byte;
    reg byte_complete;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bit_count <= 3'd0;
            shift_reg <= {NUM_LANES*8{1'b0}};
            complete_byte <= {NUM_LANES*8{1'b0}};
            byte_complete <= 1'b0;
            data_out <= {NUM_LANES*8{1'b0}};
            valid_out <= 1'b0;
        end else begin
            // Stage 1: Capture complete bytes
            byte_complete <= 1'b0;
            
            if (valid_in) begin
                // Store incoming bit
                for (integer i = 0; i < NUM_LANES; i = i + 1) begin
                    shift_reg[i*8 + bit_count] <= data_in[i];
                end
                
                // Check if byte is complete after this bit
                if (bit_count == 3'd7) begin
                    // Byte is complete - save it
                    for (integer i = 0; i < NUM_LANES; i = i + 1) begin
                        complete_byte[i*8 +: 8] <= {data_in[i], shift_reg[i*8 +: 7]};
                    end
                    byte_complete <= 1'b1;
                    bit_count <= 3'd0;
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
            
            // Stage 2: Output complete bytes (pipelined from Stage 1)
            if (byte_complete) begin
                data_out <= complete_byte;
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule