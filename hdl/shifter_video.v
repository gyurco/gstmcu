
// Atari ST shifter implementation, sync to 32 MHz clock

module shifter_video (
    input clk32,
    input nReset,
    input pixClk,
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
always @(posedge clk32) begin : shiftarray
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
reg Reload;

always @(negedge clk32, negedge nReset) begin : reloadctrl
	reg pixClk_D;
	reg LOAD_D;
	reg Reload_D;

	reg load_d1, load_d2;
	reg reload_delay_d;
	reg [3:0] rdelay;
	reg [3:0] pixCntr;
	reg reload_delay_n;
	reg pxCtrEn;

	// edge detectors
	pixClk_D <= pixClk;
	LOAD_D <= LOAD;
	Reload_D <= Reload;

	if (!nReset) begin
		reload_delay_n <= 1'b0;
		pxCtrEn <= 1'b0;
	end else begin
		if (~LOAD_D & LOAD) begin
			load_d1 <= 1'b1;
			rdelay <= { 1'b1, rdelay[3:1] };
		end

		if (~pixClk_D & pixClk) begin
			reload_delay_n <= ~Reload;
			load_d2 <= load_d1;
			Reload <= &pixCntr;
			if (pxCtrEn) pixCntr <= pixCntr + 1'h1;
			else pixCntr <= 4'h4;
		end

		else if (Reload_D & ~Reload) pxCtrEn <= load_d2;

		// originally async resets
		if (!DE) load_d1 <= 1'b0;
		if (!rdelay[0]) Reload <= 1'b0;
		if (!reload_delay_n) rdelay <= 4'b0000;
		if (load_d2) pxCtrEn <= 1'b1;
	end
end

endmodule
