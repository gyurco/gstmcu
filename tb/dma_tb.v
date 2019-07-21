module dma_tb (
	input  clk32,
	input  clk_en,
	input  FCS_N,
	input  RW,
	input  RDY_I,
	output reg RDY_O,
	input  A1,
	input  [15:0] DIN,
	output [15:0] DOUT
);

// $FF8604|word |FDC access/sector count                              |R/W
// $FF8606|word |DMA mode/status                             BIT 2 1 0|R
//        |     |Condition of FDC DATA REQUEST signal -----------' | ||
//        |     |0 - sector count null,1 - not null ---------------' ||
//        |     |0 - no error, 1 - DMA error ------------------------'|
// $FF8606|word |DMA mode/status                 BIT 8 7 6 . 4 3 2 1 .|W
//        |     |0 - read FDC/HDC,1 - write ---------' | | | | | | |  |
//        |     |0 - HDC access,1 - FDC access --------' | | | | | |  |
//        |     |0 - DMA on,1 - no DMA ------------------' | | | | |  |
//        |     |Reserved ---------------------------------' | | | |  |
//        |     |0 - FDC reg,1 - sector count reg -----------' | | |  |
//        |     |0 - FDC access,1 - HDC access ----------------' | |  |
//        |     |0 - pin A1 low, 1 - pin A1 high ----------------' |  |
//        |     |0 - pin A0 low, 1 - pin A0 high ------------------'  |

// A simpe test for DMA:
// write resets
// write dmadir to 0 starts an FDC read (memory write), write 1 starts FDC write (memory read)
// then send/receive 16 words to/from the bus

always @(posedge clk32) begin
	reg [7:0] dma_words;
	reg dma_read, dma_write;
	reg rdy_d;
	rdy_d <= RDY_I;

	if (!FCS_N) begin
		{ dma_read, dma_write } <= 2'b00;
		dma_words <= 8'h0;
		DOUT <= 16'h200;
		if (A1) begin
			{ dma_read, dma_write } <= { DIN[9], ~DIN[9] };
			RDY_O <= 1'b1;
		end
	end else begin
		if (dma_read | dma_write) begin
			if (RDY_I && dma_words < 8'd15) RDY_O <= 1'b1;
			if (~rdy_d & RDY_I) begin
				dma_words <= dma_words + 1'd1;
				DOUT <= DOUT + 1'd1;
				if (dma_words == 8'd15) begin
					RDY_O <= 1'b0;
					{ dma_read, dma_write } <= 2'b00;
				end
			end
		end else if (clk_en) begin
			RDY_O <= 1'b0;
		end
	end
end

endmodule
