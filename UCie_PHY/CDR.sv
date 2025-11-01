module ucie_cdr #(parameter NUM_LANES = 64) (
    input wire rx_clkp,
    input wire rx_clkn,
    input wire reset_n,
    input wire [NUM_LANES-1:0] data_in,
    output wire recovered_clk,
    output reg locked
);
    reg [7:0] lock_counter;
    
  
    assign recovered_clk = rx_clkp;
    
    always @(posedge rx_clkp or negedge reset_n) begin
        if (!reset_n) begin
            locked <= 1'b0;
            lock_counter <= 8'd0;
        end else begin
            // Lock quickly after 10 clock cycles
            if (lock_counter < 8'd10) begin
                lock_counter <= lock_counter + 1'b1;
                locked <= 1'b0;
            end else begin
                locked <= 1'b1;
            end
        end
    end
endmodule