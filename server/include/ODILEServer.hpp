#ifndef ODILE_SERVER_HPP
#define ODILE_SERVER_HPP

#include "udp_client_server.h"
#include "ConfigBlockList.hpp"
#include <string>
#include <pthread.h>

#define NULL_IPADDRESS "0.0.0.0"
#define COMMAND_PORT 0x3000
#define FIRMWARE_PORT 0x4000

struct async_arg_t {
  bool stop;
  int port;
  int thread_id;
  std::string ip_address;
  std::string outfname;
  bool finished;
  int nrows;
  int ncols;
  int nread;
};

//Depreciated
enum ODILECommand {
  INV = 0x00494E56, //INValid
  SEX = 0x00534558, //Start EXposure
  AEX = 0x00414558, //Abort EXposure
  STS = 0x00535453, //STep sequencer
  GCT = 0x00474354, //Get Compile Time
  RDP = 0x00524450 //ReaD Program
};

namespace epcq_consts{
  const int PAGE_SIZE_BYTES=256;
  const int PAGE_SIZE_WORDS=int(PAGE_SIZE_BYTES/4);
  const int SECTOR_BYTES=65536;
}

class ODILEServer {
public:
  ODILEServer(std::string odile_address);
  ~ODILEServer();
  std::string odile_address;
  int sendConfigData();
  int sendConfigData(std::string inifile);
  int readConfigData(std::string inifile);
  int sendData(std::vector<uint32_t> data, int port);
  int sendData(std::string infile, int port);
  int sendCommand(std::string cmd_str, int prefix=0, uint32_t secondWord=0xFFFFFFFF);
  //Depreciated
  int sendCommand(ODILECommand cmd);  

  bool setNSkips(uint16_t nskips);
  bool setNSamples(uint16_t nsamples);
  bool setNTrigSamples(uint16_t nsamples);
  ConfigBlockList configBlocks;
  //Synchrounous receive functions
  int recieveData(std::vector<uint32_t> *data, std::string serv_address, int port, int timeout_ms=-1, bool swap_bytes=true);
  int recieveData(std::vector<uint32_t> *data, int port, int timeout_ms=-1, bool swap_bytes=true);
  //Wrappers to fix my type in "recieve"
  int receiveData(std::vector<uint32_t> *data, std::string serv_address, int port, int timeout_ms=-1, bool swap_bytes=true) {recieveData(data, serv_address, port, timeout_ms);};
  int receiveData(std::vector<uint32_t> *data, int port, int timeout_ms=-1, bool swap_bytes=true) {recieveData(data, port, timeout_ms, swap_bytes);};

  //Async thread handler functions
  int launchAsyncThread(std::string outfile, std::string serv_address, int port, int ncols=-1, int nrows=-1);
  int closeAsyncThread(int thread_id=0);
  bool isValidThread(int thread_id);
  int getWordsRead(int thread_id=0);
  int getWordsToRead(int nrows, int ncols, int nskips);
  //Helper to convert string to ODILECommand
  static ODILECommand stringToCommand(std::string cmd_str);
  static uint32_t stringToInt(std::string str);

  int writeFirmware(std::string fname, std::string mapfname, uint32_t start_address);
  bool waitForDone(std::string command="NON", int timeout_ms=1000);

  void setServerAddress(std::string new_address);

  int readEPCQ(std::string ofname, uint32_t start_address, int words_to_read);
  int writeEPCQ(std::vector<uint32_t> data, uint32_t start_address, bool perform_erase=true);

  int writeFlashConfig(int config_page);
  int writeFlashConfig(int config_page, std::string inifile);

  int writeFitsHeader(std::string fname, short ndcms, std::string amplifier, double exp_time, double read_time, std::string compile_time="");
  uint32_t getCompileTime();
  std::string getCompileTimeStr();
  
private:
  udp_client_server::udp_client configClient;
  udp_client_server::udp_client cmdClient;	
  std::vector<async_arg_t*> thread_args;
  std::vector<pthread_t> threads;
  std::string server_address;

};

#endif //ODILE_SERVER_HPP
