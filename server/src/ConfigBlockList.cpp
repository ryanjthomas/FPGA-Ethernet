/*
Holds the master list of all configuration register blocks and registers.
 */

#include "ConfigBlockList.hpp"
#include "INIReader.h"

#include <fstream>

ConfigEntry UNUSED_CONFIG(char address) {
	return ConfigEntry(0x0000, address, "UNUSED", "Unused");
};
ConfigBlockList::ConfigBlockList() : write_all(true) {	
	/***************************************************************************************
Ethernet configuration entries. Note that all interfaces should have different MAC and IP addresses, and the optical (SFP) and copper (RJ45) interfaces have different TSE configurations (or they won't work).
	****************************************************************************************/
	/*Mac Address Configuration*/
	ConfigEntry SFP0_MAC0 (0x4455, 0x00, "SFP0_MAC0", "Mac address bits[15:0] for SFP0 interface");
	ConfigEntry SFP1_MAC0 (0x4456, 0x00, "SFP1_MAC0", "Mac address bits[15:0] for SFP1 interface");
	ConfigEntry RJ45_MAC0 (0x4457, 0x00, "RJ45_MAC0", "Mac address bits[15:0] for RJ45 interface");
	ConfigEntry ENET_MAC1 (0x2233, 0x01, "ENET_MAC1", "Mac address bits[31:16] for Ethernet interface");
	ConfigEntry ENET_MAC2 (0xEE11, 0x02, "ENET_MAC2", "Mac address bits[47:32] for Ethernet interface");
	//0x03 unused
	ConfigEntry SFP_ServerMAC0 (0x7434, 0x04, "SFP_ServerMAC0", "Mac address bits[15:0] for SFP0/1 interface");
	ConfigEntry SFP_ServerMAC1 (0x1151, 0x05, "SFP_ServerMAC1", "Mac address bits[31:16] for SFP0/1 interface");
	ConfigEntry SFP_ServerMAC2 (0x6CB3, 0x06, "SFP_ServerMAC2", "Mac address bits[47:32] for SFP0/1 interface");

	ConfigEntry RJ45_ServerMAC0 (0x0275, 0x04, "RJ45_ServerMAC0", "Server Mac address bits[15:0] for RJ45 interface");
	ConfigEntry RJ45_ServerMAC1 (0x0C22, 0x05, "RJ45_ServerMAC1", "Server Mac address bits[31:16] for RJ45 interface");
	ConfigEntry RJ45_ServerMAC2 (0x000E, 0x06, "RJ45_ServerMAC2", "Server Mac address bits[47:32] for RJ45 interface");
	//0x07 unused

	/*Ip Address Configuration*/
	ConfigEntry SFP0_IP0 (0x0003, 0x08, "SFP_IP0", "IP address bits [15:0] for SFP interface");
	ConfigEntry SFP1_IP0 (0x0004, 0x08, "SFP_IP0", "IP address bits [15:0] for SFP interface");
	ConfigEntry RJ45_IP0 (0x0105, 0x08, "RJ45_IP0", "IP address bits [15:0] for RJ45 interface");
	ConfigEntry ENET_IP1 (0xC0A8, 0x09, "ENET_IP1", "IP address bits [31:16] for Ethernet interface");
	ConfigEntry SFP_ServerIP0 (0x0001, 0x0A, "SFP_ServerIP0", "Server IP address bits [15:0] for SFP0/1 interfaces");
	ConfigEntry RJ45_ServerIP0 (0x0101, 0x0A, "RJ45_ServerIP0", "Server IP address bits [15:0] for RJ45 interface");
	ConfigEntry ENET_ServerIP1 (0xC0A8, 0x0B, "ENET_ServerIP1", "Server IP address bits [31:16] for Ethernet interface");
	/*Configuration word for TSE controller*/
	ConfigEntry SFP_TSE0 (0x0058, 0x0C, "SFP_TSE0", "TSE configuration bits [15:0] for TSE MAC (SFP interface)"); //TODO: add complete explanation of all bits to description
	ConfigEntry ENET_TSE1 (0x0050, 0x0D, "ENET_TSE1", "TSE configuration bits [31:16] for TSE MAC");
	ConfigEntry RJ45_TSE0 (0x00D8, 0x0C, "RJ45_TSE0", "TSE configuration bits [15:0] for TSE MAC (RJ45 interface)"); //TODO: add complete explanation of all bits to description
	ConfigEntry SFP0_UDP (0x1000, 0x0E, "SFP0_UDP", "Base UDP address for SFP0 interface");
	ConfigEntry SFP1_UDP (0x1100, 0x0E, "SFP1_UDP", "Base UDP address for SFP1 interface");
	ConfigEntry RJ45_UDP (0x1200, 0x0E, "RJ45_UDP", "Base UDP address for RJ45 interface");
	//0x0F Unused

	/*FIFO Configuration*/
	ConfigEntry ENET_FIFO (0x0555, 0x10, "ENET_FIFO", "FIFO enable flags for Ethernet interfaces");
	ConfigEntry ENET_CounterEnable (0x0000, 0x11, "ENET_CounterEnable", "Counter enable flags for Ethernet interface");
	ConfigEntry ENET_PacketSize (0x012c, 0x12, "ENET_PacketSize", "Packet size (in 32-bit words) for Ethernet interfaces");
	//0x13 unused
	ConfigEntry ENET_HeaderConfig (0x0007, 0x14, "ENET_HeaderConfig", "Ethernet header configuration");

	/***************************************************************************************
Triple-speed ethernet configuration entries. Note that these are currently only used for the copper (RJ45) interface to configure the Marvel 88E1111 chip over the MDIO interface.
The MDIO is configured by reading the register, and then writing "(result & AND) | OR", where "AND" and "OR" are the AND and OR registers. 

Note that only the extended control register is usually enabled.
	****************************************************************************************/

	ConfigEntry TSE_MDIO_Ctrl0_OR(0x0140, 0x00, "TSE_MDIO_Ctrl0_OR", "MDIO Control Register OR bits");
	ConfigEntry TSE_MDIO_Ctrl0_AND(0x937F, 0x01, "TSE_MDIO_Ctrl0_AND", "MDIO Control Register AND bits");
	ConfigEntry TSE_MDIO_AN_OR(0x0000, 0x02, "TSE_MDIO_AN_OR", "MDIO Autonegotiation register OR bits");
	ConfigEntry TSE_MDIO_AN_AND(0xFC1F, 0x03, "TSE_MDIO_AN_AND", "MDIO Autonegotiation register AND bits");
	ConfigEntry TSE_MDIO_1000BASE_OR(0x0000, 0x04, "TSE_MDIO_1000BASE", "MDIO 1000BASE Register OR bits");
	ConfigEntry TSE_MDIO_1000BASE_AND(0xFFFF, 0x05, "TSE_MDIO_1000BASE", "MDIO 1000BASE Register AND bits");
	ConfigEntry TSE_MDIO_PHYCtrl_OR(0xC000, 0x06, "TSE_MDIO_MDIOCtrl", "MDIO PHY Control Register OR bits");
	ConfigEntry TSE_MDIO_PHYCtrl_AND(0xFFFF, 0x07, "TSE_MDIO_PHYCtrl", "MDIO PHY Control Register AND bits");
	ConfigEntry TSE_MDIO_ExtPHYStat_OR(0x0004, 0x08, "TSE_MDIO_ExtPHYStat", "MDIO Extended PHY Status Register OR bits");
	ConfigEntry TSE_MDIO_ExtPHYStat_AND(0xFFF4, 0x09, "TSE_MDIO_ExtPHYStat", "MDIO Extended PHY Status Register AND bits");
	ConfigEntry TSE_MDIO_ExtPHYCtrl_OR(0x0000, 0x0A, "TSE_MDIO_ExtPHYCtrl", "MDIO Extended PHY Control Register OR bits");
	ConfigEntry TSE_MDIO_ExtPHYCtrl_AND(0xFFFF, 0x0B, "TSE_MDIO_ExtPHYCtrl", "MDIO Extended PHY Control Register AND bits");
	ConfigEntry TSE_MDIO_ResetCycles0(0x03D8, 0x0C, "TSE_MDIO_ResetCycles0", "Clock cycles (bits [15:0]) to wait during a HW reset");
	ConfigEntry TSE_MDIO_ResetCycles1(0x0000, 0x0D, "TSE_MDIO_ResetCycles1", "Clock cycles (bits [31:16])to wait during a HW reset");
	ConfigEntry TSE_MDIO_WaitCycles0(0x4240, 0x0C, "TSE_MDIO_WaitCycles0", "Clock cycles (bits [15:0]) to wait after a HW reset before configuring the PHY");
	ConfigEntry TSE_MDIO_WaitCycles1(0x000F, 0x0D, "TSE_MDIO_WaitCycles1", "Clock cycles (bits [31:16])to wait after a HW reset before configuring the PHY");

	/***************************************************************************************
Configuration block for our ADCs. 
	****************************************************************************************/
	ConfigEntry ADC_Tap_Delays(0x0004, 0x00, "ADC_Tap_Delays","Tap delay for the 20-bit 1.6 Msps ADCs. Bits [2:0] set input tap delay, bits [6:4] control output tap delay, bits [11:8] control LVDS tap delay for CDS module");
	ConfigEntry ADC_Output_Config(0x0000, 0x02, "ADC_Output_Config", "Output config for the 20-bit ADCs. [0] LVDS, [1] CDS, [2] integral mode, [3] trigger mode");
	ConfigEntry ADC_CDS_NSkips(0x0001,0x04, "ADC_CDS_NSkips","Number of skips to perform CDS over");
	ConfigEntry ADC_CDS_Config(0x0001,0x05, "ADC_CDS_Config","Config for CDS block (bit 0 controls output average if hi, output sum of pixels if low)");
	ConfigEntry ADC_CDS_NSamples(0x0001,0x06, "ADC_CDS_NSamples","Number of samples to read in integral mode");
	ConfigEntry ADC_Trigger_Samples(0x0000,0x07, "ADC_Trigger_Samples", "Number of samples to read per trigger in triggered mode");
	ConfigEntry ADC_Trigger_Delay(0x0000,0x08, "ADC_Trigger_Delay", "Number of 100 MHz clock cycles to wait before starting CNVST");
	ConfigEntry ADC_Data_Multiplier(0x0001,0x09, "ADC_Data_Multiplier", "Multiplier to apply to ADC data before CDS module");
	
	ConfigRegisterBlock ADCConfigBlock = ConfigRegisterBlock(0x20,"ADCConfigBlock");
	ConfigRegisterBlock baseEnetBlock = ConfigRegisterBlock(0x10);

	//Now create our blocks for all three ethernet controllers
	ConfigRegisterBlock SFP0ConfigBlock = baseEnetBlock;
	ConfigRegisterBlock SFP1ConfigBlock = baseEnetBlock;
	ConfigRegisterBlock RJ45ConfigBlock = baseEnetBlock;

	//Now create our TSE configuration block
	ConfigRegisterBlock baseTSEConfigBlock = ConfigRegisterBlock(0x13);

	ConfigRegisterBlock SFP0TSEConfigBlock=baseTSEConfigBlock;
	ConfigRegisterBlock SFP1TSEConfigBlock=baseTSEConfigBlock;
	ConfigRegisterBlock RJ45TSEConfigBlock=baseTSEConfigBlock;

	baseEnetBlock.addEntry(SFP0_MAC0);
	baseEnetBlock.addEntry(ENET_MAC1);
	baseEnetBlock.addEntry(ENET_MAC2);
	baseEnetBlock.addEntry(ConfigEntry(0x03));
	baseEnetBlock.addEntry(SFP_ServerMAC0);
	baseEnetBlock.addEntry(SFP_ServerMAC1);
	baseEnetBlock.addEntry(SFP_ServerMAC2);
	baseEnetBlock.addEntry(ConfigEntry(0x07));
	baseEnetBlock.addEntry(SFP0_IP0);
	baseEnetBlock.addEntry(ENET_IP1);
	baseEnetBlock.addEntry(SFP_ServerIP0);
	baseEnetBlock.addEntry(ENET_ServerIP1);
	baseEnetBlock.addEntry(SFP_TSE0);
	baseEnetBlock.addEntry(ENET_TSE1);
	baseEnetBlock.addEntry(SFP0_UDP);
	baseEnetBlock.addEntry(ConfigEntry(0x0F));
	baseEnetBlock.addEntry(ENET_FIFO);
	baseEnetBlock.addEntry(ENET_CounterEnable);
	baseEnetBlock.addEntry(ENET_PacketSize);
	baseEnetBlock.addEntry(ConfigEntry(0x13));
	baseEnetBlock.addEntry(ENET_HeaderConfig);
	baseEnetBlock.addEntry(ConfigEntry(0x15));

	SFP0ConfigBlock=baseEnetBlock;
	SFP1ConfigBlock=baseEnetBlock;
	RJ45ConfigBlock=baseEnetBlock;

	SFP0ConfigBlock.setAddress(0x10);
	SFP0ConfigBlock.setName("SFP0ConfigBlock");
	SFP0ConfigBlock.config_entries[0]=SFP0_MAC0;
	SFP0ConfigBlock.config_entries[4]=SFP_ServerMAC0;
	SFP0ConfigBlock.config_entries[5]=SFP_ServerMAC1;
	SFP0ConfigBlock.config_entries[6]=SFP_ServerMAC2;
	SFP0ConfigBlock.config_entries[8]=SFP0_IP0;
	SFP0ConfigBlock.config_entries[10]=SFP_ServerIP0;
	SFP0ConfigBlock.config_entries[12]=SFP_TSE0;
	SFP0ConfigBlock.config_entries[14]=SFP0_UDP;

	SFP1ConfigBlock.setAddress(0x11);
	SFP1ConfigBlock.setName("SFP1ConfigBlock");
	SFP1ConfigBlock.config_entries[0]=SFP1_MAC0;
	SFP1ConfigBlock.config_entries[4]=SFP_ServerMAC0;
	SFP1ConfigBlock.config_entries[5]=SFP_ServerMAC1;
	SFP1ConfigBlock.config_entries[6]=SFP_ServerMAC2;
	SFP1ConfigBlock.config_entries[8]=SFP1_IP0;
	SFP1ConfigBlock.config_entries[10]=SFP_ServerIP0;
	SFP1ConfigBlock.config_entries[12]=SFP_TSE0;
	SFP1ConfigBlock.config_entries[14]=SFP1_UDP;

	RJ45ConfigBlock.setAddress(0x12);
	RJ45ConfigBlock.setName("RJ45ConfigBlock");
	RJ45ConfigBlock.config_entries[0]=RJ45_MAC0;
	RJ45ConfigBlock.config_entries[4]=RJ45_ServerMAC0;
	RJ45ConfigBlock.config_entries[5]=RJ45_ServerMAC1;
	RJ45ConfigBlock.config_entries[6]=RJ45_ServerMAC2;
	RJ45ConfigBlock.config_entries[8]=RJ45_IP0;
	RJ45ConfigBlock.config_entries[10]=RJ45_ServerIP0;
	RJ45ConfigBlock.config_entries[12]=RJ45_TSE0;
	RJ45ConfigBlock.config_entries[14]=RJ45_UDP;
	baseTSEConfigBlock.addEntry(TSE_MDIO_Ctrl0_OR);
	baseTSEConfigBlock.addEntry(TSE_MDIO_Ctrl0_AND);
	baseTSEConfigBlock.addEntry(TSE_MDIO_AN_OR);
	baseTSEConfigBlock.addEntry(TSE_MDIO_AN_AND);
	baseTSEConfigBlock.addEntry(TSE_MDIO_1000BASE_OR);
	baseTSEConfigBlock.addEntry(TSE_MDIO_1000BASE_AND);
	baseTSEConfigBlock.addEntry(TSE_MDIO_PHYCtrl_OR);
	baseTSEConfigBlock.addEntry(TSE_MDIO_PHYCtrl_AND);
	baseTSEConfigBlock.addEntry(TSE_MDIO_ExtPHYStat_OR);
	baseTSEConfigBlock.addEntry(TSE_MDIO_ExtPHYStat_AND);
	baseTSEConfigBlock.addEntry(TSE_MDIO_ExtPHYCtrl_OR);
	baseTSEConfigBlock.addEntry(TSE_MDIO_ExtPHYCtrl_AND);
	baseTSEConfigBlock.addEntry(TSE_MDIO_ResetCycles0);
	baseTSEConfigBlock.addEntry(TSE_MDIO_ResetCycles1);
	baseTSEConfigBlock.addEntry(TSE_MDIO_WaitCycles0);
	baseTSEConfigBlock.addEntry(TSE_MDIO_WaitCycles1);

	SFP0TSEConfigBlock=baseTSEConfigBlock;
	SFP1TSEConfigBlock=baseTSEConfigBlock;
	RJ45TSEConfigBlock=baseTSEConfigBlock;
	
	SFP0TSEConfigBlock.setName("SFP0TSEConfigBlock");
	SFP1TSEConfigBlock.setName("SFP1TSEConfigBlock");
	RJ45TSEConfigBlock.setName("RJ45TSEConfigBlock");


	SFP0TSEConfigBlock.setAddress(0x13);
	SFP1TSEConfigBlock.setAddress(0x14);
	RJ45TSEConfigBlock.setAddress(0x15);

	ADCConfigBlock.addEntry(ADC_Tap_Delays);
	ADCConfigBlock.addEntry(ADC_Output_Config);
	ADCConfigBlock.addEntry(ADC_CDS_NSkips);
	ADCConfigBlock.addEntry(ADC_CDS_Config);
	ADCConfigBlock.addEntry(ADC_CDS_NSamples);
	ADCConfigBlock.addEntry(ADC_Trigger_Samples);
 	ADCConfigBlock.addEntry(ADC_Trigger_Delay);
 	ADCConfigBlock.addEntry(ADC_Data_Multiplier);
	
	//Add the blocks to our list
	blocks.push_back(SFP0ConfigBlock);
	blocks.push_back(SFP1ConfigBlock);
	blocks.push_back(RJ45ConfigBlock);
	blocks.push_back(SFP0TSEConfigBlock);
	blocks.push_back(SFP1TSEConfigBlock);
	blocks.push_back(RJ45TSEConfigBlock);
	blocks.push_back(ADCConfigBlock);
	

};

int ConfigBlockList::readINI(std::string inifile) {
	INIReader reader(inifile);
	int error = reader.ParseError();

	for (unsigned int i=0; i < blocks.size(); i++) {
		blocks[i].readINI(reader);
		blocks[i].createConfigMessages(write_all);
	};
	return error;
}

std::vector<uint32_t> ConfigBlockList::getConfigMessage() {
	std::vector<uint32_t> master_message;
	//std::cout << "Blocks size is: " << blocks.size() << std::endl;
	for (unsigned int i=0; i <  blocks.size(); i++) {
		std::vector<uint32_t> message = blocks[i].getConfigMessages(write_all);
		//master_message.insert(master_message.end(), message.begin(), message.end());
		for (unsigned int j=0; j < message.size(); j++) {
			master_message.push_back(message[j]);
		};
	};
	return master_message;
};

bool ConfigBlockList::writeINI(std::string inifile) {
	std::ofstream ofile;
	ofile.open(inifile);
	for (unsigned int i=0; i < blocks.size(); i++) {
		blocks[i].writeINI(ofile, true,true);
	}
	ofile.close();
	return true;
};

ConfigRegisterBlock& ConfigBlockList::getBlock(std::string name) {
	for (int i=0; i < blocks.size(); i++) {
		if (blocks[i].name==name) {
			return blocks[i];
		}
	}
};
	
