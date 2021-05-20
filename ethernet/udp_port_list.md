# UDP port list #

Formatted list of UDP ports, hexcode for that port, and brief description of where the target port goes. Entries with "NI" are proposed but not yet implemented. This list may not necessarily be up to data, look at constants in the [eth_common](@ref eth_common) package for a complete listing.


Port				|	hexcode				| Description
------------|---------------|-------------------
17000				|	0x4268				|	Configuration data
4096-4099		| 0x1000-0x1003	| SFP0 ADC Data
4100				| 0x1004				| SFP0 Loopback 
4352-4355		| 0x1100-0x1103	| SFP1 ADC Data
4356				| 0x1104				| SFP1 Loopback 
4608-4611		| 0x1200-0x1203 | RJ45 ADC Data
4612				| 0x1204				| RJ45 Loopback
8191				| 0x1999				| Sequencer serial program
8192				| 0x2000				| Sequencer program
8193				| 0x2001				| Sequencer timing slices
8194				| 0x2002				| Sequencer output slices
8195				| 0x2003				| Sequencer pointer functions
8196				| 0x2004				| Sequencer pointer reps 
8197				| 0x2005				| Sequencer subroutine addresses
8198				| 0x2006				| Sequencer subroutine reps
8448				| 0x2100				| CABAC program
8704				| 0x2200				| Monitoring readback
8960				| 0x2300				| CROC program
12288				| 0x3000				| Control signals
16384				| 0x4000				| EPCQ data (for firmware updates)
