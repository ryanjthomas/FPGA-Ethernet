-------------------------------------------------------------------------------
-- Title      : Ethernet-monitoring block interface
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_monitoring_interface.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-10-14
-- Last update: 2020-10-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Interface between the ODILE monitoring block and the Ethernet
-- interface.
-------------------------------------------------------------------------------
--!\file ethernet_monitoring_interface.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ltc2945_package.all;
use work.eth_common.all;

--!\brief Interface between ADC monitoring and Ethernet blocks.
--!
--! Block responsible for talking between the ADC monitoring block and the Ethernet interface.
--! Handle sending start_monitoring signal to the monitoring block, and reading back the
--! monitoring result register to the udp transmission interface.


entity ethernet_monitoring_interface is
  port (
    --! Ethernet clock    
    clock : in std_logic;
    --! Asynchronous reset
    reset : in std_logic;
    --! Start reading the register
    read_register : in std_logic := '0';
    --! Command to start monitoring from the controller
    start_monitoring_cmd : in std_logic := '0';
    --! Signal to the monitoring block to start
    start_monitoring : out std_logic := '0';
    --! Signal from the monitoring block that monitoring is in progress
    monitoring_busy : in std_logic := '0';
    --! Output result from the monitoring block
    Reg32b_monitoring : in array18x32b;
    --------------------------------------------------------------------------
    --!\name UDP data lines
    --!\{
    --------------------------------------------------------------------------
    udp_out_bus : out std_logic_vector(52 downto 0) := (others => '0');
    udp_ready : in std_logic
    );
  --!\}
end entity ethernet_monitoring_interface;

architecture vhdl_rtl of ethernet_monitoring_interface is
  signal Reg32b_monitoring_reg : array18x32b;
  signal start_monitoring_reg : std_logic;
  signal monitoring_busy_reg : std_logic;

  signal data_out        : std_logic_vector(31 downto 0) := (others => '0');
  constant data_out_port : udp_port                      := UDP_PORT_MONITORING;
  signal data_out_valid  : std_logic                     := '0';
  signal data_out_eop    : std_logic                     := '0';
  signal tx_req, tx_busy : std_logic                     := '0';

  type state_type is (HW_RESET, IDLE, TX_REQ_WAIT, READ_REG, READ_DONE);
  signal next_state : state_type := HW_RESET;
  
begin

  --Wire up to our UDP interface bus
  udp_out_bus(31 downto 0)  <= data_out;
  udp_out_bus(47 downto 32) <= data_out_port;
  udp_out_bus(48)           <= data_out_valid;
  udp_out_bus(49)           <= data_out_eop;
  udp_out_bus(50)           <= tx_req;
  udp_out_bus(51)           <= tx_busy;
  udp_out_bus(52)           <= '0';
  
  --!Buffer signals to/from the monitoring block
  register_buffer : process (clock)
  begin
    if rising_edge(clock) then
      --Inputs
      Reg32b_monitoring_reg <= Reg32b_monitoring;
      monitoring_busy_reg <= monitoring_busy;
      start_monitoring_reg <= start_monitoring_cmd;      
      --Outputs
      start_monitoring <= start_monitoring_reg;
    end if;
  end process;

  --!Handles talking to our UDP data arbiter to send all 18 words of our monitoring register.
  state_machine : process (clock)
    variable index : natural := 0;
  begin
    if reset = '1' then
      next_state <= HW_RESET;
      data_out <= (others => '0');
      data_out_valid <= '0';
      data_out_eop <= '0';
      tx_busy <= '0';
      
    elsif rising_edge(clock) then
      --Default states
      data_out_valid <= '0';
      data_out_eop <= '0';
      tx_busy <= '0';
      case next_state is
        when HW_RESET =>
          next_state <= IDLE;
        when IDLE =>
          data_out <= (others => '0');
          data_out_valid <= '0';
          data_out_eop <= '0';
                     
          if read_register='1' then
            next_state        <= TX_REQ_WAIT;
          end if;
        when TX_REQ_WAIT =>
          tx_req <= '1';
          if udp_ready = '1' then
            next_state <= READ_REG;
            index := 0;
            tx_busy <= '1';
          else
            next_state <= TX_REQ_WAIT;
          end if;

        when READ_REG =>
          data_out <= Reg32b_monitoring_reg(index);
          data_out_valid <= '1';
          tx_busy <= '1';
          if (index = Reg32b_monitoring'length - 1) then
            next_state <= READ_DONE;
          else
            next_state <= READ_REG;
            index := index + 1;
          end if;

        when READ_DONE =>
          data_out_valid <= '0';
          tx_busy <= '0';
          next_state <= IDLE;
      end case;

    end if;                           --Clock block
  end process;

end architecture;
