-------------------------------------------------------------------------------
-- Title      : Uptime counter
-- Project    : 
-------------------------------------------------------------------------------
-- File       : uptime_counter.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-12-09
-- Last update: 2020-12-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simple 32-bit uptime counter, counts seconds board has been
-- running since last reset.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 Ryan Thomas  <ryant@uchicago.edu>
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-12-09  1.0      ryan  Created
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uptime_counter is
  generic (
    clock_speed_mhz : natural := 100    --! Clock speed in MHz.
    );
  port (
    clock          : in  std_logic;
    reset          : in  std_logic;
    uptime_seconds : out std_logic_vector(31 downto 0)
    );
end entity uptime_counter;

architecture vhdl_rtl of uptime_counter is

  signal counter_internal   : unsigned(31 downto 0);
  signal uptime_internal    : unsigned(31 downto 0);
  constant COUNTER_INTERVAL : unsigned(31 downto 0) := to_unsigned(clock_speed_mhz*1000000, 32);

begin

  output_dff : process(clock)
  begin
    if rising_edge(clock) then
      uptime_seconds <= std_logic_vector(uptime_internal);
    end if;
  end process output_dff;

  counter : process(clock, reset)
  begin
    if reset = '1' then
      counter_internal <= (others => '0');
      uptime_internal  <= (others => '0');
    elsif rising_edge(clock) then
      if (counter_internal = COUNTER_INTERVAL) then
        uptime_internal  <= uptime_internal + 1;
        counter_internal <= X"00_00_00_01";
      else
        counter_internal <= counter_internal + 1;
      end if;
    end if;
  end process counter;
end architecture;





