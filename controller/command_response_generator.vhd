-------------------------------------------------------------------------------
-- Title      : UDP Data Generator
-- Project    : ODILE 
-------------------------------------------------------------------------------
-- File       : command_response_generator.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-04-07
-- Last update: 2020-12-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generates replies to commands from the DAQ
-------------------------------------------------------------------------------
--!\file command_response_generator.vhd


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.eth_common.all;
use work.datetime;
use work.ODILE_command_list.all;

--!\brief Generates replies to commands from the DAQ.
--!
--!Responsible for replies and acknowledgements to commands coming into the
--!ODILE board. Handles sending "DON" responses when commands are finished, and
--!sending back some basic data requests (such as compile time). Larger data
--!queries (such as memory reading) are handled by dedicated blocks in other
--!locations. 


entity command_response_generator is
  port (
    --! Clock, should be same speed as rest of UDP data channel
    clock         : in  std_logic;
    --! Active high asynchonours reset
    reset         : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Triggers to generate reply
    --!\{
    ---------------------------------------------------------------------------
    --! When high, send a command response
    send_cmd_ack  : in  std_logic;
    --! Holds the 32-bits of the command to respond to
    data_in       : in  std_logic_vector(31 downto 0);
    --! Signal that the previous command has finished running
    command_done  : in  std_logic;
    --! Generate an error message when high
    command_error : in  std_logic;
    --! Error code, sent to DAQ on request
    error_code    : in  std_logic_vector(31 downto 0);
    --!\}
    ---------------------------------------------------------------------------
    --!\name Interface to UDP block
    --!\{
    ---------------------------------------------------------------------------
    udp_out_bus   : out std_logic_vector(52 downto 0) := (others => '0');
    udp_ready     : in  std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!Active high busy signal
    busy          : out std_logic                     := '0'
    );

end entity command_response_generator;

architecture vhdl_rtl of command_response_generator is

  signal udp_data_sig  : std_logic_vector(31 downto 0) := (others => '0');
  signal udp_port_sig  : udp_port                      := (others => '0');
  signal udp_valid_sig : std_logic                     := '0';
  signal udp_eop_sig   : std_logic                     := '0';

  component uptime_counter is
    generic (
      clock_speed_mhz : natural);
    port (
      clock          : in  std_logic;
      reset          : in  std_logic;
      uptime_seconds : out std_logic_vector(31 downto 0));
  end component uptime_counter;

  component scfifo_32x16 is
    port (
      aclr  : in  std_logic;
      clock : in  std_logic;
      data  : in  std_logic_vector (31 downto 0);
      rdreq : in  std_logic;
      wrreq : in  std_logic;
      empty : out std_logic;
      q     : out std_logic_vector (31 downto 0));
  end component scfifo_32x16;

  signal cmdbuff_data  : std_logic_vector (31 downto 0);
  signal cmdbuff_rdreq : std_logic;
  signal cmdbuff_wrreq : std_logic;
  signal cmdbuff_empty : std_logic;
  signal cmdbuff_q     : std_logic_vector (31 downto 0);

  type state_type is (HW_RESET, IDLE, WAIT_BUFFER, READ_BUFFER, TX_REQ_WAIT, PROCESS_REPLY,
                      REPLY_TIMESTAMP, REPLY_DONE, REPLY_CMD_LIST, REPLY_UPTIME,
                      REPLY_INVALID, REPLY_ERROR_CODE);
  signal next_state        : state_type                    := IDLE;
  signal curr_command      : command                       := (others => '0');
  --Unused, for future features
  signal command_prefix    : std_logic_vector(7 downto 0)  := (others => '0');
  --UDP data lines
  signal data_out          : std_logic_vector(31 downto 0) := (others => '0');
  signal data_out_port     : std_logic_vector(15 downto 0) := (others => '0');
  signal data_out_valid    : std_logic                     := '0';
  signal data_out_eop      : std_logic                     := '0';
  signal tx_req, tx_busy   : std_logic                     := '0';
  signal command_done_reg  : std_logic                     := '0';
  signal replied_done      : std_logic                     := '0';
  signal command_error_reg : std_logic                     := '0';
  signal replied_error     : std_logic                     := '0';
  signal busy_sig          : std_logic                     := '0';
  signal error_code_reg    : std_logic_vector(31 downto 0) := (others => '0');
  signal uptime_seconds    : std_logic_vector(31 downto 0) := (others => '0');

begin
  udp_out_bus(31 downto 0)  <= data_out;
  udp_out_bus(47 downto 32) <= data_out_port;
  udp_out_bus(48)           <= data_out_valid;
  udp_out_bus(49)           <= data_out_eop;
  udp_out_bus(50)           <= tx_req;
  udp_out_bus(51)           <= tx_busy;
  udp_out_bus(52)           <= '0';
  --tx_busy                   <= data_out_valid;
  tx_busy                   <= busy_sig;
  busy                      <= busy_sig;

  uptime_counter_1 : entity work.uptime_counter
    generic map (
      clock_speed_mhz => 100)
    port map (
      clock          => clock,
      reset          => reset,
      uptime_seconds => uptime_seconds);

  --!Register our output. Also responsible for registering error signal so we
  --!only generate an error message once when we enter an error condition.
  output_register : process (clock)
    variable error_sent : boolean := false;
  begin
    if rising_edge(clock) then
      data_out       <= udp_data_sig;
      data_out_port  <= udp_port_sig;
      data_out_valid <= udp_valid_sig;
      data_out_eop   <= udp_eop_sig;
      --Pipeline data coming in
      cmdbuff_wrreq  <= send_cmd_ack;
      cmdbuff_data   <= data_in;
      --Register for our command_done signal
      if (command_done = '1') then
        command_done_reg <= '1';
      elsif (replied_done = '1') then
        command_done_reg <= '0';
      else
        command_done_reg <= command_done_reg;
      end if;
      --Register our command error reply
      --Since command_error may stay high for many cycles, use error_sent to
      --prevent resending an error message until it goes low again
      if (replied_error = '1') then
        command_error_reg <= '0';
        error_sent        := true;
      elsif (command_error = '1' and not error_sent) then
        command_error_reg <= '1';
        error_code_reg    <= error_code;
      elsif (command_error = '0' and error_sent) then
        error_sent := false;
      else
        command_error_reg <= command_error_reg;
      end if;

    end if;
  end process;

  -----------------------------------------------------------------------------
  --! Buffer that holds command lists to respond to
  --! Necessary because may commands cause immediate responses that will hold the
  --! transmit lines busy before we can respond.
  -----------------------------------------------------------------------------
  scfifo_32x16_1 : entity work.scfifo_32x16
    port map (
      aclr  => reset,
      clock => clock,
      data  => cmdbuff_data,
      rdreq => cmdbuff_rdreq,
      wrreq => cmdbuff_wrreq,
      empty => cmdbuff_empty,
      q     => cmdbuff_q);

  -----------------------------------------------------------------------------
  --! State machine to handle replies to various different commands. In most
  --! cases, it will only respond with the command that was sent to us, followed
  --! by a "DON" when the command is finished (this is sent whenever the
  --! "command_done" signal goes high).
  -----------------------------------------------------------------------------
  state_machine : process (clock)
    variable cmd_idx : natural range 0 to VALID_COMMANDS'length-1 := 0;
  begin
    if reset = '1' then
      next_state    <= HW_RESET;
      udp_data_sig  <= (others => '0');
      udp_port_sig  <= (others => '0');
      udp_valid_sig <= '0';
      udp_eop_sig   <= '0';
      cmdbuff_rdreq <= '0';
      replied_done  <= '0';

    elsif rising_edge(clock) then
      --Default states
      udp_data_sig  <= (others => '0');
      udp_port_sig  <= (others => '0');
      udp_valid_sig <= '0';
      udp_eop_sig   <= '0';
      cmdbuff_rdreq <= '0';
      --Default is busy, to keep tx_busy held hi when we still have data to transmit
      busy_sig      <= '1';
      tx_req        <= '0';
      replied_done  <= '0';
      replied_error <= '0';

      case next_state is
        when HW_RESET =>
          next_state <= IDLE;
          busy_sig   <= '0';

        when IDLE =>

          if (cmdbuff_empty = '0') then
            next_state    <= WAIT_BUFFER;
            cmdbuff_rdreq <= '1';
          elsif (command_error_reg = '1' and replied_error = '0') then
            next_state   <= TX_REQ_WAIT;
            curr_command <= CMD_ERROR;
          elsif (command_done_reg = '1' and replied_done = '0') then
            next_state   <= TX_REQ_WAIT;
            curr_command <= CMD_DONE;
          else
            next_state <= IDLE;
            --Release our tx_busy line
            busy_sig   <= '0';
          end if;

        --FIFO takes 1 clock cycle to respond
        when WAIT_BUFFER =>
          next_state <= READ_BUFFER;

        --Read and register our command to respond to
        when READ_BUFFER =>
          tx_req         <= '1';
          curr_command   <= cmdbuff_q(23 downto 0);
          command_prefix <= cmdbuff_q(31 downto 24);
          next_state     <= TX_REQ_WAIT;

        --Wait until the UDP transmission line is ready to recieve data
        when TX_REQ_WAIT =>
          if (udp_ready = '1') then
            next_state <= PROCESS_REPLY;
          else
            tx_req     <= '1';
            next_state <= TX_REQ_WAIT;
          end if;

        --Generates the actual response
        when PROCESS_REPLY =>
          udp_data_sig  <= X"F0" & curr_command;
          udp_port_sig  <= UDP_PORT_COMMAND_REPLY;
          udp_valid_sig <= '1';

          case curr_command is
            --TODO: add a check that the error is gone
            when CMD_CLEAR_ERROR =>
              next_state <= REPLY_DONE;
            --TODO: add check that reset is done
            when CMD_RESET_CABAC =>
              next_state <= REPLY_DONE;
            when CMD_DONE =>
              replied_done <= '1';
              next_state   <= IDLE;
            when CMD_ERROR =>
              replied_error <= '1';
              next_state    <= IDLE;
            when CMD_GET_TS =>
              next_state <= REPLY_TIMESTAMP;
            when CMD_GET_ERROR =>
              next_state <= REPLY_ERROR_CODE;
            --Sets an internal signal so automatically done
            when CMD_EPCQ_SETA =>
              next_state <= REPLY_DONE;
            when CMD_EPCQ_CLEAR =>
              next_state <= REPLY_DONE;
            --Generates a reply with all valid commands
            when CMD_GET_CMD_LIST =>
              next_state <= REPLY_CMD_LIST;
              cmd_idx    := 0;
            --Replies with uptime in seconds (roughly)
            when CMD_GET_UPTIME =>
              next_state <= REPLY_UPTIME;              

            when others =>
              if (is_valid_command(curr_command)) then
                next_state <= IDLE;
              else
                next_state <= REPLY_INVALID;
              end if;
          end case;
        --Replies with the compilation timestamp. This relies on datetime being
        --properly regenerated at compile time, which can be done using the
        --make_datetime.tcl script and a setting in the .qsf file.
        when REPLY_TIMESTAMP =>
          udp_data_sig  <= std_logic_vector(to_unsigned(datetime.EPOCH_INT, 32));
          udp_port_sig  <= UDP_PORT_COMMAND_REPLY;
          udp_valid_sig <= '1';
          next_state    <= REPLY_DONE;

        when REPLY_ERROR_CODE =>
          udp_data_sig  <= command_error & error_code_reg(30 downto 0);
          udp_port_sig  <= UDP_PORT_COMMAND_REPLY;
          udp_valid_sig <= '1';
          next_state    <= REPLY_DONE;

        when REPLY_CMD_LIST =>
          udp_data_sig  <= X"00" & VALID_COMMANDS(cmd_idx);
          udp_port_sig  <= UDP_PORT_COMMAND_REPLY;
          udp_valid_sig <= '1';
          if (cmd_idx >= VALID_COMMANDS'length-1) then
            next_state <= REPLY_DONE;
          else
            cmd_idx    := cmd_idx + 1;
            next_state <= REPLY_CMD_LIST;
          end if;
        when REPLY_UPTIME =>
          udp_data_sig  <= uptime_seconds;
          udp_port_sig  <= UDP_PORT_COMMAND_REPLY;
          udp_valid_sig <= '1';
          next_state    <= REPLY_DONE;
          
        --Special case for internal data generated here
        when REPLY_DONE =>
          udp_data_sig  <= X"F0" & CMD_DONE;
          udp_port_sig  <= UDP_PORT_COMMAND_REPLY;
          udp_valid_sig <= '1';
          next_state    <= IDLE;

        --Generated when we recieve an invalid command
        when REPLY_INVALID =>
          udp_data_sig  <= X"F0" & CMD_INVALID;
          udp_port_sig  <= UDP_PORT_COMMAND_REPLY;
          udp_valid_sig <= '1';
          next_state    <= IDLE;
        --Fallthrough case to make our FSM safe
        when others =>
          next_state <= IDLE;

      end case;
    end if;
  end process state_machine;


end architecture;



