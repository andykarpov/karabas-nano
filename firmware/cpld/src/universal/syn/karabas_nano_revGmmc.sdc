derive_clock_uncertainty
create_clock -period 28MHz -name {CLK28} [get_ports {CLK28}]
create_generated_clock -name {clk_14} -divide_by 2 -source [get_ports {CLK28}] [get_registers {clk_14}]
create_generated_clock -name {clk_7} -divide_by 4 -source [get_ports {CLK28}] [get_registers {clk_7}]
create_generated_clock -name {clkcpu} -divide_by 8 -source [get_ports {CLK28}] [get_registers {clkcpu}]

set_clock_groups -exclusive -group {clk_14}
set_clock_groups -exclusive -group {clk_7}
set_clock_groups -exclusive -group {clkcpu}

#set_clock_groups -exclusive -group {CLK28} -group {clk_14}
#set_clock_groups -exclusive -group {CLK28} -group {clk_7}
#set_clock_groups -exclusive -group {CLK28} -group {clkcpu}

create_clock -period 7MHz -name N_M1 N_M1
create_clock -period 1MHz -name TURBO TURBO
set_false_path -from [get_ports {N_M1}] -to [all_clocks]
set_false_path -from [get_ports {TURBO}] -to [all_clocks]
