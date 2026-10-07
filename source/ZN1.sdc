derive_pll_clocks
derive_clock_uncertainty

create_generated_clock -name {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -source {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|vco0ph[0]} -divide_by 5 -multiply_by 1 -duty_cycle 50.00 { emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk }

set_false_path -from {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} -to {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk} -to {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from {FPGA_CLK1_50} -to {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from {FPGA_CLK2_50} -to {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}

set_false_path -from {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
set_false_path -from {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}
set_false_path -from {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}
set_false_path -from {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {FPGA_CLK1_50}

# External sound board: the 128-bit SDRAM channel-3 read line (clk_3x) is only sampled by the
# sound board (clk_1x) after ch3_ready, and it cannot change until the next request is issued.
set_false_path -from [get_registers {*|sdram:sdram|ch3_dout128[*]}] -to [get_registers {*|zn_ext_audio:ext_audio|*}]

# Cheat-engine bus -> SDRAM channel-3 input buffers (clk_1x -> clk_3x). ch3buf_* are re-sampled
# every clk_3x and only used by a request that is held for a whole clk_1x cycle, so capturing the
# new value one clk_3x early is harmless; the cheat engine is never selected while an external
# sound board owns channel 3.
set_false_path -hold -from [get_registers {*|cheats:icheats|*}] -to [get_registers {*|sdram:sdram|ch3buf_*}]
