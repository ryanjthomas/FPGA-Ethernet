-------------------------------------------------------------------------------
-- Title      : Ethernet Common Package
-- Project    : 
-------------------------------------------------------------------------------
-- File       : common.vhd
-- Author     : Ryan Thomas
-- Company    : University of Chicago
-- Created    : 2019-08-21
-- Last update: 2020-11-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Package that includes some common types used accross multiple
-- components in the ethernet firmwaare.
-------------------------------------------------------------------------------
--! @file eth_common.vhd
--! @brief Common ethernet definitions


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--! Holds a number of different definitions used in different blocks that talk to
--! the Ethernet interfaces.

package eth_common is
  -------------------------------------------------------------------------------
  --Types and subtypes
  -------------------------------------------------------------------------------
  subtype word is std_logic_vector(31 downto 0);
  type data_array is array (integer range <>) of word;
  subtype in_fifo_usedw is std_logic_vector(10 downto 0);
  type in_fifo_usedw_array is array (integer range <>) of in_fifo_usedw;
  --Flag behavior: bit 0 is enable/disable, bit 1 is priority hi/normal
  subtype in_fifo_flag is std_logic_vector(1 downto 0);
  type in_fifo_flag_array is array (integer range <>) of in_fifo_flag;
  subtype mac_addr is std_logic_vector(47 downto 0);
  type mac_addr_array is array(integer range <>) of mac_addr;
  subtype ip_addr is std_logic_vector(31 downto 0);
  type ip_addr_array is array(integer range <>) of ip_addr;
  subtype udp_port is std_logic_vector(15 downto 0);
  type udp_port_array is array (integer range <>) of udp_port;
  subtype config_address is std_logic_vector(6 downto 0);
  type config_address_array is array(integer range <>) of config_address;
  type iface_type is (BASEX, RGMII, SGMII);
  type count_array is array(integer range <>) of natural;
  --For monitoring interface (hopefully temporary)
  --type array18x32b is array (0 to 17) of std_logic_vector(31 downto 0);
  -------------------------------------------------------------------------------
  -- Constants
  -------------------------------------------------------------------------------
  constant IN_FIFO_SIZE            : natural                       := 2048;
  constant IN_FIFO_AFULL           : natural                       := IN_FIFO_SIZE-100;
  --For testing
  --constant IN_FIFO_STALE_THRESHOLD : natural                       := 10;
  --1 ms @ 125 Mhz clock
  constant IN_FIFO_STALE_THRESHOLD : natural                       := 125000;
  --constant IN_FIFO_STALE_THRESHOLD : natural                       := 12;
  --100 ms @ 125 MHz clock
  constant LED_BLINK_CYCLES        : natural                       := 12500000;
  constant N_IN_FIFOS              : natural                       := 5;
  constant IN_FIFO_BITS            : natural                       := 11;
  constant MAX_FRAME_BITS          : natural                       := 9;
  constant INFIFO_DISABLE          : in_fifo_flag                  := "00";
  constant INFIFO_ENABLE           : in_fifo_flag                  := "01";
  constant INFIFO_PRIORITY         : in_fifo_flag                  := "11";
  --Ethertypes
  constant ETH_IPv4                : std_logic_vector(15 downto 0) := X"08_00";
  constant ETH_ARP                 : std_logic_vector(15 downto 0) := X"08_06";
  --IPv4 protocols
  constant PROTO_UDP               : std_logic_vector(7 downto 0)  := X"11";
  constant PROTO_ICMP              : std_logic_vector(7 downto 0)  := X"01";
  --ARP packet types
  constant ARP_REQUEST             : std_logic_vector(15 downto 0) := X"00_01";
  constant ARP_REPLY               : std_logic_vector(15 downto 0) := X"00_02";
  --ICMP types
  constant ICMP_ECHO_REQUEST       : std_logic_vector(15 downto 0) := X"08_00";
  constant ICMP_ECHO_REPLY         : std_logic_vector(15 downto 0) := X"00_00";
  --UDP ports
  constant UDP_PORT_CONFIG         : udp_port                      := X"4268";
  constant UDP_PORT_BASES : udp_port_array(2 downto 0) := (0 => X"1000",
                                                           1 => X"1100",
                                                           2 => X"1200");
  constant UDP_PORT_LOOPBACKS : udp_port_array(2 downto 0) := (0 => UDP_PORT_BASES(0) or X"0004",
                                                               1 => UDP_PORT_BASES(1) or X"0004",
                                                               2 => UDP_PORT_BASES(2) or X"0004");
  constant UDP_PORT_SEQ_SERIAL      : udp_port := X"1999";
  constant UDP_PORT_SEQ_PROGRAM     : udp_port := X"2000";
  constant UDP_PORT_SEQ_TIME        : udp_port := X"2001";
  constant UDP_PORT_SEQ_OUT         : udp_port := X"2002";
  constant UDP_PORT_SEQ_IND_FUNC    : udp_port := X"2003";
  constant UDP_PORT_SEQ_IND_REP     : udp_port := X"2004";
  constant UDP_PORT_SEQ_IND_SUB_ADD : udp_port := X"2005";
  constant UDP_PORT_SEQ_IND_SUB_REP : udp_port := X"2006";
  constant UDP_PORT_CABAC_PROG      : udp_port := X"2100";
  constant UDP_PORT_MONITORING      : udp_port := X"2200";  
  constant UDP_PORT_CROC_PROG       : udp_port := X"2300";
  constant UDP_PORT_COMMAND         : udp_port := X"3000";
  constant UDP_PORT_COMMAND_REPLY   : udp_port := UDP_PORT_COMMAND;
  constant UDP_PORT_EPCQIO          : udp_port := X"4000";


  --Configuration block addresses (note: these match the base UDP port
  --addresses above, if you change these please change above to match)
  constant ENET_CONFIG_ADDRESSES : config_address_array(2 downto 0) := (0 => "0010000",
                                                                        1 => "0010001",
                                                                        2 => "0010010");

  constant TSE_CONFIG_ADDRESSES : config_address_array(2 downto 0) := (0 => "0010011",
                                                                       1 => "0010100",
                                                                       2 => "0010101");
  constant IFACE_IP_ADDRESSES : ip_addr_array(2 downto 0) := (0 => X"C0_A8_00_03",
                                                              1 => X"C0_A8_00_04",
                                                              2 => X"C0_A8_01_05");
  constant DEST_IP_ADDRESSES : ip_addr_array(2 downto 0) := (0 => X"C0_A8_00_01",
                                                             1 => X"C0_A8_00_01",
                                                             2 => X"C0_A8_01_01");
  constant IFACE_MAC_ADDRESSES : mac_addr_array(2 downto 0) := (0 => X"EE_11_22_33_44_55",
                                                                1 => X"EE_11_22_33_44_56",
                                                                2 => X"EE_11_22_33_44_57");
  constant DEST_MAC_ADDRESSES : mac_addr_array(2 downto 0) := (0 => X"6C_B3_11_51_74_34",
                                                               1 => X"6C_B3_11_51_74_34",
                                                               2 => X"00_0e_0c_22_02_75");

  -------------------------------------------------------------------------------
  -- Functions
  -------------------------------------------------------------------------------
  --! Computes number of bits needed to represent a number
  function f_num_bits (x : natural) return natural;

end eth_common;

package body eth_common is


  function f_num_bits (x : natural) return natural is
  begin  -- function f_num_bits
    return integer(ceil(log2(real(x))));
  end function f_num_bits;

end eth_common;


