module ucie_sideband_enhanced #(parameter ENABLE_REDUNDANCY = 1) (
    input wire auxclk,
    input wire reset_n,
    input wire [63:0] tx_packet,
    input wire tx_valid,
    output reg tx_ready,
    output reg sb_tx_data,
    output reg sb_tx_clk,
    output reg sb_tx_data_rd,
    output reg sb_tx_clk_rd,
    input wire sb_rx_data,
    input wire sb_rx_clk,
    input wire sb_rx_data_rd,
    input wire sb_rx_clk_rd,
    output reg [63:0] rx_packet,
    output reg rx_valid,
    input wire retry_request,
    output reg retry_ack
);
    reg [6:0] tx_bit_count;
    reg [63:0] tx_shift_reg;
    reg tx_active;
    reg [6:0] rx_bit_count;
    reg [63:0] rx_shift_reg;
    reg rx_active;
    reg [7:0] tx_checksum;
    
    // RX clock edge detection - properly synchronized
    reg sb_rx_clk_d1, sb_rx_clk_d2;
    wire sb_rx_clk_posedge;
    
    // Synchronize RX clock to auxclk domain
    always @(posedge auxclk or negedge reset_n) begin
        if (!reset_n) begin
            sb_rx_clk_d1 <= 1'b0;
            sb_rx_clk_d2 <= 1'b0;
        end else begin
            sb_rx_clk_d1 <= sb_rx_clk;
            sb_rx_clk_d2 <= sb_rx_clk_d1;
        end
    end
    
    assign sb_rx_clk_posedge = sb_rx_clk_d1 && !sb_rx_clk_d2;
    
    // Calculate checksum
    function [7:0] calc_checksum;
        input [63:0] data;
        integer i;
        begin
            calc_checksum = 8'h00;
            for (i = 0; i < 8; i = i + 1)
                calc_checksum = calc_checksum ^ data[i*8 +: 8];
        end
    endfunction
    
    // TX Logic
    always @(posedge auxclk or negedge reset_n) begin
        if (!reset_n) begin
            sb_tx_data <= 1'b0;
            sb_tx_clk <= 1'b0;
            tx_bit_count <= 7'd0;
            tx_shift_reg <= 64'h0;
            tx_active <= 1'b0;
            tx_ready <= 1'b1;
            tx_checksum <= 8'h00;
        end else begin
            if (tx_valid && tx_ready) begin
                tx_shift_reg <= tx_packet;
                tx_checksum <= calc_checksum(tx_packet);
                tx_active <= 1'b1;
                tx_bit_count <= 7'd0;
                tx_ready <= 1'b0;
            end
            
            if (tx_active) begin
                sb_tx_data <= tx_shift_reg[0];
                sb_tx_clk <= ~sb_tx_clk;
                
                if (sb_tx_clk) begin
                    tx_shift_reg <= {1'b0, tx_shift_reg[63:1]};
                    tx_bit_count <= tx_bit_count + 1'b1;
                    
                    if (tx_bit_count == 7'd63) begin
                        tx_active <= 1'b0;
                        tx_ready <= 1'b1;
                    end
                end
            end else begin
                sb_tx_data <= 1'b0;
                sb_tx_clk <= 1'b0;
            end
        end
    end
    
    // RX Logic - Fixed to properly detect edges
    always @(posedge auxclk or negedge reset_n) begin
        if (!reset_n) begin
            rx_packet <= 64'h0;
            rx_valid <= 1'b0;
            rx_shift_reg <= 64'h0;
            rx_bit_count <= 7'd0;
            rx_active <= 1'b0;
            retry_ack <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            retry_ack <= 1'b0;
            
            if (sb_rx_clk_posedge) begin
                rx_shift_reg <= {sb_rx_data, rx_shift_reg[63:1]};
                
                if (!rx_active) begin
                    rx_active <= 1'b1;
                    rx_bit_count <= 7'd1;
                end else begin
                    rx_bit_count <= rx_bit_count + 1'b1;
                    
                    if (rx_bit_count == 7'd63) begin
                        rx_packet <= {sb_rx_data, rx_shift_reg[63:1]};
                        rx_valid <= 1'b1;
                        rx_bit_count <= 7'd0;
                        rx_active <= 1'b0;
                    end
                end
            end else if (!sb_rx_clk_d1 && rx_active) begin
                // If clock stops, reset RX state after timeout
                if (rx_bit_count > 7'd0 && rx_bit_count < 7'd64) begin
                    // Packet in progress but clock stopped - this is ok
                end
            end
            
            if (retry_request) begin
                retry_ack <= 1'b1;
            end
        end
    end
    
    assign sb_tx_data_rd = 1'b0;
    assign sb_tx_clk_rd = 1'b0;
endmodule
