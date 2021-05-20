-------------------------------------------------------------------------------
-- Title      : UDP Data Aribiter
-- Project    : 
-------------------------------------------------------------------------------
-- File       : udp_data_arbiter.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-04-23
-- Last update: 2020-10-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Arbiter for sending UDP data. Client blocks send in requests to
-- transmit data and must wait until a ready reply before sending data in.
-------------------------------------------------------------------------------
--!\file udp_data_arbiter.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief UDP data arbiter. Responsible for multiplexing access to the UDP data
--!transmission line.
--!
--!Arbitrates between the different logic blocks on the ODILE that need to
--!send UDP data to our
--!DAQ server. Clients are required to request access using the tx_req line,
--!until they recieve a response on the udp_ready line indicating that the
--!interface is ready for tranmission.
--!Clients interface with the arbiter over a 52-bit data bus. The
--!bottom 32 bits of the bus are the data, bits [47..32] are the port to send
--!data over, bit[48] is the data_valid line indicating bits [0..47] are valid,
--!bit[49] is the end-of-packet signal, bit[50] is the transmit request line,
--!and bit[51] indicates the
--!client is busy sending data. This line should go high as soon as the client
--!starts sending data, and should remain high until the client is finished.
--!The client has 1000 cycles to start sending data once it recieves the
--!udp_busy signal, after that it will need to re-request transmission access.

entity udp_data_arbiter is
  port (
    clock             : in  std_logic;
    reset             : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name UDP data outputs
    --!\{
    ---------------------------------------------------------------------------
    --!UDP data line
    udp_data_out      : out std_logic_vector(31 downto 0) := (others => '0');
    --!UDP port currently in transmission
    udp_port_out      : out std_logic_vector(15 downto 0) := (others => '0');
    --!Signal that data on udp_data_out is valid
    udp_valid_out     : out std_logic                     := '0';
    --!End-of-packet signal
    udp_eop_out       : out std_logic                     := '0';
    udp_addr_out : out std_logic_vector(79 downto 0) := (others => '0');    
    udp_dest_iface : out std_logic_vector(3 downto 0) := (others => '0');
    --!\}
    ---------------------------------------------------------------------------
    --!\name Input/outputs from command response
    --!\{
    ---------------------------------------------------------------------------
    udp_in_bus_cmd    : in  std_logic_vector(52 downto 0);
    udp_ready_cmd     : out std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name Input/outputs from ethernet-CCDControl interface
    --!\{
    ---------------------------------------------------------------------------
    udp_in_bus_ccdint : in  std_logic_vector(52 downto 0);
    udp_ready_ccdint  : out std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name Inputs/outputs from our configuration scanner
    --!\{
    ---------------------------------------------------------------------------
    udp_in_bus_scan   : in  std_logic_vector(52 downto 0);
    udp_ready_scan    : out std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name Inputs/outputs from our EPCQIO module
    --!\{
    ---------------------------------------------------------------------------
    udp_in_bus_epcqio : in  std_logic_vector(52 downto 0);
    udp_ready_epcqio  : out std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name Inputs/outputs from our monitoring interface
    --!\{
    ---------------------------------------------------------------------------
    udp_in_bus_monit : in  std_logic_vector(52 downto 0);
    udp_ready_monit  : out std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    -- General in/outs
    ---------------------------------------------------------------------------
    --!Indicates the UDP line is in use
    udp_tx_busy       : out std_logic                     := '0';
    dest_iface : in std_logic_vector(3 downto 0) := (others => '0');
    dest_addr : in std_logic_vector(79 downto 0) := (others => '0')
    );

end entity udp_data_arbiter;

architecture vhdl_rtl of udp_data_arbiter is
  signal tx_req_cmd, tx_req_ccdint            : std_logic;
  signal tx_busy_cmd, tx_busy_ccdint          : std_logic;
  signal data_cmd, data_ccdint                : std_logic_vector(31 downto 0);
  signal port_cmd, port_ccdint                : std_logic_vector(15 downto 0);
  signal valid_cmd, valid_ccdint              : std_logic;
  signal eop_cmd, eop_ccdint                  : std_logic;
  signal client_busy, client_dval, client_eop : std_logic;

  signal tx_req_scan  : std_logic;
  signal tx_busy_scan : std_logic;
  signal data_scan    : std_logic_vector(31 downto 0);
  signal port_scan    : std_logic_vector(15 downto 0);
  signal valid_scan   : std_logic;
  signal eop_scan     : std_logic;

  signal tx_req_epcqio  : std_logic;
  signal tx_busy_epcqio : std_logic;
  signal data_epcqio    : std_logic_vector(31 downto 0);
  signal port_epcqio    : std_logic_vector(15 downto 0);
  signal valid_epcqio   : std_logic;
  signal eop_epcqio     : std_logic;

  signal tx_req_monit  : std_logic;
  signal tx_busy_monit : std_logic;
  signal data_monit    : std_logic_vector(31 downto 0);
  signal port_monit    : std_logic_vector(15 downto 0);
  signal valid_monit   : std_logic;
  signal eop_monit     : std_logic;


  type state_type is (HW_RESET, IDLE, TX_WAIT, TX_BUSY);
  signal next_state     : state_type  := HW_RESET;
  type client_type is (COMMAND_RESP, CCD_INTERFACE, CONFIG_SCANNER, EPCQIO, MONIT, NONE);
  signal current_client : client_type := NONE;
  --Clients have this # of clocks to start transmitting
  constant MAX_TIMEOUT  : natural     := 1000;

begin
  data_cmd    <= udp_in_bus_cmd(31 downto 0);
  port_cmd    <= udp_in_bus_cmd(47 downto 32);
  valid_cmd   <= udp_in_bus_cmd(48);
  eop_cmd     <= udp_in_bus_cmd(49);
  tx_req_cmd  <= udp_in_bus_cmd(50);
  tx_busy_cmd <= udp_in_bus_cmd(51);

  data_ccdint    <= udp_in_bus_ccdint(31 downto 0);
  port_ccdint    <= udp_in_bus_ccdint(47 downto 32);
  valid_ccdint   <= udp_in_bus_ccdint(48);
  eop_ccdint     <= udp_in_bus_ccdint(49);
  tx_req_ccdint  <= udp_in_bus_ccdint(50);
  tx_busy_ccdint <= udp_in_bus_ccdint(51);

  data_scan    <= udp_in_bus_scan(31 downto 0);
  port_scan    <= udp_in_bus_scan(47 downto 32);
  valid_scan   <= udp_in_bus_scan(48);
  eop_scan     <= udp_in_bus_scan(49);
  tx_req_scan  <= udp_in_bus_scan(50);
  tx_busy_scan <= udp_in_bus_scan(51);

  data_epcqio    <= udp_in_bus_epcqio(31 downto 0);
  port_epcqio    <= udp_in_bus_epcqio(47 downto 32);
  valid_epcqio   <= udp_in_bus_epcqio(48);
  eop_epcqio     <= udp_in_bus_epcqio(49);
  tx_req_epcqio  <= udp_in_bus_epcqio(50);
  tx_busy_epcqio <= udp_in_bus_epcqio(51);

  data_monit    <= udp_in_bus_monit(31 downto 0);
  port_monit    <= udp_in_bus_monit(47 downto 32);
  valid_monit   <= udp_in_bus_monit(48);
  eop_monit     <= udp_in_bus_monit(49);
  tx_req_monit  <= udp_in_bus_monit(50);
  tx_busy_monit <= udp_in_bus_monit(51);

  
  --!Multiplexes the data from the current client to the Ethernet block.
  output_multiplexer : process (clock)
  begin
    if rising_edge(clock) then
      --Default output if none of the clients have requested transmission.
      udp_ready_cmd    <= '0';
      udp_ready_ccdint <= '0';
      udp_ready_scan   <= '0';
      udp_ready_epcqio <= '0';
      udp_ready_monit <= '0';
      --For now, just output the current destination iface/address no matter which block is transmitting.
      --!\todo maybe change that
      udp_dest_iface <= dest_iface;
      udp_addr_out <= dest_addr;
      if (current_client = COMMAND_RESP) then
        client_busy   <= tx_busy_cmd;
        client_dval   <= valid_cmd;
        client_eop    <= eop_cmd;
        udp_ready_cmd <= '1';
        udp_data_out  <= data_cmd;
        udp_port_out  <= port_cmd;
        udp_valid_out <= valid_cmd;
        udp_eop_out   <= eop_cmd;
      elsif (current_client = CCD_INTERFACE) then
        client_busy      <= tx_busy_ccdint;
        client_dval      <= valid_ccdint;
        client_eop       <= eop_ccdint;
        udp_ready_ccdint <= '1';
        udp_data_out     <= data_ccdint;
        udp_port_out     <= port_ccdint;
        udp_valid_out    <= valid_ccdint;
        udp_eop_out      <= eop_ccdint;
      elsif (current_client = CONFIG_SCANNER) then
        client_busy    <= tx_busy_scan;
        client_dval    <= valid_scan;
        client_eop     <= eop_scan;
        udp_ready_scan <= '1';
        udp_data_out   <= data_scan;
        udp_port_out   <= port_scan;
        udp_valid_out  <= valid_scan;
        udp_eop_out    <= eop_scan;
      elsif (current_client = EPCQIO) then
        client_busy      <= tx_busy_epcqio;
        client_dval      <= valid_epcqio;
        client_eop       <= eop_epcqio;
        udp_ready_epcqio <= '1';
        udp_data_out     <= data_epcqio;
        udp_port_out     <= port_epcqio;
        udp_valid_out    <= valid_epcqio;
        udp_eop_out      <= eop_epcqio;
      elsif (current_client = MONIT) then
        client_busy      <= tx_busy_monit;
        client_dval      <= valid_monit;
        client_eop       <= eop_monit;
        udp_ready_monit <= '1';
        udp_data_out     <= data_monit;
        udp_port_out     <= port_monit;
        udp_valid_out    <= valid_monit;
        udp_eop_out      <= eop_monit;
      else
        client_busy   <= '0';
        client_dval   <= '0';
        client_eop    <= '0';
        -- udp_data_out <= (others => '0')
        -- udp_port_out <= (others => '0');
        udp_valid_out <= '0';
      end if;
    end if;
  end process output_multiplexer;

  --!State machine that arbitrates which client is allowed to transmit over the
  --!UDP line. Clients send in a request, if not other client is transmitting
  --!the SM will send back a udp_ready signal indicating they are free to
  --!transmit. The SM will timeout the request if the client stops sending data
  --!for >1000 clock cycles.
  state_machine : process (clock, reset)
    variable timeout_count : natural := 0;
  begin
    if reset = '1' then
      next_state     <= HW_RESET;
      udp_tx_busy    <= '0';
      current_client <= NONE;
    elsif rising_edge(clock) then
      udp_tx_busy <= '1';
      case next_state is
        when HW_RESET =>
          udp_tx_busy <= '0';
          next_state  <= IDLE;

        when IDLE =>
          timeout_count := 0;
          udp_tx_busy   <= '0';
          if (tx_req_cmd = '1') then
            next_state     <= TX_WAIT;
            current_client <= COMMAND_RESP;
          elsif (tx_req_ccdint = '1') then
            next_state     <= TX_WAIT;
            current_client <= CCD_INTERFACE;
          elsif (tx_req_scan = '1') then
            next_state     <= TX_WAIT;
            current_client <= CONFIG_SCANNER;
          elsif (tx_req_epcqio = '1') then
            next_state     <= TX_WAIT;
            current_client <= EPCQIO;
          elsif (tx_req_monit = '1') then
            next_state     <= TX_WAIT;
            current_client <= MONIT;
          else
            next_state     <= IDLE;
            current_client <= NONE;
          end if;
        when TX_WAIT =>
          if (client_busy = '1') then
            next_state    <= TX_BUSY;
            timeout_count := 0;
          elsif (timeout_count >= MAX_TIMEOUT) then
            current_client <= NONE;
            next_state     <= IDLE;
          else
            timeout_count := timeout_count + 1;
            next_state    <= TX_WAIT;
          end if;

        when TX_BUSY =>
          --client finished  
          if ((client_busy = '0') or
              (timeout_count >= MAX_TIMEOUT)) then
            next_state     <= IDLE;
            current_client <= NONE;
          --If the client isn't transmitting, increase our timeout counter.
          elsif (client_dval = '0') then
            timeout_count := timeout_count + 1;
            next_state    <= TX_BUSY;
          else
            next_state <= TX_BUSY;
          end if;

      end case;
    end if;
  end process state_machine;

end architecture;





