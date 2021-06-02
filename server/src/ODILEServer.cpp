#include "ODILEServer.hpp"

#include <fstream>
#include <pthread.h>
#include <byteswap.h>
//To properly format hex to text files
#include <iomanip>
#include <iostream>
#include <sys/time.h>

//#if defined __has_include
// #if __has_include(<cfitsio.h>)
#ifdef CFITSIO_INSTALLED
#include "fitsio.h"
#endif //CFITSIO_INSTALLED
// #endif //has_include
// #endif //defined has_include

using namespace udp_client_server;

#define BUFFSIZE 2048
#define WAIT_TIME 1000

//Start addresses for our 10 configuration pages. Each one starts at a sector edge in the flash memory (so we can erase pages independently).
uint32_t CONFIG_PAGE_ADDRESS[10] = {0x01F60000,0x01F70000,0x01F80000,0x01F90000,0x01FA0000,
				    0x01FB0000,0x01FC0000,0x01FD0000,0x01FE0000,0x01FF0000};

																			
ODILEServer::ODILEServer(std::string odile_address) : odile_address(odile_address), configClient(odile_address,0x4268), cmdClient(odile_address, 0x3000) {
  //Setup our configuration data blocks
  configBlocks=ConfigBlockList();
  server_address=NULL_IPADDRESS;
};

ODILEServer::~ODILEServer() {
  //Cleanup any asyncronous threads we have lying around
  for (unsigned int i=0; i< thread_args.size(); i++) {
    closeAsyncThread(i);
  };
}

/*
  Sends configuration data from specified .ini file to the ODILE board.
*/
int ODILEServer::sendConfigData(std::string inifile) {
  //Reads the .ini file and load it into our configuration block
  readConfigData(inifile);
  return sendConfigData();
}

/*
  Sends currently loaded configuration data to our ODILE board. Returns the number of bytes sent.
*/
int ODILEServer::sendConfigData(){
  std::vector<uint32_t> config_message=configBlocks.getConfigMessage();
  //return configClient.send((char *) &config_message[0], config_message.size()*sizeof(config_message[0]));
  return configClient.send(config_message);
};

//Reads configuration data from a .ini file
int ODILEServer::readConfigData(std::string inifile) {
  int readError=configBlocks.readINI(inifile);
  if (readError != 0) {
    std::cout << "Error reading configuration file, error on line: " << readError << std::endl;
  };
  return configBlocks.readINI(inifile);
};

// int ODILEServer::sendCommand(std::string cmd_str) {
// 	return sendCommand(stringToCommand(cmd_str));
// };

/*
  Blocks until we recieve the 'DON' signal from the ODILE board on the command UDP port. 
  <	If timeout_ms is < 0, waits indefinitely, otherwise waits for the timeout.
*/
bool ODILEServer::waitForDone(std::string command, int timeout_ms) {
  int bytes_recvd=-1;
  std::vector<uint32_t> buffer;
  bool timed_out=false;
  timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  long starttime=ts.tv_nsec/1000/1000;
  //Wait until we time our *or* recieve back 'DON' signal
  while (timed_out==false) {
    //Receive our data
    bytes_recvd=recieveData(&buffer, COMMAND_PORT, timeout_ms/10);
    clock_gettime(CLOCK_REALTIME,&ts);
    if (bytes_recvd>0) {
      //scan over our buffer for 'DON'
      for (int i=0; i < buffer.size(); i++) {
	//Mask the top 8 bits (only care about bottom 24)
	if ((buffer[i] & 0x00FFFFFF)==0x00444F4E) {
	  return true;
	};
      };
    } 
    long currtime=ts.tv_nsec/1000/1000;
    if (timeout_ms > 0 & ((currtime-starttime) > timeout_ms)) {
      timed_out=true;
      return false;
    }
  }
  return false;
};

//Old command sending code.
int ODILEServer::sendCommand(ODILECommand cmd) {
  if (cmd==INV) return -1;
  std::vector<uint32_t> data;
  data.push_back(bswap_32(cmd));
  return cmdClient.send(data);
};

/*
  Sends a single command word to the ODILE. If prefix is specified, sets the 8-bit prefix for the command. 
  If secondWord is not 0xFFFFFFFF, also sends that after the command.
*/
int ODILEServer::sendCommand(std::string cmd, int prefix, uint32_t secondWord) {
  std::vector<uint32_t> data;
  if (cmd.length() != 3) {
    std::cout << "Error, command has invalid length..." << std::endl;
    return -1;
  }
  uint32_t word=stringToInt(cmd);
  //Bounds check our prefix to make sure it is within the 8-bit boundaries. Otherwise, ignore it.
  if (prefix > 0 && prefix <= 255) 
    word+=prefix<<24;
  data.push_back(bswap_32(word));
  //Send a second word if it is not all high. Probably should be a better way to handle this in case we actually do want
  //to send a 0xFFFFFFFF word.
  if (secondWord!=0xFFFFFFFF) {
    data.push_back(bswap_32(secondWord));
  }	
  return cmdClient.send(data);
}

/*
  Converts a string to a 32-bit uint. Used mainly for converting 3 character ASCII commands into hex equivalent.
*/
uint32_t ODILEServer::stringToInt(std::string str) {
  uint32_t data=0;
  for (int i=0; i < str.length(); i++) {
    unsigned int bytes=int(str[str.length()-1-i])<<i*8;
    data+=bytes;
  }
  return data;
}
		
//Old test command, no longer used.
ODILECommand ODILEServer::stringToCommand(std::string cmd_str) {
  if (cmd_str=="SEX") return SEX;
  else if (cmd_str=="AEX") return AEX;
  else if (cmd_str=="STS") return STS;
  else if (cmd_str=="GCT") return GCT;
  else if (cmd_str=="RDP") return RDP;
  else return INV;
}
	

//Sets the number of skips for skipper data acquisition, independent of the value set in our .ini file.
bool ODILEServer::setNSkips(uint16_t nskips) {
  configBlocks.getBlock("ADCConfigBlock").getConfigEntry("ADC_CDS_NSkips").value=nskips;
  //TODO: make this return error condition
  return true;
};

//Sets number of ADC samples per integration window in integral mode (this controls the CDS module)
bool ODILEServer::setNSamples(uint16_t nsamples) {
  configBlocks.getBlock("ADCConfigBlock").getConfigEntry("ADC_CDS_NSamples").value=nsamples;
  //TODO: make this return error condition
  return true;
};

//Sets number of ADC samples per trigger (this controls the ADC itself).
bool ODILEServer::setNTrigSamples(uint16_t nsamples) {
  configBlocks.getBlock("ADCConfigBlock").getConfigEntry("ADC_Trigger_Samples").value=nsamples;
  //TODO: make this return error condition
  return true;
};

/*Helper function to convert nrows and ncols into a number of samples we need to recieve based on current configuration settings (skipper mode, raw ADC/CDS mode, etc).*/
int ODILEServer::getWordsToRead(int nrows, int ncols, int nskips) {
  //Get our configuration register block
  int words_to_read=nrows*ncols;
  //Get our ADC configuration settings. Note this requires us to already have read the proper .ini file (or be using the defaults)
  ConfigRegisterBlock ADC_block = configBlocks.getBlock("ADCConfigBlock");
  uint16_t ADC_CDS_NSkips = ADC_block.getConfigEntry("ADC_CDS_NSkips").value;
  //If we don't average over the number of skips, we need to multiply our word number of the number of skips
  if (ADC_CDS_NSkips==1 && nskips > 1) {
    words_to_read*=nskips;
  };
  //If we don't read in CDS mode, we should also multiply by 2x the samples/trigger value
  uint16_t ADC_Mode_Config = ADC_block.getConfigEntry("ADC_Output_Config").value;
  bool in_cds_mode=ADC_Mode_Config & 0x2;
  if (!in_cds_mode) {
    uint16_t samps_per_trigger = ADC_block.getConfigEntry("ADC_Trigger_Samples").value;
    words_to_read *= samps_per_trigger*2;
  };
  return words_to_read;
}

//Sets our current server address.
void ODILEServer::setServerAddress(std::string new_address) {
  server_address=new_address;
}

//General purpose data transmission function, sends to an arbitrary port.
int ODILEServer::sendData(std::vector<uint32_t> data, int port) {
  udp_client_server::udp_client client(odile_address,port);
  return client.send(data);
}

//Sends data from a text file to specified UDP port.
int ODILEServer::sendData(std::string ifname, int port) {
	std::vector<uint32_t> data;
	std::ifstream ifile;
	ifile.open(ifname);
	uint32_t line;
	//Dumps the text file into a buffer.
	while (ifile >> std::hex >> line) {
		data.push_back(bswap_32(line));
	};
	return sendData(data,port);
};

//Handler to close an async receive thred.
int ODILEServer::closeAsyncThread(int thread_id) {
  if (!isValidThread(thread_id)) return -1;
  thread_args[thread_id]->stop=true;
  void *status;
  pthread_join(threads[thread_id], &status);
  //Cleanup our threads
  delete thread_args[thread_id];
  //TODO: fix this to return words read
  return 0;//(int)status;
};

//Checks if a thread ID is valid (thread exists and is still running)
bool ODILEServer::isValidThread(int thread_id) {
  return !(thread_id >= thread_args.size() ||
	   thread_args[thread_id]==NULL ||
	   thread_args[thread_id]->finished==true);
}	

//Gets the number of 32-bit words read from an async receive thread.
int ODILEServer::getWordsRead(int thread_id) {
  if (isValidThread(thread_id)) {
    return thread_args[thread_id]->nread;
  }
  return -1;
}
//Swaps byte ordering (little endian to big endian or vice versa)
void swapBufferBytes(uint32_t *buffer, int nwords) {
  for (int i=0; i < nwords; i++) {
    buffer[i]=bswap_32(buffer[i]);
  };
}
/*
  Asynchronous data receive thread. Designed to receive data from our ODILE asynchronously, so as not to block the main function. Writes to an output file specified in the argument structure.
  "args" should be a pointer to an async_arg_t struct with the parameters for the data acquisition. 
  If CFITSIO is installed and the args->outfname contains ".fits", it will automatically write to a .fits file. If CFITSIO is not installed, attempting to write a .fits file will silently fail.
  If outfname ends in ".txt", will write to text output (in hex format).
  Otherwise, will output a binary file. The first two words of the binary file will contain the NCOLS and NROWS parameters from the input args.
*/
void * asyncRecieve(void *args) {
  async_arg_t* arg=(async_arg_t*) args;
  int *words_recvd=new int;
  bool write_fits=false;
  bool write_text=false;

  //If we have CFITSIO, setup fits file stuff.
#ifdef CFITSIO_INSTALLED
  fitsfile *fFile;
  int fstatus=0;
  LONGLONG curr_pix=1;
  LONGLONG pix_to_read=arg->nrows*arg->ncols;
#endif //CFITSIO_INSTALLED

  std::ofstream outfile;
  char buffer[BUFFSIZE];	
  if (arg->outfname.find(".fits")!=std::string::npos &&
      arg->ncols>0 && arg->nrows>0) {

#ifdef CFITSIO_INSTALLED
    //Create fits file and image
    //TODO: make this handle errors in file creation
    fits_create_file(&fFile, arg->outfname.c_str(), &fstatus);
    long naxis=2;
    long naxes[2]={arg->ncols, arg->nrows};
    fits_create_img(fFile, LONG_IMG, naxis, naxes,&fstatus);
    write_fits=true;
#endif //CFITSIO_INSTALLED

  } else if (arg->outfname.find(".txt")!=std::string::npos) {
    //Run in text output mode
    outfile.open(arg->outfname, std::ios::out);
    write_text=true;
  } else {
    //Write binary data
    outfile.open(arg->outfname, std::ios::out | std::ios::binary);
    //Start by writing the ncols and nrows parameters, if they make sense
    if (arg->ncols>0 && arg->nrows>0) {
      uint32_t nrows=bswap_32(arg->nrows);
      uint32_t ncols=bswap_32(arg->ncols);
      outfile.write((char *) &ncols, sizeof(uint32_t));
      outfile.write((char *) &nrows, sizeof(uint32_t));
    }
  };
  arg->nread=0;
  udp_server data_server(arg->ip_address, arg->port);
  while (!arg->stop) {
    int packet_len=data_server.timed_recv(buffer, BUFFSIZE, WAIT_TIME);
    if (packet_len > 0) {
      int nwords=packet_len/4;
      *words_recvd+=nwords;
      arg->nread+=nwords;

      if (write_fits) {
#ifdef CFITSIO_INSTALLED
	if (curr_pix <= pix_to_read) {
	  swapBufferBytes((uint32_t*)buffer, nwords);
	  fits_write_img(fFile, TINT, curr_pix, LONGLONG(nwords), buffer, &fstatus);
	  curr_pix+=LONGLONG(nwords);
	}
#endif //CFITSIO_INSTALLED
      } else {
	if (write_text) {
	  for (int i=0; i < nwords; i++) {
	    uint32_t word=((uint32_t*)buffer)[i];
	    outfile << std::hex <<std::setw(8) << std::setfill('0') << bswap_32(word) << std::endl;
	  }
	}else {
	  outfile.write(buffer, packet_len);
	};
      };
    };
  };

  if (write_fits) {
#ifdef CFITSIO_INSTALLED
    fits_close_file(fFile, &fstatus);
#endif

  } else {
    outfile.close();
  }
  arg->finished=true;
  pthread_exit(words_recvd);
};

int ODILEServer::recieveData(std::vector<uint32_t> *data, int port, int timeout_ms, bool swap_bytes) {
  return recieveData(data,NULL_IPADDRESS,port,timeout_ms, swap_bytes);
};

int ODILEServer::recieveData(std::vector<uint32_t> *data, std::string serv_address, int port, int timeout_ms, bool swap_bytes) {
  if (data==NULL) {
    return -1;
  } else {
    if (serv_address==NULL_IPADDRESS) {
      serv_address=server_address;
    };
    udp_server server(serv_address, port);
    uint32_t buffer[BUFFSIZE/4];
    int nwords=-1;
    if (timeout_ms > 0) {
      nwords=server.timed_recv((char *)buffer, BUFFSIZE, timeout_ms)/4; 
    }  else {
      nwords=server.recv((char *)buffer, BUFFSIZE)/4;
    }
    if (swap_bytes) {
      swapBufferBytes(buffer, nwords);
    };
    for (int i=0; i < nwords; i++) {
      data->push_back(buffer[i]);
    };
    return nwords;
  };
  return -1;
};	

/*
  Starts an asynchronous read of UDP data coming in on port, and writes the data to outfile. Returns a thread handler ID that can be used to stop the read.
*/
int ODILEServer::launchAsyncThread(std::string outfile, std::string serv_address, int port, int nrows, int ncols) {
  async_arg_t* args=new async_arg_t;
  args->stop=false;
  args->finished=false;
  args->port=port;
  args->outfname=outfile;
  args->thread_id=thread_args.size();
  args->ip_address=serv_address;
  args->nrows=nrows;
  args->ncols=ncols;
  thread_args.push_back(args);
  pthread_t thread;
  pthread_create(&thread,NULL,asyncRecieve, args);
  threads.push_back(thread);
  return args->thread_id;
};

/*
  Writes firmware to the ODILE flash memory. 

  fname : a .rpd file that contains the new firmware to write to the ODILE. This firmware should be compressed so that it fits in less than half the flash (allowing two firmware version to be written simultaneously).
  mapfname :  a .map file for the .rpd file that specifies the length of the firmware. 
  start_address : the 32-bit integer start address of the firmware (usually this will be either 0x00000000, to overwrite the factory firmware, or0x01000000, to update the application firmware). No other addresses should be used in typical operation.
*/
int ODILEServer::writeFirmware(std::string fname, std::string mapfname, uint32_t start_address) {
  using namespace epcq_consts;
  //Start by parsing the map file
  std::ifstream imapfile;
  imapfile.open(mapfname);
  std::string address_str, temp;
  //Hardcoded parser
  imapfile >> temp >> temp >> temp >> temp >> temp >> temp >> temp >> address_str;
  //End address *relative to start address*
  uint32_t end_address = std::stoi(address_str, nullptr, 0);
  //Now load the input binary file
  std::ifstream ifile;
  ifile.open(fname,std::ios::binary | std::ios::in);
  uint32_t word;
  std::vector<uint32_t> write_page;
  std::vector<uint32_t> read_page;
  write_page.resize(PAGE_SIZE_WORDS);
  int pages_to_write=int(end_address/PAGE_SIZE_BYTES)+1;
  int sectors_to_write=int(end_address/SECTOR_BYTES)+1;
  uint32_t curr_address=start_address;
  //Check our start address aligns with a sector boundary
  if (start_address % SECTOR_BYTES != 0) {
    std::cout << "Error, start address is not aligned with sector boundary, make sure start address is aligned with sector start" << std::endl;
    return -1;
  };
  bool done;
  //Clear write buffers to start
  sendCommand("ERB");
  //bool done=waitForDone("ERB",-1);
  int sector_idx=-1;
  for (int page_idx=0; page_idx < pages_to_write; page_idx++) {
    //Set address
    sendCommand("ESA",0,curr_address);
    done=waitForDone("ESA",-1);
    //return 0; //temp
    if (curr_address % SECTOR_BYTES == 0 ) {
      sector_idx++;			
      //std::cout << "Writing sector " << sector_idx << " out of " << sectors_to_write << "...";
      //Erase sector		
      sendCommand("ESE");
      done=waitForDone("ESE",-1);
      //std::cout << "erase done. Beginning write..." << std::endl;
    };
    //Now write our pages
    //Read a page from the file
    for (int word_idx=0; word_idx < PAGE_SIZE_WORDS; word_idx++) {
      ifile.read((char *)&word,4);
      write_page[word_idx]=bswap_32(word);
      //write_page[word_idx]=word;
    }
    //Set our address
    sendCommand("ESA",0,curr_address);
    done=waitForDone("ESA",-1);
    //Send data to our write buffer
    sendData(write_page,FIRMWARE_PORT);
    //Execute write command
    sendCommand("EWR",PAGE_SIZE_WORDS);
    done=waitForDone("EWR",-1);
    //Now read back what we just wrote
    sendCommand("ERD",PAGE_SIZE_WORDS);
    recieveData(&read_page,FIRMWARE_PORT,-1, false);
    if (read_page != write_page) {
      std::cout << std::endl;
      std::cout << "Error, read back data does not match written data for sector: " << sector_idx << ", page: " << page_idx << std::endl;
      std::cout << "Sizes are: " << write_page.size() << ":" << read_page.size() << std::endl;
      if (write_page.size() == read_page.size()) {
	for (int i=0; i < write_page.size(); i++) {
	  std::cout << std::hex << write_page[i]  << ":" << read_page[i] << std::endl;
	};
      }
      return -2;
    }
    read_page.clear();
    curr_address += PAGE_SIZE_BYTES;
    /*************************************************************/
    //Progress bar code
    float progress = page_idx*1.0/pages_to_write;
    int barWidth = 70;

    std::cout << "[";
    int pos = barWidth * progress;
    for (int i = 0; i < barWidth; ++i) {
      if (i < pos) std::cout << "=";
      else if (i == pos) std::cout << ">";
      else std::cout << " ";
    }
    std::cout << "] " << int(progress * 100.0) << " %\r";
    std::cout.flush();
    /*************************************************************/
  }
  std::cout << std::endl;
}

/*
  Reads data from the ODILE EPCQ flash memory to a binary file.
  ofname : name of the file to write the data to. Data is written in binary format.
  start_address  : the address to start reading data from
  words_to_read  : the number of 32-bit words to read from the flash. 
	
  Returns the number of 32 bit words read.
*/
int ODILEServer::readEPCQ(std::string ofname, uint32_t start_address, int words_to_read=1) {
  std::ofstream outfile;
  using namespace epcq_consts;
  uint32_t curr_address=start_address;
  outfile.open(ofname,std::ios::binary | std::ios::out);
  bool done;
  std::cout << "Clearing buffers...";
  sendCommand("ERB");
  done=waitForDone("ERB",-1);
  std::cout << "Done." << std::endl;
  int pages_to_read=words_to_read/PAGE_SIZE_WORDS;
  int words_left=words_to_read;
  int words_read=0;
  std::vector<uint32_t> read_page;
  std::cout << "Starting read from address 0x" <<std::hex << start_address<< " ";
  sendCommand("ESA", 0, start_address);
  done=waitForDone("ESA",-1);
  for (int i=0; i < pages_to_read;i++) {
    //Read our data
    sendCommand("ERD",PAGE_SIZE_WORDS);
    recieveData(&read_page,FIRMWARE_PORT,-1,false);
    //write to file
    outfile.write((char *)&read_page[0],PAGE_SIZE_BYTES);
    curr_address+=PAGE_SIZE_BYTES;
    sendCommand("ESA",0,curr_address);
    done=waitForDone("ESA",-1);
    words_left-= PAGE_SIZE_WORDS;
    words_read+=PAGE_SIZE_WORDS;
    read_page.clear();
  };
  sendCommand("ERD",words_left);
  recieveData(&read_page,FIRMWARE_PORT,-1,false);
  //write to file
  outfile.write((char *)&read_page[0],words_left);
  words_read+=words_left;
  std::cout << "Done." << std::endl;
  outfile.close();
  return words_read;
};
/*
  Handles writing data to the ODILE EPCQ directly.
  data : vector of uint32s to write to the flash. 
  start_address : start address to begin writing to. The data address will increment upwards from this automatically.
  perform_erase : whether to erase the sector containing start_address or not. Flash memory must be erase before a write, attempting to write to non-erase addresses will result in data corruption. The EPCQ in the ODILE board can only be erased on the sector level. It is the responsibility of the user to ensure they are writing to erased addresses.

  Returns the number of 32-bit words written.
*/
int ODILEServer::writeEPCQ(std::vector<uint32_t> data, uint32_t start_address, bool perform_erase) {
  using namespace epcq_consts;
  uint32_t curr_address=start_address;
  int bytes_to_write=data.size()*4;
  int pages_to_write=int(bytes_to_write/PAGE_SIZE_BYTES)+1;
  if (bytes_to_write > SECTOR_BYTES) {
    std::cout << "Error, cannot write more than a sector at once..." << std::endl;
    return -1;
  };
  uint32_t end_address=bytes_to_write+start_address;
  int words_written=0;
  bool done;	
  //Clear our buffer
  sendCommand("ERB");
  done=waitForDone("ERB",-1);
  //Set start address
  sendCommand("ESA",0,start_address);
  done=waitForDone("ESA",-1);
  //Perform our erase first.
  if (perform_erase) {
    //Erase sector
    std::cout << "Performing sector erase...";
    sendCommand("ESE");
    done=waitForDone("ESE",-1);
    std::cout << "erase done. Beginning write..." << std::endl;
  };
  //Index for current data word
  int data_idx=0;
  std::vector<uint32_t> read_page;
  //Holds a page of data to write
  std::vector<uint32_t> write_page;
  write_page.resize(PAGE_SIZE_WORDS);	
  for (int page_idx=0; page_idx < pages_to_write; page_idx++) {
    //Now write our pages
    for (int word_idx=0; word_idx < PAGE_SIZE_WORDS; word_idx++) {
      if (data_idx >= data.size()){
	write_page[word_idx]=0xFFFFFFFF;
      } else {
	write_page[word_idx]=data[data_idx];
      }
      data_idx++;
    };
    //Set our address
    sendCommand("ESA",0,curr_address);
    done=waitForDone("ESA",-1);
    //Send data to our write buffer
    sendData(write_page,FIRMWARE_PORT);
    //Execute write command
    sendCommand("EWR",PAGE_SIZE_WORDS);
    done=waitForDone("EWR",-1);
    words_written+=PAGE_SIZE_WORDS;
    //Now read back what we just wrote
    sendCommand("ERD",PAGE_SIZE_WORDS);
    recieveData(&read_page,FIRMWARE_PORT,-1, false);
    if (read_page != write_page) {
      std::cout << "Error, read back data does not match written data for address: "<< curr_address << std::endl;
      std::cout << "Sizes are: " << write_page.size() << ":" << read_page.size() << std::endl;
      if (write_page.size() == read_page.size()) {
	for (int i=0; i < write_page.size(); i++) {
	  std::cout << std::hex << write_page[i]  << ":" << read_page[i] << std::endl;
	};
      }
      return -2;
    }
    read_page.clear();
    curr_address+=PAGE_SIZE_BYTES;		
  }
  return words_written;
}
/*
  Simple wrapper for writing configuration data from a .ini file.
*/
int ODILEServer::writeFlashConfig(int config_page, std::string inifile) {
  readConfigData(inifile);
  return writeFlashConfig(config_page);
};
	

/*
  Writes our currently loaded configuration blocks to a configuration page on the ODILE flash memory. 
  The configuration pages are the last 10 sectors of the EPCQ device, and may contain any data for the ODILE that can be sent to a UDP port over Ethernet. The ODILE will automatically load configuration data from page 0 on power on, allowing one to set persistent configuration register data by updating that configruation page. Other pages can be used for commonly used configurations or if we wish to change configuration during runtime, without sending data over Ethernet.

  Configuration data is organized as follows. The final 10 sectors of the EPCQ256 device on the ODILE are designated as configuration pages. Each sector is 512 kilobits (65,536 bytes). Each page contains up to 32 configuration blocks, with each block being composed of 64 32-bit words. The first 32-bit word of each block is a header that contains a hard-coded "configuration valid" flag (0xCD), the length of the block (in 32-bit words), and the UDP port the configuration data should be routed to (in the last 16 bits of the header). The rest of the block will then loaded by the ODILE as if it received that data (up to 63 words) to that UDP port over the Ethernet interface. Each block may be sent to a different UDP port (which corresponds to different destinations on the ODILE: 0x2000 for instance will load data to the sequencer program memory). This allows pages to contain data for different registers or memories in almost any combination.

  config_page : integer range 0 to 9 that specifies the configuration page to write to. Any other integer will result in a return of -2. Otherwise, function returns the number of 32-bit words written.
*/
int ODILEServer::writeFlashConfig(int config_page) {
  std::vector<uint32_t> config_message=configBlocks.getConfigMessage();
  //divide our config message into 63-word blocks and insert header every 64 words
  int nwords=config_message.size();
  int nblocks=nwords/63+1;
  for (int i=0; i < nblocks; i++) {
    uint8_t block_size = i < nblocks-1 ? 63 : nwords%63;
    uint32_t header = (0xCD << 24) + (block_size << 16) + 0x4268;
    header=bswap_32(header); //Our mesage expects byte ordering to be swapped
    config_message.insert(config_message.begin() + i*64, header);
  };
  //For debug only
	
  // for (unsigned int i=0; i < config_message.size(); i++) {
  // 	// printHex(4,(char *) &config_message[i]);
  // 	// std::cout << std::endl;
  // 	std::cout << std::hex << bswap_32(config_message[i]) << std::endl;
  // };
  if ((config_page >= 10) || (config_page < 0)) {
    //Invalid page number
    return -2;
  }
  uint32_t page_address=CONFIG_PAGE_ADDRESS[config_page];
  return writeEPCQ(config_message, page_address, true);
	
};

int ODILEServer::writeFitsHeader(std::string fname, short ndcms, std::string amplifier, double exp_time, double read_time, std::string compiletime) {
  int status=0;
#ifdef CFITSIO_INSTALLED
  fitsfile *fFile;
  int fstatus=0;
  int nsbin=1;
  int npbin=1;
  fits_open_file(&fFile, fname.c_str(), READWRITE, &fstatus);

  std::string fitsComment = "This image was taken using ODILEServer";
  ConfigRegisterBlock ADC_block = configBlocks.getBlock("ADCConfigBlock");
	
  fits_write_comment(fFile, fitsComment.c_str(), &fstatus);
  for (int i=0; i < ADC_block.config_entries.size(); i++) {
    ConfigEntry entry=ADC_block.config_entries[i];
    fits_write_key(fFile, TSHORT, entry.name.c_str(), &entry.value, entry.description.c_str(), &fstatus);
  };
	
  fits_write_key(fFile, TSHORT, "NDCMs", &ndcms, "Number of charge measurements", &fstatus);
  fits_write_key(fFile, TSHORT, "NPBIN", &npbin, "Vertical bining", &fstatus);
  fits_write_key(fFile, TSHORT, "NSBIN", &nsbin, "Horizontal binning", &fstatus);
  fits_write_key(fFile, TSTRING, "AMPL", (char *)amplifier.c_str() , "Horizontal binning", &fstatus);
	
  time_t rawtime;
  struct tm * timeinfo;
  time(&rawtime);
  timeinfo = localtime(&rawtime);
	
  fits_write_key(fFile, TDOUBLE, "MREAD", &read_time, "Readout time", &fstatus);
  //TODO: make this a proper exposure time
  fits_write_key(fFile, TDOUBLE, "MEXP", &exp_time, "Exposure time", &fstatus);
  fits_write_key(fFile, TSTRING, "RdEnd", (char *)asctime(timeinfo), "Readout end time", &fstatus);
  fits_write_key(fFile, TSTRING, "FWCTIME", (char *) compiletime.c_str(), "Firmware compile time", &fstatus);
  fits_close_file(fFile, &fstatus);
#else
  std::cout << "Error, compiled without cfitsio support, doing nothing..." << std::endl;
  status= -1;
#endif
  return status;
}

uint32_t ODILEServer::getCompileTime() {
  sendCommand("GCT");
  std::vector<uint32_t> data;
  recieveData(&data, NULL_IPADDRESS, COMMAND_PORT);
  uint32_t compiletime=data[1];
  return compiletime;
}
std::string ODILEServer::getCompileTimeStr() {
  uint32_t compiletime=getCompileTime();
  time_t temp=compiletime;
  std::string ctime_string=std::string(std::asctime(std::localtime(&temp)));
  return ctime_string;
}

  
