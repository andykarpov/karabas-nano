derive_clock_uncertainty
create_clock -period 28MHz -name {CLK28} [get_ports {CLK28}]
create_clock -period 24MHz -name {CLK24} [get_ports {CLK24}]
create_generated_clock -name {clk_14} -divide_by 2 -source [get_ports {CLK28}] [get_registers {clk_14}]
create_generated_clock -name {clk_7} -divide_by 2 -source [get_ports {clk_14}] [get_registers {clk_7}]
create_generated_clock -name {clk_3_5} -divide_by 2 -source [get_ports {clk_7}] [get_registers {clk_3_5}]
create_generated_clock -name {clk_1_75} -divide_by 2 -source [get_ports {clk_3_5}] [get_registers {clk_1_75}]
create_generated_clock -name {clkcpu} -divide_by 4 -source [get_ports {CLK28}] [get_registers {clkcpu}]
create_generated_clock -name {clk_12} -divide_by 2 -source [get_ports {CLK24}] [get_registers {clk_12}]
create_generated_clock -name {clk_6} -divide_by 2 -source [get_ports {clk_12}] [get_registers {clk_6}]

set_clock_groups -exclusive -group {clk_14}
set_clock_groups -exclusive -group {clk_7}
set_clock_groups -exclusive -group {clkcpu}

set_clock_groups -exclusive -group {CLK28} -group {clk_14}
set_clock_groups -exclusive -group {CLK28} -group {clk_7}
set_clock_groups -exclusive -group {CLK28} -group {clkcpu}

create_clock -period 7MHz -name N_M1 N_M1
create_clock -period 1MHz -name TURBO TURBO
set_false_path -from [get_ports {N_M1}] -to [all_clocks]
set_false_path -from [get_ports {TURBO}] -to [all_clocks]
