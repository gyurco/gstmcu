OBJ_DIR=obj_dir
VERILATOR_DIR=/usr/share/verilator/include
HDL_FILES = ../hdl/gstmcu.v ../hdl/clockgen.v ../hdl/mcucontrol.v ../hdl/hsyncgen.v ../hdl/hdegen.v ../hdl/vsyncgen.v ../hdl/vdegen.v ../hdl/vidcnt.v ../hdl/sndcnt.v ../hdl/latch.v ../hdl/register.v ../hdl/modules.v ../hdl/gstshifter.v ../hdl/shifter_video.v ../hdl/shifter_video_async.v

default: run

Vste_tb.cpp: ${OBJ_DIR}/Vste_tb.cpp


${OBJ_DIR}/Vste_tb.cpp: ste_tb.v dma_tb.v ${HDL_FILES}
	verilator -cc --exe -MMD --trace --top-module ste_tb ste_tb.cpp ste_tb.v ${HDL_FILES}

ste_tb: ${OBJ_DIR}/Vste_tb.cpp ste_tb.cpp
	$(MAKE) -j 4 -C obj_dir -f ../Makefile_obj
#	g++ -I $(OBJ_DIR) -I$(VERILATOR_DIR) $(VERILATOR_DIR)/verilated.cpp $(VERILATOR_DIR)/verilated_vcd_c.cpp ste_tb.cpp  $(OBJ_DIR)/Vste_tb__Trace.cpp $(OBJ_DIR)/Vste_tb__Trace__Slow.cpp $(OBJ_DIR)/Vste_tb.cpp $(OBJ_DIR)/Vste_tb__Syms.cpp -DOPT=-DVL_DEBUG -o ste_tb

run: ste_tb
	obj_dir/Vste_tb

video: video.png

video.png: video.rgb
	rm -f video.png
	ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt rgb444 -s 2048x313 -i video.rgb -f image2 -vcodec png video.png
	display video.png
