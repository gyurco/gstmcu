
module mcucontrol (
    input porb,
    input resb,
    input clk,
    input ideb,
    input hde1,
    input addrselb,
    input time1,
    input lcycsel,
    input ivsync,
    input sreq,
    input sndon,
    output frame,
    output vidb,
    output viden,
    output vidclkb,
    output sndclk,
    output snden,
    output dcyc_n,
    output sload_n
);

reg pk005,pk010,pk016,pk024,pk031;
wire c1 = ~(lcycsel & time1);
assign frame = ~pk005;
assign vidb = pk010;
assign viden = ~pk010;
assign vidclkb = ~(~addrselb | pk010);
assign sndclk = ~(addrselb & snden);
assign snden = ~pk016 & pk024;

/* verilator lint_off UNOPTFLAT */

wire pl025 = !porb ? 1 : (clk ? !resb | (time1 & addrselb & viden) : pl025);
assign dcyc_n = ~pl025;

wire pl031 = !porb ? 1 : (clk ? ~(addrselb & time1 & snden) : pl031);
assign sload_n = pl031;

always @(posedge c1, negedge porb) begin
	if (!porb) { pk005, pk010, pk016 } <= { 1'b0, 1'b1, 1'b0 };
	else begin
	    pk005 <= ivsync;
	    pk010 <= ideb;
	    pk016 <= hde1;
	    pk024 <= sreq;
	    pk031 <= sndon;
	end
end


endmodule;
