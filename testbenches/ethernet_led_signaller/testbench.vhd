-------------------------------------------------------------------------------
-- Title      : Testbench for design "ethernet_led_signaler"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_led_signaler_tb.vhd
-- Author     : Ryan Thomas  <ryan@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-01-30
-- Last update: 2021-05-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2020 Ryan Thomas  <ryan@uchicago.edu>
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-01-30  1.0      ryan	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------

entity testbench is

end entity testbench;

-------------------------------------------------------------------------------

architecture tb of testbench is

  -- component generics
  constant blink_cycles : natural := 1000;

  -- component ports
  signal clock            : std_logic := '0';
  signal led0_link        : std_logic := '0';
  signal led0_act         : std_logic := '0';
  signal led1_link        : std_logic := '0';
  signal led1_act         : std_logic := '0';
  signal led2_link        : std_logic := '0';
  signal led2_act         : std_logic := '0';
  signal led_link_out     : std_logic := '0';
  signal led_act_out      : std_logic := '0';
  signal led_combined_out : std_logic := '0';

begin  -- architecture testbench

  -- component instantiation
  ledsig: entity work.ethernet_led_signaler
    generic map (
      blink_cycles => blink_cycles)
    port map (
      clock            => clock,
      led0_link        => led0_link,
      led0_act         => led0_act,
      led1_link        => led1_link,
      led1_act         => led1_act,
      led2_link        => led2_link,
      led2_act         => led2_act,
      led_link_out     => led_link_out,
      led_act_out      => led_act_out,
      led_combined_out => led_combined_out);

  -- clock generation
  clock <= not clock after 10 ns;

  led0_link <= '0';
  led1_link <= '0', '1' after 10 us, '0' after 200 us;
  led2_link <= '0', '1' after 5 us, '0' after 15 us;
  led0_act <= '0';
  led1_act <= '0', '1' after 12 us, '0' after 13 us;
  led2_act <= '0';
     

end architecture tb;
