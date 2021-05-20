-------------------------------------------------------------------------------
-- Title      : Config Block Scanner
-- Project    : 
-------------------------------------------------------------------------------
-- File       : config_block_scanner.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-05-13
-- Last update: 2020-07-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Block that scans over the config register block address space
-- to read all configuration data.
-------------------------------------------------------------------------------
--!\file config_block_scanner.vhd
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.config_pkg.all;
use work.eth_common.all;

--! \brief Configuration scanner that scans over all configuration register space.
--!
--! Relatively simple tool to read config_register_block elements. Since each
--!configuration register has it's own block address, it works by sending a read
--!request to every block address from 0 to 127, then waiting for a response.
--!Since there may be several registers between it and the configuration blocks
--!(since configuration blocks are not a timing-critical path the delay is not
--!fixed) it waits for several clock cycles before assuming the block doesn't
--!exist. This means we can add or remove blocks dynamically and it will still
--!scan over all of them without requiring any alteration.
--!
--!Once it recieves valid data from a block, it will send read requests to all
--!configuration registers from that block address. This data is then forwarded
--!to our UDP data block for transmitting back to the DAQ system.

entity config_block_scanner is
  port (
    --! Main clock. Should run at same speed as all other configuration registers.
    clock               : in  std_logic;
    --! Asynchronouse active high reset
    reset               : in  std_logic;
    --! Configuration data input. Connects to ouputs of config register blocks.
    config_data_in      : in  std_logic_vector(31 downto 0) := (others => '0');
    --! Configuration data valid signal. Connects to output of config register
    --! data valid.
    config_valid_in     : in  std_logic                     := '0';
    --! Output configuration data. Contains the block and register addresses to
    --! read from.
    config_data_out     : out std_logic_vector(31 downto 0) := (others => '0');
    --! Signal that configuration_data_out is valid.
    config_valid_out    : out std_logic                     := '0';
    ---------------------------------------------------------------------------
    --! \name Interface to UDP data block
    --! \{
    ---------------------------------------------------------------------------
    udp_out_bus         : out std_logic_vector(52 downto 0) := (others => '0');
    udp_ready           : in  std_logic                     := '0';
    --! \}
    ---------------------------------------------------------------------------
    --!Signal to start scanning register blocks
    start_scan_blocks   : in  std_logic                     := '0';
    --!Indicates scan is finished
    scan_finished       : out std_logic                     := '0';
    --!Optional feature to allow scanning a single configuration block
    start_scan_single   : in  std_logic                     := '0';
    --!Block to start scan at (used for start_scan_single, mostly)
    start_block_address : in  std_logic_vector(6 downto 0)  := (others => '0');
    busy                : out std_logic                     := '0'
    );
end entity config_block_scanner;

architecture vhdl_rtl of config_block_scanner is

  type read_state_type is (HW_RESET, IDLE, START_BLOCK, WAIT_BLOCK,
                           READ_BLOCK, NEXT_BLOCK, TX_REQ_WAIT, TX_PAUSE);
  signal next_state        : read_state_type              := HW_RESET;
  signal toread_block_addr : std_logic_vector(6 downto 0) := (others => '0');
  --Clock cycles to wait for config_data_valid to go hi (allows synchronizing
  --if there are multiple clock cycles between us and the config register block)
  constant max_timer       : natural                      := 15;

  signal config_data_out_reg  : std_logic_vector(31 downto 0) := (others => '0');
  signal config_valid_out_reg : std_logic                     := '0';

  signal config_data_in_reg  : std_logic_vector(31 downto 0) := (others => '0');
  signal config_valid_in_reg : std_logic                     := '0';

  signal curr_reg_addr   : std_logic_vector(7 downto 0) := (others => '0');
  signal curr_block_addr : std_logic_vector(6 downto 0) := (others => '0');

  -----------------------------------------------------------------------------
  -- UDP Interface signals
  -----------------------------------------------------------------------------
  signal data_out        : std_logic_vector(31 downto 0) := (others => '0');
  constant data_out_port : udp_port                      := UDP_PORT_CONFIG;
  signal data_out_valid  : std_logic                     := '0';
  signal data_out_eop    : std_logic                     := '0';
  signal tx_req, tx_busy : std_logic                     := '0';

begin

  --Register outputs
  output_register : process (clock)
  begin
    if rising_edge(clock) then
      config_data_out     <= config_data_out_reg;
      config_valid_out    <= config_valid_out_reg;
      config_data_in_reg  <= config_data_in;
      config_valid_in_reg <= config_valid_in;
    end if;
  end process;

  curr_block_addr <= config_data_in_reg(30 downto 24);
  curr_reg_addr   <= config_data_in_reg(23 downto 16);

  --Wire up to our UDP interface bus
  udp_out_bus(31 downto 0)  <= data_out;
  udp_out_bus(47 downto 32) <= data_out_port;
  udp_out_bus(48)           <= data_out_valid;
  udp_out_bus(49)           <= data_out_eop;
  udp_out_bus(50)           <= tx_req;
  udp_out_bus(51)           <= tx_busy;
  udp_out_bus(52)           <= '0';

  state_machine : process (clock)
    variable timer       : natural                      := 0;
    variable pause_timer : natural                      := 0;
    variable max_addr    : std_logic_vector(6 downto 0) := (others => '0');
    variable scan_all    : boolean                      := false;
  begin
    if reset = '1' then
      next_state           <= HW_RESET;
      config_valid_out_reg <= '0';
      scan_finished        <= '0';
      timer                := 0;
      scan_all             := false;
      busy                 <= '0';
    elsif rising_edge(clock) then
      --Default states
      config_data_out_reg  <= (others => '0');
      config_valid_out_reg <= '0';
      scan_finished        <= '0';
      busy                 <= '1';
      tx_req               <= '0';
      data_out             <= (others => '0');
      data_out_valid       <= '0';

      case next_state is

        when HW_RESET =>
          next_state <= IDLE;
          busy       <= '0';
        when IDLE =>
          timer   := 0;
          tx_busy <= '0';
          if start_scan_blocks = '1' then
            next_state        <= TX_REQ_WAIT;
            toread_block_addr <= (others => '0');
            scan_all          := true;
          elsif start_scan_single = '1' then
            next_state        <= TX_REQ_WAIT;
            toread_block_addr <= start_block_address;
            scan_all          := false;
          else
            next_state <= IDLE;
            busy       <= '0';
          end if;
        --Wait until our UDP bus is ready to recieve data
        when TX_REQ_WAIT =>
          tx_req <= '1';
          if (udp_ready = '1') then
            next_state <= START_BLOCK;
            --Registered, so holds state till changed
            tx_busy    <= '1';
          else
            next_state <= TX_REQ_WAIT;
          end if;
        --Start scanning a block
        when START_BLOCK =>
          config_data_out_reg  <= "1" & toread_block_addr & "11111111" & X"00_00";
          config_valid_out_reg <= '1';
          timer                := 0;
          next_state           <= WAIT_BLOCK;
          
        --Wait until we recieve data from a block. If timer > max_timer, assume
        --the block doesn't exist and start scanning the next blcok
        when WAIT_BLOCK =>
          if (config_valid_in_reg = '1') then
            next_state <= READ_BLOCK;
          elsif (timer >= max_timer) then
            next_state <= NEXT_BLOCK;
          else
            next_state <= WAIT_BLOCK;
          end if;
          timer          := timer + 1;
          data_out       <= config_data_in_reg;
          data_out_valid <= config_valid_in_reg;

        --We recieved valid data from a block, so scan over the full register
        --space for that block.
        when READ_BLOCK =>
          if (config_valid_in_reg = '0') then
            next_state <= NEXT_BLOCK;
          else
            next_state <= READ_BLOCK;
          end if;
          data_out       <= config_data_in_reg;
          data_out_valid <= config_valid_in_reg;

        --Starts scanning the next block
        when NEXT_BLOCK =>
          if (toread_block_addr = "1111111" or not scan_all) then
            next_state    <= IDLE;
            scan_finished <= '1';
          else
            toread_block_addr <= std_logic_vector(unsigned(toread_block_addr)+1);
            next_state        <= TX_PAUSE;
            tx_busy           <= '0';
            pause_timer       := 0;
          end if;

        --When we finish scanning one block, we release the UDP data lines to
        --let other devices send data if necessary
        when TX_PAUSE =>
          if (pause_timer >= 8) then
            next_state <= TX_REQ_WAIT;
          else
            pause_timer := pause_timer + 1;
            next_state  <= TX_PAUSE;
          end if;

        when others =>
          next_state <= IDLE;

      end case;

    end if;
  end process state_machine;

end architecture;



