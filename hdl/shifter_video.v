
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

wire [15:0] shdout0, shdout1, shdout2, shdout3;
wire [15:0] shcout0, shcout1, shcout2, shcout3;
genvar i;
for(i=0; i<16; i=i+1) begin:sharray
    shifter_cell c3(clk32, pixClkEn, LOAD, Reload, (i == 0) ? shftCin3 : shcout3[i-1], shcout3[i], DIN[i], shdout3[i]);
    shifter_cell c2(clk32, pixClkEn, LOAD, Reload, (i == 0) ? shftCin2 : shcout2[i-1], shcout2[i], shdout3[i], shdout2[i]);
    shifter_cell c1(clk32, pixClkEn, LOAD, Reload, (i == 0) ? shftCin1 : shcout1[i-1], shcout1[i], shdout2[i], shdout1[i]);
    shifter_cell c0(clk32, pixClkEn, LOAD, Reload, (i == 0) ? shftCin0 : shcout0[i-1], shcout0[i], shdout1[i], shdout0[i]);
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
wire [3:0] color_index = rez[1] ? { 3'b000, shftCout0 } : rez[0] ? { 2'b00, shftCout1, shftCout0 } : { shftCout3, shftCout2, shftCout1, shftCout0 };


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

////////////////////////////////

module shifter_cell (
    input clk32,
    input pixClkEn,
    input LOAD,
    input Reload,
    input Shin,
    output reg Shout,
    input Din,
    output Dout
);

always @(posedge clk32) if (pixClkEn) Shout <= Reload ? Dout : Shin;

register Dout_r(clk32, 0, 0, LOAD, Din, Dout);

endmodule
