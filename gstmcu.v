
module gstmcu (
    input clk,
    input resb,
    input porb,
    input mde0,
    input mde1,
    input interlace,
    input ntsc,
    output HSYNC_N,
    output VSYNC_N,
    output DE,
    output BLANK_N,
    output DCYC_N,
    output SLOAD_N,
    output [6:0] hsc
);

wire mhz4,mhz8, time0,time1,time2,addrsel,m2clock,clk4,cycsel,lcycselb,latch;
wire lcycsel = ~cycsel;
wire addrselb = ~addrsel;

clockgen clockgen (
    .clk(clk),
    .resb(resb),
    .porb(porb),
    .mhz8(mhz8),
    .mhz4(mhz4),
    .clk4(clk4),
    .time0(time0),
    .time1(time1),
    .time2(time2),
    .addrsel(addrsel),
    .m2clock(m2clock),
    .cycsel(cycsel),
    .lcycselb(lcycselb),
    .latch(latch)
);

wire sndon = 0;
wire sreq = 0;
wire vidclkb,frame,vidb,viden,sndclk,snden;

mcucontrol mcucontrol (
    .porb(porb),
    .resb(resb),
    .clk(clk),
    .ivsync(ivsync),
    .ideb(ideb),
    .hde1(hde1),
    .addrselb(addrselb),
    .sreq(sreq),
    .sndon(sndon),
    .lcycsel(lcycsel),
    .time1(time1),
    .frame(frame),
    .vidb(vidb),
    .viden(viden),
    .vidclkb(vidclkb),
    .sndclk(sndclk),
    .snden(snden),
    .dcyc_n(DCYC_N),
    .sload_n(SLOAD_N)
);

wire iihsync, iivsync;
wire ihsync = ~iihsync;
wire ivsync = ~iivsync;
wire vertclk;
assign HSYNC_N = iihsync;
assign VSYNC_N = iivsync;

hsyncgen hsyncgen (
    .m2clock(m2clock),
    .resb(resb),
    .porb(porb),
    .mde1(mde1),
    .mde1b(~mde1),
    .interlace(interlace),
    .ntsc(ntsc),
    .iihsync(iihsync),
    .vertclk(vertclk),
    .hsc(hsc)
);

wire cpal, cntsc, hde1;
wire ideb = ~DE;
wire noscroll = 0;

hdegen hdegen (
    .m2clock(m2clock),
    .porb(porb),
    .mde0(mde0),
    .mde0b(~mde0),
    .mde1(mde1),
    .mde1b(~mde1),
    .ntsc(ntsc),
    .cpal(cpal),
    .cntsc(cntsc),
    .noscroll(noscroll),
    .ihsync(ihsync),
    .hde1(hde1),
    .vde(vde),
    .vblank(vblank),
    .de(DE),
    .blank_n(BLANK_N)
);

vsyncgen vsyncgen (
    .vertclk(vertclk),
    .resb(resb),
    .porb(porb),
    .mde1(mde1),
    .mde1b(~mde1),
    .interlace(interlace),
    .ntsc(ntsc),
    .iivsync(iivsync)
);

wire vde, vblank;

vdegen vdegen (
    .porb(porb),
    .mde1(mde1),
    .cpal(cpal),
    .cntsc(cntsc),
    .ihsync(ihsync),
    .ivsync(ivsync),
    .vde(vde),
    .vblank(vblank)
);

wire [21:0] vid, vld = 0;//{1'b0, 21'haaaaa};
wire [7:0] hoff = 8'hf0;
wire wloclb =1 ,wlocmb = 1, wlochb = 1;

vidcnt vidcnt (
    .porb(porb),
    .vidb(vidb),
    .vidclkb(vidclkb),
    .hoff(hoff),
    .vld(vld),
    .frame(frame),
    .wloclb(wloclb),
    .wlocmb(wlocmb),
    .wlochb(wlochb),
    .vid(vid)
);

endmodule;

