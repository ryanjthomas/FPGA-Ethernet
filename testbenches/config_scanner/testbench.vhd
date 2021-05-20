-------------------------------------------------------------------------------
-- Title      : Testbench for design "config_block_scanner"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : testbench.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-01-06
-- Last update: 2021-05-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2020 Ryan Thomas  <ryant@uchicago.edu>
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-01-06  1.0      ryan  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
library work;
use work.eth_common.all;
use work.config_pkg.all;

-------------------------------------------------------------------------------

entity testbench is
end entity testbench;

-------------------------------------------------------------------------------

architecture tb of testbench is

  constant NCONFIG_LINES : natural := 3;


  constant BLOCK_ADDRESS0 : std_logic_vector(6 downto 0) := "0101010";
  constant BLOCK_ADDRESS1 : std_logic_vector(6 downto 0) := "1111111";
  constant BLOCK_ADDRESS2 : std_logic_vector(6 downto 0) := "0000000";

  constant DEFAULT_SETTINGS0 : config_word_array(2 downto 0) := (0 => X"01_23_45_67",
                                                                  1 => X"AA_BB_CC_DD",
                                                                  2 => X"98_76_54_00");

  constant DEFAULT_SETTINGS1 : config_word_array(1 downto 0) := (0 => X"11_22_33_44",
                                                                  1 => X"99_88_77_66");

  constant DEFAULT_SETTINGS2 : config_word_array(6 downto 0) := (0 => X"DE_AD_BE_00",
                                                                  1 => X"DE_AD_BE_01",
                                                                  2 => X"DE_AD_BE_02",
                                                                  3 => X"DE_AD_BE_03",
                                                                  4 => X"DE_AD_BE_04",
                                                                  5 => X"DE_AD_BE_05",
                                                                  6 => X"0E_4D_BE_06");

  signal clock : std_logic := '0';
  signal reset : std_logic := '0';

  signal config_data_in0   : std_logic_vector(31 downto 0)                          := (others => '0');
  signal config_valid_in0  : std_logic                                              := '0';
  signal config_data_out0  : std_logic_vector(31 downto 0)                          := (others => '0');
  signal config_valid_out0 : std_logic                                              := '0';
  signal config_registers0 : config_word_array(DEFAULT_SETTINGS0'length-1 downto 0) := DEFAULT_SETTINGS0;
  signal config_changed0   : std_logic                                              := '0';
  signal config_error0     : std_logic                                              := '0';

  signal config_data_in1   : std_logic_vector(31 downto 0)                          := (others => '0');
  signal config_valid_in1  : std_logic                                              := '0';
  signal config_data_out1  : std_logic_vector(31 downto 0)                          := (others => '0');
  signal config_valid_out1 : std_logic                                              := '0';
  signal config_registers1 : config_word_array(DEFAULT_SETTINGS1'length-1 downto 0) := DEFAULT_SETTINGS1;
  signal config_changed1   : std_logic                                              := '0';
  signal config_error1     : std_logic                                              := '0';

  signal config_data_in2   : std_logic_vector(31 downto 0)                          := (others => '0');
  signal config_valid_in2  : std_logic                                              := '0';
  signal config_data_out2  : std_logic_vector(31 downto 0)                          := (others => '0');
  signal config_valid_out2 : std_logic                                              := '0';
  signal config_registers2 : config_word_array(DEFAULT_SETTINGS2'length-1 downto 0) := DEFAULT_SETTINGS2;
  signal config_changed2   : std_logic                                              := '0';
  signal config_error2     : std_logic                                              := '0';

  signal config_data_in_mult   : config_word_array(NCONFIG_LINES-1 downto 0);
  signal config_valid_in_mult  : std_logic_vector(NCONFIG_LINES-1 downto 0);
  signal config_data_out_mult  : config_word;
  signal config_valid_out_mult : std_logic;

  signal config_data_in   : std_logic_vector(31 downto 0) := (others => '0');
  signal config_valid_in  : std_logic                     := '0';
  signal config_data_out  : std_logic_vector(31 downto 0) := (others => '0');
  signal config_valid_out : std_logic                     := '0';
  signal udp_out_busy     : std_logic_vector(52 downto 0) := (others => '0');
  signal udp_ready        : std_logic                     := '0';
  signal start_scan_blocks      : std_logic                     := '0';
  signal scan_finished    : std_logic                     := '0';
  signal start_scan_single       : std_logic                     := '0';
  signal start_block_address    : std_logic_vector(6 downto 0)  := (others => '0');
  signal busy             : std_logic                     := '0';

  --Signals for UDP arbiter, mostly unused
  signal udp_data_out      : std_logic_vector(31 downto 0) := (others => '0');
  signal udp_port_out      : std_logic_vector(15 downto 0) := (others => '0');
  signal udp_valid_out     : std_logic                     := '0';
  signal udp_eop_out       : std_logic                     := '0';
  signal udp_addr_out      : std_logic_vector(79 downto 0) := (others => '0');
  signal udp_dest_iface    : std_logic_vector(3 downto 0)  := (others => '0');  
  signal udp_in_bus_cmd    : std_logic_vector(52 downto 0) := (others => '0');
  signal udp_ready_cmd     : std_logic                     := '0';
  signal udp_in_bus_ccdint : std_logic_vector(52 downto 0) := (others => '0');
  signal udp_ready_ccdint  : std_logic                     := '0';
  signal udp_in_bus_scan   : std_logic_vector(52 downto 0) := (others => '0');
  signal udp_ready_scan    : std_logic                     := '0';
  signal udp_in_bus_epcqio : std_logic_vector(52 downto 0);
  signal udp_ready_epcqio  : std_logic                     := '0';
  signal udp_in_bus_monit  : std_logic_vector(52 downto 0);
  signal udp_ready_monit   : std_logic                     := '0';
  signal udp_tx_busy       : std_logic                     := '0';
  signal dest_iface        : std_logic_vector(3 downto 0)  := (others => '0');
  signal dest_addr         : std_logic_vector(79 downto 0) := (others => '0');
  
begin

  config_data_in_mult(0)  <= config_data_out0;
  config_valid_in_mult(0) <= config_valid_out0;
  config_data_in_mult(1)  <= config_data_out1;
  config_valid_in_mult(1) <= config_valid_out1;
  config_data_in_mult(2)  <= config_data_out2;
  config_valid_in_mult(2) <= config_valid_out2;

  config_data_in0 <= config_data_out;
  config_valid_in0 <= config_valid_out;
  config_data_in1 <= config_data_out;
  config_valid_in1 <= config_valid_out;
  config_data_in2 <= config_data_out;
  config_valid_in2 <= config_valid_out;


  
  udp_data_arbiter_1: entity work.udp_data_arbiter
    port map (
      clock             => clock,
      reset             => reset,
      udp_data_out      => udp_data_out,
      udp_port_out      => udp_port_out,
      udp_valid_out     => udp_valid_out,
      udp_eop_out       => udp_eop_out,
      udp_addr_out      => udp_addr_out,
      udp_dest_iface    => udp_dest_iface,
      udp_in_bus_cmd    => udp_in_bus_cmd,
      udp_ready_cmd     => udp_ready_cmd,
      udp_in_bus_ccdint => udp_in_bus_ccdint,
      udp_ready_ccdint  => udp_ready_ccdint,
      udp_in_bus_scan   => udp_in_bus_scan,
      udp_ready_scan    => udp_ready_scan,
      udp_in_bus_epcqio => udp_in_bus_epcqio,
      udp_ready_epcqio  => udp_ready_epcqio,
      udp_in_bus_monit  => udp_in_bus_monit,
      udp_ready_monit   => udp_ready_monit,
      udp_tx_busy       => udp_tx_busy,
      dest_iface        => dest_iface,
      dest_addr         => dest_addr);

  
  config_block_scanner_1 : entity work.config_block_scanner
    port map (
      clock            => clock,
      reset            => reset,
      config_data_in   => config_data_in,
      config_valid_in  => config_valid_in,
      config_data_out  => config_data_out,
      config_valid_out => config_valid_out,
      udp_out_bus      => udp_in_bus_scan,
      udp_ready        => udp_ready_scan,
      start_scan_blocks      => start_scan_blocks,
      scan_finished    => scan_finished,
      start_scan_single       => start_scan_single,
      start_block_address    => start_block_address,
      busy             => busy);

  config_read_multiplexer_1 : entity work.config_read_multiplexer
    generic map (
      NCONFIG_LINES => NCONFIG_LINES)
    port map (
      clock            => clock,
      config_data_in   => config_data_in_mult,
      config_valid_in  => config_valid_in_mult,
      config_data_out  => config_data_in,
      config_valid_out => config_valid_in);


  config_register_block_1 : entity work.config_register_block
    generic map (
      BLOCK_ADDRESS    => BLOCK_ADDRESS0,
      DEFAULT_SETTINGS => DEFAULT_SETTINGS0)
    port map (
      clock            => clock,
      reset            => reset,
      config_data_in   => config_data_in0,
      config_valid_in  => config_valid_in0,
      config_data_out  => config_data_out0,
      config_valid_out => config_valid_out0,
      config_registers => config_registers0,
      config_changed   => config_changed0,
      config_error     => config_error0);

  config_register_block_2 : entity work.config_register_block
    generic map (
      BLOCK_ADDRESS    => BLOCK_ADDRESS1,
      DEFAULT_SETTINGS => DEFAULT_SETTINGS1)
    port map (
      clock            => clock,
      reset            => reset,
      config_data_in   => config_data_in1,
      config_valid_in  => config_valid_in1,
      config_data_out  => config_data_out1,
      config_valid_out => config_valid_out1,
      config_registers => config_registers1,
      config_changed   => config_changed1,
      config_error     => config_error1);

  config_register_block_3 : entity work.config_register_block
    generic map (
      BLOCK_ADDRESS    => BLOCK_ADDRESS2,
      DEFAULT_SETTINGS => DEFAULT_SETTINGS2)
    port map (
      clock            => clock,
      reset            => reset,
      config_data_in   => config_data_in2,
      config_valid_in  => config_valid_in2,
      config_data_out  => config_data_out2,
      config_valid_out => config_valid_out2,
      config_registers => config_registers2,
      config_changed   => config_changed2,
      config_error     => config_error2);


  -- clock generation
  clock <= not clock after 10 ns;
  reset <= '1', '0'  after 100 ns;

  --Signal generation
  start_scan_blocks <= '0', '1' after 1000 ns, '0' after  1100 ns;

  
  --Test scanning a single block
  process
  begin
    wait until scan_finished='1';
    wait for 40 ns;
    start_block_address<="0101010";
    start_scan_single <= '1';
    wait for 40 ns;
    start_scan_single <= '0';
    wait until scan_finished='1';
    wait for 1 us;
    assert FALSE Report "Simulation Finished" severity FAILURE;
  end process;
    
  

end architecture tb;
