-------------------------------------------------------------------------------
-- Title      : EPCQIO Controller
-- Project    : ODILE
-------------------------------------------------------------------------------
-- File       : epcqio_control.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-06-05
-- Last update: 2020-08-06
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Controls reading/writing from the EPCQ flash memory.
-------------------------------------------------------------------------------
--!\file epcqio_control.vhd

--TODO:
--Add error codes
--Add ability to read data and not send to Ethernet interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.eth_common.all;

--!\brief Controller to read/write data to EPCQ device. 
--!
--! Handles interfacing with the Altera EPCQIO block. When one of the
--!read_data, write_data, or erase_sector lines goes high, the block will
--!register the num_words and address line and either read/write that number of
--!32-bit words from the EPCQ, or will erase the sector containing that address.
--!The busy lines will go high during the read.
--!
--!Note that the last 10 sectors of the ECPQ256 device are reserved for saving
--!configuration registers/ sequencer memory data.

entity epcqio_control is
  port (
    --!Max 20 MHz clock for writing to EPCQ
    epcq_clock        : in  std_logic;
    --!Clock for logic and data in/out lines
    data_clock        : in  std_logic;
    reset             : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Inputs to write
    --!\{
    ---------------------------------------------------------------------------
    --!32-bit data in bus
    data_in           : in  std_logic_vector(31 downto 0) := (others => '0');
    --!Data in write request line
    data_in_valid     : in  std_logic                     := '0';
    --!Indicates write buffer is full, don't write more data
    write_buffer_full : out std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name Interface to UDP transmission buffer
    --!\{
    ---------------------------------------------------------------------------
    udp_out_bus       : out std_logic_vector(52 downto 0) := (others => '0');
    udp_ready         : in  std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!Address to read/write to
    address           : in  std_logic_vector(31 downto 0) := (others => '0');
    --!Number of words to read/write
    num_words         : in  std_logic_vector(6 downto 0)  := (others => '0');
    --!Read/write triggers
    read_data         : in  std_logic                     := '0';
    write_data        : in  std_logic                     := '0';
    --!External trigger to enable 4byte addressing. Should be unnecessary.
    enable_4byte      : in  std_logic                     := '0';
    --!Erase current sector
    erase_sector      : in  std_logic                     := '0';
    ---------------------------------------------------------------------------
    --!\name State Info
    --!\{
    ---------------------------------------------------------------------------
    read_busy         : out std_logic                     := '0';
    write_busy        : out std_logic                     := '0';
    erase_busy        : out std_logic                     := '0';
    done              : out std_logic                     := '0';
    error_code        : out std_logic_vector(31 downto 0) := (others => '0');
    error_status      : out std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!Clear read/write buffers
    clear_buffers     : in  std_logic                     := '0'
    );
end entity epcqio_control;

architecture vhdl_rtl of epcqio_control is

  --Constants used for various settings
  constant CONST_ONES : std_logic_vector(31 downto 0) := (others => '1');
  constant FIFO_DELAY : natural                       := 2;
  --!Size of pages to read/write
  constant PAGE_SIZE  : natural                       := 256;

  component ru_wrbuff_32x512 is
    port (
      aclr    : in  std_logic := '0';
      data    : in  std_logic_vector (31 downto 0);
      rdclk   : in  std_logic;
      rdreq   : in  std_logic;
      wrclk   : in  std_logic;
      wrreq   : in  std_logic;
      q       : out std_logic_vector (7 downto 0);
      rdempty : out std_logic;
      wrempty : out std_logic;
      wrfull  : out std_logic;
      wrusedw : out std_logic_vector (8 downto 0));
  end component ru_wrbuff_32x512;

  component ru_rdbuff_32x512 is
    port (
      aclr    : in  std_logic := '0';
      data    : in  std_logic_vector (7 downto 0);
      rdclk   : in  std_logic;
      rdreq   : in  std_logic;
      wrclk   : in  std_logic;
      wrreq   : in  std_logic;
      q       : out std_logic_vector (31 downto 0);
      rdempty : out std_logic;
      rdfull  : out std_logic;
      rdusedw : out std_logic_vector (6 downto 0);
      wrfull  : out std_logic;
      wrusedw : out std_logic_vector (8 downto 0));
  end component ru_rdbuff_32x512;

  component epcqio_altasmi_parallel_1vl2 is
    port (
      addr          : in  std_logic_vector (31 downto 0);
      bulk_erase    : in  std_logic                     := '0';
      busy          : out std_logic;
      clkin         : in  std_logic;
      data_valid    : out std_logic;
      datain        : in  std_logic_vector (7 downto 0) := (others => '0');
      dataout       : out std_logic_vector (7 downto 0);
      en4b_addr     : in  std_logic                     := '0';
      illegal_erase : out std_logic;
      illegal_write : out std_logic;
      rden          : in  std_logic;
      read          : in  std_logic                     := '0';
      read_address  : out std_logic_vector (31 downto 0);
      reset         : in  std_logic                     := '0';
      sector_erase  : in  std_logic                     := '0';
      shift_bytes   : in  std_logic                     := '0';
      wren          : in  std_logic                     := '1';
      write         : in  std_logic                     := '0');
  end component epcqio_altasmi_parallel_1vl2;

  constant READBUFF_FULL : std_logic_vector(8 downto 0) := "111111100";

  signal wrbuff_datain  : std_logic_vector(31 downto 0);
  signal wrbuff_rdreq   : std_logic;
  signal wrbuff_wrreq   : std_logic;
  signal wrbuff_q       : std_logic_vector (7 downto 0);
  signal wrbuff_rdempty : std_logic;
  signal wrbuff_wrempty : std_logic;
  --signal wrbuff_rdfull  : std_logic;
  --signal wrbuff_rdusedw : std_logic_vector (6 downto 0);
  signal wrbuff_wrusedw : std_logic_vector (8 downto 0);
  signal wrbuff_wrfull  : std_logic;

  signal rdbuff_datain  : std_logic_vector (7 downto 0);
  signal rdbuff_rdreq   : std_logic;
  signal rdbuff_wrreq   : std_logic;
  signal rdbuff_q       : std_logic_vector (31 downto 0);
  signal rdbuff_rdempty : std_logic;
  signal rdbuff_rdfull  : std_logic;
  signal rdbuff_rdusedw : std_logic_vector (6 downto 0);
  signal rdbuff_wrfull  : std_logic;
  signal rdbuff_wrusedw : std_logic_vector (8 downto 0);

  -----------------------------------------------------------------------------
  -- Internal Signals
  -----------------------------------------------------------------------------
  subtype nwords_type is std_logic_vector(6 downto 0);
  signal nwords        : nwords_type  := (others => '0');
  subtype address_type is std_logic_vector(31 downto 0);
  signal start_address : address_type := (others => '0');

  --Cross-domain registers
  constant NSYNC_STAGES : natural                              := 3;  --Sync stages +1
  type nwords_array is array (integer range <>) of nwords_type;
  signal nwords_sync    : nwords_array(NSYNC_STAGES downto 0)  := (others => (others => '0'));
  type address_array is array (integer range <>) of address_type;
  signal address_sync   : address_array(NSYNC_STAGES downto 0) := (others => (others => '0'));

  subtype ec_cmd_type is std_logic_vector(7 downto 0);
  type ec_cmd_array is array (integer range <>) of ec_cmd_type;
  signal ec_cmd_sync : ec_cmd_array(NSYNC_STAGES downto 0) := (others => (others => '0'));
  signal ec_rsp_sync : ec_cmd_array(NSYNC_STAGES downto 0) := (others => (others => '0'));

  signal ec_cmd : ec_cmd_type := (others => '0');
  signal ec_rsp : ec_cmd_type := (others => '0');

  -----------------------------------------------------------------------------
  --!\name Cross-domain synchronization commands
  --!\{
  -----------------------------------------------------------------------------

  constant ECMD_READ_START   : ec_cmd_type := X"01";
  constant ECMD_READ_STARTED : ec_cmd_type := X"11";
  constant ECMD_READ_DONE    : ec_cmd_type := X"81";

  constant ECMD_WRITE_START   : ec_cmd_type := X"02";
  constant ECMD_WRITE_STARTED : ec_cmd_type := X"12";
  constant ECMD_WRITE_DONE    : ec_cmd_type := X"82";

  constant ECMD_EN4B_START   : ec_cmd_type := X"03";
  constant ECMD_EN4B_STARTED : ec_cmd_type := X"13";
  constant ECMD_EN4B_DONE    : ec_cmd_type := X"83";

  constant ECMD_ERASE_SECTOR_START   : ec_cmd_type := X"04";
  constant ECMD_ERASE_SECTOR_STARTED : ec_cmd_type := X"14";
  constant ECMD_ERASE_SECTOR_DONE    : ec_cmd_type := X"84";
  --!\}
  -----------------------------------------------------------------------------

  type epcqio_state is (HW_RESET, IDLE, ENABLE4B, START_READ, READ_BUFFER,
                        START_WRITE, WAIT_FIFO, SHIFT_BYTES, WAIT_WRITE, START_ERASE_SECTOR, WAIT_BUSY);
  signal ec_next_state : epcqio_state := IDLE;

  type data_state_type is (HW_RESET, IDLE, SEND_WRITE, SEND_READ, SEND_EN4B, SEND_ERASE_SECTOR,
                           WAIT_START, WAIT_DONE);
  signal data_next_state          : data_state_type               := IDLE;
  signal read_busy_sig            : std_logic                     := '0';
  signal buff_reset               : std_logic                     := '0';
  -----------------------------------------------------------------------------
  --!\name EPCQIO component signals
  --!\{
  -----------------------------------------------------------------------------
  signal epcqio_clock             : std_logic                     := '0';
  signal epcqio_addr              : std_logic_vector (31 downto 0);
  signal epcqio_bulk_erase        : std_logic                     := '0';
  signal epcqio_busy              : std_logic;
  signal epcqio_data_valid        : std_logic;
  signal epcqio_datain            : std_logic_vector (7 downto 0) := (others => '0');
  signal epcqio_dataout           : std_logic_vector (7 downto 0);
  signal epcqio_en4b_addr         : std_logic                     := '0';
  signal epcqio_illegal_erase     : std_logic;
  signal epcqio_illegal_write     : std_logic;
  signal epcqio_rden              : std_logic;
  signal epcqio_read              : std_logic                     := '0';
  signal epcqio_read_address      : std_logic_vector (31 downto 0);
  signal epcqio_sector_erase      : std_logic                     := '0';
  signal epcqio_shift_bytes       : std_logic                     := '0';
  signal epcqio_wren              : std_logic                     := '1';
  signal epcqio_write             : std_logic                     := '0';
  --!\}
  -----------------------------------------------------------------------------
  -- UDP interface signals
  -----------------------------------------------------------------------------
  signal data_out                 : std_logic_vector(31 downto 0) := (others => '0');
  constant data_out_port          : std_logic_vector(15 downto 0) := UDP_PORT_EPCQIO;
  signal data_out_valid           : std_logic                     := '0';
  signal data_out_eop             : std_logic                     := '0';
  signal tx_req, tx_busy          : std_logic                     := '0';
  type udp_interface_state_type is (HW_RESET, IDLE, TX_REQ_WAIT, SENDING_DATA, TX_DONE);
  signal udp_interface_next_state : udp_interface_state_type      := IDLE;

begin

  --!Register our UDP output bus
  udp_bus_register : process (data_clock)
  begin
    if rising_edge(data_clock) then
      udp_out_bus(31 downto 0)  <= data_out;
      udp_out_bus(47 downto 32) <= data_out_port;
      udp_out_bus(48)           <= data_out_valid;
      udp_out_bus(49)           <= data_out_eop;
      udp_out_bus(50)           <= tx_req;
      udp_out_bus(51)           <= tx_busy;
      udp_out_bus(52)           <= '0';
    end if;
  end process;

  -----------------------------------------------------------------------------
  --!UDP interface. Responsible for sending data read from the EPCQ device back
  --!to the DAQ server. 
  -----------------------------------------------------------------------------
  udp_interface : process(data_clock, reset)
    variable fifo_timer    : natural := 0;
    variable words_to_read : natural := 0;
    variable words_read    : natural := 0;
  begin
    if reset = '1' then
      data_out                 <= (others => '0');
      data_out_valid           <= '0';
      tx_req                   <= '0';
      tx_busy                  <= '0';
      udp_interface_next_state <= HW_RESET;

    elsif rising_edge(data_clock) then
      --Defaults
      tx_req         <= '0';
      data_out       <= rdbuff_q;
      --data_out <= (others => '0');
      data_out_valid <= '0';
      data_out_eop   <= '0';

      case udp_interface_next_state is
        when HW_RESET =>
          udp_interface_next_state <= IDLE;
          tx_busy                  <= '0';
        when IDLE =>
          words_read := 0;
          tx_busy    <= '0';
          if (read_busy_sig = '0' and to_integer(unsigned(rdbuff_rdusedw)) /= 0) then
            udp_interface_next_state <= TX_REQ_WAIT;
            words_to_read            := to_integer(unsigned(rdbuff_rdusedw));
          end if;
        when TX_REQ_WAIT =>
          tx_req <= '1';
          if (udp_ready = '1') then
            udp_interface_next_state <= SENDING_DATA;
            fifo_timer               := 1;
            rdbuff_rdreq             <= '1';
            tx_busy                  <= '1';
          end if;

        when SENDING_DATA =>
          tx_busy <= '1';
          if (fifo_timer >= FIFO_DELAY) then
            data_out_valid <= '1';
            words_read     := words_read + 1;
          end if;
          --Controls reading fifo
          if (fifo_timer >= words_to_read) then
            rdbuff_rdreq <= '0';
          else
            rdbuff_rdreq <= '1';
          end if;
          if words_read >= words_to_read then
            udp_interface_next_state <= TX_DONE;
          end if;
          fifo_timer := fifo_timer + 1;

        when TX_DONE =>
          tx_busy                  <= '0';
          udp_interface_next_state <= IDLE;

        when others =>
          udp_interface_next_state <= IDLE;
      end case;

    end if;  --Clock block
  end process;

  read_busy         <= read_busy_sig;
  epcqio_clock      <= epcq_clock;
  buff_reset        <= reset or clear_buffers;
  -----------------------------------------------------------------------------
  -- Write buffer signals
  -----------------------------------------------------------------------------
  write_buffer_full <= wrbuff_wrfull;
  wrbuff_datain     <= data_in;
  wrbuff_wrreq      <= data_in_valid;

  --!FIFO buffer that holds data to write to the flash memory.
  wrbuff : entity work.ru_wrbuff_32x512
    port map (
      aclr    => buff_reset,
      data    => wrbuff_datain,
      rdclk   => epcq_clock,
      rdreq   => wrbuff_rdreq,
      wrclk   => data_clock,
      wrreq   => wrbuff_wrreq,
      q       => wrbuff_q,
      rdempty => wrbuff_rdempty,
      wrempty => wrbuff_wrempty,
      wrfull  => wrbuff_wrfull,
      wrusedw => wrbuff_wrusedw);

  -----------------------------------------------------------------------------
  -- Read buffer signals
  -----------------------------------------------------------------------------
  --!FIFO buffer that holds data read from the flash memory.
  rdbuff : entity work.ru_rdbuff_32x512
    port map (
      aclr    => buff_reset,
      data    => rdbuff_datain,
      rdclk   => data_clock,
      rdreq   => rdbuff_rdreq,
      wrclk   => epcq_clock,
      wrreq   => rdbuff_wrreq,
      q       => rdbuff_q,
      rdempty => rdbuff_rdempty,
      rdfull  => rdbuff_rdfull,
      rdusedw => rdbuff_rdusedw,
      wrfull  => rdbuff_wrfull,
      wrusedw => rdbuff_wrusedw);

  -----------------------------------------------------------------------------
  -- EPCQIO device
  -----------------------------------------------------------------------------
  --!Altera megafunction that handles interface with the EPCQ device. Uses the
  --!ARRIA chips dedicated active serial lines to communicate with the flash.
  epcqio_altasmi_parallel_1vl2_1 : entity work.epcqio_altasmi_parallel_1vl2
    port map (
      addr          => epcqio_addr,
      bulk_erase    => epcqio_bulk_erase,
      busy          => epcqio_busy,
      clkin         => epcqio_clock,
      data_valid    => epcqio_data_valid,
      datain        => epcqio_datain,
      dataout       => epcqio_dataout,
      en4b_addr     => epcqio_en4b_addr,
      illegal_erase => epcqio_illegal_erase,
      illegal_write => epcqio_illegal_write,
      rden          => epcqio_rden,
      read          => epcqio_read,
      read_address  => epcqio_read_address,
      reset         => reset,
      sector_erase  => epcqio_sector_erase,
      shift_bytes   => epcqio_shift_bytes,
      wren          => epcqio_wren,
      write         => epcqio_write);

  -----------------------------------------------------------------------------
  -- Data_clock synchronized processes
  -----------------------------------------------------------------------------
  --TODO: add some timeout checks so we don't get stuck in a state
  --!Handles cross-clock synchronization between the logic side (which operates
  --!at ~100 MHz) and the EPCQ flash handling which operates at a slower ~20MHz
  --!clock. 
  data_state_machine : process (data_clock, reset)
    variable timer : natural := 0;
  begin
    if reset = '1' then
      data_next_state <= HW_RESET;
      nwords          <= (others => '0');
      timer           := 0;

    elsif rising_edge(data_clock) then
      case data_next_state is
        when HW_RESET =>
          data_next_state <= IDLE;
        when IDLE =>
          --Default state signals. Will be set appropriately
          --during the read/write/erase command.
          write_busy    <= '0';
          read_busy_sig <= '0';
          erase_busy    <= '0';
          done          <= '0';
          ec_cmd        <= (others => '0');
          timer         := 0;
          --Send commands to the EPCQ controller
          if write_data = '1' then
            data_next_state <= SEND_WRITE;
            nwords          <= num_words;
            start_address   <= address;
          elsif read_data = '1' then
            data_next_state <= SEND_READ;
            start_address   <= address;
            nwords          <= num_words;
          elsif enable_4byte = '1' then
            data_next_state <= SEND_EN4B;
          elsif erase_sector = '1' then
            data_next_state <= SEND_ERASE_SECTOR;
            --Used to determine sector to erase
            start_address   <= address;
          end if;

        --Send write command
        when SEND_WRITE =>
          ec_cmd          <= ECMD_WRITE_START;
          data_next_state <= WAIT_START;
          write_busy      <= '1';
        --Send read command
        when SEND_READ =>
          ec_cmd          <= ECMD_READ_START;
          data_next_state <= WAIT_START;
          read_busy_sig   <= '1';
        --Send enable 4byte addressing
        when SEND_EN4B =>
          ec_cmd          <= ECMD_EN4B_START;
          data_next_state <= WAIT_START;
        --Send sector erase commadn
        when SEND_ERASE_SECTOR =>
          ec_cmd          <= ECMD_ERASE_SECTOR_START;
          data_next_state <= WAIT_START;
          erase_busy      <= '1';
        --Wait until the controller send back that it's started. Timeout after
        --a while because we may miss the start response.
        when WAIT_START =>
          if ec_rsp_sync(0)(4) = '1' then
            data_next_state <= WAIT_DONE;
          --I don't think this is necessary but just in case
          -- elsif ec_rsp_sync(0) = ECMD_EN4B_DONE then
          --    data_next_state <= IDLE;
          --    done            <= '1';
          --    ec_cmd          <= (others => '0');
          else
            data_next_state <= WAIT_START;
          end if;
          --Timeout in case we miss the start response.
          timer := timer + 1;
          if (timer >= 1000000) then
            data_next_state <= IDLE;
          end if;
        --Wait until we recieve a done response.
        when WAIT_DONE =>
          ec_cmd <= (others => '0');
          if ec_rsp_sync(0)(7) = '1' then
            data_next_state <= IDLE;
            done            <= '1';
          else
            data_next_state <= WAIT_DONE;
          end if;
        --Failsafe state
        when others =>
          data_next_state <= IDLE;
      end case;

    end if;
  end process data_state_machine;

  -----------------------------------------------------------------------------
  -- Synchronization registers
  -----------------------------------------------------------------------------
  --!Synchronize commands from the logic clock to the epcq clock.
  ec_sync_reg : process (epcq_clock, reset)
  begin
    if reset = '1' then
      nwords_sync(NSYNC_STAGES-1 downto 0)  <= (others => (others => '0'));
      address_sync(NSYNC_STAGES-1 downto 0) <= (others => (others => '1'));
      ec_cmd_sync                           <= (others => (others => '0'));
    elsif rising_edge(epcq_clock) then
      for I in NSYNC_STAGES-1 downto 0 loop
        nwords_sync(I)  <= nwords_sync(I+1);
        address_sync(I) <= address_sync(I+1);
        ec_cmd_sync(I)  <= ec_cmd_sync(I+1);
      end loop;
      nwords_sync(NSYNC_STAGES)  <= nwords;
      address_sync(NSYNC_STAGES) <= start_address;
      ec_cmd_sync(NSYNC_STAGES)  <= ec_cmd;
    end if;
  end process ec_sync_reg;

  --!Synchronize responses coming from the epcq to the data clock.
  data_sync_reg : process(data_clock, reset)
  begin
    if reset = '1' then
      ec_rsp_sync(NSYNC_STAGES-1 downto 0) <= (others => (others => '0'));
    elsif rising_edge(data_clock) then
      for I in NSYNC_STAGES-1 downto 0 loop
        ec_rsp_sync(I) <= ec_rsp_sync(I+1);
      end loop;
      ec_rsp_sync(NSYNC_STAGES) <= ec_rsp;
    end if;
  end process data_sync_reg;

  -----------------------------------------------------------------------------
  -- epcqio_clock syncronized processes
  -----------------------------------------------------------------------------
  --! Controls interfacing with the Altera EPCQIO device to perform reads,
  --! writes, and sector erases. Sets the 
  epcio_control : process (epcq_clock, reset)
    variable do_read       : boolean                       := false;
    variable curr_address  : std_logic_vector(31 downto 0) := (others => '1');
    variable end_address   : std_logic_vector(31 downto 0) := (others => '1');
    variable en4b_enabled  : boolean                       := false;
    variable bytes_done    : natural                       := 0;
    variable bytes_todo    : natural                       := 0;
    variable fifo_timer    : natural                       := 0;
    variable busy_timer    : natural                       := 0;
    variable bytes_shifted : natural                       := 0;
    variable wait_timer    : natural                       := 0;
    variable last_cmd      : ec_cmd_type                   := (others => '0');
    variable last_address  : std_logic_vector(31 downto 0) := (others => '1');
  begin
    if reset = '1' then
      do_read      := false;
      curr_address := (others => '1');
      end_address  := (others => '1');
      epcqio_addr  <= (others => '1');
      last_address := (others => '1');
      en4b_enabled := false;
    elsif rising_edge(epcq_clock) then
      for i in rdbuff_datain'range loop
        rdbuff_datain(rdbuff_datain'left-i) <= epcqio_dataout(i);
      end loop;
      for i in epcqio_datain'range loop
        epcqio_datain(epcqio_datain'left-i) <= wrbuff_q(i);
      end loop;
      rdbuff_wrreq        <= epcqio_data_valid;
      wrbuff_rdreq        <= '0';
      --Default inputs
      epcqio_wren         <= '0';
      epcqio_write        <= '0';
      epcqio_en4b_addr    <= '0';
      epcqio_read         <= '0';
      epcqio_rden         <= '0';
      epcqio_sector_erase <= '0';
      epcqio_bulk_erase   <= '0';
      epcqio_shift_bytes  <= '0';

      case ec_next_state is
        when HW_RESET =>
          ec_next_state <= IDLE;

        when IDLE =>
          bytes_done   := 0;
          busy_timer   := 0;
          wait_timer   := 0;
          end_address  := std_logic_vector(unsigned(address_sync(0))+unsigned(nwords_sync(0))*4);
          bytes_todo   := to_integer(unsigned(nwords_sync(0)))*4;
          curr_address := address_sync(0);
          --Enable 4-byte addressing if we haven't.
          if (en4b_enabled = false) then
            ec_next_state <= ENABLE4B;
          --Do this only if we didn't *just* do it. Mostly used for testing,
          --generally not used. 
          elsif ec_cmd_sync(0) = ECMD_EN4B_START and last_cmd /= ECMD_EN4B_START then
            ec_next_state <= ENABLE4B;
            last_cmd      := ECMD_EN4B_START;
          elsif ec_cmd_sync(0) = ECMD_READ_START then
            ec_next_state <= START_READ;
            last_cmd      := ECMD_READ_START;
          elsif ec_cmd_sync(0) = ECMD_WRITE_START then
            ec_next_state <= START_WRITE;
            last_cmd      := ECMD_WRITE_START;
          --Check we didn't just erase this sector (useful so we don't get
          --stuck in an erase cycle and burn out the chip)
          elsif ec_cmd_sync(0) = ECMD_ERASE_SECTOR_START and last_address /= curr_address and last_cmd /= ECMD_ERASE_SECTOR_START then
            ec_next_state <= START_ERASE_SECTOR;
            last_cmd      := ECMD_ERASE_SECTOR_START;
          else
            ec_next_state <= IDLE;
          end if;
        --Enable 4-byte addressing mode. 
        when ENABLE4B =>
          epcqio_wren      <= '1';
          epcqio_en4b_addr <= '1';
          en4b_enabled     := true;
          ec_next_state    <= WAIT_BUSY;
          wait_timer       := 0;
          ec_rsp           <= ECMD_EN4B_STARTED;
        -----------------------------------------------------------------------
        -- Reading code
        -----------------------------------------------------------------------
        when START_READ =>
          ec_rsp        <= ECMD_READ_STARTED;
          epcqio_addr   <= curr_address;
          epcqio_rden   <= '1';
          epcqio_read   <= '1';
          ec_next_state <= READ_BUFFER;
          --Since we read 8 bit words, but words elsewhere are 32 bit words
          --words_todo    := words_todo * 4;

        when READ_BUFFER =>
          epcqio_rden  <= '1';
          curr_address := epcqio_read_address;
          if epcqio_data_valid = '1' then
            bytes_done := bytes_done + 1;
          end if;
          -- The -1 is because it reads 1 more byte since rden is still high
          if bytes_done = bytes_todo-1 then
            ec_next_state <= WAIT_BUSY;
            wait_timer    := 0;
          --Check for buffer overflows
          elsif unsigned(rdbuff_wrusedw(rdbuff_wrusedw'length-1 downto 0)) >= unsigned(READBUFF_FULL) then
            ec_next_state <= WAIT_BUSY;
            wait_timer    := 0;
          --epcq_err <= EPCQIO_ERR_READBUFF_FULL;
          else
            ec_next_state <= READ_BUFFER;
          end if;

        -----------------------------------------------------------------------
        -- Writing code
        -----------------------------------------------------------------------
        when START_WRITE =>
          ec_rsp        <= ECMD_WRITE_STARTED;
          epcqio_addr   <= curr_address;
          wrbuff_rdreq  <= '1';
          fifo_timer    := 1;
          ec_next_state <= WAIT_FIFO;
          bytes_shifted := 0;
        --Wait for our FIFO to start outputting valid data.
        when WAIT_FIFO =>
          if fifo_timer >= PAGE_SIZE then
            wrbuff_rdreq <= '0';
          else
            wrbuff_rdreq <= '1';
          end if;
          --Data is now valid, so start writing to the EPCQIO's write buffer.
          if fifo_timer >= FIFO_DELAY then
            epcqio_wren        <= '1';
            epcqio_shift_bytes <= '1';
            ec_next_state      <= SHIFT_BYTES;
            bytes_shifted      := 1;
            bytes_done         := bytes_done + 1;
          end if;
          fifo_timer := fifo_timer +1;
        --Shift bytes until we've shifted in more than our page size or the
        --number of bytes we want to write.
        when SHIFT_BYTES =>
          if ((fifo_timer >= PAGE_SIZE) or
              (fifo_timer >= bytes_todo)) then
            wrbuff_rdreq <= '0';
          else
            wrbuff_rdreq <= '1';
          end if;
          --Tell the EPCQIO to write to the flash
          if bytes_done >= bytes_todo then
            epcqio_write  <= '1';
            epcqio_wren   <= '1';
            ec_next_state <= WAIT_WRITE;
            wait_timer    := 0;
          --Otherwise keep shifting in data to the buffer.
          elsif bytes_shifted < PAGE_SIZE then
            epcqio_wren        <= '1';
            epcqio_shift_bytes <= '1';
            bytes_shifted      := bytes_shifted + 1;
            bytes_done         := bytes_done + 1;
          --If we've written more than the page, write data to prevent data corruption.
          else
            epcqio_write  <= '1';
            epcqio_wren   <= '1';
            ec_next_state <= WAIT_WRITE;
            bytes_done    := bytes_done;
            wait_timer    := 0;
          end if;
          fifo_timer := fifo_timer +1;
        --Wait for the EPCQIO device to finish writing to the flash.
        when WAIT_WRITE =>
          if epcqio_busy = '1' then
            ec_next_state <= WAIT_WRITE;
            wait_timer    := 0;
          --Timeout to let the EPCQ start the write process.
          elsif wait_timer < 8 then
            ec_next_state <= WAIT_WRITE;
          --If we're done writing data, finish up.
          elsif bytes_done >= bytes_todo then
            ec_next_state <= IDLE;
            ec_rsp        <= ECMD_WRITE_DONE;
          --Otherwise start writing a new page.
          else
            ec_next_state <= START_WRITE;
            curr_address  := std_logic_vector(unsigned(curr_address)+PAGE_SIZE);
          end if;
          wait_timer := wait_timer + 1;
        --Send the sector erase command.
        when START_ERASE_SECTOR =>
          epcqio_sector_erase <= '1';
          epcqio_wren         <= '1';
          ec_next_state       <= WAIT_BUSY;
          ec_rsp              <= ECMD_ERASE_SECTOR_STARTED;
          wait_timer          := 0;
          epcqio_addr         <= curr_address;

        -----------------------------------------------------------------------
        -- Generic end-of-process wait
        -----------------------------------------------------------------------
        when WAIT_BUSY =>
          if epcqio_busy = '1' then
            ec_next_state <= WAIT_BUSY;
            wait_timer    := 0;
          elsif wait_timer < 4 then
            ec_next_state <= WAIT_BUSY;
          else
            ec_next_state <= IDLE;
            if last_cmd = ECMD_EN4B_START then
              ec_rsp <= ECMD_EN4B_DONE;
            elsif last_cmd <= ECMD_READ_START then
              ec_rsp <= ECMD_READ_DONE;
            elsif last_cmd <= ECMD_WRITE_START then
              ec_rsp <= ECMD_WRITE_DONE;
            elsif last_cmd <= ECMD_ERASE_SECTOR_START then
              ec_rsp <= ECMD_ERASE_SECTOR_DONE;
            end if;
          end if;
          wait_timer := wait_timer + 1;
        when others =>
          ec_next_state <= IDLE;
      end case;

    end if;  --Clock block

  end process epcio_control;

end architecture;


