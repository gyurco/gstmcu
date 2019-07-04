//
// shifter.v
// 
// Atari ST(E) shifter implementation for the MiST board
// http://code.google.com/p/mist-board/
// 
// Copyright (c) 2013-2015 Till Harbaum <till@harbaum.org> 
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 

module gstshifter (
	input  clk32,
	input  ste,
	input  resb,

	// CPU/RAM interface
	input  CS,           // CMPCS
	input  [6:1] A,
	input  [15:0] DIN,
	output [15:0] DOUT,
	input  LATCH,
	input  RDAT_N,       // output enable for latched MDIN or shifter out -> DOUT
	input  WDAT_N,       // DIN  -> MDOUT
	input  RW,
	input  [15:0] MDIN,  // RAM input
	output [15:0] MDOUT, // RAM output
	// VIDEO
	output MONO,
	input  LOAD_N,       // DCYC_N
	input  DE,
	input  BLANK_N,
	output [3:0] R,
	output [3:0] G,
	output [3:0] B,
	// DMA SOUND
	input  SLOAD_N,
	output SREQ,
	output reg [7:0] audio_left,
	output reg [7:0] audio_right
);

// ---------------------------------------------------------------------------
// --------------------------- CPU/MEMORY BUS separation ---------------------
// ---------------------------------------------------------------------------

wire [15:0] mbus_in = CS ? s_dout : MDIN;
wire [15:0] s_dout;

latch #(16) dout_l(clk32, 0, 0, LATCH, mbus_in, DOUT);

latch #(16) mdout_l(clk32, 0, 0, !WDAT_N, DIN, MDOUT);


// default video mode is monochrome
parameter DEFAULT_MODE = 2'd2;

// shiftmode register
reg [1:0] shmode;
wire mono  = (shmode == 2'd2);
wire mid   = (shmode == 2'd1);
wire low   = (shmode == 2'd0);

// derive number of planes from shiftmode
wire [2:0] planes = mono?3'd1:(mid?3'd2:3'd4);

 // data input buffers for up to 4 planes
reg [15:0] data_latch[4];

// 16 colors with 3*4 bits each (4 bits for STE, ST only uses 3 bits)
reg [3:0] palette_r[15:0];
reg [3:0] palette_g[15:0];
reg [3:0] palette_b[15:0];

// STE-only registers
reg [3:0] pixel_offset;             // number of pixels to skip at begin of line

// ---------------------------------------------------------------------------
// ----------------------------- CPU register read ---------------------------
// ---------------------------------------------------------------------------

always @(*) begin
	s_dout = 16'h0000;

	// read registers
	if(CS && RW) begin

		if(ste) begin
			if(A == 6'h32) s_dout = { 12'h000, pixel_offset };
		end

		// the color palette registers
		if(A >= 6'h20 && A < 6'h30 ) begin
			s_dout[ 3:0] = palette_b[A[4:1]];
			s_dout[ 7:4] = palette_g[A[4:1]];
			s_dout[11:8] = palette_r[A[4:1]];

			// return only the 3 msb in non-ste mode
			if(!ste) begin
				s_dout[ 3] = 1'b0;
				s_dout[ 7] = 1'b0;
				s_dout[11] = 1'b0;
			end
		end

		// shift mode register
		if(A == 6'h30) s_dout = { 6'h00, shmode, 8'h00    };

		if(ste) begin
			// sound mode register
			if(A == 6'h10) s_dout[7:0] = { mode[2], 5'd0, mode[1:0] };
			// mircowire
			if(A == 6'h11) s_dout = mw_data_reg;
			if(A == 6'h12) s_dout = mw_mask_reg;
		end
	end
end

// ---------------------------------------------------------------------------
// ----------------------------- CPU register write --------------------------
// ---------------------------------------------------------------------------

always @(posedge clk32) begin
	if(!resb) begin
		shmode <= DEFAULT_MODE;   // default video mode 2 => mono

		// disable STE hard scroll features
		pixel_offset <= 4'h0;

		palette_b[ 0] <= 4'b111;

	end else begin
		// write registers
		if(CS && !RW) begin

			// writing special STE registers
			if(ste) begin
				if(A == 6'h32) begin
					pixel_offset <= DIN[3:0];
				end
			end

			// the color palette registers, always write bit 3 with zero if not in 
			// ste mode as this is the lsb of ste
			if(A >= 6'h20 && A < 6'h30 ) begin
				if(!ste) begin
					palette_r[A[4:1]] <= { 1'b0, DIN[10:8] };
					palette_g[A[4:1]] <= { 1'b0, DIN[ 6:4] };
					palette_b[A[4:1]] <= { 1'b0, DIN[ 2:0] };
				end else begin
					palette_r[A[4:1]] <= DIN[11:8];
					palette_g[A[4:1]] <= DIN[ 7:4];
					palette_b[A[4:1]] <= DIN[ 3:0];
				end
			end

			// make msb writeable if MiST video modes are enabled
			if(A == 6'h30) shmode <= DIN[9:8];
		end
	end
end

// ---------------------------------------------------------------------------
// -------------------------- video signal generator -------------------------
// ---------------------------------------------------------------------------

// ----------------------- monochrome video signal ---------------------------
// mono uses the lsb of blue palette entry 0 to invert video
wire [3:0] blue0 = palette_b[0];
wire mono_bit = blue0[0]^shift_0[15];
wire [3:0] mono_rgb = { mono_bit, mono_bit, mono_bit, mono_bit };

// ------------------------- colour video signal -----------------------------

// For ST compatibility reasons the STE has the color bit order 0321. This is 
// handled here
wire [3:0] color_index = { shift_3[15], shift_2[15], shift_1[15], shift_0[15] };
wire [3:0] color_r_pal = palette_r[color_index];
wire [3:0] color_r = { color_r_pal[2:0], color_r_pal[3] };
wire [3:0] color_g_pal = palette_g[color_index];
wire [3:0] color_g = { color_g_pal[2:0], color_g_pal[3] };
wire [3:0] color_b_pal = palette_b[color_index];
wire [3:0] color_b = { color_b_pal[2:0], color_b_pal[3] };

// --------------- de-multiplex color and mono into one vga signal -----------
wire [3:0] stvid_r = mono?mono_rgb:color_r;
wire [3:0] stvid_g = mono?mono_rgb:color_g;
wire [3:0] stvid_b = mono?mono_rgb:color_b;

// shift registers for up to 4 planes
reg [15:0] shift_0, shift_1, shift_2, shift_3;

reg  [1:0] t;
always @(posedge clk32) t <= t + 1'd1;

// clock divider to generate the mid and low rez pixel clocks
wire   pclk_en = low?t==2'b10:mid?~t[0]:1'b1;
// use variable dot clock

reg [3:0] hcnt;
always @(posedge clk32) begin
	if (!resb) begin
		hcnt <= 0;
	end else if (pclk_en) begin
		if (!DE) hcnt <= 0;
		else hcnt <= hcnt  + 1'd1;

		// drive video output
		R <= BLANK_N?4'b0000:stvid_r;
		G <= BLANK_N?4'b0000:stvid_g;
		B <= BLANK_N?4'b0000:stvid_b;

		// shift all planes and reload 
		// shift registers every 16 pixels
		if(hcnt == 4'hf) begin
			if(!ste || (pixel_offset == 0)) begin
				shift_0 <= data_latch[0];
				shift_1 <= data_latch[1];
				shift_2 <= data_latch[2];
				shift_3 <= data_latch[3];
			end else begin
				shift_0 <= ste_shifted_0;
				shift_1 <= ste_shifted_1;
				shift_2 <= ste_shifted_2;
				shift_3 <= ste_shifted_3;
			end
		end else begin
			shift_0 <= { shift_0[14:0], 1'b0 };
			shift_1 <= { shift_1[14:0], 1'b0 };
			shift_2 <= { shift_2[14:0], 1'b0 };
			shift_3 <= { shift_3[14:0], 1'b0 };
		end
	end
end

reg       load_d;
reg [1:0] plane;

// ---------------------------------------------------------------------------
// ----------------------------- Latch data from RAM -------------------------
// ---------------------------------------------------------------------------

always @(posedge clk32) begin

	if (!resb) begin
		plane <= 0;
		hcnt <= 0;
	end else begin
		load_d <= LOAD_N;
		if (!DE) begin
			plane <= 0;
			hcnt <= 0;
		end else begin
			if (load_d & ~LOAD_N) begin
				data_latch[plane] <= MDIN;
				// advance plane counter
				if(planes != 1) begin
					plane <= plane + 1'd1;
					if({1'b0, plane} == planes - 1'd1) plane <= 0;
				end
			end
		end
	end
end

// ---------------------------------------------------------------------------
// --------------------------- STE hard scroll shifter -----------------------
// ---------------------------------------------------------------------------

// extra 32 bit registers required for STE hard scrolling
reg [31:0] ste_shift_0, ste_shift_1, ste_shift_2, ste_shift_3;

// shifted data
wire [15:0] ste_shifted_0, ste_shifted_1, ste_shifted_2, ste_shifted_3;

// connect STE scroll shifters for each plane
ste_shifter ste_shifter_0 (
	.skew (pixel_offset),
	.in   (ste_shift_0),
	.out  (ste_shifted_0)
);

ste_shifter ste_shifter_1 (
	.skew (pixel_offset),
	.in   (ste_shift_1),
	.out  (ste_shifted_1)
);

ste_shifter ste_shifter_2 (
	.skew (pixel_offset),
	.in   (ste_shift_2),
	.out  (ste_shifted_2)
);

ste_shifter ste_shifter_3 (
	.skew (pixel_offset),
	.in   (ste_shift_3),
	.out  (ste_shifted_3)
);

// move data into STE hard scroll shift registers 
always @(posedge clk32) begin
	if((load_d & ~LOAD_N) && (plane == 2'd0)) begin
		// shift up 16 pixels and load new data into lower bits of shift registers
		ste_shift_0 <= { ste_shift_0[15:0], data_latch[0] };
		ste_shift_1 <= { ste_shift_1[15:0], (planes > 3'd1)?data_latch[1]:16'h0000 };
		ste_shift_2 <= { ste_shift_2[15:0], (planes > 3'd2)?data_latch[2]:16'h0000 };
		ste_shift_3 <= { ste_shift_3[15:0], (planes > 3'd2)?data_latch[3]:16'h0000 };
	end
end


//////////////////////////////////////////////////////////////////////////
//////////////////////////////// DMA SOUND ///////////////////////////////
//////////////////////////////////////////////////////////////////////////

reg [2:0] mode;

// micro wire
reg [15:0] mw_data_reg, mw_mask_reg;
reg  [6:0] mw_cnt;   // micro wire shifter counter

// micro wire outputs
reg mw_clk;
reg mw_data;
reg mw_done;

wire mw_write = CS && !RW && A == 6'h11;
wire clk_8_en = (t == 0);
always @(posedge clk32) begin
	if(!resb) begin
		mw_cnt <= 7'h00;        // no micro wire transfer in progress
	end else begin
		// sound mode register
		if(CS && !RW && A == 6'h10) mode <= { DIN[7], DIN[1:0] };
		// micro wire has a 16 bit interface
		if(CS && !RW && A == 6'h12) mw_mask_reg <= DIN;
	end

	// ----------- micro wire interface -----------
	if(clk_8_en && mw_cnt != 0) begin

		// decrease shift counter. Do this before the register write as
		// register write has priority and should reload the counter
		if(mw_cnt != 0)
			mw_cnt <= mw_cnt - 7'd1;

		if(mw_cnt[2:0] == 3'b000) begin
			// send/shift next bit every 8 clocks -> 1 MBit/s
			mw_data_reg <= { mw_data_reg[14:0], 1'b0 };
			mw_data <= mw_data_reg[15];
		end

		// rotate mask on first access and on every further 8 clocks
		if(mw_cnt[2:0] == 3'b000) begin
			mw_mask_reg <= { mw_mask_reg[14:0], mw_mask_reg[15]};
			// notify client of valid bits
			mw_clk <= mw_mask_reg[15];
		end

		// indicate end of transfer
		mw_done <= (mw_cnt == 7'h01);
	end

	// writing the data register triggers the transfer
	if (mw_write) begin
		// first bit is evaluated imediately
		mw_data_reg <= { DIN[14:0], 1'b0 };
		mw_data <= DIN[15];
		mw_cnt <= 7'h7f;
		mw_mask_reg <= { mw_mask_reg[14:0], mw_mask_reg[15]};
		// notify client of valid bits
		mw_clk <= mw_mask_reg[15];
	end

end

// ---------------------------------------------------------------------------
// ------------------------------ clock generation ---------------------------
// ---------------------------------------------------------------------------

// base clock is 8MHz/160 (32MHz/640)
reg       a2base;
reg [9:0] a2base_cnt;
reg       a2base_en;

always @(posedge clk32) begin
	a2base_cnt <= a2base_cnt + 1'd1;
	if(a2base_cnt == 639) a2base_cnt <= 0;
	a2base_en <= (a2base_cnt == 0);
end

// generate current audio clock
reg [2:0] aclk_cnt;
always @(posedge clk32) if (a2base_en) aclk_cnt <= aclk_cnt + 3'd1;

reg aclk_en;
always @(posedge clk32) begin
	aclk_en <=  a2base_en & (
	            (mode[1:0] == 2'b11)?a2base_en:             // 50 kHz
	           ((mode[1:0] == 2'b10)?(aclk_cnt[0] == 0):    // 25 kHz
	           ((mode[1:0] == 2'b01)?(aclk_cnt[1:0] == 0):  // 12.5 kHz
	            (aclk_cnt == 0))));                         // 6.25 kHz
end

// ---------------------------------------------------------------------------
// --------------------------------- audio fifo ------------------------------
// ---------------------------------------------------------------------------

// This type of fifo can actually never be 100% full. It contains at most
// 2^n-1 words. A n=2 buffer can thus contain at most 3 words which at 50kHz
// stereo means that the buffer needs to be reloaded at 16.6kHz. Reloading
// happens in hde1 at 15.6Khz. Thus a n=2 buffer is not sufficient..

localparam FIFO_ADDR_BITS = 3;    // four words
localparam FIFO_DEPTH = (1 << FIFO_ADDR_BITS);
reg [15:0] fifo [FIFO_DEPTH-1:0];
reg [FIFO_ADDR_BITS-1:0] writeP, readP;
wire fifo_empty = (readP == writeP);
wire fifo_full = (readP == (writeP + 2'd1));

assign SREQ = !fifo_full;

// ---------------------------------------------------------------------------
// -------------------------------- audio engine -----------------------------
// ---------------------------------------------------------------------------

reg bytesel;   // byte-in-word toggle flag
wire [15:0] fifo_out = fifo[readP];
wire [7:0] mono_byte = (!bytesel)?fifo_out[15:8]:fifo_out[7:0];

// empty the fifo at the correct rate
always @(posedge clk32) begin
	if(!resb) begin
		readP <= 0;
	end else if (aclk_en) begin
		// audio data in fifo? play it!
		if(!fifo_empty) begin
			if(!mode[2]) begin
				audio_left  <= fifo_out[15:8] + 8'd128;   // high byte == left channel
				audio_right <= fifo_out[ 7:0] + 8'd128;   // low byte == right channel
			end else begin
				audio_left  <= mono_byte + 8'd128;
				audio_right <= mono_byte + 8'd128;
				bytesel <= !bytesel;
			end
			// increase fifo read pointer every sample in stereo mode and every
			// second sample in mono mode
			if(!mode[2] || bytesel) readP <= readP + 1'd1;
		end
	end
end

always @(posedge clk32) begin
	reg sload_d;

	if (!resb) begin
		writeP <= 0;
	end else begin
		if (sload_d & ~SLOAD_N) begin
			// data was requested when fifo wasn't full, so don't have to check it here
			fifo[writeP] <= MDIN;
			writeP <= writeP + 1'd1;
		end
	end
end


endmodule

// ---------------------------------------------------------------------------
// --------------------------- STE hard scroll shifter -----------------------
// ---------------------------------------------------------------------------

module ste_shifter (
   input  [3:0] skew,
   input  [31:0] in,
   output reg [15:0] out
);

always @(skew, in) begin
    out = 16'h0000;

   case(skew)
     15: out =  in[16:1];
     14: out =  in[17:2];
     13: out =  in[18:3];
     12: out =  in[19:4];
     11: out =  in[20:5];
     10: out =  in[21:6];
     9:  out =  in[22:7];
     8:  out =  in[23:8];
     7:  out =  in[24:9];
     6:  out =  in[25:10];
     5:  out =  in[26:11];
     4:  out =  in[27:12];
     3:  out =  in[28:13];
     2:  out =  in[29:14];
     1:  out =  in[30:15];
     0:  out =  in[31:16];
   endcase; // case (skew)
end

endmodule
