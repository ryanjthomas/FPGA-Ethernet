#include "ODILEServer.hpp"
#include <fstream>
#include <vector>
#include <byteswap.h>
#include <ctime>
#include <unistd.h>

#define TCLAP_SETBASE_ZERO 1
#include "tclap/CmdLine.h"

using namespace udp_client_server;

int main (int argc, char *argv[]) {
	//Parse command line arguments
	std::string ipAddress="192.168.0.3";
	std::string servIpAddress="192.168.0.1";
	std::string mapFile="";
	std::string rpdFile="";
	uint32_t startAddress=0x01000000;
	bool forceWrite=false;
	int prefix=0;
	try {
		TCLAP::CmdLine cmd("Program to write new firmware to an ODILE flash memory over Ethernet", ' ', "0.1");
		TCLAP::ValueArg<std::string> ipAddressArg("i", "ip","IP address to send config data to", false, ipAddress, "string",cmd);
		TCLAP::ValueArg<std::string> mapFileArg("m", "map",".map file to read end address from", false, mapFile, "string",cmd);
		TCLAP::ValueArg<std::string> rpdFileArg("f", "file",".rpd file containing firmware", true, rpdFile, "string",cmd);
		TCLAP::ValueArg<uint32_t> startAddressArg("a", "address","Start address (in bytes) to write firmware to", false, startAddress, "uint32_t",cmd);
		TCLAP::SwitchArg forceWriteArg("","force","Force write to address",cmd, forceWrite);
		cmd.parse(argc, argv);
		ipAddress=ipAddressArg.getValue();
		mapFile=mapFileArg.getValue();
		rpdFile=rpdFileArg.getValue();
		startAddress=startAddressArg.getValue();
		forceWrite=forceWriteArg.getValue();
	} catch (TCLAP::ArgException &e) {
		std::cerr << "Error: " << e.error() << " for argument " << e.argId() << std::endl;
	}
	if (mapFile=="") {
		size_t idx=rpdFile.find(".rpd");
		mapFile=rpdFile;
		mapFile.replace(idx,4,".map");
		std::cout << ".map file not given, assuming file is: " << mapFile << std::endl;
	}
	if (startAddress != 0x1000000 && !forceWrite) {
		std::cout << "Warning, address is not application, rerun with force flag enabled to write firmware" << std::endl;
	}
	ODILEServer server(ipAddress);
	server.setServerAddress(servIpAddress);
	server.writeFirmware(rpdFile,mapFile,startAddress);	
}
