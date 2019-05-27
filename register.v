// simulate registers with async clocks in the 'clock' domain

module register (
    input clock,
    input s,    // set
    input r,    // reset
    input c,    // write clock
    input d,    // new value
    output q    // value
);

reg val_reg;
reg c_d;

always @(*) begin
    if (r)
        q = 0;
    else if (s)
        q = 1;
    else if (~c_d & c)
        q = d;
    else
        q = val_reg;
end

always @(posedge clock) begin
    c_d <= c;
    val_reg <= q;
end

endmodule