module ucie_tx_clock_forward (
    input wire clk,
    input wire reset_n,
    input wire enable,
    output wire clkp,
    output wire clkn
);
    assign clkp = enable ? clk : 1'b0;
    assign clkn = enable ? ~clk : 1'b1;
endmodule