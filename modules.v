

module ncbms (
	input       c,
	input       xs,
	input       xr,
	input       ci,
	output      q,
	output      xq
);

reg dprs;
wire d = ci ? dprs : ~dprs;
assign q = dprs;
assign xq = ~dprs;

always @(posedge c, negedge xr, negedge xs) begin

	if (!xr) dprs <= 0;
	else if (!xs) dprs <= 1;
	else dprs <= d;
end

endmodule;


module nlcbn (
	input       c,
	input       xs,
	input       xr,
	input       ci,
	output      co,
	output      q,
	output      xq
);

reg dprs;
wire d = ci ? dprs : ~dprs;
assign co = ~(~ci & dprs);
assign q = dprs;
assign xq = ~dprs;

always @(posedge c, negedge xr, negedge xs) begin

	if (!xr) dprs <= 0;
	else if (!xs) dprs <= 1;
	else dprs <= d;
end

endmodule;

module nlcb1 (
	input       c,
	input       xs,
	input       xr,
	input       ch,
	output      co,
	output      q,
	output      xq
);

wire d = ch ? ~dprs : dprs;
assign co = ~(ch & dprs);
assign q = dprs;
assign xq = ~dprs;
reg dprs;

always @(posedge c, negedge xr, negedge xs) begin

	if (!xr) dprs <= 0;
	else if (!xs) dprs <= 1;
	else dprs <= d;
end

endmodule;

module cbms (
	input       c,
	input       l,
	input       d,
	input       ci,
	input       xr,
	output      q,
	output      xq
);

wire dc;

lt2 lt2 (
	.xr(xr),
	.c(c),
	.l(l),
	.dl(d),
	.dc(dc),
	.q(q),
	.xq(xq)
);

always @(*) begin
    dc = ci ? q : xq;
end

endmodule;

module cbn (
	input       c,
	input       l,
	input       d,
	input       ci,
	input       xr,
	output      q,
	output      xq,
	output      co
);

wire dc;

lt2 lt2 (
	.xr(xr),
	.c(c),
	.l(l),
	.dl(d),
	.dc(dc),
	.q(q),
	.xq(xq)
);

always @(*) begin
    dc = ci ? q : xq;
    co = ~(~ci & q);
end

endmodule;


module cb1 (
	input       c,
	input       l,
	input       d,
	input       ch,
	input       xr,
	output      q,
	output      xq,
	output      co
);

wire dc;

lt2 lt2 (
	.xr(xr),
	.c(c),
	.l(l),
	.dl(d),
	.dc(dc),
	.q(q),
	.xq(xq)
);

always @(*) begin
    dc = ch ? xq : q;
    co = ~(ch & q);
end

endmodule;

module lt2 (
	input       c,
	input       dc,
	input       l,
	input       dl,
	input       xr,
	output      q,
	output reg  xq
);

assign q = ~xq;

always @(posedge c, posedge l, negedge xr) begin
    if (!xr) xq <= 1;
    else if(l) xq <= ~dl;
    else xq <= ~dc;
//    else begin
//        xq <= l ? ~dl : ~dc;
//    end
end;

/*
wire latch_d;
wire o1,o2,o3;
reg latch;

always @(*) begin
    o1 = c ? o2 : dc;
    o2 = l ? dl : o3;
    latch_d = ~o3;
    o3 = xr & o1;
//    q = ~xr ? 0 : (~c ? latch_d : q); //orignal design with latch
    q = ~xq;
end

always @(negedge c, negedge xr) begin
    if (!xr) xq<=1;
    else xq <= latch_d;
end
*/
endmodule;
