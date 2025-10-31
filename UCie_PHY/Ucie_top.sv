module ucie_phy_top #(
    parameter PACKAGE_TYPE = "ADVANCED",
    parameter MODULE_WIDTH = 64,
    parameter MAX_DATA_RATE = 16,
    parameter ENABLE_REDUNDANCY = 1,
    parameter ENABLE_SIDEBAND = 1,
    parameter NUM_MODULES = 1
) (
    input  wire                          refclk, auxclk, reset_n,
    input  wire [MODULE_WIDTH*8-1:0]     rdi_tx_data,
    input  wire                          rdi_tx_valid,
    output wire                          rdi_tx_ready,
    output wire [MODULE_WIDTH*8-1:0]     rdi_rx_data,
    output wire                          rdi_rx_valid,
    output wire                          rdi_rx_error,
    output wire [MODULE_WIDTH-1:0]       tx_data,
    output wire                          tx_valid, tx_clkp, tx_clkn, tx_track,
    input  wire [MODULE_WIDTH-1:0]       rx_data,
    input  wire                          rx_valid, rx_clkp, rx_clkn, rx_track,
    output wire [3:0]                    tx_data_rd,
    output wire                          tx_ckrd, tx_valid_rd,
    input  wire [3:0]                    rx_data_rd,
    input  wire                          rx_ckrd, rx_valid_rd,
    output wire                          sb_tx_data, sb_tx_clk, sb_tx_data_rd, sb_tx_clk_rd,
    input  wire                          sb_rx_data, sb_rx_clk, sb_rx_data_rd, sb_rx_clk_rd,
    input  wire [2:0]                    cfg_data_rate,
    input  wire                          cfg_scrambling_en, cfg_clock_gating_en, cfg_start_training,
    output wire [7:0]                    status_ltsm_state,
    output wire                          status_link_up,
    output wire [15:0]                   status_error_count
);

    wire io_clk, pll_locked;
    wire [MODULE_WIDTH-1:0] tx_data_parallel, tx_data_scrambled;
    wire [MODULE_WIDTH-1:0] rx_data_sampled, rx_data_descrambled;
    wire [MODULE_WIDTH*8-1:0] rx_data_deserialized;
    wire tx_data_valid, rx_valid_sampled, rx_deserial_valid;
    wire [7:0] ltsm_state;
    wire ltsm_link_up, ltsm_active;
    wire [63:0] sb_tx_packet, sb_rx_packet;
    wire sb_tx_valid, sb_rx_valid;
    
    assign io_clk = refclk;
    assign pll_locked = reset_n;
    
    // ========================================================================
    // TX PATH
    // ========================================================================
    ucie_tx_byte_to_lane #(.NUM_LANES(MODULE_WIDTH)) u_tx_byte_lane (
        .clk(io_clk), 
        .reset_n(reset_n), 
        .data_in(rdi_tx_data), 
        .valid_in(rdi_tx_valid && ltsm_active),
        .data_out(tx_data_parallel), 
        .ready(rdi_tx_ready),
        .valid_out(tx_data_valid)
    );
    
    ucie_scrambler #(.WIDTH(MODULE_WIDTH)) u_tx_scrambler (
        .clk(io_clk), 
        .reset_n(reset_n), 
        .enable(cfg_scrambling_en && tx_data_valid),
        .data_in(tx_data_parallel), 
        .data_out(tx_data_scrambled)
    );
    
    assign tx_data = tx_data_scrambled;
    assign tx_valid = tx_data_valid && ltsm_active;
    
    ucie_tx_clock_forward u_tx_clock (
        .clk(io_clk), 
        .reset_n(reset_n), 
        .enable(ltsm_active),
        .clkp(tx_clkp), 
        .clkn(tx_clkn)
    );
    
    assign tx_track = 1'b0;
    assign tx_data_rd = 4'b0;
    assign tx_ckrd = 1'b0;
    assign tx_valid_rd = 1'b0;
    
    // ========================================================================
    // RX PATH - All on refclk to avoid CDC issues
    // ========================================================================
    ucie_rx_sampler #(.NUM_LANES(MODULE_WIDTH)) u_rx_sampler (
        .rx_clkp(refclk),
        .reset_n(reset_n), 
        .data_in(rx_data), 
        .valid_in(rx_valid),
        .data_out(rx_data_sampled), 
        .valid_out(rx_valid_sampled)
    );
    
    ucie_scrambler #(.WIDTH(MODULE_WIDTH)) u_rx_descrambler (
        .clk(refclk),
        .reset_n(reset_n), 
        .enable(cfg_scrambling_en && rx_valid_sampled),
        .data_in(rx_data_sampled), 
        .data_out(rx_data_descrambled)
    );
    
    ucie_rx_deserializer #(.NUM_LANES(MODULE_WIDTH)) u_rx_deserializer (
        .clk(refclk),
        .reset_n(reset_n),
        .data_in(rx_data_descrambled), 
        .valid_in(rx_valid_sampled && ltsm_active),
        .data_out(rx_data_deserialized), 
        .valid_out(rx_deserial_valid)
    );

    assign rdi_rx_data = rx_data_deserialized;
    assign rdi_rx_valid = rx_deserial_valid;
    
    // ========================================================================
    // SIDEBAND
    // ========================================================================
    generate
        if (ENABLE_SIDEBAND) begin : gen_sideband
            ucie_sideband #(.ENABLE_REDUNDANCY(0)) u_sideband (
                .auxclk(auxclk), 
                .reset_n(reset_n), 
                .tx_packet(sb_tx_packet), 
                .tx_valid(sb_tx_valid),
                .sb_tx_data(sb_tx_data), 
                .sb_tx_clk(sb_tx_clk), 
                .sb_tx_data_rd(sb_tx_data_rd), 
                .sb_tx_clk_rd(sb_tx_clk_rd),
                .sb_rx_data(sb_rx_data), 
                .sb_rx_clk(sb_rx_clk), 
                .sb_rx_data_rd(sb_rx_data_rd), 
                .sb_rx_clk_rd(sb_rx_clk_rd),
                .rx_packet(sb_rx_packet), 
                .rx_valid(sb_rx_valid)
            );
        end else begin : gen_no_sideband
            assign sb_tx_data = 1'b0; 
            assign sb_tx_clk = 1'b0; 
            assign sb_tx_data_rd = 1'b0; 
            assign sb_tx_clk_rd = 1'b0;
            assign sb_rx_packet = 64'h0; 
            assign sb_rx_valid = 1'b0;
        end
    endgenerate
    
    // ========================================================================
    // LINK TRAINING STATE MACHINE
    // ========================================================================
    ucie_ltsm #(.PACKAGE_TYPE(PACKAGE_TYPE), .MODULE_WIDTH(MODULE_WIDTH)) u_ltsm (
        .clk(io_clk), 
        .auxclk(auxclk), 
        .reset_n(reset_n), 
        .pll_locked(pll_locked), 
        .start_training(cfg_start_training),
        .sb_tx_packet(sb_tx_packet), 
        .sb_tx_valid(sb_tx_valid), 
        .sb_rx_packet(sb_rx_packet), 
        .sb_rx_valid(sb_rx_valid),
        .tx_repair_map(), 
        .rx_repair_map(),
        .tx_repair_shift(), 
        .rx_repair_shift(),
        .current_state(ltsm_state), 
        .link_up(ltsm_link_up), 
        .active_state(ltsm_active)
    );
    
    assign status_ltsm_state = ltsm_state;
    assign status_link_up = ltsm_link_up;
    assign status_error_count = 16'h0;
    assign rdi_rx_error = 1'b0;

endmodule