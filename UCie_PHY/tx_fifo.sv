module ucie_tx_fifo #(
    parameter DATA_WIDTH = 512,
    parameter DEPTH = 16
) (
    input wire clk,
    input wire reset_n,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire wr_valid,
    output wire wr_ready,
    input wire [7:0] wr_seqnum,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire rd_valid,
    input wire rd_ready,
    output wire [7:0] rd_seqnum,
    input wire retry_request,
    input wire [7:0] retry_seqnum,
    output wire empty
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [7:0] seqnum_mem [0:DEPTH-1];
    reg [$clog2(DEPTH):0] wr_ptr, rd_ptr;
    reg [$clog2(DEPTH):0] count;
    
    assign empty = (count == 0);
    assign wr_ready = (count < DEPTH);
    assign rd_valid = !empty;
    assign rd_data = mem[rd_ptr[$clog2(DEPTH)-1:0]];
    assign rd_seqnum = seqnum_mem[rd_ptr[$clog2(DEPTH)-1:0]];
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
        end else begin
            if (retry_request) begin
                // Rewind read pointer for retry
                rd_ptr <= wr_ptr - count;
            end else begin
                if (wr_valid && wr_ready) begin
                    mem[wr_ptr[$clog2(DEPTH)-1:0]] <= wr_data;
                    seqnum_mem[wr_ptr[$clog2(DEPTH)-1:0]] <= wr_seqnum;
                    wr_ptr <= wr_ptr + 1'b1;
                end
                
                if (rd_valid && rd_ready) begin
                    rd_ptr <= rd_ptr + 1'b1;
                end
                
                if ((wr_valid && wr_ready) && !(rd_valid && rd_ready))
                    count <= count + 1'b1;
                else if (!(wr_valid && wr_ready) && (rd_valid && rd_ready))
                    count <= count - 1'b1;
            end
        end
    end
endmodule
