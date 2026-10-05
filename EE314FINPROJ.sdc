## ============================================================================
## EE314FINPROJ.sdc  — clean timing constraints for the fighting-game project
## Replaces the Terasic default, which referenced many ports this design does
## not have (CLOCK2_50, TD_CLK27, DRAM_*, AUD_*, VGA_BLANK ...) and set a wrong
## 108 MHz VGA clock. Here only the real 50 MHz input clock is constrained; the
## internal /2 pixel clock is declared as a generated clock; asynchronous human
## inputs and slow display/LED outputs are excluded from timing.
## ============================================================================

# 50 MHz board clock (20 ns period)
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# Internal 25 MHz pixel clock = CLOCK_50 / 2 (toggle FF inside clock_divider)
create_generated_clock -name PIX_CLK -source [get_ports CLOCK_50] \
    -divide_by 2 [get_registers {*clk_25mhz*}]

derive_clock_uncertainty

# Asynchronous, debounced human inputs — no setup/hold relationship to model
set_false_path -from [get_ports {KEY[*] SW[*] GPIO[*]}] -to [all_registers]

# Display / 7-seg / LED outputs drive slow, human-visible devices: cut timing
set_false_path -to [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS \
    VGA_CLK VGA_BLANK_N VGA_SYNC_N HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] \
    HEX5[*] LEDR[*]}]
