#ifndef CONFIG_REGISTER_BLOCK_HPP
#define CONFIG_REGISTER_BLOCK_HPP
#include <string>
#include <vector>
#include <cstdint>
#include <iostream>
#include <fstream>
#include <byteswap.h>

#include "INIReader.h"

class ConfigEntry {
 public:
	ConfigEntry(short default_value, char address, std::string name, std::string description="");
	ConfigEntry(char address);
	~ConfigEntry() {};
	//16-bit fields
	uint16_t value;
	uint16_t default_value;	
	char address;
	std::string name;
	std::string description;
	bool operator==(ConfigEntry &rhs);
};

class ConfigRegisterBlock {
 public:
	ConfigRegisterBlock(char address, std::string name="None");
	~ConfigRegisterBlock() {};
	std::vector<ConfigEntry> config_entries;
	std::vector<uint32_t> config_messages;	
	char address;
	std::string name;
	void setAddress(char new_address) {address=new_address;}
	void setName(std::string new_name) {name=new_name;};
	bool addEntry(ConfigEntry new_entry) {config_entries.push_back(new_entry); return true;}
	char getAddress() {return address;};
	ConfigEntry& getConfigEntry(std::string name);
	void createConfigMessages(bool write_all=false);
	std::vector<uint32_t> getConfigMessages(bool write_all=false);
	void writeINI(std::ofstream &ini_file, bool write_all=false, bool write_description=true);
	void readINI(INIReader & reader);
	int findEntry(std::string name);
private:
	bool messages_created;
};

#endif //CONFIG_REGISTER_BLOCK_HPP
