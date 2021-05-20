-------------------------------------------------------------------------------
-- Title      : Ethernet LED Signaler
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_led_signaler.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-01-21
-- Last update: 2020-07-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: LED signaler for the Ethernet blocks. Takes as input the link
-- and activity LEDs from the ethernet blocks. Activity causes the activity_led
-- line to strobe @~100 ms intervals.
-------------------------------------------------------------------------------
--!\file ethernet_led_signaler.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--!\brief Converts Ethernet link and activity signals into slower signals that
--!can be used for Ethernet activity LED.

entity ethernet_led_signaler is
  generic (
    --!Clock cycles to blink LED on to signal activity.
    blink_cycles : natural := 12500000
    );
  port (
    clock            : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name LED link/activity inputs
    --!\{
    ---------------------------------------------------------------------------
    led0_link        : in  std_logic;
    led0_act         : in  std_logic;
    led1_link        : in  std_logic;
    led1_act         : in  std_logic;
    led2_link        : in  std_logic;
    led2_act         : in  std_logic;
    --!\}
    --!LED output, link status
    led_link_out     : out std_logic;
    --!LED output, activity status
    led_act_out      : out std_logic;
    --!On/off indicates link, blinks if activity
    led_combined_out : out std_logic
    );

end entity ethernet_led_signaler;

architecture vhdl_rtl of ethernet_led_signaler is
  signal led_act_out_sig : std_logic := '0';
  signal led_link        : std_logic := '0';
  signal led_act         : std_logic := '0';
begin

  --!Register LED inputs to reduce timing requirements
  led_register : process(clock)
  begin
    if rising_edge(clock) then
      led_link <= led0_link or led1_link or led2_link;
      led_act  <= (led0_act and led0_link) or
                 (led1_act and led1_link) or
                 (led2_act and led2_link);
      led_link_out     <= led_link;
      led_act_out      <= led_act_out_sig;
      led_combined_out <= led_link and not led_act_out_sig;
    end if;
  end process led_register;

  --!Delays/stretches our activity signal into a strobe that can be seen by eye
  act_stretcher : process(clock)
    variable counter : natural := 0;
  begin
    if rising_edge(clock) then
      if counter = 0 then
        if led_act = '1' then
          --Start stretching our signal
          counter         := counter + 1;
          led_act_out_sig <= '1';
        end if;
      elsif counter <= blink_cycles then
        --50% on duty cycle
        led_act_out_sig <= '1';
        counter         := counter + 1;
      elsif counter <= blink_cycles*2 then
        --50% off duty cycle
        led_act_out_sig <= '0';
        counter         := counter + 1;
      elsif counter >= blink_cycles*2 then
        --Reset our stretcher
        counter         := 0;
        led_act_out_sig <= '0';
      end if;
    end if;
  end process act_stretcher;

end architecture;







