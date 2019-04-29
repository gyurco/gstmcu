
module gstmcu (
    input clk,
    input resb,
    input porb,
    input mde0,
    input mde1,
    input interlace,
    input ntsc,
    output hsync_n,
    output vsync_n,
    output de,
    output blank_n,
    output [6:0] hsc
);

wire mhz4,mhz8, time0,time1,time2,addrsel,m2clock,clk4,cycsel,latch;

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
    .latch(latch)
);

wire iihsync, iivsync;
wire ihsync = ~iihsync;
wire ivsync = ~iivsync;
wire vertclk;
assign hsync_n = iihsync;
assign vsync_n = iivsync;

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

wire       cpal, cntsc, hde1;

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
    .noscroll(1),
    .ihsync(ihsync),
    .hde1(hde1),
    .vde(vde),
    .vblank(vblank),
    .de(de),
    .blank_n(blank_n)
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

endmodule;

