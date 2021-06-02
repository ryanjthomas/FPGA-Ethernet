#include "ConfigBlockList.hpp"
#include "ODILEServer.hpp"
#include "udp_client_server.h"
#include "INIReader.h"
#include <fstream>

#define TCLAP_SETBASE_ZERO 1
#include "tclap/CmdLine.h"

using namespace udp_client_server;

int main (int argc, char *argv[]) {
	//Parse command line arguments
	std::string ipAddress="192.168.0.3";
	std::string inFname="";
	bool enableDebug=false;
	int port=0x2000;
	try {
		TCLAP::CmdLine cmd("Simple c++ program to write data to an ODILE board over Ethernet", ' ', "0.1");
		TCLAP::ValueArg<std::string> ipAddressArg("i", "ip","IP address to send data to", false, ipAddress, "string",cmd);
		TCLAP::ValueArg<std::string> inFnameArg("f", "file","Configuration file to read from", true, inFname, "string",cmd);
		TCLAP::ValueArg<int> portArg("p","port","UDP port to send data to", false, port,"int",cmd);
		TCLAP::SwitchArg enableDebugArg("d","debug", "Enable debug output", cmd,enableDebug);
		cmd.parse(argc, argv);
		ipAddress=ipAddressArg.getValue();
		inFname=inFnameArg.getValue();
		enableDebug=enableDebugArg.getValue();
		port=portArg.getValue();
	} catch (TCLAP::ArgException &e) {
		std::cerr << "Error: " << e.error() << " for argument " << e.argId() << std::endl;
	}
	ODILEServer server(ipAddress);
	server.sendData(inFname, port);
	
	return 0;
}
