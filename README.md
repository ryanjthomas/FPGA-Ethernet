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
included.

The design of the mainboard can be found here:
http://edg.uchicago.edu/~bogdan/DAMIC_ODILE/index.html

## Organization

All code related to the Ethernet interface proper is in the "ethernet"
folder. Other folders contain specific functionality driven by
Ethernet signal, or used by the Ethernet block ("common_modules"
specifically).

## Requirements

Code was developed using Quartus Prime 13.0sp1. In order to actually
use this code, you would need to create the Altera megafunctions used:
the main requirement is the Triple-Speed Ethernet megafunction. A
handful of other functions are used as well (mainly FIFOs for various
buffers, and the ALTREMOTE_UPDATE and ALTASMI_PARALLEL to access the
remote update hardware and EPCQIO flash memory, respectively).

## Testbenches

Testbenches for some of the blocks is included in the "testbenches"
folder. These are meant to be run using Modelsim Altera edition, using
the included "simulate_??.tcl" scripts. Testbenches include
verification of some basic functionality.

## Server Code

Some example C++ server code is included in the "server" to interface
with the FPGA code. This code includes the
[udp_client_server](https://linux.m2osw.com/c-implementation-udp-clientserver)
and [tclap](http://tclap.sourceforge.net) libraries, copyright their
respective owners. This code is distributed under a GPLv3 license to
retain compatibility with the libaries.