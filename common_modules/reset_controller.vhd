-------------------------------------------------------------------------------
-- Title      : Reset Controller
-- Project    : 
-------------------------------------------------------------------------------
-- File       : reset_controller.vhd
-- Author     : Ryan Thomas 
-- Company    : University of Chicago
-- Created    : 2019-10-17
-- Last update: 2021-02-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: A simple synchronous reset controller. Triggered by activate_reset
-- going high. Sends the reset signal high for a configurable number of
-- cycles before going low, at which point the "reset_done" signal will go hi
-------------------------------------------------------------------------------
--!\file reset_controller.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--!\brief Synchronous reset controller.
--!
--!When activate_reset goes high, this block will send out a reset_out signal
--!for reset_cycles clock cycles. When done, reset_done will go high for one
--!clock cycle. 

entity reset_controller is
  port (
    clock          : in  std_logic := '0';
    --!Reset trigger signal
    activate_reset : in  std_logic := '0';
    --!Active high reset output
    reset_out      : out std_logic := '0';
    --!Reset finished signal. Goes high for 10 cycles after reset_out goes low.
    reset_done     : out std_logic := '0';
    --!Number of clock cycles to hold reset_out high for.
    reset_cycles : in std_logic_vector(31 downto 0) := X"00_00_00_FF"
    );
end entity reset_controller;

architecture rtl of reset_controller is
  constant reset_done_delayed_cycles : natural   := 10;
  signal reset_done_delayed          : std_logic;
  signal reset_done_sig              : std_logic := '0';
begin
  reset_done <= reset_done_delayed;
  
  --!Triggers the reset_out signal when we recieve the activate_reset signal.
  --!The reset signal is held high for reset_cycles clocks.
  reset_trigger : process(clock)
    variable cycle : natural := 0;
  begin
    if rising_edge(clock) then
      if (activate_reset = '1') then
        reset_out      <= '1';
        cycle          := 1;
        reset_done_sig <= '0';
      elsif (cycle >= to_integer(unsigned(reset_cycles))) then
        reset_done_sig <= '1';
        reset_out      <= '0';
        cycle          := 0;
      elsif (cycle >= 1) then
        reset_out      <= '1';
        reset_done_sig <= '0';
        cycle          := cycle + 1;
      elsif (cycle = 0) then
        reset_out      <= '0';
        reset_done_sig <= '0';
      end if;
    end if;
  end process reset_trigger;

  --!Output our reset_done signal for a few clock cycles after we're done with
  --!our reset.
  reset_done_delayer : process(clock)
    variable cycle : natural := 0;
  begin
    if rising_edge(clock) then
      if (reset_done_sig = '1') then
        cycle              := 1;
        reset_done_delayed <= '1';
      elsif (cycle >= reset_done_delayed_cycles) then
        cycle              := 0;
        reset_done_delayed <= '0';
      elsif (cycle >= 1) then
        cycle := cycle + 1;
        reset_done_delayed <= '1';
      else
        reset_done_delayed <= '0';
      end if;
    end if;
  end process reset_done_delayer;
end architecture rtl;




