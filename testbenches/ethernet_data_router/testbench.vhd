-------------------------------------------------------------------------------
-- Title      : Testbench for design "ethernet_block"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_optical_block_tb.vhd
-- Author     : Ryan Thomas  <ryan@uchicago.edu>

-- Company    : University of Chicago
-- Created    : 2019-08-26
-- Last update: 2021-05-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Ryan Thomas  <ryan@uchicago.edu>
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-08-26  1.0      ryan  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;
-------------------------------------------------------------------------------

entity testbench is

end entity testbench;

-------------------------------------------------------------------------------

architecture tb of testbench is
  
  signal clock           : std_logic := '0';
  signal reset           : std_logic := '0';
  signal data_in0        : std_logic_vector(31 downto 0) := (others => '0');
  signal data_valid0     : std_logic := '0';
  signal data_port0      : std_logic_vector(15 downto 0) := (others => '0');
  signal data_addr0      : std_logic_vector(79 downto 0);
  signal data_in1        : std_logic_vector(31 downto 0) := (others => '0');
  signal data_valid1     : std_logic := '0';
  signal data_port1      : std_logic_vector(15 downto 0) := (others => '0');
  signal data_addr1      : std_logic_vector(79 downto 0);
  signal data_in2        : std_logic_vector(31 downto 0) := (others => '0');
  signal data_valid2     : std_logic := '0';
  signal data_port2      : std_logic_vector(15 downto 0) := (others => '0');
  signal data_addr2      : std_logic_vector(79 downto 0);  
  signal config_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal config_valid    : std_logic := '0';
  signal loopback_data0  : std_logic_vector(31 downto 0) := (others => '0');
  signal loopback_wrreq0 : std_logic := '0';
  signal loopback_data1  : std_logic_vector(31 downto 0) := (others => '0');
  signal loopback_wrreq1 : std_logic := '0';
  signal loopback_data2  : std_logic_vector(31 downto 0) := (others => '0');
  signal loopback_wrreq2 : std_logic := '0';
  signal int_data_in     : std_logic_vector(31 downto 0);
  signal int_valid_in    : std_logic;
  signal int_port_in     : std_logic_vector(15 downto 0);
  signal epcqio_data_out : std_logic_vector(31 downto 0) := (others => '0');
  signal epcqio_valid    : std_logic                     := '0';
  signal eth_data_out    : std_logic_vector(31 downto 0) := (others => '0');
  signal eth_data_port   : std_logic_vector(15 downto 0) := (others => '0');
  signal eth_data_valid  : std_logic                     := '0';
  signal eth_data_addr   : std_logic_vector(79 downto 0) := (others => '0');
  signal source_iface    : std_logic_vector(3 downto 0)  := (others => '0');

  signal sim_start : std_logic;

  
begin  -- architecture testbench

  edata_router: entity work.ethernet_data_router
    port map (
      clock           => clock,
      reset           => reset,
      data_in0        => data_in0,
      data_valid0     => data_valid0,
      data_port0      => data_port0,
      data_addr0      => data_addr0,
      data_in1        => data_in1,
      data_valid1     => data_valid1,
      data_port1      => data_port1,
      data_addr1      => data_addr1,
      data_in2        => data_in2,
      data_valid2     => data_valid2,
      data_port2      => data_port2,
      data_addr2      => data_addr2,
      int_data_in     => int_data_in,
      int_valid_in    => int_valid_in,
      int_port_in     => int_port_in,
      config_data_out => config_data_out,
      config_valid    => config_valid,
      loopback_data0  => loopback_data0,
      loopback_wrreq0 => loopback_wrreq0,
      loopback_data1  => loopback_data1,
      loopback_wrreq1 => loopback_wrreq1,
      loopback_data2  => loopback_data2,
      loopback_wrreq2 => loopback_wrreq2,
      epcqio_data_out => epcqio_data_out,
      epcqio_valid    => epcqio_valid,
      eth_data_out    => eth_data_out,
      eth_data_port   => eth_data_port,
      eth_data_valid  => eth_data_valid,
      eth_data_addr   => eth_data_addr,
      source_iface    => source_iface);
  

  reset <= '0', '1' after 10 ns, '0' after 100 ns;
  sim_start <= '0', '1' after 110 ns;
  -- clock generation
  --100 Mhz main clock
  clock                    <= not clock         after 10 ns;



  data_gen : process(clock, sim_start)
    variable word_num : natural := 0;
  begin
    if rising_edge(clock) and sim_start='1' then
      if word_num=0 then
        data_in0 <= X"00_00_12_34";
        data_valid0 <= '1';
        data_port0 <= UDP_PORT_CONFIG;
      elsif word_num=1 then
        data_in0 <= X"00_01_56_78";
        data_valid0 <= '1';
        data_port0 <= UDP_PORT_CONFIG;
      elsif word_num>=2 then
        data_valid0 <= '0';
        data_valid1 <= '1';
        data_in1 <= std_logic_vector(to_unsigned(word_num, data_in1'length));
        data_port1 <= UDP_PORT_LOOPBACKS(2);
      end if;
      word_num := word_num + 1;
    end if;
  end process data_gen;
        

end architecture tb;
