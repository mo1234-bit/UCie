module ucie_crc_gen #(parameter DATA_WIDTH = 512) (
    input wire clk,
    input wire reset_n,
    input wire enable,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire valid_in,
    output reg [DATA_WIDTH+15:0] data_out,
    output reg [15:0] crc_out
);
    reg [15:0] crc;
    integer i;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            crc <= 16'hFFFF;
            data_out <= 0;
            crc_out <= 0;
        end else if (valid_in) begin
            if (enable) begin
                crc = 16'hFFFF;
                for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                    crc = {crc[14:0], 1'b0} ^ (crc[15] ^ data_in[i] ? 16'h1021 : 16'h0);
                end
                data_out <= {crc, data_in};
                crc_out <= crc;
            end else begin
                data_out <= {{16{1'b0}}, data_in};
                crc_out <= 16'h0;
            end
        end
    end
endmodule
