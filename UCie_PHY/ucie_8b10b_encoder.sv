module ucie_8b10b_encoder #(parameter NUM_LANES = 64) (
    input wire clk,
    input wire reset_n,
    input wire enable,
    input wire [NUM_LANES-1:0] data_in,
    output reg [NUM_LANES-1:0] data_out
);
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            data_out <= {NUM_LANES{1'b0}};
        else if (enable)
            data_out <= data_in; // Simplified - real encoder would do 8b/10b
        else
            data_out <= {NUM_LANES{1'b0}};
    end
endmodule