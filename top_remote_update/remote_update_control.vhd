-------------------------------------------------------------------------------
-- Title      : ODILE Remote Update Controller
-- Project    : 
-------------------------------------------------------------------------------
-- File       : remote_update_control.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-07-07
-- Last update: 2020-08-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Controller for the remote update functionality of the DAMIC-M
-- ODILE board.
-------------------------------------------------------------------------------
--!\file remote_update_control.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.eth_common.all;

--!\brief Controls Altera remote update logic.
--!
--!Responsible for setting up the remote update parameters: enabling thew
--!watchdog, setting the watchdog timeout, writing the start address of the
--!firmware, and actually starting the reconfiguration. Also reads parameters
--!from the RU block when our logic comes up, either from loading a new firmware
--!or from an initial power on.

entity remote_update_control is
  port (
    clock               : in  std_logic;
    reset               : in  std_logic;
    --!Start the reconfiguration
    do_reconfig         : in  std_logic                     := '0';
    --!Re-read the configuration parameters
    reread_params       : in  std_logic                     := '0';
    --!The upper 24 bits of the address with the firmware to load
    application_address : in  std_logic_vector(23 downto 0) := (others => '1');
    --!Is application or factory firmware flag. Currently non-functional
    is_anf              : out std_logic                     := '0';
    --!Should go high when there is a reconfiguration error.
    reconfig_error      : out std_logic                     := '0'
    );
end entity remote_update_control;

architecture vhdl_rtl of remote_update_control is
  constant ZEROS            : std_logic_vector(31 downto 0) := (others => '0');
  --!Default watchdog timeout (in units of 
  constant WATCHDOG_TIMEOUT : std_logic_vector(11 downto 0) := "000100000000";

  component altru_block_rmtupdt_adl is
    port (
      busy        : out std_logic;
      clock       : in  std_logic;
      data_in     : in  std_logic_vector (23 downto 0) := (others => '0');
      data_out    : out std_logic_vector (23 downto 0);
      param       : in  std_logic_vector (2 downto 0)  := (others => '0');
      read_param  : in  std_logic                      := '0';
      reconfig    : in  std_logic                      := '0';
      reset       : in  std_logic;
      reset_timer : in  std_logic                      := '0';
      write_param : in  std_logic                      := '0');
  end component altru_block_rmtupdt_adl;

  signal ru_busy        : std_logic;
  signal ru_data_in     : std_logic_vector (23 downto 0) := (others => '0');
  signal ru_data_out    : std_logic_vector (23 downto 0);
  signal ru_param       : std_logic_vector (2 downto 0)  := (others => '0');
  signal ru_read_param  : std_logic                      := '0';
  signal ru_reconfig    : std_logic                      := '0';
  signal ru_reset_timer : std_logic                      := '0';
  signal ru_write_param : std_logic                      := '0';

  constant PARAM_RECONFIG   : std_logic_vector(2 downto 0) := "000";
  constant PARAM_PAGE_ADDR  : std_logic_vector(2 downto 0) := "100";
  constant PARAM_ANF        : std_logic_vector(2 downto 0) := "101";
  constant PARAM_WD_TIMEOUT : std_logic_vector(2 downto 0) := "010";
  constant PARAM_WD_ENABLE  : std_logic_vector(2 downto 0) := "011";

  signal curr_anf             : std_logic                     := '0';
  signal curr_reconfig_status : std_logic_vector(4 downto 0)  := (others => '0');
  signal curr_page_address    : std_logic_vector(23 downto 0) := (others => '1');

  type reconfig_state is (HW_RESET, IDLE, WRITE_TIMEOUT, WRITE_WATCHDOG_ENABLE, WRITE_PAGE_ADDRESS,
                          WRITE_ANF, START_RECONFIG, READ_RECONFIG, READ_PAGE_ADDRESS, READ_ANF, READ_DONE);
  signal next_state : reconfig_state := HW_RESET;

begin

  reconfig_error <= curr_reconfig_status(0);
  is_anf         <= curr_anf;

  altru_block_rmtupdt_adl_1 : entity work.altru_block_rmtupdt_adl
    port map (
      busy        => ru_busy,
      clock       => clock,
      data_in     => ru_data_in,
      data_out    => ru_data_out,
      param       => ru_param,
      read_param  => ru_read_param,
      reconfig    => ru_reconfig,
      reset       => reset,
      reset_timer => ru_reset_timer,
      write_param => ru_write_param);

  --!Kick the watchdog timer every so often to prevent a reset.
  --!\todo Change this so we can deliberately cause a reconfig in case of problems.
  watchdog_timer : process (clock)
    variable timer : natural range 0 to 20 := 0;
  begin
    if rising_edge(clock) then
      if timer = 10 then
        ru_reset_timer <= '1';
        timer          := 0;
      else
        ru_reset_timer <= '0';
        timer          := timer + 1;
      end if;
    end if;  --Clock block
  end process watchdog_timer;

  --!State machine that handles talking to the altera remote update block. 
  reconfig_sm : process (clock, reset)
    variable page_address : std_logic_vector(23 downto 0) := (others => '0');
    variable params_read  : boolean                       := false;
    variable timer : natural := 0;
    variable wait_busy : boolean := false;
  begin
    if reset = '1' then
      next_state  <= HW_RESET;
      params_read := false;
    elsif rising_edge(clock) then
      --defaults
      ru_write_param <= '0';
      ru_reconfig    <= '0';
      ru_read_param  <= '0';

      --If the RU block is busy, don't go to the next state.
      if ru_busy = '1' then
        next_state <= next_state;
        wait_busy := false;
        timer := 0;
      --Wait a while for the RU block to start. We need this because the busy
      --signal goes high one clock cycle after we trigger a read/write, so we
      --can't rely on that to tell us not to go to the next state.
      elsif wait_busy then
        if timer <= 60 then
          timer := timer + 1;
        else
          --We've exceeded timeout, so don't lockup the interface          
          --!\todo generate error here
          wait_busy := false;
          timer := 0;
        end if;
        
      else
        case next_state is
          when HW_RESET =>
            next_state <= IDLE;
          when IDLE =>
            timer := 0;
            if params_read = false or reread_params = '1' then
              next_state <= READ_RECONFIG;
              params_read := false;
            elsif do_reconfig = '1' then
              --Register our address
              page_address := application_address;
              next_state   <= WRITE_TIMEOUT;
            end if;

          ---------------------------------------------------------------------
          -- Write parameters and start reconfiguration
          ---------------------------------------------------------------------
          when WRITE_TIMEOUT =>
            ru_param   <= PARAM_WD_TIMEOUT;
            ru_data_in <= ZEROS(23 downto 12) & WATCHDOG_TIMEOUT;
            ru_write_param <= '1';
            next_state <= WRITE_WATCHDOG_ENABLE;
            wait_busy := true;

          when WRITE_WATCHDOG_ENABLE =>
            ru_param   <= PARAM_WD_ENABLE;
            ru_data_in <= ZEROS(23 downto 1) & "1";
            ru_write_param <= '1';
            next_state <= WRITE_PAGE_ADDRESS;
            wait_busy := true;

          when WRITE_PAGE_ADDRESS =>
            ru_param   <= PARAM_PAGE_ADDR;
            ru_data_in <= page_address;
            ru_write_param <= '1';
            next_state <= WRITE_ANF;
            wait_busy := true;

          when WRITE_ANF =>
            ru_param   <= PARAM_ANF;
            ru_data_in <= ZEROS(23 downto 1) & "1";
            ru_write_param <= '1';
            next_state <= START_RECONFIG;
            wait_busy := true;
            timer := 0;
            
          when START_RECONFIG =>
            timer := timer + 1;
            ru_reconfig <= '1';
            if (timer < 500) then
              next_state  <= START_RECONFIG;
            else
              next_state <= IDLE;
            end if;

          ---------------------------------------------------------------------
          -- Parameter reading
          ---------------------------------------------------------------------
          when READ_RECONFIG =>
            ru_read_param <= '1';
            ru_param      <= PARAM_RECONFIG;
            next_state    <= READ_PAGE_ADDRESS;
            wait_busy := true;

          when READ_PAGE_ADDRESS =>
            --Read last read parameter
            curr_reconfig_status <= ru_data_out(4 downto 0);
            --And read new parameter
            ru_read_param        <= '1';
            ru_param             <= PARAM_PAGE_ADDR;
            next_state           <= READ_ANF;
            wait_busy := true;

          when READ_ANF =>
            curr_page_address <= ru_data_out;
            ru_read_param     <= '1';
            ru_param          <= PARAM_ANF;
            next_state        <= READ_DONE;
            wait_busy := true;

          when READ_DONE =>
            curr_anf    <= ru_data_out(0);
            next_state  <= IDLE;
            params_read := true;

          when others =>
            next_state <= IDLE;
        end case;


      end if;
    end if;  --Clock block
  end process;

end architecture;

