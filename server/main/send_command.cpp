#include "ConfigBlockList.hpp"
#include "ODILEServer.hpp"
#include "udp_client_server.h"
#include "INIReader.h"
#include <fstream>
#include <vector>
#include <byteswap.h>
#include <ctime>
#include <unistd.h>
#include <cstdio>

#define TCLAP_SETBASE_ZERO 1
#include "tclap/CmdLine.h"

using namespace udp_client_server;

int main (int argc, char *argv[]) {
	//Parse command line arguments
	std::string ipAddress="192.168.0.3";
	std::string servIpAddress="192.168.0.1";
	std::string command="";
	std::string outFname="";
	uint32_t secondWord=0xFFFFFFFF;
	int prefix=0;
	bool waitResponse=false;
	bool enableDebug=false;
	try {
		TCLAP::CmdLine cmd("Standalone C++ program to send commands to an ODILE board over Ethernet", ' ', "0.1");
		TCLAP::ValueArg<std::string> ipAddressArg("i", "ip","IP address of ODILE to send command to", false, ipAddress, "string",cmd);
		TCLAP::ValueArg<std::string> commandArg("c", "command","Command to send to board to board. Should be 3 ASCII characters long (see documentation for list of valid commands).", false, command, "string",cmd);
		TCLAP::ValueArg<std::string> outFnameArg("f","file", "File to dump output to. Used when commands produce length response, such as when dumping configuration registers. ", false, outFname, "string", cmd);
		TCLAP::SwitchArg enableDebugArg("d","debug", "Enable debug output", cmd,enableDebug);
		TCLAP::SwitchArg waitResponseArg("r","response", "Wait for response from ODILE. Will print out simple responses to commands such as 'INV' if the command is invalid.", cmd, waitResponse);
		TCLAP::ValueArg<int> prefixArg("p", "prefix","8-bit command prefix. Allows sending 8-bit prefixes to the 24-bit commands. Used for some commands to pass in additional parameters for the command.",false, prefix, "uint8_t",cmd);
		TCLAP::ValueArg<uint32_t> secondWordArg("w","second","second word to send with command. Sends a second 32-bit word after the command, used with some commands to pass in additional parameters.",false, secondWord, "uint32_t", cmd);
		cmd.parse(argc, argv);
		ipAddress=ipAddressArg.getValue();
		enableDebug=enableDebugArg.getValue();
		command=commandArg.getValue();
		waitResponse=waitResponseArg.getValue();
		outFname=outFnameArg.getValue();
		prefix=prefixArg.getValue();
		secondWord=secondWordArg.getValue();
	} catch (TCLAP::ArgException &e) {
		std::cerr << "Error: " << e.error() << " for argument " << e.argId() << std::endl;
	}
	ODILEServer server(ipAddress);
	// if (ODILEServer::stringToCommand(command) == INV ) {
	// 	std::cout << "Error, command not valid" << std::endl;
	// 	return 1;
	//};
	if (outFname !=""){
		//Sequencer buffer reads
		if (command == "RDP" || command == "RDT" || command == "RDO" || command == "RDF" ||
				 command == "RDR" || command == "RDA" || command == "RDS") {
			server.launchAsyncThread(outFname,servIpAddress,0x1999,0,0);
			//Configuration register read
		}  else if (command == "RDB") {
			server.launchAsyncThread(outFname,servIpAddress,0x4268,0,0);
		} 
	}
	//CABAC buffer read
	if (command == "RDC" || command == "GCM") {
		if (outFname == "") {
			outFname="temp_cabac_delete.txt";
		}
		if (command=="RDC") {
			server.launchAsyncThread(outFname,servIpAddress,0x2100,0,0);
		}	else if (command =="GCM") {
			server.launchAsyncThread(outFname,servIpAddress,0x2200,0,0);
		}
	}
	sleep(1);
	
	std::vector<uint32_t> data;
	int words_sent  = server.sendCommand(command, prefix, secondWord);
	//std::cout << "Sent: " << words_sent/4 << " words. " << std::endl;
	if (waitResponse) {
		int words_recvd = server.recieveData(&data, servIpAddress, 0x3000);
		if (enableDebug) {
			std::cout << "Recieved: " << words_recvd << " words. " << std::endl;
			for (int i=0; i < words_recvd; i++){
				uint32_t word=data[i] & 0x7fffff;
				std::cout << std::hex << word << ' ';
			}
			std::cout << std::endl;
		}
		if (command=="GCT") {
			uint32_t compiletime=data[1];
			time_t temp=compiletime;
			if (enableDebug)
				std::cout <<  compiletime << std::endl;
			std::cout << "Firmware was compiled at: " << std::asctime(std::localtime(&temp)) << std::endl;
		} else if (command=="GUT") {
			uint32_t uptime=data[1];
			time_t temp=uptime;
			std::cout << "System has been running for: " << uptime << " seconds (roughly)" << std::endl;
		} else if (command=="GEC") {
			uint32_t errcode=data[1];
			std::cout << "Error code is: 0x" << std::hex << errcode << std::endl;
		} else if (command=="GCL") {
			std::cout << "Valid commands are: ";
			char *charData = (char*)&data[0];
			for (int i=1; i < data.size()-1; i++) {
				for (int j=2; j >=0; j--) {
					std::cout << charData[i*4+j];
				}
				std::cout << ",";
			}
			std::cout << std::endl;
		} else {
			std::cout << "Recieved responses: ";
			char *charData = (char*)&data[0];
			for (int i=0; i < words_recvd; i++) {
				for (int j=2; j >=0; j--) {
					std::cout << charData[i*4+j] << ' ';
				}
				std::cout << " ";
			};
		}

		//Now read out CABAC buffer when appropriate
		if (command=="RDC" || command == "GCM") {
			std::ifstream cabacfile(outFname);
			std::cout << std::endl << "Register is: ";
			if (cabacfile.is_open()) {
				std::cout << cabacfile.rdbuf();
			}
			//Now delete the temporary file
			if (outFname=="temp_cabac_delete.txt") {
				std::remove(outFname.c_str());
			}
		}
		std::cout << std::endl;
	}
	// std::cout << "Closing read thread..." << std::endl;
	// server.closeAsyncThread(0);
	// std::cout << "Read thread closed.." << std::endl;

	sleep(1);
	
	return 0;
}
