# 50 MHz System Clock
set_property -dict { PACKAGE_PIN N11   IOSTANDARD LVCMOS33 } [get_ports { clk }];

# USB UART
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { usb_uart_rxd }];
set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { usb_uart_txd }];

# 8 Status LEDs (For Boot and Ready Flags)
set_property -dict { PACKAGE_PIN J3    IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN H3    IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN J1    IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports { led[3] }];
set_property -dict { PACKAGE_PIN L3    IOSTANDARD LVCMOS33 } [get_ports { led[4] }];
set_property -dict { PACKAGE_PIN L2    IOSTANDARD LVCMOS33 } [get_ports { led[5] }];
set_property -dict { PACKAGE_PIN K3    IOSTANDARD LVCMOS33 } [get_ports { led[6] }];
set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports { led[7] }];

# SDRAM Control Signals
set_property -dict { PACKAGE_PIN D13   IOSTANDARD LVCMOS33 } [get_ports { sdram_clk }];
set_property -dict { PACKAGE_PIN A15   IOSTANDARD LVCMOS33 } [get_ports { sdram_cke }];
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { sdram_cs_n }];
set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33 } [get_ports { sdram_ras_n }];
set_property -dict { PACKAGE_PIN C13   IOSTANDARD LVCMOS33 } [get_ports { sdram_cas_n }];
set_property -dict { PACKAGE_PIN C11   IOSTANDARD LVCMOS33 } [get_ports { sdram_we_n }];

# SDRAM Bank & Data Mask
set_property -dict { PACKAGE_PIN B14   IOSTANDARD LVCMOS33 } [get_ports { sdram_ba[0] }];
set_property -dict { PACKAGE_PIN B15   IOSTANDARD LVCMOS33 } [get_ports { sdram_ba[1] }];
set_property -dict { PACKAGE_PIN E12   IOSTANDARD LVCMOS33 } [get_ports { sdram_dqm[0] }];
set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { sdram_dqm[1] }];

# SDRAM Address Bus (13 bits)
set_property -dict { PACKAGE_PIN D11   IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[0] }];
set_property -dict { PACKAGE_PIN E11   IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[1] }];
set_property -dict { PACKAGE_PIN E13   IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[2] }];
set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[3] }];
set_property -dict { PACKAGE_PIN F3    IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[4] }];
set_property -dict { PACKAGE_PIN G2    IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[5] }];
set_property -dict { PACKAGE_PIN G1    IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[6] }];
set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[7] }];
set_property -dict { PACKAGE_PIN J5    IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[8] }];
set_property -dict { PACKAGE_PIN H2    IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[9] }];
set_property -dict { PACKAGE_PIN J4    IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[10] }];
set_property -dict { PACKAGE_PIN H4    IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[11] }];
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { sdram_addr[12] }];

# SDRAM Data Bus (16 bits)
set_property -dict { PACKAGE_PIN D8    IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[0] }];
set_property -dict { PACKAGE_PIN C8    IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[1] }];
set_property -dict { PACKAGE_PIN A8    IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[2] }];
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[3] }];
set_property -dict { PACKAGE_PIN B9    IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[4] }];
set_property -dict { PACKAGE_PIN A10   IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[5] }];
set_property -dict { PACKAGE_PIN B10   IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[6] }];
set_property -dict { PACKAGE_PIN C14   IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[7] }];
set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[8] }];
set_property -dict { PACKAGE_PIN A13   IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[9] }];
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[10] }];
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[11] }];
set_property -dict { PACKAGE_PIN C9    IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[12] }];
set_property -dict { PACKAGE_PIN A12   IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[13] }];
set_property -dict { PACKAGE_PIN B12   IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[14] }];
set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { sdram_dq[15] }];