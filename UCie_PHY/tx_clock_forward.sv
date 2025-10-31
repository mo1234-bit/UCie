module ucie_tx_clock_forward (
    input wire clk, reset_n, enable,
    output wire clkp, clkn
);
    assign clkp = enable ? clk : 1'b0;
    assign clkn = enable ? ~clk : 1'b1;
endmodule
