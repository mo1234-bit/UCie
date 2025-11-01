module ucie_8b10b_decoder #(parameter NUM_LANES = 64) (
    input wire clk,
    input wire reset_n,
    input wire [NUM_LANES-1:0] data_in,
    input wire valid_in,
    output reg [NUM_LANES-1:0] data_out,
    output reg error
);
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            data_out <= {NUM_LANES{1'b0}};
            error <= 1'b0;
        end else if (valid_in) begin
            data_out <= data_in; // Simplified
            error <= 1'b0;
        end else begin
            error <= 1'b0;
        end
    end
endmodule