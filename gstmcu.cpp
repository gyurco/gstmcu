#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>
#include "Vgstmcu.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

static Vgstmcu *tb;
static VerilatedVcdC *trace;
static int tickcount;

void tick(int c) {
	tb->clk = c;
	tb->eval();
	trace->dump(tickcount++);
}

void print(bool rise) {
    std::cout << (rise ? "rise" : "fall");
    std::cout << "- hsc : " << std::setw(3) << (int)tb->hsc;
    std::cout << " hsync " << bool(tb->hsync_n);
    std::cout << " vsync " << bool(tb->vsync_n);
    std::cout << std::endl;
}

void dump(bool ntsc, bool mde1) {
	int steps = 128*2048;
	bool disp;

	tb->mde0 = 0;
	tb->mde1 = mde1;
	tb->ntsc = ntsc;
	std::cout << "=========================" << std::endl;
	std::cout << "NTSC : " << ntsc << " mde1 : " << mde1 << std::endl;
	std::cout << "=========================" << std::endl;

	disp = false;
	while(steps--) {
	    tick(0);
	    if (tb->hsc == 127) disp = true;
	    if (disp) print(true);
	    tick(1);
	    if (disp) print(false);
	}

}

int main(int argc, char **argv) {

	char steps = 250;
	// Initialize Verilators variables
	Verilated::commandArgs(argc, argv);
//	Verilated::debug(1);
	Verilated::traceEverOn(true);
	trace = new VerilatedVcdC;
	tickcount = 0;

	// Create an instance of our module under test
	tb = new Vgstmcu;
	tb->trace(trace, 99);
	trace->open("gstmcu.vcd");

	tb->interlace = 0;
	tb->resb = 1;
	tb->porb = 1;
	tick(0);
	tick(1);
	tb->resb = 0;
	tick(0);
	tick(1);
	tb->resb = 1;
	dump(false,false);
	dump(true,false);
	dump(true,true);

	trace->close();
}
