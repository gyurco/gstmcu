#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>
#include "Vste_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"


static Vste_tb *tb;
static VerilatedVcdC *trace;
static int tickcount;

static unsigned char ram[4*1024*1024];

void initram() {
	FILE *file=fopen("stram.bin", "rb");
	fread(&ram, 4*1024, 1024, file);
	fclose(file);
}

void tick(int c) {
	static int old_addr = 0xffffff;

	tb->clk32 = c;
	tb->eval();
	trace->dump(tickcount++);

	if (c && !(tb->RAS0_N && tb->RAS1_N) && tb->ram_a < 0x200000) {
		if (!tb->we_n) {
			ram[tb->ram_a<<1] = (tb->mdout & 0xff00) >> 8;
			ram[(tb->ram_a<<1) + 1] = tb->mdout & 0xff;
			std::cout << "ram write at " << std::hex << tb->ram_a << " value " << tb->mdout << std::endl;
		}
		tb->mdin = (ram[tb->ram_a<<1] * 256) + ram[(tb->ram_a<<1) + 1];
		//if (!tb->AS_N) std::cout << "ram access at " << std::hex << tb->ram_a << " value " << tb->mdin << std::endl;
	}

	if (c && !tb->ROM2_N && tb->A < 0x200000) {
		tb->mdin = (ram[tb->A<<1] * 256) + ram[(tb->A<<1) + 1];
		//if (!tb->AS_N) std::cout << "ram access at " << std::hex << tb->ram_a << " value " << tb->mdin << std::endl;
	}
}

void print(bool rise) {
    std::cout << (rise ? "rise" : "fall");
//    std::cout << "- hsc : " << std::setw(3) << (int)tb->hsc;
    std::cout << " hsync " << bool(tb->HSYNC_N);
    std::cout << " vsync " << bool(tb->VSYNC_N);
    std::cout << std::endl;
}

void write_reg(int addr, int data)
{
	// S0
	while (!tb->MHZ8_EN1) {
		tick(1);
		tick(0);
	};
	tb->RW = 1;

	// S1
	while (!tb->MHZ8_EN2) {
		tick(1);
		tick(0);
	};
	tb->A = addr >> 1;

	// S2
	while (!tb->MHZ8_EN1) {
		tick(1);
		tick(0);
	};
	tb->AS_N = 0;
	tb->RW = 0;

	// S3
	while (!tb->MHZ8_EN2) {
		tick(1);
		tick(0);
	};
	tb->DIN = data;

	// S4
	while (!tb->MHZ8_EN1) {
		tick(1);
		tick(0);
	};
	tb->UDS_N = 0;
	tb->LDS_N = 0;

	// S5
	while (true) {
		tick(1);
		tick(0);
		if (tb->MHZ8_EN2 && !(tb->DTACK_N && tb->BERR_N)) break;
	}

	// S6
	while (!tb->MHZ8_EN1) {
		tick(1);
		tick(0);
	}

	// S7
	while (!tb->MHZ8_EN2) {
		tick(1);
		tick(0);
	}
	tb->RW=1;
	tb->AS_N=1;
	tb->UDS_N=1;
	tb->LDS_N=1;
	tick(1);
	tick(0);
}

int read_reg(int addr)
{
	int dout;
	// S0
	while (!tb->MHZ8_EN1) {
		tick(1);
		tick(0);
	};
	tb->RW = 1;

	// S1
	while (!tb->MHZ8_EN2) {
		tick(1);
		tick(0);
	};
	tb->A = addr >> 1;

	// S2
	while (!tb->MHZ8_EN1) {
		tick(1);
		tick(0);
	};
	tb->AS_N = 0;
	tb->UDS_N = 0;
	tb->LDS_N = 0;
	// S3
	while (!tb->MHZ8_EN2) {
		tick(1);
		tick(0);
	}
	// S4 - S5
	while (true) {
		tick(1);
		tick(0);
		if (tb->MHZ8_EN2 && !(tb->DTACK_N && tb->BERR_N)) break;
	}

	// S6
	while (!tb->MHZ8_EN1) {
		tick(1);
		tick(0);
	}

	//S7
	while (!tb->MHZ8_EN2) {
		tick(1);
		tick(0);
	}
	dout = tb->DOUT;
	tb->AS_N=1;
	tb->UDS_N=1;
	tb->LDS_N=1;
	tick(1);
	tick(0);
	return dout;
}

void memtest() {
	FILE *file;
	int addr=0,data,data2;
	file = fopen("memtest.bin", "wb");
	while(true) {
		data=read_reg(addr<<1);
//		std::cout << "addr: " << std::hex << addr << " data: " << data << std::endl;
		data2=((data & 0xff) << 8) | ((data >> 8) & 0xff);
		fwrite(&data2,1,2,file);
		addr++;
		if(addr==0x200000) break;
	}
	fclose(file);
}

void dump(bool ntsc, bool mde0, bool mde1, bool vid) {
	int steps = 128*2048*8;
	bool disp;
	bool vidout = false;
	bool once = vid;
	int vsync = 0;
	unsigned short rgb;
	FILE *file;

	write_reg(0xff820a, ntsc ? 0 : 0x200);
	write_reg(0xff8260, (mde1 ? 0x200 : 0) | (mde0 ? 0x100 : 0));
	std::cout << "=========================" << std::endl;
	std::cout << "NTSC : " << ntsc << " mde0 : " << mde0 << " mde1: " << mde1 << std::endl;
	std::cout << "=========================" << std::endl;

	if (vid) file=fopen("video.rgb", "wb");

	disp = false;
	while(steps--) {
		if (!tb->VSYNC_N && vsync) {
			vidout = !vidout && once;
			if (!vidout) once = false;
			std::cout << "vsync start, vidout : " << vidout << std::endl;
		}
	    vsync = tb->VSYNC_N;
	    tick(1);
//	    if (tb->hsc == 127) disp = true;
	    if (disp) print(true);
	    tick(0);
	    if (disp) print(false);
	    if (vid && vidout) {
		if (!tb->VSYNC_N) rgb = 0x00f0;
		else if (!tb->HSYNC_N) rgb = 0x0f00;
		else if (!tb->BLANK_N) rgb = 0x000f;
		else rgb = tb->R*256 + tb->G*16 + tb->B;
		fwrite(&rgb, 1, sizeof(rgb), file);
	    }
	}
	if (vid) fclose(file);

}

int main(int argc, char **argv) {

	initram();
	char steps = 250;
	// Initialize Verilators variables
	Verilated::commandArgs(argc, argv);
//	Verilated::debug(1);
	Verilated::traceEverOn(true);
	trace = new VerilatedVcdC;
	tickcount = 0;

	// Create an instance of our module under test
	tb = new Vste_tb;
	tb->trace(trace, 99);
	trace->open("gstmcu.vcd");

	tb->resb = 0;
	tb->porb = 0;
	tick(1);
	tick(0);

	tb->AS_N = 1;
	tb->UDS_N = 1;
	tb->LDS_N = 1;
	tb->RW = 1;
	tb->VMA_N = 1;
	tb->MFPINT_N = 1;
	tb->BR_N = 1;

	tb->FC0 = 0;
	tb->FC1 = 1;
	tb->FC2 = 1;
	tb->resb = 1;
	tb->porb = 1;
	tick(1);
	tick(0);
	tb->resb = 0;
	tick(1);
	tick(0);
	tb->resb = 1;
	write_reg(0xff8000, 0x0c); // memory conrol reg
	write_reg(0xff8200, 0x1f); // video base hi
	write_reg(0xff8202, 0x80); // video base mid
	write_reg(0xff820c, 0x00); // video base lo

	write_reg(0xff8921, 0x83); // stereo/50kHz

	write_reg(0xff8902, 0x00); // snd frame start hi
	write_reg(0xff8904, 0x10); // snd frame start mid
	write_reg(0xff8906, 0x00); // snd frame start lo
	write_reg(0xff890e, 0x00); // snd frame end hi
	write_reg(0xff8910, 0x14); // snd frame end mid
	write_reg(0xff8912, 0x03); // snd frame end lo
	write_reg(0xff8900, 0x03); // snd ctrl - start+loop

	write_reg(0x00ffff, 0xaaaa); // write to RAM

	write_reg(0xff8240, 0x0fff); //palette registers
	write_reg(0xff8242, 0x0f00);
	write_reg(0xff8244, 0x00f0);
	write_reg(0xff8246, 0x0000);
	write_reg(0xff8248, 0x0fff);
	write_reg(0xff824a, 0x0f00);
	write_reg(0xff824c, 0x00f0);
	write_reg(0xff824e, 0x0ff0);

	write_reg(0xff8250, 0x000f); //palette registers
	write_reg(0xff8252, 0x0f0f);
	write_reg(0xff8254, 0x00ff);
	write_reg(0xff8256, 0x0555);
	write_reg(0xff8258, 0x0333);
	write_reg(0xff825a, 0x0f33);
	write_reg(0xff825c, 0x03f3);
	write_reg(0xff825e, 0x0ff3);

//	memtest();

//	write_reg(0xff820e, 0x0050); // horizontal offset

	dump(false,true,false,true);

	std::cout << std::hex << "ram 0x0ffff (0xaaaa): " << std::hex << read_reg(0xffff) << std::endl;
	std::cout << std::hex << "shmode 0xff8260: " << std::hex << read_reg(0xff8260) << std::endl;

	write_reg(0xff8800, 0); //write to AY
//	write_reg(0xff8264, 0x00aa); //write to hscroll

	dump(true,false,true,false);
	std::cout << std::hex << "shmode 0xff8260: " << std::hex << read_reg(0xff8260) << std::endl;
	write_reg(0xff0000, 0); //generate bus error
	dump(true,false,false,false);
	std::cout << std::hex << "shmode 0xff8260: " << std::hex << read_reg(0xff8260) << std::endl;

//	std::cout << std::hex << read_reg(0xff820c) << std::endl;

	std::cout << std::hex << "ROM READ 0-2" << std::endl;
	std::cout << std::hex << read_reg(0x000000) << std::endl;
	std::cout << std::hex << read_reg(0x000002) << std::endl;

	trace->close();

}
