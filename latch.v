// simulate latches in the 'clock' domain

module latch (
    input clock,
    input s,    // set
    input r,    // reset
    input g,    // gate
    input d,    // input
    output q    // output
);

reg val_reg;

always @(*) begin
    if (r)
        q = 0;
    else if (s)
        q = 1;
    else if (g)
        q = d;
    else
        q = val_reg;
end

always @(posedge clock) begin
    val_reg <= q;
end

endmodule