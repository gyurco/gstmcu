OBJ_DIR=obj_dir
VERILATOR_DIR=/usr/share/verilator/include

all: gstmcu

Vgstmcu.cpp: ${OBJ_DIR}/Vgstmcu.cpp

${OBJ_DIR}/Vgstmcu.cpp: gstmcu.v clockgen.v mcucontrol.v hsyncgen.v hdegen.v vsyncgen.v vdegen.v vidcnt.v sndcnt.v modules.v
	verilator --trace --top-module gstmcu -cc gstmcu.v clockgen.v mcucontrol.v hdegen.v hsyncgen.v vsyncgen.v vdegen.v vidcnt.v sndcnt.v modules.v

gstmcu: ${OBJ_DIR}/Vgstmcu.cpp gstmcu.cpp
	g++ -I $(OBJ_DIR) -I$(VERILATOR_DIR) $(VERILATOR_DIR)/verilated.cpp $(VERILATOR_DIR)/verilated_vcd_c.cpp gstmcu.cpp  $(OBJ_DIR)/Vgstmcu__Trace.cpp $(OBJ_DIR)/Vgstmcu__Trace__Slow.cpp $(OBJ_DIR)/Vgstmcu.cpp $(OBJ_DIR)/Vgstmcu__Syms.cpp -DOPT=-DVL_DEBUG -o gstmcu