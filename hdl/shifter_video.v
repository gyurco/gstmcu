
// Atari ST shifter implementation, sync to 32 MHz clock

module shifter_video (
    input clk32,
    input nReset,
    input pixClkEn,
    input DE,
    input LOAD,
    input [1:0] rez,
    input monocolor,
    input [15:0] DIN,
    output [3:0] color_index
);

// shift array
reg [15:0] shdout0, shdout1, shdout2, shdout3;
reg [15:0] shcout0, shcout1, shcout2, shcout3;
always @(posedge clk32) begin
	reg loadD;
	loadD <= LOAD;
	if (pixClkEn) begin
		shcout3 <= Reload ? shdout3 : {shcout3[14:0], shftCin3};
		shcout2 <= Reload ? shdout2 : {shcout2[14:0], shftCin2};
		shcout1 <= Reload ? shdout1 : {shcout1[14:0], shftCin1};
		shcout0 <= Reload ? shdout0 : {shcout0[14:0], shftCin0};
	end
	if (~loadD & LOAD) begin
		shdout3 <= DIN;
		shdout2 <= shdout3;
		shdout1 <= shdout2;
		shdout0 <= shdout1;
	end
end

// shift array logic
wire notlow = rez[0] | rez[1];
wire shftCout3 = shcout3[15];
wire shftCout2 = shcout2[15];
wire shftCout1 = shcout1[15];
wire shftCout0 = shcout0[15];
wire shftCin3  = ~monocolor & rez[1];
wire shftCin2  = shftCout3 & rez[1] & notlow;
wire shftCin1  = (shftCout3 & ~rez[1] & notlow) | (shftCout2 & rez[1] & notlow);
wire shftCin0  = (shftCout2 & ~rez[1] & notlow) | (shftCout1 & rez[1] & notlow);
assign color_index = { shftCout3, shftCout2, shftCout1, shftCout0 };

// reload control
wire load_d1;
register load_d1_r(clk32, 0, !DE, LOAD, 1'b1, load_d1);

reg load_d2;
reg reload_delay_n;

always @(posedge clk32, negedge nReset) begin
	if (!nReset) reload_delay_n <= 1'b0;
	else if (pixClkEn) begin
		reload_delay_n <= ~Reload;
		load_d2 <= load_d1;
	end
end

wire pxCtrEn;
register pxCtrEn_r(clk32, load_d2, !nReset, Reload, load_d2, pxCtrEn);

wire [3:0] rdelay;
register #(4) rdelay_r(clk32, 0, !reload_delay_n, LOAD, { 1'b1, rdelay[3:1] }, rdelay);

reg [3:0] pixCntr;
reg       Reload;

always @(posedge clk32, negedge rdelay[0]) begin
	if (!rdelay[0]) Reload <= 1'b0;
	else if (pixClkEn) Reload <= &pixCntr;
end

always @(posedge clk32) begin
	if (pixClkEn) begin
		if (pxCtrEn) pixCntr <= pixCntr + 1'h1;
		else pixCntr <= 4'h4;
	end;
end
endmodule
