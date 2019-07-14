#!/bin/sh

export PATH=$PATH:/opt/bin
ghdl -a --ieee=synopsys zcontroller.vhd
ghdl -a --ieee=synopsys karabas_nano_revB.vhd
ghdl -a --ieee=synopsys karabas_nano_tb.vhd
ghdl -e --ieee=synopsys karabas_nano_tb
ghdl -r --ieee=synopsys karabas_nano_tb --stop-time=100ms --wave=karabas_nano_revB.ghw

