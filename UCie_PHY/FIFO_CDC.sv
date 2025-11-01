module ucie_cdc_fifo #(
    parameter DATA_WIDTH = 512,
    parameter DEPTH = 8,
    parameter ADDR_WIDTH = $clog2(DEPTH)
) (
    input wire wr_clk,
    input wire wr_reset_n,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire wr_valid,
    input wire rd_clk,
    input wire rd_reset_n,
    output reg [DATA_WIDTH-1:0] rd_data,
    output reg rd_valid,
    input wire rd_ready
);
    // Memory
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Write domain pointers
    reg [ADDR_WIDTH:0] wr_ptr, wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;
    
    // Read domain pointers  
    reg [ADDR_WIDTH:0] rd_ptr, rd_ptr_gray;
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
    
    // Gray code conversion functions
    function [ADDR_WIDTH:0] bin2gray;
        input [ADDR_WIDTH:0] bin;
        begin
            bin2gray = bin ^ (bin >> 1);
        end
    endfunction
    
    function [ADDR_WIDTH:0] gray2bin;
        input [ADDR_WIDTH:0] gray;
        integer i;
        begin
            gray2bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
            for (i = ADDR_WIDTH-1; i >= 0; i = i - 1) begin
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
            end
        end
    endfunction
    
    // Write clock domain
    wire wr_full = (wr_ptr_gray == {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], 
                                     rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});
    
    always @(posedge wr_clk or negedge wr_reset_n) begin
        if (!wr_reset_n) begin
            wr_ptr <= 0;
            wr_ptr_gray <= 0;
            rd_ptr_gray_sync1 <= 0;
            rd_ptr_gray_sync2 <= 0;
        end else begin
            // Synchronize read pointer
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
            
            // Write operation
            if (wr_valid && !wr_full) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
                wr_ptr_gray <= bin2gray(wr_ptr + 1'b1);
            end
        end
    end
    
    // Read clock domain
    wire rd_empty = (rd_ptr_gray == wr_ptr_gray_sync2);
      always @(posedge rd_clk or negedge rd_reset_n) begin
        if (!rd_reset_n) begin
            rd_ptr <= 0;
            rd_ptr_gray <= 0;
            wr_ptr_gray_sync1 <= 0;
            wr_ptr_gray_sync2 <= 0;
            rd_data <= 0;
            rd_valid <= 1'b0;
        end else begin
            // Synchronize write pointer
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
            
            // Read operation
            if (!rd_empty && (rd_ready || !rd_valid)) begin
                rd_data <= mem[rd_ptr[ADDR_WIDTH-1:0]];
                rd_valid <= 1'b1;
                rd_ptr <= rd_ptr + 1'b1;
                rd_ptr_gray <= bin2gray(rd_ptr + 1'b1);
            end else if (rd_ready) begin
                rd_valid <= 1'b0;
            end
        end
    end
endmodule