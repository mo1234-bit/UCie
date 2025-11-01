module ucie_crc_check #(parameter DATA_WIDTH = 512) (
    input wire clk,
    input wire reset_n,
    input wire enable,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire valid_in,
    output reg [DATA_WIDTH-17:0] data_out,
    output reg crc_error,
    output reg [7:0] seqnum_out
);
    reg [15:0] received_crc, calculated_crc;
    integer i;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            crc_error <= 1'b0;
            data_out <= 0;
            seqnum_out <= 0;
        end else if (valid_in) begin
            if (enable && DATA_WIDTH > 16) begin
                received_crc = data_in[DATA_WIDTH-1:DATA_WIDTH-16];
                calculated_crc = 16'hFFFF;
                
                for (i = 0; i < DATA_WIDTH-16; i = i + 1) begin
                    calculated_crc = {calculated_crc[14:0], 1'b0} ^ 
                                    (calculated_crc[15] ^ data_in[i] ? 16'h1021 : 16'h0);
                end
                
                crc_error <= (calculated_crc != received_crc);
                data_out <= data_in[DATA_WIDTH-17:0];
                seqnum_out <= seqnum_out + 1'b1;
            end else begin
                crc_error <= 1'b0;
                data_out <= data_in[DATA_WIDTH-17:0];
            end
        end else begin
            crc_error <= 1'b0;
        end
    end
endmodule
