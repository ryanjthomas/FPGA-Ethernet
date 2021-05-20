-------------------------------------------------------------------------------
-- Title      : Testbench for design "ethernet_block"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_optical_block_tb.vhd
-- Author     : Ryan Thomas  <ryan@ryan-ThinkPad-T450s>
-- Company    : University of Chicago
-- Created    : 2019-08-26
-- Last update: 2021-05-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Ryan Thomas  <ryan@ryan-ThinkPad-T450s>
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

  -- component ports
  signal clock             : std_logic                     := '0';
  signal reset             : std_logic                     := '0';
  signal counter_clock     : std_logic                     := '0';
  signal ref_clk           : std_logic                     := '0';
  signal rxp               : std_logic                     := '0';
  signal txp               : std_logic;
  signal mdc               : std_logic;
  signal mdio_in           : std_logic                     := '0';
  signal mdio_out          : std_logic;
  signal mdio_oen          : std_logic;
  signal conf_done         : std_logic;
  constant NFIFOS          : natural                       := 5;
  signal wrreqs_in         : std_logic_vector(0 to NFIFOS-1);
  signal data_in           : data_array(0 to NFIFOS-1);
  signal wrclks_in         : std_logic_vector(0 to NFIFOS-1);
  signal data_out          : word;
  signal data_valid        : std_logic;
  signal data_eop          : std_logic;
  signal data_port         : std_logic_vector(15 downto 0);
  signal counter           : word;
  signal counter_enable    : std_logic;
  signal config_data_in    : std_logic_vector(31 downto 0);
  signal config_data_out   : std_logic_vector(31 downto 0);
  signal config_valid_in   : std_logic;
  signal config_valid_out  : std_logic;
  signal MAC_change        : boolean                       := false;
  signal flag_change       : boolean                       := false;
  signal counter_change    : boolean                       := false;
  signal mdio              : std_logic                     := 'Z';
  signal udp_data_in       : std_logic_vector(31 downto 0) := (others => '0');
  signal udp_data_valid_in : std_logic                     := '0';
  signal udp_data_port_in  : std_logic_vector(15 downto 0) := (others => '0');
  signal udp_eop_in        : std_logic                     := '0';
  signal udp_addr_in       : std_logic_vector(79 downto 0) := (others => '0');

  signal data_addr_out : std_logic_vector(79 downto 0);
  signal hw_reset_out  : std_logic;
  signal led_link      : std_logic;
  signal led_act       : std_logic;
  signal eth_ready     : std_logic;


begin  -- architecture testbench

  mdio_in <= mdio     when mdio_oen = '1' else 'Z';
  mdio    <= mdio_out when mdio_oen = '0' else 'Z';


  top_mdio_slave_1 : entity work.top_mdio_slave
    port map (
      reset     => reset,
      mdc       => mdc,
      mdio      => mdio,
      dev_addr  => "00000",
      conf_done => conf_done);

  -- component instantiation

  seblock : entity work.ethernet_sgmii_block
    generic map (
      is_testbench => true,
      NFIFOS       => 5,
      port_id      => 0)
    port map (
      clock             => clock,
      reset             => reset,
      config_data_in    => config_data_in,
      config_valid_in   => config_valid_in,
      config_data_out   => config_data_out,
      config_valid_out  => config_valid_out,
      mdc               => mdc,
      mdio              => mdio,
      ref_clk           => ref_clk,
      rxp               => rxp,
      txp               => txp,
      data_in           => data_in,
      wrreqs_in         => wrreqs_in,
      wrclks_in         => wrclks_in,
      udp_data_in       => udp_data_in,
      udp_data_valid_in => udp_data_valid_in,
      udp_data_port_in  => udp_data_port_in,
      udp_eop_in        => udp_eop_in,
      udp_addr_in       => udp_addr_in,
      data_out          => data_out,
      data_valid        => data_valid,
      data_eop          => data_eop,
      data_port         => data_port,
      data_addr_out     => data_addr_out,
      hw_reset_out      => hw_reset_out,
      led_link          => led_link,
      led_act           => led_act,
      eth_ready         => eth_ready);

  reset <= '0', '1' after 10 ns, '0' after 100 ns;

  -- clock generation
  --125 Mhz reference clock
  ref_clk                  <= not ref_clk after 8 ns;
  --100 Mhz main clock
  clock                    <= not clock   after 10 ns;
  --2 Mhz
  --counter_clock            <= not counter_clock after 50 ns;
  counter_clock            <= clock;
  --Loopback
  rxp                      <= txp;
  data_in(0)               <= counter;
  data_in(1)               <= data_out;
  wrreqs_in(0)             <= '1';
  --wrreqs_in(1)             <= data_valid;
  wrreqs_in(1)             <= '0';
  wrreqs_in(2 to NFIFOS-1) <= (others => '0');
  counter_enable           <= '0', '1'    after 100 ns;
  MAC_change               <= false, true after 50 us;
  flag_change              <= false, true after 200 us;
  counter_change           <= false, true after 500 us;

  wrclks_gen : for I in wrclks_in'range generate
    wrclks_in(I) <= counter_clock;
  end generate;


  counter32 : process(counter_clock, reset)
  begin
    if reset = '1' then
      counter <= (others => '0');
    elsif rising_edge(counter_clock) then
      if (counter_enable = '1') then
        counter      <= std_logic_vector(unsigned(counter) + 1);
        wrreqs_in(0) <= '1';
      else
        wrreqs_in(0) <= '0';
        counter      <= counter;
      end if;

    end if;
  end process counter32;

  change_config : process(clock, reset)
    variable mac_changed     : boolean := false;
    variable flag_changed    : boolean := false;
    variable counter_changed : boolean := false;
  begin
    if rising_edge(clock) then
      if (MAC_change and not mac_changed) then
        config_data_in  <= X"10_00_98_76";
        config_valid_in <= '1';
        mac_changed     := true;
      elsif (flag_change and not flag_changed) then
        config_data_in  <= X"10_10_00_11";
        config_valid_in <= '1';
        flag_changed    := true;
      elsif (counter_change and not counter_changed) then
        config_data_in  <= X"10_11_FF_FF";
        config_valid_in <= '1';
        counter_changed := true;
      else
        config_valid_in <= '0';
        config_data_in  <= (others => '0');
      end if;
    end if;
  end process change_config;

  udp_data_gen : process(clock, reset)
    variable count    : natural                       := 100;
    variable testport : std_logic_vector(15 downto 0) := X"ABAB";
  begin
    if rising_edge(clock) then
      udp_data_valid_in <= '0';
      udp_eop_in        <= '0';
      --Delay till after the MAC has changed
      if (MAC_change) then
        if (count < 130) then
          udp_data_in       <= std_logic_vector(to_unsigned(count, 32));
          udp_data_port_in  <= testport;
          udp_data_valid_in <= '1';
          count             := count + 1;
        elsif (count < 160) then
          testport          := X"BABA";
          udp_data_in       <= std_logic_vector(to_unsigned(count, 32));
          udp_data_port_in  <= testport;
          udp_data_valid_in <= '1';
          count             := count + 1;
          if (count = 145) then
            udp_eop_in <= '1';
          end if;
        elsif (count < 180) then
          udp_data_port_in  <= X"0011";
          udp_data_valid_in <= '1';
          udp_data_in       <= std_logic_vector(to_unsigned(count, 32));
          count             := count + 1;

        end if;
      end if;
    end if;
  end process;



end architecture tb;
