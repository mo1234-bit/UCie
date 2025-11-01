module ucie_rx_deserializer #(parameter NUM_LANES = 64) (
    input wire clk,
    input wire reset_n,
    input wire [NUM_LANES-1:0] data_in,
    input wire valid_in,
    output reg [NUM_LANES*8-1:0] data_out,
    output reg valid_out
);
    reg [2:0] bit_count;
    reg [NUM_LANES*8-1:0] shift_reg;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bit_count <= 3'd0;
            shift_reg <= {NUM_LANES*8{1'b0}};
            data_out <= {NUM_LANES*8{1'b0}};
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;  // Default: pulse output
            
            if (valid_in) begin
                // Accumulate bits for each lane
                for (integer i = 0; i < NUM_LANES; i = i + 1) begin
                    shift_reg[i*8 + bit_count] <= data_in[i];
                end
                
                if (bit_count == 3'd7) begin
                    // Complete byte received for all lanes
                    data_out <= shift_reg;
                    valid_out <= 1'b1;
                    bit_count <= 3'd0;
                    shift_reg <= {NUM_LANES*8{1'b0}};
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
        end
    end
endmodule
