module ucie_tx_byte_to_lane #(parameter NUM_LANES = 64) (
    input wire clk,
    input wire reset_n,
    input wire [NUM_LANES*8-1:0] data_in,
    input wire valid_in,
    output reg [NUM_LANES-1:0] data_out,
    output wire ready,
    output reg valid_out
);
    reg [2:0] bit_counter;
    reg [NUM_LANES*8-1:0] data_reg;
    reg transmitting;
    
    // Ready when not transmitting or on last bit
    assign ready = !transmitting || (bit_counter == 3'd7);
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bit_counter <= 3'd0;
            data_out <= {NUM_LANES{1'b0}};
            data_reg <= {NUM_LANES*8{1'b0}};
            transmitting <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            if (valid_in && ready) begin
                // Start new transmission
                data_reg <= data_in;
                transmitting <= 1'b1;
                bit_counter <= 3'd0;
                valid_out <= 1'b1;
                
                // Send first bit of each byte lane
                for (integer i = 0; i < NUM_LANES; i = i + 1) begin
                    data_out[i] <= data_in[i*8];  // LSB first
                end
            end else if (transmitting) begin
                if (bit_counter < 3'd7) begin
                    // Continue transmission
                    bit_counter <= bit_counter + 1'b1;
                    valid_out <= 1'b1;
                    
                    // Send next bit of each byte lane
                    for (integer i = 0; i < NUM_LANES; i = i + 1) begin
                        data_out[i] <= data_reg[i*8 + bit_counter + 1];
                    end
                end else begin
                    // Transmission complete
                    transmitting <= 1'b0;
                    bit_counter <= 3'd0;
                    valid_out <= 1'b0;
                    data_out <= {NUM_LANES{1'b0}};
                end
            end else begin
                valid_out <= 1'b0;
                data_out <= {NUM_LANES{1'b0}};
            end
        end
    end
endmodule