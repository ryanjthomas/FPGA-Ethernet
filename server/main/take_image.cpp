#include "ODILEServer.hpp"
#include <fstream>
#include <vector>
#include <byteswap.h>
#include <ctime>
#include <unistd.h>
#include "utils.hpp"
#include <sys/stat.h>

#define TCLAP_SETBASE_ZERO 1
#include "tclap/CmdLine.h"

using namespace udp_client_server;

int main (int argc, char *argv[]) {
	//Parse command line arguments
	std::string ipAddress="192.168.0.3";
	std::string servIpAddress="192.168.0.1";
	std::string imageFname="test.fits";
	std::string configFname="config.ini";
	int port=0x1202;
	int ncols=1100;
	int nrows=6000;
	short nskips=1;
	bool odileAvgSkips=false;
	int nTrigSamps=-1;
	try {
		TCLAP::CmdLine cmd("Standalone program to setup and read data from ODILE board for image acquisition.", ' ', "0.1");
		TCLAP::ValueArg<std::string> ipAddressArg("i", "ip","IP address of ODILE", false, ipAddress, "string",cmd);
		TCLAP::ValueArg<std::string> servIpAddressArg("s", "sip","IP address of PC", false, servIpAddress, "string",cmd);		
		TCLAP::ValueArg<std::string> imageFnameArg("f", "file","Output file to write image data to", false, imageFname, "string",cmd);
		TCLAP::ValueArg<std::string> configFnameArg("c","config","Configuration file to use taking image", false, configFname, "string",cmd);
		TCLAP::ValueArg<int> portArg("p","port","UDP port to read data from",false, port,"int",cmd);
		TCLAP::ValueArg<int> ncolsArg("n","ncols","Number of columns of the CCD to read (in non-skipper mode, should be cols*NDCMs)",false, port,"int",cmd);
		TCLAP::ValueArg<int> nrowsArg("r","nrows","Number of rows of the CCD to read",false, port,"int",cmd);
		TCLAP::ValueArg<short> nskipsArg("k","nskips","Number of NDCMs (only added to header)",false, nskips,"short",cmd);
		TCLAP::SwitchArg odileAvgSkipsArg("a","oaskip","Set ODILE to average over number of skips set by nskips parameter",cmd, odileAvgSkips);
		TCLAP::ValueArg<int> nTrigSampsArg("S","samps","Number of samples per trigger to average over",false,nTrigSamps,"uint16_t", cmd);
		cmd.parse(argc, argv);
		ipAddress=ipAddressArg.getValue();
		servIpAddress=servIpAddressArg.getValue();
		imageFname=imageFnameArg.getValue();
		configFname=configFnameArg.getValue();
		ncols=ncolsArg.getValue();
		nrows=nrowsArg.getValue();
		port=portArg.getValue();
		nskips=nskipsArg.getValue();
		odileAvgSkips=odileAvgSkipsArg.getValue();
		nTrigSamps=nTrigSampsArg.getValue();

	} catch (TCLAP::ArgException &e) {
		std::cerr << "Error: " << e.error() << " for argument " << e.argId() << std::endl;
	}

	struct stat buffer;
	if (stat (imageFname.c_str(), &buffer) == 0){
	  std::cout << "The specified output file already exist. Please specify a different name for the output.\n";
	  return -1;
	}

	ODILEServer server(ipAddress);
	//Load configuration for image taking
	server.readConfigData(configFname);
	//Set command line configuration parameters
	if (odileAvgSkips) {
	  server.setNSkips(nskips);
	  std::cout << "Averaging over " << nskips << " skips." << std::endl;
	}
	if (nTrigSamps > 0) {
	  server.setNTrigSamples(nTrigSamps);
	}
	
	server.sendConfigData();
	sleep(1); //Give the ODILE a second to clear it's previous configuration
	//int npix=ncols*nrows;
	int npix=server.getWordsToRead(nrows,ncols,nskips);
	//If we don't average over skips on the ODILE, need to make the .fits file wider
	int fits_cols=npix/nrows;
	int threadID=server.launchAsyncThread(imageFname,servIpAddress,port,nrows, fits_cols);
	std::cout << "Reading " << npix << " samples." << std::endl;
	int npixRead=0;
	while (npixRead<npix) {
		sleep(1);
		npixRead = server.getWordsRead(threadID);		
		print_progress(npixRead*1.0/npix);
	}
	//Placeholder
	std::string ctime=server.getCompileTimeStr();
	server.writeFitsHeader(imageFname, nskips, "L", 5, 100, ctime);
	std::cout <<std::endl <<  "Read a total of " << npixRead << " words." << std::endl;
};
