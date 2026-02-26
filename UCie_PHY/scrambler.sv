module ucie_scrambler #(parameter WIDTH = 64) (
    input wire clk,
    input wire reset_n,
    input wire enable,
    input wire [WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out
);
    reg [22:0] lfsr [0:7];
    localparam [22:0] SEEDS [0:7] = '{
        23'h1DBFBC, 23'h0607BB, 23'h1EC760, 23'h18C0DB,
        23'h010F12, 23'h19CFC9, 23'h0277CE, 23'h1BB807
    };
    
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_lfsr
            wire feedback = lfsr[i][22] ^ lfsr[i][17];
            
            always @(posedge clk or negedge reset_n) begin
                if (!reset_n)
                    lfsr[i] <= SEEDS[i];
                else if (enable)
                    lfsr[i] <= {lfsr[i][21:0], feedback};
            end
        end
        
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_scramble
            assign data_out[i] = enable ? (data_in[i] ^ lfsr[i % 8][0]) : data_in[i];
        end
    endgenerate
endmodule

