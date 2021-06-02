#ifndef CONFIG_BLOCK_LIST_HPP
#define CONFIG_BLOCK_LIST_HPP
#include "ConfigRegisterBlock.hpp"
#include <vector>
#include <string>

class ConfigBlockList {
public:
	ConfigBlockList();
	~ConfigBlockList() {};
	std::vector<ConfigRegisterBlock> blocks;
	int readINI(std::string inifile="default.ini");
	bool writeINI(std::string inifile);
	std::vector<uint32_t> getConfigMessage();
	bool write_all;
	ConfigRegisterBlock& getBlock(std::string name);
};

#endif //CONFIG_BLOCK_LIST_HPP
