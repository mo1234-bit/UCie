module ucie_ltsm_enhanced #(
    parameter PACKAGE_TYPE = "ADVANCED",
    parameter MODULE_WIDTH = 64,
    parameter ENABLE_REDUNDANCY = 1
) (
    input wire clk,
    input wire auxclk,
    input wire reset_n,
    input wire pll_locked,
    input wire cdr_locked,
    input wire start_training,
    input wire [63:0] sb_rx_packet,
    input wire sb_rx_valid,
    output reg [63:0] sb_tx_packet,
    output reg sb_tx_valid,
    input wire [5:0] cfg_active_lanes,
    output reg [MODULE_WIDTH-1:0] active_lane_mask,
    output reg [MODULE_WIDTH-1:0] tx_repair_map,
    output reg [MODULE_WIDTH-1:0] rx_repair_map,
    output reg [1:0] tx_repair_shift,
    output reg [1:0] rx_repair_shift,
    output reg [7:0] current_state,
    output reg link_up,
    output reg active_state,
    output reg [7:0] link_quality
);
    localparam [7:0]
        RESET        = 8'h00,
        SBINIT       = 8'h01,
        MBINIT       = 8'h02,
        MBTRAIN      = 8'h03,
        REPAIR       = 8'h04,
        PARAM_EXCH   = 8'h05,
        LINKINIT     = 8'h09,
        ACTIVE       = 8'h0A,
        L1           = 8'h0B,
        L2           = 8'h0C,
        RETRAIN      = 8'h0D;
    
    reg [19:0] timer;
    reg [7:0] error_count;
    reg [7:0] training_attempts;
    reg [MODULE_WIDTH-1:0] lane_error_map;
    reg handshake_received;
    
    // Link quality calculation
    always @(posedge clk) begin
        if (error_count == 0)
            link_quality <= 8'd255;
        else if (error_count < 10)
            link_quality <= 8'd200;
        else if (error_count < 50)
            link_quality <= 8'd150;
        else if (error_count < 100)
            link_quality <= 8'd100;
        else
            link_quality <= 8'd50;
    end
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= RESET;
            link_up <= 1'b0;
            active_state <= 1'b0;
            timer <= 20'd0;
            tx_repair_map <= {MODULE_WIDTH{1'b0}};
            rx_repair_map <= {MODULE_WIDTH{1'b0}};
            tx_repair_shift <= 2'b00;
            rx_repair_shift <= 2'b00;
            sb_tx_packet <= 64'h0;
            sb_tx_valid <= 1'b0;
            error_count <= 8'd0;
            training_attempts <= 8'd0;
            lane_error_map <= {MODULE_WIDTH{1'b0}};
            handshake_received <= 1'b0;
            active_lane_mask <= {MODULE_WIDTH{1'b1}};
        end else begin
            sb_tx_valid <= 1'b0;
            timer <= timer + 1'b1;
            
            // Monitor for handshake packets
            if (sb_rx_valid) begin
                handshake_received <= 1'b1;
            end
            
            case (current_state)
                RESET: begin
                    link_up <= 1'b0;
                    active_state <= 1'b0;
                    error_count <= 8'd0;
                    training_attempts <= 8'd0;
                    
                    if (pll_locked && start_training) begin
                        current_state <= SBINIT;
                        timer <= 20'd0;
                    end
                end
                
                SBINIT: begin
                    // Send initialization packet on sideband
                    if (timer == 20'd10) begin
                        sb_tx_packet <= {8'h01, 56'hDEADBEEFCAFE};
                        sb_tx_valid <= 1'b1;
                    end
                    
                    if (timer >= 20'd100) begin  // Increased from 50
                        current_state <= MBINIT;
                        timer <= 20'd0;
                        handshake_received <= 1'b0;
                    end
                end
                
                MBINIT: begin
                    // Initialize main band - INCREASED TIMEOUT
                    if (timer >= 20'd5000 && cdr_locked) begin  // Increased from 100
                        current_state <= MBTRAIN;
                        timer <= 20'd0;
                    end else if (timer >= 20'd10000) begin  // Increased from 1000
                        // Timeout - retry
                        current_state <= RESET;
                        training_attempts <= training_attempts + 1'b1;
                    end
                end
                
                MBTRAIN: begin
                    // Train bit alignment and timing - INCREASED TIMEOUT
                    if (timer >= 20'd1000) begin  // Increased from 200
                        if (ENABLE_REDUNDANCY)
                            current_state <= REPAIR;
                        else
                            current_state <= PARAM_EXCH;
                        timer <= 20'd0;
                    end
                end
                
                REPAIR: begin
                    // Lane repair and redundancy mapping
                    if (timer >= 20'd200) begin  // Increased from 100
                        // Calculate active lane mask based on cfg_active_lanes
                        if (cfg_active_lanes > 0) begin
                            active_lane_mask <= (1 << cfg_active_lanes) - 1;
                        end
                        current_state <= PARAM_EXCH;
                        timer <= 20'd0;
                    end
                end
                
                PARAM_EXCH: begin
                    // Exchange link parameters
                    if (timer == 20'd10) begin
                        sb_tx_packet <= {8'h03, 8'(MODULE_WIDTH), 48'h123456789ABC};
                        sb_tx_valid <= 1'b1;
                    end
                    
                    if (timer >= 20'd200) begin  // Increased from 100
                        current_state <= LINKINIT;
                        timer <= 20'd0;
                    end else if (timer >= 20'd10000) begin  // Increased from 5000
                        // Extended timeout - retry
                        current_state <= MBINIT;
                        training_attempts <= training_attempts + 1'b1;
                    end
                end
                
                LINKINIT: begin
                    if (timer >= 20'd100) begin  // Increased from 50
                        current_state <= ACTIVE;
                        link_up <= 1'b1;
                        active_state <= 1'b1;
                        timer <= 20'd0;
                    end
                end
                
                ACTIVE: begin
                    link_up <= 1'b1;
                    active_state <= 1'b1;
                    
                    // Monitor link quality
                    if (link_quality < 8'd100) begin
                        if (timer >= 20'd100000) begin
                            // Link quality degraded - consider retraining
                            current_state <= RETRAIN;
                            timer <= 20'd0;
                        end
                    end
                end
                
                L1: begin
                    // Low power state L1 (partial)
                    active_state <= 1'b0;
                    if (start_training) begin
                        current_state <= ACTIVE;
                        active_state <= 1'b1;
                    end
                end
                
                L2: begin
                    // Low power state L2 (deep)
                    link_up <= 1'b0;
                    active_state <= 1'b0;
                    if (start_training) begin
                        current_state <= SBINIT;
                        timer <= 20'd0;
                    end
                end
                
                RETRAIN: begin
                    link_up <= 1'b0;
                    active_state <= 1'b0;
                    current_state <= MBINIT;
                    timer <= 20'd0;
                end
                
                default: current_state <= RESET;
            endcase
        end
    end
endmodule
