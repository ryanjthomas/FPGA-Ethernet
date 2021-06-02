#include "ODILEServer.hpp"
#include "udp_client_server.h"
#include "INIReader.h"
#include <fstream>
#include <iostream>
#include <string>
#include <unistd.h>

#define TCLAP_SETBASE_ZERO 1
#include "tclap/CmdLine.h"

#define BUFFSIZE 2048

using namespace udp_client_server;

int main (int argc, char *argv[]) {
	std::string outFname="out_data.bin";
	unsigned int port=0x1000;
	unsigned int npack=100;
	std::string ipAddress="192.168.0.1";
	bool readEPCQ=false;
	uint32_t startAddress=0x00000000;
	try {
		TCLAP::CmdLine cmd("Simple c++ program to read data from an ODILE board over Ethernet. Requires specifying the UDP port to read data from and the file to dump the data to. This program is fairly old and depreciated, should only be used for debugging purposes.", ' ', "0.2");
		TCLAP::ValueArg<unsigned int> portArg("p","port","Port to recieve data on", false, port,"integer", cmd);
		TCLAP::ValueArg<unsigned int> npackArg("n","number","Number of packets to recieeve", false, npack,"integer", cmd);
		TCLAP::ValueArg<std::string> outFnameArg("f", "file", "File to write binary data to", false, outFname, "string",cmd);
		TCLAP::ValueArg<std::string> ipAddressArg("i", "ip","Ip address to bind to", false, ipAddress, "string",cmd);
		TCLAP::ValueArg<uint32_t> startAddressArg("a","start","Start address when reading EPCQ device",false,startAddress,"uint32_t",cmd);
		TCLAP::SwitchArg readEPCQArg("e","epcq","Read automatically from EPCQ",cmd, readEPCQ);
		cmd.parse(argc, argv);
		port=portArg.getValue();
		npack=npackArg.getValue();
		outFname=outFnameArg.getValue();
		ipAddress=ipAddressArg.getValue();
		readEPCQ=readEPCQArg.getValue();
		startAddress=startAddressArg.getValue();
	} catch (TCLAP::ArgException &e) {
		std::cerr << "Error: " << e.error() << " for argument " << e.argId() << std::endl;
	}

	//udp_client config_client("192.168.0.3", 0x4268);
	// udp_server data_server(ipAddress, port);
	// std::ofstream out_file;
	// out_file.open(outFname, std::ios::out | std::ios::binary);
	// char buffer[BUFFSIZE];
	// for (unsigned int i=0; i < npack; i++) {
	// 	int packet_len=data_server.recv(buffer, BUFFSIZE);
	// 	out_file.write((char *)&buffer[0], packet_len);
	// }

	ODILEServer server("192.168.0.3");	
	if (readEPCQ) {
		server.readEPCQ(outFname,startAddress,npack);
	} else {
		server.launchAsyncThread(outFname,ipAddress,port, 10,100);
		sleep(10);
	}
	return 0;
}
