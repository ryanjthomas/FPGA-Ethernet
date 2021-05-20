-------------------------------------------------------------------------------
-- Title      : ARP Cache
-- Project    : 
-------------------------------------------------------------------------------
-- File       : arp_cache.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2021-02-22
-- Last update: 2021-03-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
--!\file arp_cache.vhd

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.eth_common.all;

entity arp_cache is
  generic (
    clock_speed_mhz : natural := 100;
    timeout_ms : natural := 60000       --!60 seconds (can be increased later maybe)
    );
  port (
    reset : in std_logic;               --!Asynchronous reset
    clock : in std_logic;               --!Clock synchronous to data lines

    server_ip_addr : in std_logic_vector(31 downto 0);  --!IP address of the server whose MAC address we are interested in

    source_mac_addr : in std_logic_vector(47 downto 0);  --!MAC address of whatever just sent us a packet
    source_ip_addr : in std_logic_vector(31 downto 0);  --!Ip Address of whatever sent us a packet
    source_addr_valid : in std_logic := '0';  --!Trigger signal to indicate "source" values are valid
    ARP_cache_reset : in std_logic := '0';  --!Reset our cache values    
    ARP_cache_value : out std_logic_vector(47 downto 0) := (others => '0');  --!Current value of our MAC cache
    ARP_cache_valid : out std_logic := '0';  --!Whether our current value is valid or not
    ARP_cache_stale : out std_logic := '0'  --!Signal that indicates our cache is stale
    );
end entity arp_cache;



architecture vhdl_rtl of arp_cache is
  
  signal cache_updated : std_logic := '0';
  
begin

  --!Cache timeout. Indicates the ARP cache is stale after a certain time has elapsed.
  --!External logic should refresh the cache at that point.
  process (clock)
    variable ms_timer : natural := 0;
    variable clock_timer : natural := 0;
  begin
    if reset = '1' then
      ms_timer := 0;
      clock_timer := 0;
      ARP_cache_stale <= '0';
    elsif rising_edge(clock) then
      if cache_updated = '1' then
        --Reset our timer anytime the cache is updated
        clock_timer := 0;
        ms_timer := 0;
      end if;
      if clock_timer > clock_speed_mhz * 1000 then
        clock_timer := 0;
        --Increment our ms timer
        ms_timer := ms_timer + 1;
      end if;
      if ms_timer >= timeout_ms then
        --Indicates our cache is stale
        ARP_cache_stale <= '1';
      else
        --Otherwise, keep incrementing our timer
        clock_timer := clock_timer + 1;
        --And set our cache to not-stale
        ARP_cache_stale <= '0';
      end if;
    end if;
  end process;
  

  process (clock)
  begin
    if reset = '1' then
      ARP_cache_value <= (others => '0');
      ARP_cache_valid <= '0';
      cache_updated <= '0';
    elsif rising_edge(clock) then
      --Default value
      cache_updated <= '0';
      if ARP_cache_reset = '1' then
        ARP_cache_value <= (others => '0');
        ARP_cache_valid <= '0';
      elsif server_ip_addr = source_ip_addr and source_addr_valid = '1' then
        ARP_cache_value <= source_mac_addr;
        ARP_cache_valid <= '1';
        cache_updated <= '1';
      end if;
    end if;
  end process;

end architecture;
