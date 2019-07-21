// ====================================================================
//
//  Atari STE GSTMCU
//  Based on ST4081S.PDF recovered by Christian Zietz
//
//  Copyright (C) 2019 Gyorgy Szombathelyi <gyurco@freemail.hu>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

// TODO:
// - pen, joystick, paddle registers
// - less useful: refresh address generation

module gstmcu (
    input clk32,
    input resb,
    input porb,
    input  FC0,
    input  FC1,
    input  FC2,
    input  AS_N,
    input  RW,
    input  UDS_N,
    input  LDS_N,
    input  VMA_N,
    input  MFPINT_N,
    input  [23:1] A,    // from CPU
    output reg [23:1] ADDR, // to RAM
    input  [15:0] DIN,
    output [15:0] DOUT,
    output CLK_O, // 16 MHz clock, here's an output
    output MHZ8,
    output MHZ8_EN1,
    output MHZ8_EN2,
    output MHZ4,
    output MHZ4_EN,
    input  RDY_N_I,
    output RDY_N_O,
    input  BG_N,
    input  BR_N_I,
    output BR_N_O,
    input  BGACK_N_I,
    output BGACK_N_O,
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
    output RAS0_N,
    output RAS1_N,
    output CAS0L_N,
    output CAS0H_N,
    output CAS1L_N,
    output CAS1H_N,
    output RAM_LDS, // RAM byte selects
    output RAM_UDS, // CAS signals come a bit late for a fast SDRAM controller
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
    output reg DE,
    output reg BLANK_N,
    output RDAT_N,
    output WE_N,
    output WDAT_N,
    output CMPCS_N,
    output DCYC_N,
    input  SREQ,
    output SLOAD_N,
    output SINT,

    input  viking_at_c0,   // RAM decode for the Viking card at 0xc00000
    input  viking_at_e8,   // RAM decode for the Viking card at 0xe80000
    output [1:0] bus_cycle // compatibility signal for existing code
);

///////// ADDRESS BUS MUX ////////
always @(*) begin
    casez ({ addrselb, ixdmab, snden, refb })
        4'b00??: ADDR = dmaa; // DMA_ADDR
        4'b01??: ADDR = A; // CPU_ADDR
        4'b1??0: ADDR = 0; // REFRESH_ADDR
        4'b1?11: ADDR = { 2'b0, snd }; // SND DMA ADDR
        4'b1?01: ADDR = { 2'b0, vid }; // VIDEO ADDR
    endcase
end

/////// BUS INTERFACE //////////

wire         ias  = ixdma ? aso : ~AS_N;
wire         irwz = ixdma ? drw : RW;
wire         irwb = ~irwz;
wire         iuds = ixdma ? dso : ~UDS_N;
wire         ilds = ixdma ? dso : ~LDS_N;
wire         ivma = ~VMA_N;
wire         ifc0  = ixdma ? 1'b1 : FC0;
wire         ifc1  = ixdma ? 1'b0 : FC1;
wire         ifc2  = ixdma ? 1'b1 : FC2;
wire         iiack = ias & ifc0 & ifc1 & ifc2;
wire         ifc2z = ifc2;
wire         fcx = ifc0 ^ ifc1;
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
assign SNDIR   = ~isndcsb & ~irwz;
assign SNDCS   = ~isndcsb & ~A[1];
assign N6850   = ~(idev & ivma & A[15:3] == { 12'hFC0, 1'b0 });  // FFFC00-FFFC07
wire   pifcsb  = ~(idev & ias & ilds & iuds & A[15:2] == { 12'h860, 2'b01 }); // FF8604-FF8607
wire   ifcsb   = pifcsb & resb;
assign FCS_N   = ifcsb;
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

// Not original signals (Viking RAM decodes)
wire viking_c0 = viking_at_c0 && A[23:18] == 6'b110000; // 256k at 0xc00000
wire viking_e8 = viking_at_e8 && A[23:19] == 5'b11101;  // 512k at $e80000 for STEroids

wire system = ifc2z | A[15:11] != 0;
wire irama = |A[21:16];
wire iramb = fcx & ~A[23] & ~A[22];
wire iramaa = irama & iramb; // 01xxxxx - 3fxxxxx
wire iramc = overlap & fcx & system;
wire iramab = A[23:16] == 0 & iramc;
wire iram = iramaa | iramab | ~ixdmab | viking_c0 | viking_e8 | ~resb;
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
assign DOUT[ 7:0] = vid_o & snd_o & dma_o;

/////// SYNC and INTERRUPT INTERFACE ///////

assign HSYNC_N = iihsync;
assign VSYNC_N = iivsync;
assign IPL0_N = 1'b1;
assign IPL1_N = MFPINT_N & (hintb | ~vintb);
assign IPL2_N = MFPINT_N & vintb;

wire hintb;
register hintb_r(clk32, ~(resb & porb & hclrb), 0, ~iihsync, 0, hintb);
wire vintb;
register vintb_r(clk32, ~(resb & porb & vclrb), 0, ~iivsync, 0, vintb);

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
mlatch noscroll_l(clk32, ~(resb & porb), 0, scrlsel, ~|id[3:0], noscroll);
wire mde1;
register mde1_r(clk32, 0, ~(resb & porb), ~(irwb & mdesel & iuds), id[9], mde1);
wire mde0;
register mde0_r(clk32, 0, ~(resb & porb), ~(irwb & mdesel & iuds), id[8], mde0);
wire pal;
register pal_r(clk32, 0, ~(resb & porb), ~(irwb & syncsel & iuds), id[9], pal);
wire ntsc = ~pal;
wire drw;
register drw_r(clk32, ~(resb & porb), 0, dmadirb, id[8], drw);

wire penr = iuds & ilds & irwz & pensel;
wire padr = ilds & irwz & padsel;
wire butr = ilds & irwz & butsel;

reg [9:8] idout_h;
always @(*) begin
	idout_h = 2'b11;
	if (cartsel & irwz & iuds) idout_h = { 1'b0, gamecart };
	if (syncsel & irwz & iuds) idout_h = { pal, 1'b0 };
//    udenb = ~(irwz & iuds & (cartsel | syncsel));
end

////////////// VIDEO REGISTERS ////////////////

wire [7:0] hoff;
mlatch #(.WIDTH(8)) hoff_l(clk32, 0, ~(resb & porb), ~whoffb, id[7:0], hoff);
wire [21:1] vld;
mlatch #(.WIDTH(7)) vld_ll(clk32, 0, ~(resb & porb & wvidbmb & wvidbhb), ~wvidblb, id[7:1], vld[ 7: 1]);
mlatch #(.WIDTH(8)) vld_ml(clk32, 0, ~(resb & porb), ~wvidbmb, id[7:0], vld[15: 8]);
mlatch #(.WIDTH(6)) vld_hl(clk32, 0, ~(resb & porb), ~wvidbhb, id[5:0], vld[21:16]);
wire [3:0] conf_reg;
mlatch #(.WIDTH(4)) conf_l(clk32, 0, ~(resb & porb), ~wconfigb, id[3:0], conf_reg[3:0]);
wire rs2b = ~conf_reg[2];
wire rs3b = ~conf_reg[3];

reg [7:0] vid_o;

always @(*) begin
	vid_o = 8'hff;
	if (~rhoffb)   vid_o = hoff;
	if (~rvidblb)  vid_o = { vld[7:1], 1'b0 };
	if (~rvidbmb)  vid_o = vld[15:8];
	if (~rvidbhb)  vid_o = { 2'b00, vld[21:16] };
	if (~rconfigb) vid_o = { 4'b0000, conf_reg };
	if (~rloclb)   vid_o = { vid[7:1], 1'b0 };
	if (~rlocmb)   vid_o = vid[15:8];
	if (~rlochb)   vid_o = { 2'b00, vid[21:16] };
end

////////////// SOUND REGISTERS ////////////////

wire [21:1] sfb, sft_l;
reg  [21:1] sft;
wire  [3:1] snd_ctrl;
wire sndon;
wire sfrep = snd_ctrl[1];

mlatch #(.WIDTH(7)) sfb_ll(clk32, 0, (~resb & porb), ~wsfblb, id[7:1], sfb[ 7: 1]);
mlatch #(.WIDTH(8)) sfb_ml(clk32, 0, (~resb & porb), ~wsfbmb, id[7:0], sfb[15: 8]);
mlatch #(.WIDTH(6)) sfb_hl(clk32, 0, (~resb & porb), ~wsfbhb, id[5:0], sfb[21:16]);
mlatch #(.WIDTH(3)) sctl_l(clk32, 0, (~resb & porb), ~wscntlb, id[3:1], snd_ctrl);
mlatch #(.WIDTH(1)) sndon_l(clk32, 0, (~resb & porb) | stoff, ~wscntlb, id[0], sndon);

// latch sft register writes
mlatch #(.WIDTH(7)) sft_lll(clk32, 0, (~resb & porb), ~wsftlb, id[7:1], sft_l[ 7: 1]);
mlatch #(.WIDTH(8)) sft_mll(clk32, 0, (~resb & porb), ~wsftmb, id[7:0], sft_l[15: 8]);
mlatch #(.WIDTH(6)) sft_hll(clk32, 0, (~resb & porb), ~wsfthb, id[5:0], sft_l[21:16]);
// load sft when no sound - originally latches were used, but they create some
// weird combinatorial loops. Use sync load instead, with a half 16 MHz clock delay.
//mlatch #(.WIDTH(21)) sft_ll(clk32, 0, ~porb, ~sframe, sft_l, sft);
always @(posedge clk32) if (~porb) sft <= 0; else if (~sframe) sft <= sft_l;

reg [7:0] snd_o;

always @(*) begin
	snd_o = 8'hff;
	if (~rsfblb)  snd_o = { sfb[7:1], 1'b0 };
	if (~rsfbmb)  snd_o = sfb[15:8];
	if (~rsfbhb)  snd_o = { 2'b00, sfb[21:16] };
	if (~rscntlb) snd_o = { 4'b0000, snd_ctrl, sndon };
	if (~rsftlb)  snd_o = { sft[7:1], 1'b0 };
	if (~rsftmb)  snd_o = sft[15:8];
	if (~rsfthb)  snd_o = { 2'b00, sft[21:16] };
	if (~rsfclb)  snd_o = { snd[7:1], 1'b0 };
	if (~rsfcmb)  snd_o = snd[15:8];
	if (~rsfchb)  snd_o = { 2'b00, snd[21:16] };
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


assign RDY_N_O = ~aso;
wire   ready = RDY_N_O & RDY_N_I;

`ifdef VERILATOR

wire   aso_a = p8008 | ~p8010;
wire   dso_a = (p8008 & p8001) | (p8008 & drw) | ~p8010;

reg fcsackb_a = 1'b1;
reg p8001, p8006, p8008, p8010 = 1'b1;

always @(posedge ready, negedge porb, negedge ias) begin
	if (!porb) fcsackb_a <= 1'b1;
	else if (!ias) fcsackb_a <= 1'b1;
	else fcsackb_a <= ifcsb;
end

always @(negedge MHZ8, negedge porb) begin
	if (!porb) p8006 <= 1'b0;
	else p8006 <= dtack;
end

always @(posedge MHZ8, negedge porb, negedge ixdma) begin
	if (!porb) { p8001, p8008 } <= 2'b00;
	else if (!ixdma) { p8001, p8008 } <= 2'b00;
	else begin
		p8001 <= p8008;
		p8008 <= p8001 ^ ~(p8008 & p8001 & ~p8006);
	end
end

always @(negedge MHZ8, negedge porb, negedge ixdma) begin
	if (!porb) p8010 <= 1'b1;
	else if (!ixdma) p8010 <= 1'b1;
	else begin
		p8010 <= ~(p8001 & p8008);
	end
end
`endif

wire fcsackb;
register fcsackb_r(clk32, ~(porb & ias), 0, ready, ifcsb, fcsackb);

wire dtack_d, p8001_s, p8008_s, p8010_s;
register dtack_d_r(clk32, 0, !porb, ~MHZ8, dtack, dtack_d); // p8006
register p8001_r(clk32, 0, ~(porb & ixdma), MHZ8, p8008_s, p8001_s);
register p8008_r(clk32, 0, ~(porb & ixdma), MHZ8, p8001_s ^ ~(p8008_s & p8001_s & ~dtack_d), p8008_s);
register p8010_r(clk32, ~(porb & ixdma), 0, ~MHZ8, ~(p8001_s & p8008_s), p8010_s);

wire   aso   = p8008_s | ~p8010_s;
wire   dso   = (p8008_s & p8001_s) | (p8008_s & drw) | ~p8010_s;
wire   dtack   = sndack | ~ramcycb | ~cmpcycb | ~romxb | ~regxackb | cartsel | syncsel | butr | joysel | padr | penr | ~fcsackb;
assign DTACK_N = ~dtack;

/////////////// BUS ARBITRATION //////////////////

wire   ixdmab    = ~ixdma;
wire   br_n      = BR_N_I & BR_N_O;
wire   bgack_n   = BGACK_N_I & BGACK_N_O;
assign BGACK_N_O = ixdmab;
assign BR_N_O    = ~br_o;

wire   p9033_i   = (ready & ~ias) | (p9033 & ias);
wire   ixdma_i   = ixdma | (~ias & ~BG_N);
wire   br_o_i    = (br_n | br_o) & (BG_N | br_o) & p9033 & bgack_n;

// asunc
`ifdef VERILATOR

reg    ixdma_a; // p9021
reg    p9033_a;
reg    br_o_a;  // p9011

wire   p9033_i_a = (ready & ~ias) | (p9033_a & ias);
wire   ixdma_i_a = ixdma_a | (~ias & ~BG_N);
wire   br_o_i_a  = (br_n | br_o_a) & (BG_N | br_o_a) & p9033_a & bgack_n;

always @(posedge MHZ8, negedge porb, negedge resb) begin
	if (!porb) p9033_a <= 1'b0;
	else if (!resb) p9033_a <= 1'b0;
	else p9033_a <= p9033_i_a;

	if (!porb) br_o_a <= 1'b0;
	else if (!resb) br_o_a <= 1'b0;
	else br_o_a <= br_o_i_a;
end

always @(negedge MHZ8, negedge p9033_a) begin
	if (!p9033_a) ixdma_a <= 1'b0;
	else ixdma_a <= ixdma_i_a;
end
`endif

// sync to clk32
wire  ixdma;   // p9021
wire  p9033;
wire  br_o;    // p9011

register p9033_r(clk32, 0, ~(porb & resb), MHZ8, p9033_i, p9033);
register br_o_r(clk32, 0, ~(porb & resb), MHZ8, br_o_i, br_o);
register ixdma_r(clk32, 0, !p9033, ~MHZ8, ixdma_i, ixdma);

///////// DRAM SIZE/CONFIGURATION DECODES ////////

wire sela = rs2b & rs3b;
wire [3:0] ramaaa = sela ? { ~ADDR[21] & ~ADDR[20], ~ADDR[19], ~ADDR[18], ~ADDR[17] } : { 1'b1, ~ADDR[21], ~ADDR[20], ~ADDR[19] };
wire ram1 = viking_c0 | viking_e8 | (rs3b ? &ramaaa : ADDR[21]);
wire ram2 = rs3b ? ramaaa[3] & ramaaa[2] & ramaaa[1] & ~ramaaa[0] : ~ADDR[21];

//////////////// RAS GENERATOR ///////////////////

wire ram1a, ram2a;
wire udsl, ldsl;

mlatch ram1a_l(clk32, 0, !porb, clk4, ram1, ram1a);
mlatch ram2a_l(clk32, 0, !porb, clk4, ram2, ram2a);
mlatch ldsl_l (clk32, 0, !porb, clk4, ilds, ldsl);
mlatch udsl_l (clk32, 0, !porb, clk4, iuds, udsl);

assign RAS0_N = ~( (time0 & addrselb & (~refb | (ram1a & vos))) | (~time0 & addrsel & ram1a & ~ramcycb) );
assign RAS1_N = ~( (time0 & addrselb & (~refb | (ram2a & vos))) | (~time0 & addrsel & ram2a & ~ramcycb) );

assign CAS0L_N = ~( (time2 & ~lcycsel & ram1a & vos) | (~time2 & lcycsel & ram1a & ~ramcycb & ldsl) );
assign CAS0H_N = ~( (time2 & ~lcycsel & ram1a & vos) | (~time2 & lcycsel & ram1a & ~ramcycb & udsl) );
assign CAS1L_N = ~( (time2 & ~lcycsel & ram2a & vos) | (~time2 & lcycsel & ram2a & ~ramcycb & ldsl) );
assign CAS1H_N = ~( (time2 & ~lcycsel & ram2a & vos) | (~time2 & lcycsel & ram2a & ~ramcycb & udsl) );

// not original signals
assign RAM_LDS = (time0 & addrselb & (ram1a | ram2a) & vos) | (~time0 & addrsel & (ram1a | ram2a) & ~ramcycb & ldsl);
assign RAM_UDS = (time0 & addrselb & (ram1a | ram2a) & vos) | (~time0 & addrsel & (ram1a | ram2a) & ~ramcycb & udsl);

////////////////////////////////////////////

wire clk,time0,time1,time2,time4,addrsel,m2clock,m2clock_en_p,m2clock_en_n,clk4,cycsel,cycsel_en;
wire lcycsel = cycsel;
wire addrselb = ~addrsel;

assign bus_cycle = { ~time4, ~time0 };
assign CLK_O = clk;

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
    .m2clock_en_p(m2clock_en_p),
    .m2clock_en_n(m2clock_en_n),
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

/////// HORIZONTAL SYNC GENERATOR ////////
wire interlace = 0; // investigate is it useful or not?

wire ihsync = ~iihsync;
wire ivsync = ~iivsync;
wire vertclk;

// async
`ifdef VERILATOR
wire iihsync_a;

hsyncgen hsyncgen (
    .m2clock(m2clock),
    .resb(resb),
    .porb(porb),
    .mde1(mde1),
    .mde1b(~mde1),
    .interlace(interlace),
    .ntsc(ntsc),
    .iihsync(iihsync_a),
    .vertclk(vertclk)
);
`endif

// sync to clk32
reg  [6:0] hsc;
wire [6:0] hsc_load_val = { mde1 | interlace, 2'b00, mde1, 1'b0, ntsc & ~mde1, ~(ntsc & ~mde1) };
reg        hsc_load; // vertclkb

reg        iihsync;
wire [6:0] ihsync_set = mde1 ? 7'd121 : 7'd101;
wire [6:0] ihsync_res = mde1 ? 7'd127 : 7'd111;

always @(posedge clk32, negedge resb) begin
	if (!resb) begin
		hsc <= 0;
		hsc_load <= 0;
		iihsync <= 1;
	end else if (m2clock_en_p) begin
		hsc <= hsc + 1'd1;
		if (hsc == 7'd127 | hsc_load) begin
			hsc_load <= ~hsc_load;
			hsc <= hsc_load_val;
		end
		if (hsc == ihsync_set) iihsync <= 0;
		if (hsc == ihsync_res) iihsync <= 1;
	end
end

///////// HORIZONTAL DE GENERATOR ///////

wire ideb = ~DE;
wire cpal = ~mde1 & ~ntsc;
wire cntsc = ~mde1 & ntsc;
// async
`ifdef VERILATOR

wire hde1_a, de_a, blank_n_a;

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
    .ihsync(~iihsync_a),
    .hde1(hde1_a),
    .vde(vde),
    .vblank(vblank),
    .de(de_a),
    .blank_n(blank_n_a)
);
`endif

// sync to clk32
reg  [7:0] hdec;
reg        hblank;
wire       hblank_set = (cntsc & hdec == 8'd8 ) |  (cpal & hdec == 8'd9);
wire       hblank_reset = mde1 | hdec == 8'd114;

reg        hde, hde1;
wire       hde_set   = (cntsc & hdec == 8'd11) | (cpal & hdec == 8'd12) | (mde1 & hdec == 8'd2);
wire       hde_reset = (cntsc & hdec == 8'd95) | (cpal & hdec == 8'd96) | (mde1 & hdec == 8'd43);
reg        hde_set_r1, hde_set_r2, hde_set_r3, hde_set_r4;

always @(posedge clk32, negedge porb) begin
	if (!porb) begin
		hdec <= 0;
		hblank <= 0;

		{ hde_set_r1, hde_set_r2, hde_set_r3, hde_set_r4 } <= 0;
		hde <= 0;
	end else begin
		if ((m2clock_en_p && hsc == ihsync_set) || ~iihsync) begin
			// sync equivalent of ~iihsync async reset
			hdec <= 0;
			hblank <= 0;

			{ hde_set_r1, hde_set_r2, hde_set_r3, hde_set_r4 } <= 0;
			hde <= 0;
		end else
		if (m2clock_en_n) begin
			hdec <= hdec + 1'd1;

			if (hblank_set) hblank <= 1;
			if (hblank_reset) hblank <= 0;

			hde_set_r1 <= hde_set;
			hde_set_r2 <= hde_set_r1;
			hde_set_r3 <= hde_set_r2;
			hde_set_r4 <= hde_set_r3;
			if (hde_reset) hde <= 0;
			else if ( noscroll && ((~mde1 & hde_set_r4) || (mde1 && hde_set_r1))) hde <= 1;
			else if (!noscroll && ((~mde0 & hde_set) || (mde0 && hde_set_r2))) hde <= 1;
		end
	end
end

always @(posedge clk32, negedge porb) begin
	if (!porb) begin
		BLANK_N <= 1;
		hde1 <= 0;
		DE <= 1;
	end else if (m2clock_en_p) begin
		BLANK_N <= hblank & vblank;
		hde1 <= hde;
		DE <= hde & vde;
	end
end

//////////// VERTICAL SYNC GENERATOR ///////////

// async
wire iivsync_a;

`ifdef VERILATOR

vsyncgen vsyncgen (
    .vertclk(vertclk),
    .resb(resb),
    .porb(porb),
    .mde1(mde1),
    .mde1b(~mde1),
    .interlace(interlace),
    .ntsc(ntsc),
    .iivsync(iivsync_a)
);
`endif

// sync to clk32
wire       vertclk_en = hsc_load & m2clock_en_p;
reg  [8:0] vsc;
wire [8:0] vsc_load_val = { 1'b0, ~mde1, ~mde1, ~mde1 & ntsc, ~mde1 & ntsc, 1'b1, mde1, ~mde1 & ntsc, 1'b0 };
reg        vsc_load;

reg        iivsync;
wire [8:0] ivsync_set = mde1 ? 9'd510 : 9'd508;

always @(posedge clk32, negedge resb) begin
	if (!resb) begin
		vsc <= 0;
		vsc_load <= 1;
		iivsync <= 1;
	end else if (vertclk_en) begin
		vsc <= vsc + 1'd1;
		if (vsc == 9'd511 | vsc_load) begin
			vsc_load <= ~vsc_load;
			vsc <= vsc_load_val;
			iivsync <= 1;
		end
		if (vsc == ivsync_set) iivsync <= 0;
	end
end

///////////// VERTICAL DE GENERATOR ////////////

reg vde, vblank;
//async
`ifdef VERILATOR

wire vde_a, vblank_a;

vdegen vdegen (
    .porb(porb),
    .mde1(mde1),
    .cpal(cpal),
    .cntsc(cntsc),
    .ihsync(ihsync),
    .ivsync(ivsync),
    .vde(vde_a),
    .vblank(vblank_a)
);

`endif

// sync to clk32
reg  [8:0] vdec;

wire       vblank_set =   (cpal & vdec == 9'd24) | (cntsc & vdec == 9'd15);        // 0030 = 24, 0017 = 15
wire       vblank_reset = mde1 | (cpal & vdec == 9'd307) | (cntsc & vdec == 9'd257); // 0463 = 307, 0401 = 257

wire       vde_set =      (mde1 & vdec == 9'd35 ) | (cpal & vdec == 9'd62 ) | (cntsc & vdec == 9'd33 ); // 0043 = 35, 0076 = 62, 0041 = 33
wire       vde_reset =    (mde1 & vdec == 9'd435) | (cpal & vdec == 9'd262) | (cntsc & vdec == 9'd233); // 0663 = 435, 0406 = 262, 0351 = 233

always @(posedge clk32, negedge porb) begin
	if (!porb) begin
		vdec <= 0;
		vde <= 0;
		vblank <= 0;
	end else begin
		if ((vertclk_en & vsc == ivsync_set) | ~iivsync) begin
			// sync equivalent of async ~iivsync reset
			vdec <= 0;
			vde <= 0;
			vblank <= 0;
		end else
		if (m2clock_en_p && hsc == ihsync_res) begin
			vdec <= vdec + 1'd1;
			if (vde_set)   vde <= 1;
			if (vde_reset) vde <= 0;
			if (vblank_set) vblank <= 1;
			if (vblank_reset) vblank <= 0;
		end
	end
end

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
reg  [21:1] vid, vid_reg;
reg vid_r_d, vidclk_d, vidb_d;

reg pf071, pf071_reg;

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

//////// DMA ADDRESS COUNTER ////////

wire        dmaclk = ~(dso & ixdma);
reg  [23:1] dmaa, dma_reg;
reg         dmaclk_d;

always @(*) begin
	dmaa = dma_reg;
	if (~(resb & porb)) dmaa = 0;
	if (~dmaclk_d & dmaclk) dmaa = dmaa + 1'd1;
	if (!wdmal) dmaa[ 7: 1] = id[7:1];
	if (!wdmam) dmaa[15: 8] = id[7:0];
	if (!wdmah) dmaa[23:16] = id[7:0];
end

always @(posedge clk32) begin
	dmaclk_d <= dmaclk;
	dma_reg <= dmaa;
end

reg [7:0] dma_o;

always @(*) begin
	dma_o = 8'hff;
	if (~rdmalb) dma_o = { dmaa[7:1], 1'b0 };
	if (~rdmamb) dma_o = dmaa[15:8];
	if (~rdmahb) dma_o = dmaa[23:16];
end

endmodule
