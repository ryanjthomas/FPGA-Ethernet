#include "ConfigBlockList.hpp"
#include "ODILEServer.hpp"
#include "udp_client_server.h"
#include "INIReader.h"
#include <fstream>

#define TCLAP_SETBASE_ZERO 1
#include "tclap/CmdLine.h"

using namespace udp_client_server;

//Constrain our config page value to 0-9
class PageConstraint : public TCLAP::Constraint<int> {
public:
	virtual bool check(const int & value) const { if (value >=0 and value <= 9) return true; else return false;}
	virtual std::string description() const { return "Page value must be in range [0,9]";}
	virtual std::string shortID() const {return "int";}
};

int main (int argc, char *argv[]) {
	//Parse command line arguments
	std::string ipAddress="192.168.0.3";
	std::string configFname="config.ini";
	bool enableDebug=false;
	bool writeDefault=false;
	bool flashConfig=false;
	int configPage=0;
	try {
		TCLAP::CmdLine cmd("Simple c++ program to write configuration data to an ODILE board over Ethernet", ' ', "0.1");
		TCLAP::ValueArg<std::string> ipAddressArg("i", "ip","IP address to send config data to", false, ipAddress, "string",cmd);
		TCLAP::ValueArg<std::string> configFnameArg("c", "config","Configuration file to read from", false, configFname, "string",cmd);
		TCLAP::SwitchArg enableDebugArg("d","debug", "Enable debug output", cmd,enableDebug);
		TCLAP::SwitchArg writeDefaultArg("w","write","Regenerate default.ini file", cmd, writeDefault);
		TCLAP::SwitchArg flashConfigArg("f","flash","Write the configuration to flash",cmd,flashConfig);
		PageConstraint page_constraint=PageConstraint();
		TCLAP::ValueArg<int> configPageArg("p","page","Config page",false,configPage, &page_constraint,cmd);		
		cmd.parse(argc, argv);
		ipAddress=ipAddressArg.getValue();
		configFname=configFnameArg.getValue();
		enableDebug=enableDebugArg.getValue();
		writeDefault=writeDefaultArg.getValue();
		flashConfig=flashConfigArg.getValue();
		configPage=configPageArg.getValue();
	} catch (TCLAP::ArgException &e) {
		std::cerr << "Error: " << e.error() << " for argument " << e.argId() << std::endl;
	}
	ODILEServer server(ipAddress);
	if (flashConfig) {
		server.writeFlashConfig(configPage,configFname);
	}	else {
		server.sendConfigData(configFname);
	}

	if (writeDefault) {
	//Write a default configuration file
		server.configBlocks.writeINI("default.ini");
		// std::ofstream def_ini;
		// def_ini.open("default.ini");
		// SFP0ConfigBlock.writeINI(def_ini, true,true);
		// SFP1ConfigBlock.writeINI(def_ini, true,true);		
		// RJ45ConfigBlock.writeINI(def_ini, true, true);
		// ADCConfigBlock.writeINI(def_ini, true, true);
		// def_ini.close();
	}

	//Parse and generate bitstreams for configuration
	// INIReader reader(configFname);	
	// int conf_port=reader.GetInteger("default", "configuration_port", 0x4268);
		
	// udp_client config_client(ipAddress, conf_port);

	if (enableDebug) {
		for (unsigned int i=0; i < server.configBlocks.blocks[0].config_messages.size(); i++) {
			printHex(4,(char *) &server.configBlocks.blocks[0].config_messages[i]);
			std::cout << std::endl;
			//		std::cout << std::endl << SFP0ConfigBlock.config_messages[i] << std::endl;
		};
		
		//printHex(RJ45ConfigBlock.config_messages.size()*sizeof(RJ45ConfigBlock.config_entries[0].value),(char *) &RJ45ConfigBlock.config_messages[0]);
		printHex(server.configBlocks.blocks[2].config_messages.size()*sizeof(server.configBlocks.blocks[2].config_entries[0].value),(char *) &server.configBlocks.blocks[2].config_messages[0]);
	}
	
	return 0;
}
