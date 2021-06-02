#include "ConfigRegisterBlock.hpp"
#include "udp_client_server.h"
#include <set>
#include <string>

ConfigEntry::ConfigEntry(short default_value, char address, std::string name, std::string description) : value(default_value), default_value(default_value), address(address), name(name), description(description) {};

ConfigEntry::ConfigEntry(char address) : value(0x0000), default_value(0x0000), address(address), name("UNUSED"), description("Unused") {};

bool ConfigEntry::operator==(ConfigEntry &rhs) {
	return (address=rhs.address && value==rhs.value && name==rhs.name && description==rhs.description);
};

ConfigRegisterBlock::ConfigRegisterBlock(char address, std::string name) : address(address), name(name) {
	messages_created=false;
};

void ConfigRegisterBlock::createConfigMessages(bool write_all) {
	//For now just clear our old messages
	//TODO: make this smarter maybe?
	config_messages.clear();
	for (unsigned int i=0; i < config_entries.size(); i++) {
		if (((config_entries[i].value != config_entries[i].default_value) or write_all) and config_entries[i].name!="UNUSED") {
			uint32_t config_word = (address<<24 | config_entries[i].address << 16 | (config_entries[i].value));
			config_messages.push_back(bswap_32(config_word));
			//printHex(config_word);
		}
	}
	messages_created=true;
};

std::vector<uint32_t> ConfigRegisterBlock::getConfigMessages(bool write_all) {
	createConfigMessages(write_all);
	return config_messages;
};

void ConfigRegisterBlock::writeINI(std::ofstream &ini_file, bool write_all, bool write_description) {
	if (!messages_created) createConfigMessages();
	ini_file << "[" << name << "]" << std::endl;
	for (unsigned int i=0; i < config_entries.size(); i++) {
		if (((config_entries[i].value != config_entries[i].default_value) or write_all) and config_entries[i].name!="UNUSED") {
			if (write_description) {
				ini_file << ";" << std::showbase << std::hex << int(config_entries[i].address) << " " << config_entries[i].description << std::endl;
			}
			ini_file << config_entries[i].name << " = " << std::showbase << std::hex<< config_entries[i].value << std::endl;
		}
	}
}

void ConfigRegisterBlock::readINI(INIReader &reader) {
	std::set<std::string> sections=reader.GetSections();
	//Check if we have a  section in the INI file
	if (sections.find(name)!=sections.end()) {
		//If we do, read all the entries
		std::set<std::string> fields=reader.GetFields(name);
		for (auto it=fields.begin(); it!= fields.end(); it++) {
			int entry=findEntry(*it);
			if (entry >=0) {
				config_entries[entry].value=reader.GetInteger(name, *it, 0);
			}
		}
	}
}
int ConfigRegisterBlock::findEntry(std::string entry_name) {
	for (unsigned int i=0; i < config_entries.size(); i++ ) {
		if (entry_name==config_entries[i].name) return i;
	}
	//Entry not found
	return -1;
}
	
			
ConfigEntry& ConfigRegisterBlock::getConfigEntry(std::string name) {
	for (unsigned int i=0; i < config_entries.size(); i++) {
		if (config_entries[i].name==name) {
			return config_entries[i];
		}
	}
	//return ConfigEntry(0x0000, 0x00, "INVALID","Invalid");
}

