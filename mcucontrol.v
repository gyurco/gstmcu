
module mcucontrol (
    input porb,
    input resb,
    input clk,
    input ias,
    input idev,
    input iram,
    input iuds,
    input ilds,
    input irwz,
    input ixdmab,
    input vmapb,
    input smapb,
    input ideb,
    input hde1,
    input addrselb,
    input time1,
    input lcycsel,
    input ivsync,
    input sreq,
    input sndon,
    input sfrep,
    input [21:1] snd,
    input [21:1] sft,
    output cmpcycb,
    output ramcycb,
    output refb,
    output frame,
    output vidb,
    output viden,
    output vidclkb,
    output vos,
    output sndclk,
    output snden, // sadsel
    output reg sframe,
    output stoff,
    output dcyc_n,
    output sload_n,
    output reg sint
);

reg pk005,pk010,pk016,pk024,pk031,pl001,pl002;
wire c1 = ~(lcycsel & time1);
assign frame = ~pk005;
assign vidb = pk010;
assign viden = ~pk010;
assign vidclkb = ~(~addrselb | pk010);
assign sndclk = ~(addrselb & snden);
assign snden = ~pk016 & pk024;
assign refb = pk016 | pk024;
assign vos = ~(pk010 & ~snden);
assign cmpcycb = ~pl002;
assign ramcycb = ~pl001;

wire cmap = (~irwz | iuds | ilds) & (~vmapb | ~smapb) & idev & ias;
wire ramsel = (~irwz | ilds | iuds) & ixdmab & ias & iram;

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
	    pk031 <= sndon;
	end
end

wire pk061 = (snd == sft) & ~c1;
wire sintsb = sframe;
assign stoff = pk061 & ~sfrep;

always @(negedge clk, negedge pk031) begin
    if (!pk031) sframe <= 0;
    else sframe <= ~(pk061 & sfrep);
end;

always @(negedge c1, negedge sintsb) begin
    if (!sintsb) sint <= 1;
    else sint <= 0;
end;

always @(posedge c1, negedge pk031) begin
    if (!pk031) pk024 <= 0;
    else pk024 <= sreq;
end;

always @(posedge lcycsel, negedge cmap) begin
    if (!cmap) pl002 <= 0;
    else pl002 <= cmap;
end;

always @(posedge lcycsel, negedge ramsel) begin
    if (!ramsel) pl001 <= 0;
    else pl001 <= ramsel;
end;

endmodule;
