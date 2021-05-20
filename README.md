# FPGA-Ethernet

This code is the Ethernet firmware interface code for the ODILE
mainboard, designed for CCD readout in the Dark Matter in CCDs-Modane
("DAMIC-M") project. The MAC used is the Altera Triple-Speed Ethernet,
intended to run at Gigabit speed in either fiber optical or through an
SGMII interface to copper RJ-45 (the PHY in that case is a Marvell
88E1111 chip). With different MAC configurations, it could probably
operate any type of Ethernet, with the appropriate changes to
configuration settings in the "tse_config_controller" block.

This codebase creates a full TCP/UDP data stack, and includes ICMP
echo (aka ping) reply, ARP reply/request, and multiple UDP
transmission pathways, designed for both continuous and intermittent
data paths. Data is routed to and from destinations on the FPGA
through UDP port addressing (see udp_port_list.md for examples).

Code in this repository is included as-is, in the hope it may be
useful to someone else. Some code is included for interfacing with the
CABAC and CROC chips (mezzanine cards on the ODILE). All code included
has been written by me: to avoid copyright issues, no Altera code is
included. Modelsim tesbenches for some code is included in the
testbench folder: some of these may not be updated for the latest
firmware, but most should work. They can be loaded in modelsim with
the command "do simulate_tb.tcl"

The design of the mainboard can be found here:
http://edg.uchicago.edu/~bogdan/DAMIC_ODILE/index.html