module ucie_sideband #(parameter ENABLE_REDUNDANCY = 1) (
    input wire auxclk, reset_n,
    input wire [63:0] tx_packet,
    input wire tx_valid,
    output reg sb_tx_data, sb_tx_clk, sb_tx_data_rd, sb_tx_clk_rd,
    input wire sb_rx_data, sb_rx_clk, sb_rx_data_rd, sb_rx_clk_rd,
    output reg [63:0] rx_packet,
    output reg rx_valid
);
    reg [5:0] tx_bit_count;
    reg [63:0] tx_shift_reg;
    reg tx_active;
    
    always @(posedge auxclk or negedge reset_n) begin
        if (!reset_n) begin
            sb_tx_data <= 1'b0;
            sb_tx_clk <= 1'b0;
            tx_bit_count <= 6'd0;
            tx_shift_reg <= 64'h0;
            tx_active <= 1'b0;
        end else begin
            if (tx_valid && !tx_active) begin
                tx_shift_reg <= tx_packet;
                tx_active <= 1'b1;
                tx_bit_count <= 6'd0;
            end
            
            if (tx_active) begin
                sb_tx_data <= tx_shift_reg[0];
                sb_tx_clk <= ~sb_tx_clk;
                
                if (sb_tx_clk) begin
                    tx_shift_reg <= {1'b0, tx_shift_reg[63:1]};
                    tx_bit_count <= tx_bit_count + 1'b1;
                    
                    if (tx_bit_count == 6'd63)
                        tx_active <= 1'b0;
                end
            end else begin
                sb_tx_data <= 1'b0;
                sb_tx_clk <= 1'b0;
            end
        end
    end
    
    always @(posedge auxclk or negedge reset_n) begin
        if (!reset_n) begin
            rx_packet <= 64'h0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
        end
    end
    
    assign sb_tx_data_rd = 1'b0;
    assign sb_tx_clk_rd = 1'b0;
endmodule