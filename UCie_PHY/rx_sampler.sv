module ucie_rx_sampler #(parameter NUM_LANES = 64) (
    input wire rx_clkp, reset_n,
    input wire [NUM_LANES-1:0] data_in,
    input wire valid_in,
    output reg [NUM_LANES-1:0] data_out,
    output reg valid_out
);
    always @(posedge rx_clkp or negedge reset_n) begin
        if (!reset_n) begin
            data_out <= {NUM_LANES{1'b0}};
            valid_out <= 1'b0;
        end else begin
            data_out <= data_in;
            valid_out <= valid_in;
        end
    end
endmodule