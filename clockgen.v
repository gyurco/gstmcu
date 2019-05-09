/* verilator lint_off UNOPTFLAT */

module clockgen (
	input clk,
	input resb,
	input porb,
	output mhz8,
	output mhz4,
	output time0,
	output time1,
	output time2,
	output addrsel,
	output m2clock,
	output clk4,
	output latch,
	output cycsel,
	output lcycselb
);

assign clk4 = l2;
assign mhz8 = !porb ? 0 : (clk ? l1 : mhz8);
assign mhz4 = !porb ? 1 : (clk ? ~l2 : mhz4);
assign time0 = !porb ? 0 : (clk ? ~l3 : time0);
assign time1 = !porb ? 0 : (~clk ? time0 : time1);
assign time2 = !porb ? 0 : (clk ? time1 : time2);
wire   time3 = !porb ? 0 : (~clk ? time2 : time3);
wire   time4 = !porb ? 0 : (clk ? time3 : time4);
assign addrsel = !porb ? 0 : (~clk ? time4 : addrsel);
wire   time6 = !porb ? 1 : (clk ? addrsel : time6);
assign m2clock = ~time6;
assign cycsel = !porb ? 0 : (~clk ? time6 : cycsel);
wire latchb = !porb ? 1 : (clk ? ~(addrsel & ~time1) : latchb);
assign latch = ~latchb;
assign lcycselb = !porb ? 0 : (~clk ? ~time6 : lcycselb);

reg l1, l2, l3;

always @(negedge clk, negedge resb) begin
	if (!resb) begin
		{l1, l2} <= 0;
		l3 <= 1;
	end else begin
		l1 <= ~l1;
		l2 <= l1 ? l2 : ~l2;
		l3 <= (~l1 & ~l2) ? ~l3 : l3;
	end
end

endmodule