# Atari STE GST MCU + GST Shifter
Simulation model of the Atari STE GSTMCU + Shifter

This repository contains a Verilog model of the Atari STE GST MCU (Glue + MMU combo).
The model tries to be an exact replica based on the [schematics recovered](https://www.chzsoft.de/asic-web/) by Christian Zietz.
The code contains both the identical gate-level circuits with asynchronous clocking, and a synchronous model hopefully suitable for FPGA synthesis.

# Testbench

The tb/ directory contains a testbench, which runs the circuits to generate waveforms for several frames. Also an rgb file is created using a RAM dump.
To run the test:

```
cd tb
gzip -d stram.bin.gz
make
./ste_tb
```

To see the genarated waveforms:

```
gtkwave gstmcu.vcd
```

To see a generated video frame:

```
make video
```
