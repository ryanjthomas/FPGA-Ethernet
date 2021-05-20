-------------------------------------------------------------------------------
-- Title      : Configuration Data Manager
-- Project    : ODILE
-------------------------------------------------------------------------------
-- File       : config_data_manager.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-08-06
-- Last update: 2020-08-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Loads and saves configuration register data to and from the
-- EPCQ256 flash device on the ODILE board.
-------------------------------------------------------------------------------
--!\file config_data_manager.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief Configuration data manager for loading and saving data to and from
--!the EPCQ256 flash memory on the ODILE mainboard.
--!
--!Configuration data on the EPCQ is stored in 64-word blocks, with each
--!block starting with a 32-bit word, with bits [31..24]=0xcd, [24..16]=block size (max 64),
--!and bits [15..0] = UDP port for data to go.

entity config_data_manager is
  port (
    --!Clock, assumed to be 100 MHz
    clock          : in  std_logic;
    --!Asynchronous reset
    reset          : in  std_logic;
    --!Load configuration signal
    load_config    : in  std_logic                    := '0';
    --!Configuration page to load (0 to 9) 
    config_page    : in  std_logic_vector(3 downto 0) := (others => '0');
    ---------------------------------------------------------------------------
    --!\name EPCQ interface lines
    --!\{
    ---------------------------------------------------------------------------
    epcq_address   : out std_logic_vector(31 downto 0);
    epcq_numwords  : out std_logic_vector(6 downto 0);
    --epcq_write_data         : out std_logic                     := '0';
    epcq_read_data : out std_logic                    := '0';
    --epcq_sector_erase       : out std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name Data in/out lines
    --!\{
    ---------------------------------------------------------------------------
    eth_data_out   : out std_logic_vector(31 downto 0);
    eth_port_out   : out std_logic_vector(15 downto 0);
    eth_dval_out   : out std_logic;
    eth_data_in    : in  std_logic_vector(31 downto 0);
    eth_port_in    : in  std_logic_vector(15 downto 0);
    eth_dval_in    : in  std_logic;
    --!\}
    config_busy    : out std_logic                    := '0';
    config_done    : out std_logic                    := '0'
    );

end entity config_data_manager;

architecture vhdl_rtl of config_data_manager is
  --!Number of cycles to wait after reset before we do anything. 500 ms @100
  --!MHz clock.
  constant RESET_WAIT_CYCLES : natural                       := 50000000;
  constant EPCQ_TIMEOUT      : natural                       := 1000000;
  --!Number of 32 bit words to read at a time
  constant EPCQ_PAGE_SIZE    : std_logic_vector(6 downto 0)  := std_logic_vector(to_unsigned(64, 7));
  subtype address_type is std_logic_vector(31 downto 0);
  type address_array_type is array(integer range <>) of address_type;
  constant CPAGE_SIZE        : std_logic_vector(31 downto 0) := X"00_01_00_00";
  constant CPAGE_START_ADDRESSES : address_array_type(0 to 9) := (X"01_F6_00_00",
                                                                  X"01_F7_00_00",
                                                                  X"01_F8_00_00",
                                                                  X"01_F9_00_00",
                                                                  X"01_FA_00_00",
                                                                  X"01_FB_00_00",
                                                                  X"01_FC_00_00",
                                                                  X"01_FD_00_00",
                                                                  X"01_FE_00_00",
                                                                  X"01_FF_00_00");  --Page 9

  type state_type is (HW_RESET, IDLE, RESET_WAIT, START_CONFIG, READ_CPAGE,
                      WAIT_READ, READ_DATA, CONFIG_ERROR, READ_DONE);
  signal next_state : state_type := HW_RESET;

  signal config_page_reg    : natural range 0 to 15         := 0;
  signal curr_addr_reg      : std_logic_vector(31 downto 0) := (others => '0');
  signal epcq_address_reg   : std_logic_vector(31 downto 0);
  signal epcq_read_data_reg : std_logic;

  signal data_in_reg, data_out_reg : std_logic_vector(31 downto 0);
  signal port_in_reg, port_out_reg : std_logic_vector(15 downto 0);
  signal dval_in_reg, dval_out_reg : std_logic;
  signal error_code_reg            : std_logic_vector(15 downto 0) := (others => '0');

  constant ERR_TIMEOUT : std_logic_vector(15 downto 0) := X"00_10";
  signal block_size    : natural;

begin

  --epcq_address  <= curr_addr_reg;
  epcq_numwords <= EPCQ_PAGE_SIZE;

  --!Register our data in/out
  data_inout_reg : process(clock)
  begin
    if rising_edge(clock) then
      data_in_reg    <= eth_data_in;
      port_in_reg    <= eth_port_in;
      dval_in_reg    <= eth_dval_in;
      eth_data_out   <= data_out_reg;
      eth_port_out   <= port_out_reg;
      eth_dval_out   <= dval_out_reg;
      epcq_read_data <= epcq_read_data_reg;
      epcq_address   <= epcq_address_reg;
    end if;
  end process data_inout_reg;

  state_machine : process(clock, reset)
    variable timer         : natural := 0;
    variable words_read    : natural := 0;
    variable words_to_read : integer := 0;
  begin
    if reset = '1' then
      next_state <= HW_RESET;
    elsif rising_edge(clock) then
      --Default states
      dval_out_reg       <= '0';
      data_out_reg       <= (others => '0');
      config_busy        <= '1';
      config_done        <= '0';
      epcq_read_data_reg <= '0';
      case next_state is
        when IDLE =>
          config_busy <= '0';
          timer       := 0;
          if load_config = '1' then
            --Register the configuration page to load
            config_page_reg <= to_integer(unsigned(config_page));
            next_state      <= START_CONFIG;
          else
            next_state <= IDLE;
          end if;
          port_out_reg <= (others => '0');

        when HW_RESET =>
          next_state      <= RESET_WAIT;
          timer           := 0;
          config_page_reg <= 0;

        --Wait for some timer after a reset before trying to load any data. 
        when RESET_WAIT =>
          timer := timer + 1;
          if timer >= RESET_WAIT_CYCLES then
            next_state <= START_CONFIG;
          else
            next_state <= RESET_WAIT;
          end if;

        --Setup anything for start of reading from flash.
        when START_CONFIG =>
          curr_addr_reg <= CPAGE_START_ADDRESSES(config_page_reg);
          next_state    <= READ_CPAGE;
          port_out_reg  <= (others => '0');

        when READ_CPAGE =>
          --Start reading data from our EPCQ device          
          epcq_address_reg   <= curr_addr_reg;
          epcq_read_data_reg <= '1';
          next_state         <= WAIT_READ;
          timer              := 0;
          words_read         := 0;

        --Wait for data from our flash memory to be available
        when WAIT_READ =>
          if (dval_in_reg = '1' and port_in_reg = UDP_PORT_EPCQIO) then
            --Check if we have a valid block of data and we are still within the current page
            if (data_in_reg(31 downto 24) /= X"CD") or
              (unsigned(curr_addr_reg) >= unsigned(CPAGE_START_ADDRESSES(config_page_reg))+unsigned(CPAGE_SIZE)) then
              next_state <= READ_DONE;
            else
              --Grab the port to send the data to from the first word of each 256-byte page
              port_out_reg <= data_in_reg(15 downto 0);
              --Size of configuration block, **including** this word
              block_size   <= to_integer(unsigned(data_in_reg(23 downto 16)));
              next_state   <= READ_DATA;
              --This is our first word, so set it to 1
              words_read   := 1;
            end if;
          elsif timer >= EPCQ_TIMEOUT then
            next_state     <= CONFIG_ERROR;
            error_code_reg <= ERR_TIMEOUT;
          else
            next_state <= WAIT_READ;
            timer      := timer + 1;
          end if;

        when READ_DATA =>
          --Read our next block of data
          if (words_read >= to_integer(unsigned(EPCQ_PAGE_SIZE))) then
            curr_addr_reg <= std_logic_vector(unsigned(curr_addr_reg)+unsigned(EPCQ_PAGE_SIZE)*4);
            next_state    <= READ_CPAGE;
          elsif dval_in_reg = '1' then
            --Port is registered above            
            data_out_reg <= data_in_reg;
            if (words_read < block_size) then
              dval_out_reg <= '1';
            end if;
            words_read   := words_read + 1;
          elsif timer >= EPCQ_TIMEOUT then
            next_state     <= CONFIG_ERROR;
            error_code_reg <= ERR_TIMEOUT;
          else
            timer := timer + 1;
          end if;

        --!\todo add logic here
        when CONFIG_ERROR =>
          next_state <= IDLE;

        when READ_DONE =>
          next_state  <= IDLE;
          config_done <= '1';

        when others =>
          next_state <= IDLE;

      end case;
    end if;  --Clock block
  end process;

end architecture;


