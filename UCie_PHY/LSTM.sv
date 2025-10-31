module ucie_ltsm #(parameter PACKAGE_TYPE = "ADVANCED", MODULE_WIDTH = 64) (
    input wire clk, auxclk, reset_n, pll_locked, start_training,
    input wire [63:0] sb_rx_packet,
    input wire sb_rx_valid,
    output reg [63:0] sb_tx_packet,
    output reg sb_tx_valid,
    output reg [MODULE_WIDTH-1:0] tx_repair_map, rx_repair_map,
    output reg [1:0] tx_repair_shift, rx_repair_shift,
    output reg [7:0] current_state,
    output reg link_up, active_state
);
    localparam [7:0] 
        RESET      = 8'h00,
        SBINIT     = 8'h01,
        MBINIT     = 8'h02,
        MBTRAIN    = 8'h03,
        LINKINIT   = 8'h09,
        ACTIVE     = 8'h0A;
    
    reg [15:0] timer;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= RESET;
            link_up <= 1'b0;
            active_state <= 1'b0;
            timer <= 16'd0;
            tx_repair_map <= {MODULE_WIDTH{1'b0}};
            rx_repair_map <= {MODULE_WIDTH{1'b0}};
            tx_repair_shift <= 2'b00;
            rx_repair_shift <= 2'b00;
            sb_tx_packet <= 64'h0;
            sb_tx_valid <= 1'b0;
        end else begin
            sb_tx_valid <= 1'b0;
            timer <= timer + 1'b1;
            
            case (current_state)
                RESET: begin
                    if (pll_locked && start_training) begin
                        current_state <= SBINIT;
                        timer <= 16'd0;
                    end
                end
                
                SBINIT: begin
                    if (timer >= 16'd50) begin
                        current_state <= MBINIT;
                        timer <= 16'd0;
                    end
                end
                
                MBINIT: begin
                    if (timer >= 16'd50) begin
                        current_state <= MBTRAIN;
                        timer <= 16'd0;
                    end
                end
                
                MBTRAIN: begin
                    if (timer >= 16'd50) begin
                        current_state <= LINKINIT;
                        timer <= 16'd0;
                    end
                end
                
                LINKINIT: begin
                    if (timer >= 16'd50) begin
                        current_state <= ACTIVE;
                        link_up <= 1'b1;
                        active_state <= 1'b1;
                        timer <= 16'd0;
                    end
                end
                
                ACTIVE: begin
                    link_up <= 1'b1;
                    active_state <= 1'b1;
                end
                
                default: current_state <= RESET;
            endcase
        end
    end
endmodule