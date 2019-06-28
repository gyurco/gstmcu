
module gstmcu (
    input clk32,
    input resb,
    input porb,
    input interlace,
    input  FC0,
    input  FC1,
    input  FC2,
    input  AS_N,
    input  RW,
    input  UDS_N,
    input  LDS_N,
    input  VMA_N,
    input  MFPINT_N,
    input  [23:1] A,
    input  [15:0] DIN,
    output [15:0] DOUT,
    output MHZ8,
    output MHZ8_EN1,
    output MHZ8_EN2,
    output MHZ4,
    output MHZ4_EN,
    output BERR_N,
    output IPL0_N,
    output IPL1_N,
    output IPL2_N,
    output DTACK_N,
    output IACK_N,
    output ROM0_N,
    output ROM1_N,
    output ROM2_N,
    output ROM3_N,
    output ROM4_N,
    output ROM5_N,
    output ROM6_N,
    output ROMP_N,
    output RAM_N,
    output VPA_N,
    output MFPCS_N,
    output SNDIR,
    output SNDCS,
    output N6850,
    output FCS_N,
    output RTCCS_N,
    output RTCRD_N,
    output RTCWR_N,
    output LATCH,
    output HSYNC_N,
    output VSYNC_N,
    output DE,
    output BLANK_N,
    output RDAT_N,
    output WE_N,
    output WDAT_N,
    output CMPCS_N,
    output DCYC_N,
    input  SREQ,
    output SLOAD_N,
    output SINT,
    output [23:1] ADDR,
    output [6:0] hsc
);

///////// ADDRESS BUS MUX ////////

always @(*) begin
    casez ({ addrselb, ixdmab, snden, refb })
        4'b00??: ADDR = 0; // DMA_ADDR
        4'b01??: ADDR = A; // CPU_ADDR
        4'b1??0: ADDR = 0; // REFRESH_ADDR
        4'b1?11: ADDR = { 2'b0, snd }; // SND DMA ADDR
        4'b1?01: ADDR = { 2'b0, vid }; // VIDEO ADDR
    endcase
end

/////// BUS INTERFACE //////////

wire         ias = ~AS_N;
wire         irwz = RW;
wire         irwb = ~RW;
wire         iuds = ~UDS_N;
wire         ilds = ~LDS_N;
wire         ivma = ~VMA_N;
wire         iiack = ias & FC0 & FC1 & FC2;
wire         ifc2z = FC2;
wire         fcx = FC0 ^ FC1;
wire [15:0]  id = DIN;

//////// ADDRESS DECODE /////////

wire vclrb = ~(iiack & A[3:1] == 3'b100);
wire hclrb = ~(iiack & A[3:1] == 3'b010);

wire device = ixdmab & ifc2z & fcx;
wire idev = device & A[23:16] == 8'hFF;

assign IACK_N = ~(iiack & A[3:1] == 3'b110);
assign VPA_N = ~((idev & ias & A[15:9] == { 4'hF, 3'b110 }) | ~vclrb | ~hclrb); // FFFCxx - FFFDxx or VINT/HINT ack

assign MFPCS_N = ~(idev & ias & A[15:6] == { 8'hFA, 2'b00 });  // FFFA0x-FFFA3x
wire   isndcsb = ~(idev & ias & A[15:8] == 8'h88);             // FF88xx
assign SNDIR = ~isndcsb & ~irwz;
assign SNDCS = ~isndcsb & ~A[1];
assign N6850 = ~(idev & ivma & A[15:3] == { 12'hFC0, 1'b0 });  // FFFC00-FFFC07
assign FCS_N = ~(idev & ias & ilds & iuds & A[15:2] == { 12'h860, 2'b01 }); // FF8604-FF8607
assign RTCCS_N = ~(idev & ias & A[15:5] == { 8'hFC, 3'b001 }); // FFFC2x-FFFC3x
assign RTCRD_N = ~(irwz & ivma & ilds);
assign RTCWR_N = ~(irwb & ivma & ilds);

wire overlap = |A[15:3];
wire rvec = irwz & ~overlap & ifc2z & fcx & ixdmab;
wire rom = irwz & fcx & ixdmab;

wire irom0 = rom & ias & A[23:18] == { 4'hE, 2'b10 }; // E8xxxx-EBxxxx
wire irom1 = rom & ias & A[23:18] == { 4'hE, 2'b01 }; // E4xxxx-E7xxxx
wire irom2 = (ias & rvec & A[23:16] == 8'h00) | (rom & ias & A[23:18] == { 4'hE, 2'b00 }); // 0-7, E0xxxx-E3xxxx
wire irom3 = (rom & ias & ~gamecart & A[23:16] == 8'hFB) | (rom & ias & gamecart & A[23:18] == { 4'hD, 2'b11 });
wire irom4 = (rom & ias & ~gamecart & A[23:16] == 8'hFA) | (rom & ias & gamecart & A[23:18] == { 4'hD, 2'b10 });
wire irom5 = rom & ias & A[23:18] == { 4'hD, 2'b01 };
wire irom6 = rom & ias & A[23:18] == { 4'hD, 2'b00 };
wire romp  = rom & ias & A[23:13] == { 8'hFE, 3'b000 };
wire romxb = ~(irom0 | irom1 | irom2 | irom3 | irom4 | irom6 | irom6 | romp);

assign ROM0_N = ~irom0;
assign ROM1_N = ~irom1;
assign ROM2_N = ~irom2;
assign ROM3_N = ~irom3;
assign ROM4_N = ~irom4;
assign ROM5_N = ~irom5;
assign ROM6_N = ~irom6;
assign ROMP_N = ~romp;

wire system = ifc2z | A[15:11] == 0;
wire irama = |A[21:16];
wire iramb = fcx & ~A[23] & ~A[22];
wire iramaa = irama & iramb; // 01xxxxx - 3fxxxxx
wire iramc = overlap | fcx | system;
wire iramab = A[23:16] == 0 & iramc;
wire iram = iramaa | iramab | ~ixdmab | ~resb;
assign RAM_N = ~iram;

wire dmadir  = idev & ias & iuds & A[15:1] == { 12'h860, 3'b011 };
wire dmadirb = ~dmadir;
wire mdesel  = idev & ias & A[15:1] == { 12'h826, 3'b000 }; // FF8260-1
wire syncsel = idev & ias & A[15:1] == { 12'h820, 3'b101 }; // FF820A-B
wire scrlsel = idev & ias & ilds & A[15:1] == { 12'h826, 3'b010 }; // FF8264-5
wire cartsel = idev & ias & A[15:1] == { 12'h900, 3'b000 };
wire butsel  = idev & ias & A[15:1] == { 12'h920, 3'b000 };
wire joysel  = idev & ias & A[15:1] == { 12'h920, 3'b001 };
wire padsel  = idev & ias & A[15:3] == { 12'h921, 1'b1 };
wire pensel  = idev & ias & A[15:2] == { 12'h922, 2'b00 };

////////// REGISTER SELECT DECODE //////////

wire regs    = idev & ias & A[15:12] == 4'h8 & ~A[8] & ~A[11];
wire dma     =  A[9] &  A[10];  // FF86xx
wire video   =  A[9] & ~A[10];  // FF82xx
wire conf    = ~A[9] & ~A[10];  // FF80xx
wire vmapb   = ~(idev & A[15:6] == { 8'h82, 2'b01 }); // FF824x-FF827x - video regs also in shifter

wire regrd   = irwz & A[7:4] == 4'h0 & ilds;
wire regwr   = irwb & A[7:4] == 4'h0 & ilds;

wire rconfigb = ~(regs & conf & regrd & A[3:1] == 3'd0);  // FF8000-1
wire wconfigb = ~(regs & conf & regwr & A[3:1] == 3'd0);

wire rvidbhb  = ~(regs & video & regrd & A[3:1] == 3'd0); // FF8200-1
wire wvidbhb  = ~(regs & video & regwr & A[3:1] == 3'd0);
wire rvidbmb  = ~(regs & video & regrd & A[3:1] == 3'd1); // FF8202-3
wire wvidbmb  = ~(regs & video & regwr & A[3:1] == 3'd1);
wire rlochb   = ~(regs & video & regrd & A[3:1] == 3'd2); // FF8204-5
wire wlochb   = ~(regs & video & regwr & A[3:1] == 3'd2);
wire rlocmb   = ~(regs & video & regrd & A[3:1] == 3'd3); // FF8206-7
wire wlocmb   = ~(regs & video & regwr & A[3:1] == 3'd3);
wire rloclb   = ~(regs & video & regrd & A[3:1] == 3'd4); // FF8208-9
wire wloclb   = ~(regs & video & regwr & A[3:1] == 3'd4);
wire rvidblb  = ~(regs & video & regrd & A[3:1] == 3'd6); // FF820C-D
wire wvidblb  = ~(regs & video & regwr & A[3:1] == 3'd6);
wire rhoffb   = ~(regs & video & regrd & A[3:1] == 3'd7); // FF820E-F
wire whoffb   = ~(regs & video & regwr & A[3:1] == 3'd7);

wire rdmahb   = ~(regs & dma & regrd & A[3:1] == 3'd4);   // FF8608-9
wire wdmah    = ~(regs & dma & regwr & A[3:1] == 3'd4);
wire rdmamb   = ~(regs & dma & regrd & A[3:1] == 3'd5);   // FF860A-B
wire wdmam    = ~(regs & dma & regwr & A[3:1] == 3'd5);
wire rdmalb   = ~(regs & dma & regrd & A[3:1] == 3'd6);   // FF860C-D
wire wdmal    = ~(regs & dma & regwr & A[3:1] == 3'd6);

wire regxackb = ~((regs & (A[9] | ~A[10]) & (~dma | A[3]) & A[7:4] == 4'h0) | ~srgackb);

// sound regs

wire srgackb = ~(idev & ias & A[15:5] == { 8'h89, 3'b000 }); // FF890x-FF891x
wire smapb   = ~(idev & A[15:5] == { 8'h89, 3'b001 });       // FF892x-FF893x - sound regs in shifter

wire rscntlb = ~(idev & ias & ilds & irwz & A[15:1] == { 12'h890, 3'd0 });
wire wscntlb = ~(idev & ias & ilds & irwb & A[15:1] == { 12'h890, 3'd0 });
wire rsfbhb  = ~(idev & ias & ilds & irwz & A[15:1] == { 12'h890, 3'd1 });
wire wsfbhb  = ~(idev & ias & ilds & irwb & A[15:1] == { 12'h890, 3'd1 });
wire rsfbmb  = ~(idev & ias & ilds & irwz & A[15:1] == { 12'h890, 3'd2 });
wire wsfbmb  = ~(idev & ias & ilds & irwb & A[15:1] == { 12'h890, 3'd2 });
wire rsfblb  = ~(idev & ias & ilds & irwz & A[15:1] == { 12'h890, 3'd3 });
wire wsfblb  = ~(idev & ias & ilds & irwb & A[15:1] == { 12'h890, 3'd3 });
wire rsfchb  = ~(idev & ias & ilds & irwz & A[15:1] == { 12'h890, 3'd4 });
wire rsfcmb  = ~(idev & ias & ilds & irwz & A[15:1] == { 12'h890, 3'd5 });
wire rsfclb  = ~(idev & ias & ilds & irwz & A[15:1] == { 12'h890, 3'd6 });
wire rsfthb  = ~(idev & ias & ilds & irwz & A[15:1] == { 12'h890, 3'd7 });
wire wsfthb  = ~(idev & ias & ilds & irwb & A[15:1] == { 12'h890, 3'd7 });
wire rsftmb  = ~(idev & ias & ilds & irwz & A[15:1] == { 12'h891, 3'd0 });
wire wsftmb  = ~(idev & ias & ilds & irwb & A[15:1] == { 12'h891, 3'd0 });
wire rsftlb  = ~(idev & ias & ilds & irwz & A[15:1] == { 12'h891, 3'd1 });
wire wsftlb  = ~(idev & ias & ilds & irwb & A[15:1] == { 12'h891, 3'd1 });

/////////// DATA BUS INTERFACE /////////////

assign DOUT[15:8] = { 6'b111111, idout_h };
assign DOUT[ 7:0] = vid_o & snd_o;

/////// SYNC and INTERRUPT INTERFACE ///////

assign HSYNC_N = iihsync;
assign VSYNC_N = iivsync;
assign IPL0_N = 1'b1;
assign IPL1_N = MFPINT_N & ~hint;
assign IPL2_N = MFPINT_N & vintb;

wire hintb, hint = ~hintb;
register hintb_r(clk32, ~(resb & porb & vclrb), 0, ~iihsync, 0, hintb);
wire vintb;
register vintb_r(clk32, ~(resb & porb & hclrb), 0, ~iivsync, 0, vintb);

//////// BUS ERROR GENERATION //////////////

reg [6:0] berr_cnt;
assign BERR_N = ~berr_cnt[6];

always @(posedge clk32, negedge porb) begin
    if (!porb) berr_cnt <= 0;
    else if (~ias) berr_cnt <= 0;
    else if (MHZ8_EN1) berr_cnt <= berr_cnt + 1'd1;
end

//////// DMA/VIDEO REGISTERS ///////////////

wire gamecart;
register gamecart_r(clk32, 0, ~(resb & porb), irwb & cartsel & iuds, id[8], gamecart);
wire noscroll;
latch noscroll_l(clk32, ~(resb & porb), 0, scrlsel, ~|id[3:0], noscroll);
wire mde1;
register mde1_r(clk32, 0, ~(resb & porb), ~(irwb & mdesel & iuds), id[9], mde1);
wire mde0;
register mde0_r(clk32, 0, ~(resb & porb), ~(irwb & mdesel & iuds), id[8], mde0);
wire pal;
register pal_r(clk32, 0, ~(resb & porb), ~(irwb & syncsel & iuds), id[9], pal);
wire ntsc = ~pal;
wire drw;
register drw_r(clk32, ~(resb & porb), 0, dmadirb, id[8], drw);

wire [9:8] idout_h;
always @(*) begin
	idout_h = 2'b11;
	if (cartsel & irwz & iuds) idout_h = { 1'b0, gamecart };
	if (syncsel & irwz & iuds) idout_h = { pal, 1'b0 };
//    udenb = ~(irwz & iuds & (cartsel | syncsel));
end

////////////// VIDEO REGISTERS ////////////////

wire [7:0] hoff;
latch #(.WIDTH(8)) hoff_l(clk32, 0, ~(resb & porb), ~whoffb, id[7:0], hoff);
wire [21:1] vld;
latch #(.WIDTH(7)) vld_ll(clk32, 0, ~(resb & porb), ~wvidblb, id[7:1], vld[ 7: 1]);
latch #(.WIDTH(8)) vld_ml(clk32, 0, ~(resb & porb), ~wvidbmb, id[7:0], vld[15: 8]);
latch #(.WIDTH(6)) vld_hl(clk32, 0, ~(resb & porb), ~wvidbhb, id[5:0], vld[21:16]);
wire [3:0] conf_reg;
latch #(.WIDTH(4)) conf_l(clk32, 0, ~(resb & porb), ~wconfigb, id[3:0], conf_reg[3:0]);

wire [7:0] vid_o;

always @(*) begin
	vid_o = 8'hff;
	if (~rhoffb)   vid_o = hoff;
	if (~rvidblb)  vid_o = { vld[7:1], 1'b0 };
	if (~rvidbmb)  vid_o = vld[15:8];
	if (~rvidbhb)  vid_o = { 2'b00, vld[21:16] };
	if (~rconfigb) vid_o = { 4'b0000, conf_reg };
end

////////////// SOUND REGISTERS ////////////////

wire [21:1] sfb, sft, sft_l;
wire  [3:1] snd_ctrl;
wire sndon;
wire sfrep = snd_ctrl[1];

latch #(.WIDTH(7)) sfb_ll(clk32, 0, (~resb & porb), ~wsfblb, id[7:1], sfb[ 7: 1]);
latch #(.WIDTH(8)) sfb_ml(clk32, 0, (~resb & porb), ~wsfbmb, id[7:0], sfb[15: 8]);
latch #(.WIDTH(6)) sfb_hl(clk32, 0, (~resb & porb), ~wsfbhb, id[5:0], sfb[21:16]);
latch #(.WIDTH(3)) sctl_l(clk32, 0, (~resb & porb), ~wscntlb, id[3:1], snd_ctrl);
latch #(.WIDTH(1)) sndon_l(clk32, 0, (~resb & porb) | stoff, ~wscntlb, id[0], sndon);

// latch sft register writes
latch #(.WIDTH(7)) sft_lll(clk32, 0, (~resb & porb), ~wsftlb, id[7:1], sft_l[ 7: 1]);
latch #(.WIDTH(8)) sft_mll(clk32, 0, (~resb & porb), ~wsftmb, id[7:0], sft_l[15: 8]);
latch #(.WIDTH(6)) sft_hll(clk32, 0, (~resb & porb), ~wsfthb, id[5:0], sft_l[21:16]);
// load sft when no sound
latch #(.WIDTH(21)) sft_ll(clk32, 0, ~porb, ~sframe, sft_l, sft);

wire [7:0] snd_o;

always @(*) begin
	snd_o = 8'hff;
	if (~rsfblb)  snd_o = { sfb[7:1], 1'b0 };
	if (~rsfbmb)  snd_o = sfb[15:8];
	if (~rsfbhb)  snd_o = { 2'b00, sfb[21:16] };
	if (~rscntlb) snd_o = { 4'b0000, snd_ctrl, sndon };
	if (~rsftlb)  snd_o = { sft[7:1], 1'b0 };
	if (~rsftmb)  snd_o = sft[15:8];
	if (~rsfthb)  snd_o = { 2'b00, sft[21:16] };
end

//////// BUS TIMING GENERATOR /////////////////

reg sndack;  // snd cs delayed by 2 8MHz cycles
always @(posedge clk32, posedge isndcsb) begin
	reg sndack1;
	if (isndcsb) { sndack, sndack1 } <= 0;
	else if (MHZ8_EN1) begin
		sndack1 <= ~isndcsb;
		sndack  <= sndack1;
	end
end

assign DTACK_N = ~(sndack | ~ramcycb | ~cmpcycb | ~romxb | ~regxackb | joysel | cartsel | syncsel);

////////////////////////////////////////////

wire ixdmab = 1;
wire clk,time0,time1,time2,time4,addrsel,m2clock,clk4,cycsel,cycsel_en;
wire lcycsel = cycsel;
wire addrselb = ~addrsel;

clockgen clockgen (
    .clk32(clk32),
    .clk(clk),
    .resb(resb),
    .porb(porb),
    .mhz8(MHZ8),
    .mhz8_en1(MHZ8_EN1),
    .mhz8_en2(MHZ8_EN2),
    .mhz4(MHZ4),
    .mhz4_en(MHZ4_EN),
    .clk4(clk4),
    .time0(time0),
    .time1(time1),
    .time2(time2),
    .time4(time4),
    .addrsel(addrsel),
    .m2clock(m2clock),
    .cycsel(cycsel),
    .cycsel_en(cycsel_en),
    .latch(LATCH)
);

wire stoff, sframe;
wire refb,vidclkb,frame,vidb,viden,sndclk,snden,vos;
wire cmpcycb, ramcycb;

mcucontrol mcucontrol (
    .clk32(clk32),
    .porb(porb),
    .resb(resb),
    .clk(clk),
    .ias(ias),
    .idev(idev),
    .iram(iram),
    .iuds(iuds),
    .ilds(ilds),
    .irwz(irwz),
    .ixdmab(ixdmab),
    .vmapb(vmapb),
    .smapb(smapb),
    .ivsync(ivsync),
    .ideb(ideb),
    .hde1(hde1),
    .addrselb(addrselb),
    .sreq(SREQ),
    .sndon(sndon),
    .lcycsel(lcycsel),
    .cycsel_en(cycsel_en),
    .time0(time0),
    .time1(time1),
    .frame(frame),
    .refb(refb),
    .vidb(vidb),
    .viden(viden),
    .vidclkb(vidclkb),
    .vos(vos),
    .snd(snd),
    .sft(sft),
    .stoff(stoff),
    .sfrep(sfrep),
    .sframe(sframe),
    .sndclk(sndclk),
    .snden(snden),
    .cmpcycb(cmpcycb),
    .ramcycb(ramcycb),
    .rdat_n(RDAT_N),
    .we_n(WE_N),
    .wdat_n(WDAT_N),
    .cmpcs_n(CMPCS_N),
    .dcyc_n(DCYC_N),
    .sload_n(SLOAD_N),
    .sint(SINT)
);

wire iihsync, iivsync;
wire ihsync = ~iihsync;
wire ivsync = ~iivsync;
wire vertclk;

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

//////// VIDEO ADDRESS COUNTER ////

//async

`ifdef VERILATOR

wire [21:1] vid_a;

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
    .vid(vid_a)
);

`endif

//sync to clk32
reg  [21:1] vid_reg;
wire [21:1] vid;
reg vid_r_d, vidclk_d, vidb_d;

reg pf071_reg;
wire pf071;

wire vid_r = pf071 & vidb;
wire vid_xll = !(!wloclb | !frame);
wire vid_xlm = !(!wlocmb | !frame);
wire vid_xlh = !(!wlochb | !frame);
wire vid_rr = ~(!porb | !frame | !wlochb | !wlocmb | !wloclb);

always @(*) begin
	vid = vid_reg;
	if (~vid_r_d & vid_r) vid = vid + {13 'd0, hoff };
	else if (~vidclk_d & ~vidclkb) vid = vid_reg + 1'd1;
	if (!vid_xll) vid[ 7: 1] = vld[ 7: 1];
	if (!vid_xlm) vid[15: 8] = vld[15: 8];
	if (!vid_xlh) vid[21:16] = vld[21:16];

	pf071 = pf071_reg;
	if (!vid_rr) pf071 = 0;
	else if (~vidb_d & vidb) pf071 = 1;
end

always @(posedge clk32) begin
	vid_r_d <= vid_r;
	vidclk_d <= ~vidclkb;
	vid_reg <= vid;
	vidb_d <= vidb;
	pf071_reg <= pf071;
end

//////// DMA SOUND COUNTER ////////

// async

`ifdef VERILATOR

wire [21:1] snd_a;

sndcnt sndcnt (
    .porb(porb),
    .lresb(resb),
    .sndclk(sndclk),
    .sframe(sframe),
    .sfb(sfb),
    .snd(snd_a)
);

`endif

//sync to clk32
wire sndclk_en = addrselb & time4 & snden;
reg [21:1] snd;

always @(posedge clk32) begin
    if (!(porb & resb)) snd <= 0;
    else if (!sframe) snd <= sfb; // load is async originally, here delayed by half mhz16. Doh.
    else if (sndclk_en) snd <= snd + 1'd1;
end

endmodule;
