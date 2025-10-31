// ============================================================================
// UCIe PHY Debug Testbench - Simple Test with Full Tracing
// ============================================================================

`timescale 1ns/1ps

module ucie_phy_tb;

    parameter MODULE_WIDTH = 64;
    parameter CLK_PERIOD = 10.0;
    parameter AUXCLK_PERIOD = 1.25;
    
    // Die 0 signals
    reg refclk_0, auxclk_0, reset_n;
    reg  [MODULE_WIDTH*8-1:0] rdi_tx_data_0;
    reg                       rdi_tx_valid_0;
    wire                      rdi_tx_ready_0;
    wire [MODULE_WIDTH*8-1:0] rdi_rx_data_0;
    wire                      rdi_rx_valid_0;
    wire [MODULE_WIDTH-1:0]   tx_data_0;
    wire                      tx_valid_0, tx_clkp_0, tx_clkn_0;
    reg  [2:0]                cfg_data_rate_0;
    reg                       cfg_scrambling_en_0, cfg_start_training_0;
    wire [7:0]                status_ltsm_state_0;
    wire                      status_link_up_0;
    
    // Die 1 signals
    reg refclk_1, auxclk_1;
    reg  [MODULE_WIDTH*8-1:0] rdi_tx_data_1;
    reg                       rdi_tx_valid_1;
    wire                      rdi_tx_ready_1;
    wire [MODULE_WIDTH*8-1:0] rdi_rx_data_1;
    wire                      rdi_rx_valid_1;
    wire [MODULE_WIDTH-1:0]   tx_data_1;
    wire                      tx_valid_1, tx_clkp_1, tx_clkn_1;
    reg  [2:0]                cfg_data_rate_1;
    reg                       cfg_scrambling_en_1, cfg_start_training_1;
    wire [7:0]                status_ltsm_state_1;
    wire                      status_link_up_1;
    
    integer tx_count = 0;
    integer rx_count = 0;
    
    // Instantiate Die 0
    ucie_phy_top #(
        .MODULE_WIDTH(MODULE_WIDTH)
    ) u_phy_die0 (
        .refclk(refclk_0), .auxclk(auxclk_0), .reset_n(reset_n),
        .rdi_tx_data(rdi_tx_data_0), .rdi_tx_valid(rdi_tx_valid_0), .rdi_tx_ready(rdi_tx_ready_0),
        .rdi_rx_data(rdi_rx_data_0), .rdi_rx_valid(rdi_rx_valid_0),
        .tx_data(tx_data_0), .tx_valid(tx_valid_0), .tx_clkp(tx_clkp_0), .tx_clkn(tx_clkn_0),
        .rx_data(tx_data_1), .rx_valid(tx_valid_1), .rx_clkp(tx_clkp_1), .rx_clkn(tx_clkn_1),
        .cfg_data_rate(cfg_data_rate_0), .cfg_scrambling_en(cfg_scrambling_en_0),
        .cfg_start_training(cfg_start_training_0),
        .status_ltsm_state(status_ltsm_state_0), .status_link_up(status_link_up_0),
        // Tie off unused
        .rdi_rx_error(), .tx_track(), .rx_track(1'b0),
        .tx_data_rd(), .tx_ckrd(), .tx_valid_rd(),
        .rx_data_rd(4'b0), .rx_ckrd(1'b0), .rx_valid_rd(1'b0),
        .sb_tx_data(), .sb_tx_clk(), .sb_tx_data_rd(), .sb_tx_clk_rd(),
        .sb_rx_data(1'b0), .sb_rx_clk(1'b0), .sb_rx_data_rd(1'b0), .sb_rx_clk_rd(1'b0),
        .cfg_clock_gating_en(1'b0), .status_error_count()
    );
    
    // Instantiate Die 1
    ucie_phy_top #(
        .MODULE_WIDTH(MODULE_WIDTH)
    ) u_phy_die1 (
        .refclk(refclk_1), .auxclk(auxclk_1), .reset_n(reset_n),
        .rdi_tx_data(rdi_tx_data_1), .rdi_tx_valid(rdi_tx_valid_1), .rdi_tx_ready(rdi_tx_ready_1),
        .rdi_rx_data(rdi_rx_data_1), .rdi_rx_valid(rdi_rx_valid_1),
        .tx_data(tx_data_1), .tx_valid(tx_valid_1), .tx_clkp(tx_clkp_1), .tx_clkn(tx_clkn_1),
        .rx_data(tx_data_0), .rx_valid(tx_valid_0), .rx_clkp(tx_clkp_0), .rx_clkn(tx_clkn_0),
        .cfg_data_rate(cfg_data_rate_1), .cfg_scrambling_en(cfg_scrambling_en_1),
        .cfg_start_training(cfg_start_training_1),
        .status_ltsm_state(status_ltsm_state_1), .status_link_up(status_link_up_1),
        // Tie off unused
        .rdi_rx_error(), .tx_track(), .rx_track(1'b0),
        .tx_data_rd(), .tx_ckrd(), .tx_valid_rd(),
        .rx_data_rd(4'b0), .rx_ckrd(1'b0), .rx_valid_rd(1'b0),
        .sb_tx_data(), .sb_tx_clk(), .sb_tx_data_rd(), .sb_tx_clk_rd(),
        .sb_rx_data(1'b0), .sb_rx_clk(1'b0), .sb_rx_data_rd(1'b0), .sb_rx_clk_rd(1'b0),
        .cfg_clock_gating_en(1'b0), .status_error_count()
    );
    
    // Clock generation
    initial begin refclk_0 = 0; forever #(CLK_PERIOD/2) refclk_0 = ~refclk_0; end
    initial begin refclk_1 = 0; forever #(CLK_PERIOD/2) refclk_1 = ~refclk_1; end
    initial begin auxclk_0 = 0; forever #(AUXCLK_PERIOD/2) auxclk_0 = ~auxclk_0; end
    initial begin auxclk_1 = 0; forever #(AUXCLK_PERIOD/2) auxclk_1 = ~auxclk_1; end
    
    // ========================================================================
    // DEBUG MONITORS - Trace every signal in RX path
    // ========================================================================
    
    // Monitor TX path (Die 0 sending)
    always @(posedge refclk_0) begin
        if (tx_valid_0) begin
            $display("[%0t] TX_VALID=1, TX_DATA[3:0]=%b_%b_%b_%b (lane 0-3 bits)", 
                     $time, tx_data_0[3], tx_data_0[2], tx_data_0[1], tx_data_0[0]);
        end
    end
    
    // Monitor what Die 1 RX sampler receives
    always @(posedge refclk_1) begin
        if (u_phy_die1.rx_valid_sampled) begin
            $display("[%0t]   RX_SAMPLED: valid=1, data[3:0]=%b_%b_%b_%b", 
                     $time, 
                     u_phy_die1.rx_data_sampled[3],
                     u_phy_die1.rx_data_sampled[2],
                     u_phy_die1.rx_data_sampled[1],
                     u_phy_die1.rx_data_sampled[0]);
        end
    end
    
    // Monitor descrambler output
    always @(posedge refclk_1) begin
        if (u_phy_die1.u_rx_descrambler.enable) begin
            $display("[%0t]     DESCRAMBLER: in[3:0]=%b_%b_%b_%b, out[3:0]=%b_%b_%b_%b", 
                     $time,
                     u_phy_die1.rx_data_sampled[3],
                     u_phy_die1.rx_data_sampled[2],
                     u_phy_die1.rx_data_sampled[1],
                     u_phy_die1.rx_data_sampled[0],
                     u_phy_die1.rx_data_descrambled[3],
                     u_phy_die1.rx_data_descrambled[2],
                     u_phy_die1.rx_data_descrambled[1],
                     u_phy_die1.rx_data_descrambled[0]);
        end
    end
    
    // Monitor deserializer internals
    always @(posedge refclk_1) begin
        if (u_phy_die1.u_rx_deserializer.valid_in) begin
            $display("[%0t]       DESERIAL: bit_count=%0d, valid_in=1, data_in[0]=%b, byte_complete=%b, valid_out=%b", 
                     $time,
                     u_phy_die1.u_rx_deserializer.bit_count,
                     u_phy_die1.u_rx_deserializer.data_in[0],
                     u_phy_die1.u_rx_deserializer.byte_complete,
                     u_phy_die1.u_rx_deserializer.valid_out);
            
            // Show shift register for lane 0
            if (u_phy_die1.u_rx_deserializer.bit_count == 3'd7) begin
                $display("[%0t]         DESERIAL: BYTE COMPLETE! shift_reg[7:0]=%b_%b_%b_%b_%b_%b_%b_%b", 
                         $time,
                         u_phy_die1.u_rx_deserializer.shift_reg[7],
                         u_phy_die1.u_rx_deserializer.shift_reg[6],
                         u_phy_die1.u_rx_deserializer.shift_reg[5],
                         u_phy_die1.u_rx_deserializer.shift_reg[4],
                         u_phy_die1.u_rx_deserializer.shift_reg[3],
                         u_phy_die1.u_rx_deserializer.shift_reg[2],
                         u_phy_die1.u_rx_deserializer.shift_reg[1],
                         u_phy_die1.u_rx_deserializer.shift_reg[0]);
            end
        end
    end
    
    // Monitor final RX output
    always @(posedge refclk_1) begin
        if (rdi_rx_valid_1) begin
            rx_count++;
            $display("[%0t] *** RX OUTPUT #%0d: valid=1, data=0x%h ***", 
                     $time, rx_count, rdi_rx_data_1);
        end
    end
    
    // ========================================================================
    // Test Sequence
    // ========================================================================
    initial begin
        // $dumpfile("ucie_debug.vcd");
        // $dumpvars(0, ucie_phy_debug_tb);
        
        $display("\n=== UCIe PHY Debug Test ===\n");
        
        // Reset
        reset_n = 0;
        cfg_data_rate_0 = 3'b000;
        cfg_data_rate_1 = 3'b000;
        cfg_scrambling_en_0 = 0;  // DISABLE scrambling for easier debug
        cfg_scrambling_en_1 = 0;
        cfg_start_training_0 = 0;
        cfg_start_training_1 = 0;
        rdi_tx_data_0 = 0;
        rdi_tx_data_1 = 0;
        rdi_tx_valid_0 = 0;
        rdi_tx_valid_1 = 0;
        
        repeat(10) @(posedge refclk_0);
        reset_n = 1;
        $display("[%0t] Reset released\n", $time);
        
        // Start training
        @(posedge refclk_0);
        cfg_start_training_0 = 1;
        cfg_start_training_1 = 1;
        
        // Wait for link up
        $display("[%0t] Waiting for link up...", $time);
        wait(status_link_up_0 && status_link_up_1);
        repeat(50) @(posedge refclk_0);
        $display("[%0t] Link is UP!\n", $time);
        
        // Send a simple test packet
        $display("[%0t] === Sending Test Packet 0xAA (binary 10101010) ===\n", $time);
        @(posedge refclk_0);
        wait(rdi_tx_ready_0);
        
        // Send simple pattern: first byte = 0xAA for all lanes
        rdi_tx_data_0 = {MODULE_WIDTH{8'hAA}};
        rdi_tx_valid_0 = 1;
        tx_count++;
        $display("[%0t] TX: Sending packet #%0d = 0x%h", $time, tx_count, rdi_tx_data_0);
        
        @(posedge refclk_0);
        rdi_tx_valid_0 = 0;
        
        // Wait and observe
        $display("\n[%0t] Waiting for RX...\n", $time);
        repeat(100) @(posedge refclk_0);
        
        // Send another packet
        $display("\n[%0t] === Sending Test Packet 0x55 (binary 01010101) ===\n", $time);
        @(posedge refclk_0);
        wait(rdi_tx_ready_0);
        rdi_tx_data_0 = {MODULE_WIDTH{8'h55}};
        rdi_tx_valid_0 = 1;
        tx_count++;
        $display("[%0t] TX: Sending packet #%0d = 0x%h", $time, tx_count, rdi_tx_data_0);
        
        @(posedge refclk_0);
        rdi_tx_valid_0 = 0;
        
        repeat(100) @(posedge refclk_0);
        
        // Results
        $display("\n=== Test Complete ===");
        $display("TX Count: %0d", tx_count);
        $display("RX Count: %0d", rx_count);
        
        if (rx_count == tx_count) begin
            $display("SUCCESS: All packets received!");
        end else begin
            $display("FAILURE: Packet loss detected!");
            $display("Looking at internal states:");
            $display("  Die1 LTSM State: 0x%h", status_ltsm_state_1);
            $display("  Die1 ltsm_active: %b", u_phy_die1.ltsm_active);
            $display("  Die1 rx_valid_sampled: %b", u_phy_die1.rx_valid_sampled);
            $display("  Die1 deserializer valid_in: %b", u_phy_die1.u_rx_deserializer.valid_in);
            $display("  Die1 deserializer bit_count: %0d", u_phy_die1.u_rx_deserializer.bit_count);
        end
        
        $finish;
    end
    
    // Timeout
    initial begin
        #50000;
        $display("\n[%0t] TIMEOUT!", $time);
        $finish;
    end

endmodule