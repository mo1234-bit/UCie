module ucie_phy_top #(
    parameter PACKAGE_TYPE = "ADVANCED",
    parameter MODULE_WIDTH = 64,
    parameter MAX_DATA_RATE = 16,
    parameter ENABLE_REDUNDANCY = 1,
    parameter ENABLE_SIDEBAND = 1,
    parameter NUM_MODULES = 1,
    parameter ENABLE_CRC = 1,
    parameter ENABLE_RETRY = 1,
    parameter FIFO_DEPTH = 16
) (
    // Clocks and Reset
    input  wire                          refclk,
    input  wire                          auxclk,
    input  wire                          reset_n,
    
    // RDI TX Interface
    input  wire [MODULE_WIDTH*8-1:0]     rdi_tx_data,
    input  wire                          rdi_tx_valid,
    output wire                          rdi_tx_ready,
    input  wire [7:0]                    rdi_tx_seqnum,
    
    // RDI RX Interface
    output wire [MODULE_WIDTH*8-1:0]     rdi_rx_data,
    output wire                          rdi_rx_valid,
    output wire                          rdi_rx_error,
    output wire [7:0]                    rdi_rx_seqnum,
    input  wire                          rdi_rx_retry,
    
    // Main Band TX
    output wire [MODULE_WIDTH-1:0]       tx_data,
    output wire                          tx_valid,
    output wire                          tx_clkp,
    output wire                          tx_clkn,
    output wire                          tx_track,
    
    // Main Band RX
    input  wire [MODULE_WIDTH-1:0]       rx_data,
    input  wire                          rx_valid,
    input  wire                          rx_clkp,
    input  wire                          rx_clkn,
    input  wire                          rx_track,
    
    // Redundancy TX/RX
    output wire [3:0]                    tx_data_rd,
    output wire                          tx_ckrd,
    output wire                          tx_valid_rd,
    input  wire [3:0]                    rx_data_rd,
    input  wire                          rx_ckrd,
    input  wire                          rx_valid_rd,
    
    // Sideband TX/RX
    output wire                          sb_tx_data,
    output wire                          sb_tx_clk,
    output wire                          sb_tx_data_rd,
    output wire                          sb_tx_clk_rd,
    input  wire                          sb_rx_data,
    input  wire                          sb_rx_clk,
    input  wire                          sb_rx_data_rd,
    input  wire                          sb_rx_clk_rd,
    
    // Configuration
    input  wire [2:0]                    cfg_data_rate,
    input  wire                          cfg_scrambling_en,
    input  wire                          cfg_clock_gating_en,
    input  wire                          cfg_start_training,
    input  wire                          cfg_enable_crc,
    input  wire                          cfg_enable_retry,
    input  wire [5:0]                    cfg_active_lanes,
    
    // Status and Diagnostics
    output wire [7:0]                    status_ltsm_state,
    output wire                          status_link_up,
    output wire [15:0]                   status_error_count,
    output wire [31:0]                   status_retry_count,
    output wire [31:0]                   status_tx_packets,
    output wire [31:0]                   status_rx_packets,
    output wire [7:0]                    status_link_quality,
    output wire                          status_cdr_locked
);

    // Internal signals
    wire io_clk, rx_recovered_clk, pll_locked;
    wire [MODULE_WIDTH-1:0] tx_data_parallel, tx_data_scrambled, tx_data_encoded;
    wire [MODULE_WIDTH-1:0] rx_data_sampled, rx_data_descrambled, rx_data_decoded;
    wire [MODULE_WIDTH*8-1:0] rx_data_deserialized;
    wire tx_data_valid, rx_valid_sampled, rx_deserial_valid;
    wire [7:0] ltsm_state;
    wire ltsm_link_up, ltsm_active;
    wire [63:0] sb_tx_packet, sb_rx_packet;
    wire sb_tx_valid, sb_rx_valid;
    wire [15:0] crc_value;
    wire crc_error;
    wire retry_request, retry_ack;
    wire [7:0] tx_seqnum, rx_seqnum;
    
    // Performance counters
    reg [31:0] retry_counter, tx_packet_counter, rx_packet_counter;
    reg [15:0] error_counter;
    reg [7:0] link_quality;
    
    // Clock management
    assign io_clk = refclk;
    assign pll_locked = reset_n;
    
    
    
    // TX FIFO for retry buffer
    wire [MODULE_WIDTH*8-1:0] tx_fifo_data;
    wire tx_fifo_valid, tx_fifo_ready, tx_fifo_empty;
    wire [7:0] tx_fifo_seqnum;
    
    //  bypass FIFO for now to reduce complexity
    assign tx_fifo_data = rdi_tx_data;
    assign tx_fifo_valid = rdi_tx_valid && ltsm_active;
    assign rdi_tx_ready = tx_fifo_ready;
    assign tx_fifo_seqnum = rdi_tx_seqnum;
    
    /*
    ucie_tx_fifo #(
        .DATA_WIDTH(MODULE_WIDTH*8),
        .DEPTH(FIFO_DEPTH)
    ) u_tx_fifo (
        .clk(io_clk),
        .reset_n(reset_n),
        .wr_data(rdi_tx_data),
        .wr_valid(rdi_tx_valid),
        .wr_ready(rdi_tx_ready),
        .wr_seqnum(rdi_tx_seqnum),
        .rd_data(tx_fifo_data),
        .rd_valid(tx_fifo_valid),
        .rd_ready(tx_fifo_ready),
        .rd_seqnum(tx_fifo_seqnum),
        .retry_request(retry_request),
        .retry_seqnum(rx_seqnum),
        .empty(tx_fifo_empty)
    );
    */
    
    // CRC Generator - Bypass for now
    wire [MODULE_WIDTH*8-1:0] tx_data_with_crc;
    assign tx_data_with_crc = tx_fifo_data;
    
    /*
    ucie_crc_gen #(
        .DATA_WIDTH(MODULE_WIDTH*8)
    ) u_tx_crc (
        .clk(io_clk),
        .reset_n(reset_n),
        .enable(cfg_enable_crc),
        .data_in(tx_fifo_data),
        .valid_in(tx_fifo_valid),
        .data_out(tx_data_with_crc),
        .crc_out(crc_value)
    );
    */
    
    // Byte to Lane conversion
    ucie_tx_byte_to_lane #(
        .NUM_LANES(MODULE_WIDTH)
    ) u_tx_byte_lane (
        .clk(io_clk),
        .reset_n(reset_n),
        .data_in(tx_data_with_crc),
        .valid_in(tx_fifo_valid),
        .data_out(tx_data_parallel),
        .ready(tx_fifo_ready),
        .valid_out(tx_data_valid)
    );
    
    // Scrambler
    ucie_scrambler #(
        .WIDTH(MODULE_WIDTH)
    ) u_tx_scrambler (
        .clk(io_clk),
        .reset_n(reset_n),
        .enable(cfg_scrambling_en && tx_data_valid),
        .data_in(tx_data_parallel),
        .data_out(tx_data_scrambled)
    );
    
    // 8b/10b Encoder - Bypass for now
    assign tx_data_encoded = tx_data_scrambled;
    
    /*
    ucie_8b10b_encoder #(
        .NUM_LANES(MODULE_WIDTH)
    ) u_tx_encoder (
        .clk(io_clk),
        .reset_n(reset_n),
        .enable(ltsm_active),
        .data_in(tx_data_scrambled),
        .data_out(tx_data_encoded)
    );
    */
    
    assign tx_data = tx_data_encoded;
    assign tx_valid = tx_data_valid && ltsm_active;
    assign tx_seqnum = tx_fifo_seqnum;
    
    // Clock forwarding
    ucie_tx_clock_forward u_tx_clock (
        .clk(io_clk),
        .reset_n(reset_n),
        .enable(ltsm_link_up || (ltsm_state >= 8'h01)),  // Enable clock as soon as training starts
        .clkp(tx_clkp),
        .clkn(tx_clkn)
    );
    
    assign tx_track = 1'b0;
    assign tx_data_rd = 4'b0;
    assign tx_ckrd = 1'b0;
    assign tx_valid_rd = 1'b0;
    

    
    // Clock Data Recovery
    wire cdr_locked;
    ucie_cdr #(
        .NUM_LANES(MODULE_WIDTH)
    ) u_cdr (
        .rx_clkp(rx_clkp),
        .rx_clkn(rx_clkn),
        .reset_n(reset_n),
        .data_in(rx_data),
        .recovered_clk(rx_recovered_clk),
        .locked(cdr_locked)
    );
    
    assign status_cdr_locked = cdr_locked;
    
    // RX  with recovered clock
    ucie_rx_sampler #(
        .NUM_LANES(MODULE_WIDTH)
    ) u_rx_sampler (
        .rx_clkp(rx_recovered_clk),
        .reset_n(reset_n),
        .data_in(rx_data),
        .valid_in(rx_valid && cdr_locked),
        .data_out(rx_data_sampled),
        .valid_out(rx_valid_sampled)
    );
    
    // 8b/10b Decoder - Bypass
    assign rx_data_decoded = rx_data_sampled;
    assign rx_decode_error = 1'b0;
    
    /*
    wire rx_decode_error;
    ucie_8b10b_decoder #(
        .NUM_LANES(MODULE_WIDTH)
    ) u_rx_decoder (
        .clk(rx_recovered_clk),
        .reset_n(reset_n),
        .data_in(rx_data_sampled),
        .valid_in(rx_valid_sampled),
        .data_out(rx_data_decoded),
        .error(rx_decode_error)
    );
    */
    
    // Descrambler
    ucie_scrambler #(
        .WIDTH(MODULE_WIDTH)
    ) u_rx_descrambler (
        .clk(rx_recovered_clk),
        .reset_n(reset_n),
        .enable(cfg_scrambling_en && rx_valid_sampled),
        .data_in(rx_data_decoded),
        .data_out(rx_data_descrambled)
    );
    
    // Deserializer
    ucie_rx_deserializer #(
        .NUM_LANES(MODULE_WIDTH)
    ) u_rx_deserializer (
        .clk(rx_recovered_clk),
        .reset_n(reset_n),
        .data_in(rx_data_descrambled),
        .valid_in(rx_valid_sampled && ltsm_active),
        .data_out(rx_data_deserialized),
        .valid_out(rx_deserial_valid)
    );
    
    // CRC Checker - Bypass for now
    wire [MODULE_WIDTH*8-1:0] rx_data_checked = rx_data_deserialized;
    assign rx_crc_error = 1'b0;
    
    /*
    wire [MODULE_WIDTH*8-1:0] rx_data_checked;
    wire rx_crc_error;
    ucie_crc_check #(
        .DATA_WIDTH(MODULE_WIDTH*8+16)  // Include CRC in data width
    ) u_rx_crc (
        .clk(rx_recovered_clk),
        .reset_n(reset_n),
        .enable(cfg_enable_crc),
        .data_in(rx_data_deserialized),
        .valid_in(rx_deserial_valid),
        .data_out(rx_data_checked),
        .crc_error(rx_crc_error),
        .seqnum_out(rx_seqnum)
    );
    */
    
    // Clock domain crossing for RX data
    wire [MODULE_WIDTH*8-1:0] rx_data_sync;
    wire rx_valid_sync;
    ucie_cdc_fifo #(
        .DATA_WIDTH(MODULE_WIDTH*8),
        .DEPTH(8)
    ) u_rx_cdc (
        .wr_clk(rx_recovered_clk),
        .wr_reset_n(reset_n),
        .wr_data(rx_data_checked),
        .wr_valid(rx_deserial_valid && !rx_crc_error),
        .rd_clk(refclk),
        .rd_reset_n(reset_n),
        .rd_data(rx_data_sync),
        .rd_valid(rx_valid_sync),
        .rd_ready(1'b1)
    );
    
    assign rdi_rx_data = rx_data_sync;
    assign rdi_rx_valid = rx_valid_sync;
    assign rdi_rx_error = rx_crc_error || rx_decode_error;
    
 
    reg [7:0] rx_seqnum_counter;
    always @(posedge refclk or negedge reset_n) begin
        if (!reset_n)
            rx_seqnum_counter <= 8'd0;
        else if (rx_valid_sync)
            rx_seqnum_counter <= rx_seqnum_counter + 1'b1;
    end
    assign rdi_rx_seqnum = rx_seqnum_counter;
    
    // Retry logic
    assign retry_request = rdi_rx_retry || rx_crc_error;
    
   
    generate
        if (ENABLE_SIDEBAND) begin : gen_sideband
            ucie_sideband #(
                .ENABLE_REDUNDANCY(ENABLE_REDUNDANCY)
            ) u_sideband (
                .auxclk(auxclk),
                .reset_n(reset_n),
                .tx_packet(sb_tx_packet),
                .tx_valid(sb_tx_valid),
                .tx_ready(),
                .sb_tx_data(sb_tx_data),
                .sb_tx_clk(sb_tx_clk),
                .sb_tx_data_rd(sb_tx_data_rd),
                .sb_tx_clk_rd(sb_tx_clk_rd),
                .sb_rx_data(sb_rx_data),
                .sb_rx_clk(sb_rx_clk),
                .sb_rx_data_rd(sb_rx_data_rd),
                .sb_rx_clk_rd(sb_rx_clk_rd),
                .rx_packet(sb_rx_packet),
                .rx_valid(sb_rx_valid),
                .retry_request(retry_request),
                .retry_ack(retry_ack)
            );
        end else begin : gen_no_sideband
            assign sb_tx_data = 1'b0;
            assign sb_tx_clk = 1'b0;
            assign sb_tx_data_rd = 1'b0;
            assign sb_tx_clk_rd = 1'b0;
            assign sb_rx_packet = 64'h0;
            assign sb_rx_valid = 1'b0;
            assign retry_ack = 1'b0;
        end
    endgenerate
    
    
    wire [MODULE_WIDTH-1:0] active_lane_mask;
    ucie_ltsm #(
        .PACKAGE_TYPE(PACKAGE_TYPE),
        .MODULE_WIDTH(MODULE_WIDTH),
        .ENABLE_REDUNDANCY(ENABLE_REDUNDANCY)
    ) u_ltsm (
        .clk(io_clk),
        .auxclk(auxclk),
        .reset_n(reset_n),
        .pll_locked(pll_locked),
        .cdr_locked(cdr_locked),
        .start_training(cfg_start_training),
        .sb_tx_packet(sb_tx_packet),
        .sb_tx_valid(sb_tx_valid),
        .sb_rx_packet(sb_rx_packet),
        .sb_rx_valid(sb_rx_valid),
        .cfg_active_lanes(cfg_active_lanes),
        .active_lane_mask(active_lane_mask),
        .tx_repair_map(),
        .rx_repair_map(),
        .tx_repair_shift(),
        .rx_repair_shift(),
        .current_state(ltsm_state),
        .link_up(ltsm_link_up),
        .active_state(ltsm_active),
        .link_quality(link_quality)
    );
    
    
    always @(posedge io_clk or negedge reset_n) begin
        if (!reset_n) begin
            retry_counter <= 32'd0;
            tx_packet_counter <= 32'd0;
            rx_packet_counter <= 32'd0;
            error_counter <= 16'd0;
        end else begin
            if (retry_request && cfg_enable_retry)
                retry_counter <= retry_counter + 1'b1;
            
            if (tx_data_valid && ltsm_active)
                tx_packet_counter <= tx_packet_counter + 1'b1;
            
            if (rx_valid_sync)
                rx_packet_counter <= rx_packet_counter + 1'b1;
            
            if (rx_crc_error || rx_decode_error) begin
                if (error_counter != 16'hFFFF)
                    error_counter <= error_counter + 1'b1;
            end
        end
    end
    

    assign status_ltsm_state = ltsm_state;
    assign status_link_up = ltsm_link_up;
    assign status_error_count = error_counter;
    assign status_retry_count = retry_counter;
    assign status_tx_packets = tx_packet_counter;
    assign status_rx_packets = rx_packet_counter;
    assign status_link_quality = link_quality;


endmodule
