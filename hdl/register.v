// simulate registers with async clocks in the 'clock' domain

module register (
    input clock,
    input s,    // set
    input r,    // reset
    input c,    // write clock
    input d,    // new value
    output reg q    // value
);

reg val_reg;
reg c_d;
/*
always @(posedge c, posedge s, posedge r)
begin
    if (r)
        q <= 0;
    else if (s)
        q <= 1;
    else
        q <= d;
end
*/
reg q_r;

always @(*) begin
    if (r)
        q = 0;
    else if (s)
        q = 1;
    else
        q = val_reg;
end

always @(negedge clock) begin
    c_d <= c;
    if  (~c_d & c)
        val_reg <= d;
    else
        val_reg <= q;
end

endmodule