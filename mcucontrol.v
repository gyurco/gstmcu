/* verilator lint_off UNOPTFLAT */

module mcucontrol (
    input clk32,
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
    input time0,
    input time1,
    input lcycsel,
    input cycsel_en,
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
    output rdat_n,
    output we_n,
    output wdat_n,
    output cmpcs_n,
    output dcyc_n,
    output sload_n,
    output reg sint
);

wire c1 = ~(lcycsel & time1);

//////////// VIDEO CONTROL //////////
reg pk005,pk010,pk016;
assign frame = ~pk005;
assign vidb = pk010;
assign viden = ~pk010;
assign vidclkb = ~(~addrselb | pk010);
assign refb = pk016 | pk024;
assign vos = ~(pk010 & ~snden);


always @(posedge c1, negedge porb) begin
	if (!porb) { pk005, pk010, pk016 } <= { 1'b0, 1'b1, 1'b0 };
	else begin
	    pk005 <= ivsync;
	    pk010 <= ideb;
	    pk016 <= hde1;
	end
end

///////// SOUND DMA CONTROL //////
reg pk024,pk031;

assign sndclk = ~(addrselb & snden);
assign snden = ~pk016 & pk024;

always @(posedge c1) begin
    pk031 <= sndon;
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

wire sload_n = !porb ? 1 : (clk ? ~(addrselb & time1 & snden) : sload_n); // pl031

///////////////////// RAM/SHIFTER ////////////////

wire cmap = (~irwz | iuds | ilds) & (~vmapb | ~smapb) & idev & ias;
wire ramsel = (~irwz | ilds | iuds) & ixdmab & ias & iram;

// async implementation from the original schematic
reg ramcyc_a,cmpcyc_a;

always @(posedge lcycsel, negedge cmap) begin
    if (!cmap) cmpcyc_a <= 0;
    else cmpcyc_a <= cmap;
end;

always @(posedge lcycsel, negedge ramsel) begin
    if (!ramsel) ramcyc_a <= 0;
    else ramcyc_a <= ramsel;
end;

wire dcyc_a = !porb ? 1 : (clk ? !resb | (time1 & addrselb & viden) : dcyc_a); // pl025

// sync to clk32 implementation
reg ramcyc,cmpcyc;

always @(posedge clk32, negedge cmap) begin
    if (!cmap) cmpcyc <= 0;
    else if(cycsel_en) cmpcyc <= cmap;
end;

always @(posedge clk32, negedge ramsel) begin
    if (!ramsel) ramcyc <= 0;
    else if (cycsel_en) ramcyc <= ramsel;
end;

wire dcyc;
latch dcyc_l(clk32, !porb, 0, clk, !resb | (time1 & addrselb & viden), dcyc); // pl025

/////

assign dcyc_n = ~dcyc;
assign cmpcycb = ~cmpcyc;
assign ramcycb = ~ramcyc;
assign we_n = ~(ramcyc & cmpcycb & ~irwz & ~time0 & ~addrselb);
assign rdat_n = ~((cmpcyc & ramcycb & irwz) | (ramcyc & cmpcycb & irwz));
assign wdat_n = ~(~we_n | (cmpcyc & ramcycb & ~irwz & ~time1 & ~addrselb));
assign cmpcs_n =~((cmpcyc & ramcycb & ~irwz & ~time1 & ~addrselb) | (cmpcyc & ramcycb & irwz & lcycsel & ~time1) | ~resb);

endmodule;
