-------------------------------------------------------------------------------
-- Title      : TSE Config Controller
-- Project    : 
-------------------------------------------------------------------------------
-- File       : tse_config_controller.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2018-10-15
-- Last update: 2020-08-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Configuration controller for Altera TSE MAC. 
-------------------------------------------------------------------------------
--!\file tse_config_controller.vhd
--Configuration controller for triple-speed ethernet module
--TODO: allow reading of statistiscs
--TODO: implement SW reset
--TODO: allow DMA access of MAC registers


library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.eth_common.all;
use work.config_pkg.all;

--!\brief TSE Configuration controller.
--!
--!Sets up the neccessary settings for the Altera TSE MAC. The TSE needs
--!settings such as the physical interface (SFP, copper SGMII, etc.), so this
--!handles that. See the
--!Altera TSE megafunction users guide for more information.

entity tse_config_controller is
  generic (
    --!Size of the TSE fifos in words
    TSE_FIFO_SIZE : natural := 2048;
    --!Interface ID
    port_id       : natural := 0
    );
  port (
    --!The clock
    clock            : in  std_logic;
    reset            : in  std_logic;
    --!SW reset. Not implemented.
    mac_sw_reset     : in  std_logic;
    --!Reconfigure the TSE (useful to reset the device or indicate configuration changes
    reconfig         : in  std_logic;
    ---Communication bus to the tse MAC
    --Reading lines
    ---------------------------------------------------------------------------
    --!\name TSE configuration lines
    --!\{
    ---------------------------------------------------------------------------
    readdata         : in  std_logic_vector(31 downto 0);
    read_req         : out std_logic;
    --Writing lines
    writedata        : out std_logic_vector(31 downto 0);
    write_req        : out std_logic;
    --Pause line
    waitrequest      : in  std_logic;
    address          : out std_logic_vector(7 downto 0);
    --!\}
    ---------------------------------------------------------------------------
    --!Copper PHY hardware reset signal.
    hw_reset_out     : out std_logic;
    ---------------------------------------------------------------------------
    --!\name Configuration lines
    --!\{
    ---------------------------------------------------------------------------
    config_data_in   : in  std_logic_vector(31 downto 0);
    config_valid_in  : in  std_logic;
    config_data_out  : out std_logic_vector(31 downto 0);
    config_valid_out : out std_logic;
    config           : in  std_logic_vector(31 downto 0);
    mac_addr         : in  std_logic_vector(47 downto 0);
    --!\}    
    ---------------------------------------------------------------------------
    --!\name Status lines
    --!\{
    ---------------------------------------------------------------------------
    mac_ready        : out std_logic;
    --!Indicates error in configuration
    mac_error        : out std_logic;
    --!Link status, used to read the copper PHY link status
    link_status      : out std_logic
    );
  --!\}

end entity tse_config_controller;

architecture RTL of tse_config_controller is
  --State machine configuration, should be control register?
  constant STATE_MACHINE_TIMEOUT        : natural            := 5000;
  constant STATE_MACHINE_RESET_ATTEMPTS : natural            := 10;
  -----------------------------------------------------------------------------
  -- Need to wait ~5ms after reset before setting MDIO registers, this is
  -- ~625,000 cycles @125MHz
  -----------------------------------------------------------------------------
  --constant MDIO_WAIT_CYCLES             : natural            := 1000000;
  constant MDIO_WAIT_CYCLES             : natural            := 30000;
  constant HW_RESET_CYCLES              : natural            := 1000;
  --constant MDIO_WAIT_CYCLES : natural := 100;
  subtype tse_config_address is std_logic_vector(7 downto 0);
  subtype tse_config_data is std_logic_vector(31 downto 0);
  -----------------------------------------------------------------------------
  -- MAC Configuration Addresses
  -----------------------------------------------------------------------------
  constant MAC_COMMAND_ADDR             : tse_config_address := X"02";
  constant MAC0_ADDR                    : tse_config_address := X"03";
  constant MAC1_ADDR                    : tse_config_address := X"04";
  constant FRAME_LENGTH_ADDR            : tse_config_address := X"05";
  constant PAUSE_QUANTA_ADDR            : tse_config_address := X"06";
  constant RX_SECTION_EMPTY_ADDR        : tse_config_address := X"07";
  constant RX_SECTION_FULL_ADDR         : tse_config_address := X"08";
  constant TX_SECTION_EMPTY_ADDR        : tse_config_address := X"09";
  constant TX_SECTION_FULL_ADDR         : tse_config_address := X"0A";
  constant RX_ALMOST_EMPTY_ADDR         : tse_config_address := X"0B";
  constant RX_ALMOST_FULL_ADDR          : tse_config_address := X"0C";
  constant TX_ALMOST_EMPTY_ADDR         : tse_config_address := X"0D";
  constant TX_ALMOST_FULL_ADDR          : tse_config_address := X"0E";
  constant TX_IPG_LENGTH_ADDR           : tse_config_address := X"17";
  constant TX_CMD_STAT_ADDR             : tse_config_address := X"3A";
  constant RX_CMD_STAT_ADDR             : tse_config_address := X"3B";
  constant MDIO_ADDR0_ADDR              : tse_config_address := X"0F";
  constant MDIO_ADDR1_ADDR              : tse_config_address := X"10";
  -----------------------------------------------------------------------------
  -- PCS Configuration Addresses
  -----------------------------------------------------------------------------
  constant IF_MODE_ADDR                 : tse_config_address := X"94";
  constant PCS_CONTROL_ADDR             : tse_config_address := X"80";
  constant PCS_STATUS_ADDR              : tse_config_address := X"81";
--  constant PCS_DEV_ABIL_ADDR : tse_config_address := X"84"; --Unused
  constant PCS_LINK_TIMER0_ADDR         : tse_config_address := X"92";
  constant PCS_LINK_TIMER1_ADDR         : tse_config_address := X"93";
  constant PCS_IF_MODE_ADDR             : tse_config_address := X"94";
  -----------------------------------------------------------------------------
  -- PCS Configuration Signals
  -----------------------------------------------------------------------------
  --10 ms, in units of 8 ns
  constant PCS_1000BASEX_AN_LINK_TIMER  : tse_config_data    := X"00_13_12_D0";
  constant PCS_SGMII_AN_LINK_TIMER      : tse_config_data    := X"00_03_0D40";
  constant PCS_1000BASEX_IF_MODE        : tse_config_data    := X"00_00_00_00";
  constant PCS_SGMII_IF_MODE            : tse_config_data    := X"00_00_00_03";
  constant PCS_SGMII_IF_AN_OFF          : tse_config_data    := X"00_00_00_09";
  signal PCS_AN_LINK_TIMER              : tse_config_data    := PCS_1000BASEX_AN_LINK_TIMER;
  signal PCS_IF_MODE                    : tse_config_data    := PCS_1000BASEX_IF_MODE;
  constant PAUSE_QUANTA                 : tse_config_data    := X"00_00_FF_FF";
  --For AN disabled
  constant PCS_COMMAND_WORD_ANOFF       : tse_config_data    := X"00_00_00_00";
  constant PCS_RESET_WORD_ANOFF         : tse_config_data    := X"00_00_80_00";
  --For AN enabled
  constant PCS_COMMAND_WORD_ANON        : tse_config_data    := X"00_00_1140";
  constant PCS_RESET_WORD_ANON          : tse_config_data    := X"00_00_9140";
  --RX/TX command words
  --Align to 32-bit boundary, enable CRC generation
  constant TX_CMD_STAT                  : tse_config_data    := X"00_04_00_00";
  --Align to 32-bit boundary
  constant RX_CMD_STAT                  : tse_config_data    := X"02_00_00_00";
  signal pcs_command_word               : tse_config_data    := PCS_COMMAND_WORD_ANOFF;
  signal pcs_reset_word                 : tse_config_data    := PCS_RESET_WORD_ANOFF;
  -----------------------------------------------------------------------------
  -- MDIO Configuration addresses
  -----------------------------------------------------------------------------
  constant MDIO_CTRL_ADDR               : tse_config_address := X"80";
  constant MDIO_AN_ADDR                 : tse_config_address := X"84";
  constant MDIO_1000BASE_ADDR           : tse_config_address := X"89";
  constant MDIO_PHYCTRL_ADDR            : tse_config_address := X"90";
  constant MDIO_EPHYSTATUS_ADDR         : tse_config_address := X"9B";
  constant MDIO_EPHYCTRL_ADDR           : tse_config_address := X"94";
  constant MDIO_PHYSTATUS_ADDR          : tse_config_address := X"91";
  constant MDIO_PHY_ADDR                : tse_config_data    := X"00_00_00_00";

  -----------------------------------------------------------------------------
  -- MDIO Configuration Signals
  -----------------------------------------------------------------------------
  constant MDIO_CTRL_RESET    : tse_config_data := X"00_00_80_00";
  --Initial configuration settings (w/ SW reset)
  constant MDIO_CTRL_INIT     : tse_config_data := X"00_00_93_7F";
  constant MDIO_CTRL_SPDP     : tse_config_data := X"00_00_01_40";
  --Disable unsupported AN features
  constant MDIO_AN_ENABLE     : tse_config_data := X"00_00_FC_1F";
  --Disable half duplex
  constant MDIO_1000BASE_CTRL : tse_config_data := X"00_00_FE_FF";
  --Max TX Fifo size
  constant MDIO_PHYCTRL       : tse_config_data := X"00_00_C0_00";
  --Enable RGMII to copper
  constant MDIO_EPHYSTATUS    : tse_config_data := X"00_00_00_0B";
  constant MDIO_EPHYCTRL      : tse_config_data := X"00_00_00_82";


--  signal mac_addr_sig : std_logic_vector(47 downto 0);
  signal reconfig_sig : std_logic := '0';


  type state_type is (HW_RESET, PRE_CONFIG,
                      --MDIO Configs (for copper mode)
                      MAC_WRITE_MDIO_ADDR, PHY_RESET_TRIGGER, PHY_RESET_WAIT,
                      MDIO_WAIT,
                      MDIO_READ_CTRL0, MDIO_WRITE_CTRL0,
                      MDIO_READ_AN, MDIO_WRITE_AN,
                      MDIO_READ_1000BASE_CTRL, MDIO_WRITE_1000BASE_CTRL,
                      MDIO_READ_PHYCTRL, MDIO_WRITE_PHYCTRL,
                      MDIO_READ_EPHYSTATUS, MDIO_WRITE_EPHYSTATUS,
                      MDIO_READ_EPHYCTRL, MDIO_WRITE_EPHYCTRL,
                      MDIO_READ_RESET, MDIO_WRITE_RESET,
                      --PCS Configs (for optical mode)
                      PCS_CFG_AUTO_TM0, PCS_CFG_AUTO_TM1,
                      PCS_CFG_IF_MODE, PCS_CFG_AN_EN, PCS_CFG_WRITE_RESET,
                      PCS_CFG_READ_RESET,
                      MAC_CFG_WRITE_ENA_DB, MAC_CFG_WAIT_ENA_DB,
                      --TX FIFO levels
                      MAC_CFG_FIFO_TX_SE, MAC_CFG_FIFO_TX_SF,
                      MAC_CFG_FIFO_TX_AE, MAC_CFG_FIFO_TX_AF,
                      --RX FIFO levels                      
                      MAC_CFG_FIFO_RX_SE, MAC_CFG_FIFO_RX_SF,
                      MAC_CFG_FIFO_RX_AE, MAC_CFG_FIFO_RX_AF,
                      --MAC Address configuration
                      MAC_CFG_MAC_ADDR0, MAC_CFG_MAC_ADDR1,
                      --MAC func config
                      MAC_CFG_FRM_LENGTH, MAC_CFG_IPG_LENGTH,
                      MAC_CFG_PAUSE_QUANTA, MAC_CFG_TX_CMD_STAT,
                      MAC_CFG_RX_CMD_STAT, MAC_CFG_SW_RESET,
                      MAC_CFG_WAIT_SW_RESET, MAC_CFG_WRITE_ENA_EN,
                      MAC_CFG_WAIT_ENA_EN,
                      MAC_CFG_READY, MAC_CONFIG_ERROR,
                      MDIO_READ_PHYSTATUS, MDIO_PROCESS_LINKSTATUS);

  signal state      : state_type := PRE_CONFIG;
  signal next_state : state_type := PRE_CONFIG;

  signal read_data_sig  : tse_config_data;
  signal write_data_sig : tse_config_data;

  signal address_sig   : tse_config_address;
  signal read_req_sig  : std_logic;
  signal write_req_sig : std_logic;

  signal mac_ready_sig : std_logic := '0';
  signal mac_error_sig : std_logic := '0';

  signal state_machine_reset : boolean := false;
  signal state_machine_error : boolean := false;

  --TODO: implement this
  signal do_sw_reset : boolean := false;

  --MAC command word parameters
  --Set to 1 to disable config register read timeout
  constant read_timeout : std_logic                    := '0';
  --Set to 1 to discard erroneous frames
  constant rx_err_disc  : std_logic                    := '0';
  --Whether to enable 1 MBps
  constant ena_10       : std_logic                    := '0';
  --Length checker
  signal no_lgth_check  : std_logic                    := '0';
  --Whether to accept MAC control frames and forward us
  constant cntl_frm_ena : std_logic                    := '0';
  --Generate a pause frame w/ preset quanta
  signal xoff_gen       : std_logic                    := '0';
  --Set to go to sleep and enable magic frame detection
  signal sleep          : std_logic                    := '0';
  --Set to enable magic packet detection
  signal magic_ena      : std_logic                    := '0';
  --Which source mac address to use
  constant tx_addr_sel  : std_logic_vector(2 downto 0) := "000";
  --Enable/disable SW loopback
  signal loop_ena       : std_logic                    := '0';
  --Hash table stuff (TODO)
  constant mhash_sel    : std_logic                    := '0';
  --RO signals from the MAC
  signal excess_col     : std_logic                    := '0';
  signal late_col       : std_logic                    := '0';
  --Enable half duplex
  signal hd_ena         : std_logic                    := '0';
  --If the MAC should overwrite the source MAC ADR
  signal tx_addr_ins    : std_logic                    := '0';
  constant pause_ignore : std_logic                    := '0';
  constant pause_fwd    : std_logic                    := '0';
  --To forward the CRC or not
  signal crc_fwd        : std_logic                    := '0';
  --constant crc_fwd      : std_logic                    := '1';
  --Remove padding before forwarding
  constant pad_en       : std_logic                    := '1';
  --Promiscious mode, usually should be disabled
  signal promis_en      : std_logic                    := '0';
  --Speed is always GigE
  constant eth_speed    : std_logic                    := '1';
  --To generate pause frame w/ 0 quanta
  signal xon_gen        : std_logic                    := '0';
  --Enable autonegotiation (necessary for hardware, cannot be enabled in testbench)
  signal enable_AN      : std_logic                    := '0';
  signal config_PCS     : std_logic                    := '1';
  signal config_MDIO    : std_logic                    := '0';
  signal in_mdio        : std_logic                    := '0';

  signal set_MDIO_ctrl0      : std_logic := '0';
  signal set_MDIO_AN         : std_logic := '0';
  signal set_MDIO_1000base   : std_logic := '0';
  signal set_MDIO_phyctrl    : std_logic := '0';
  signal set_MDIO_ephystatus : std_logic := '1';
  signal set_MDIO_ephyctrl   : std_logic := '0';
  signal set_MDIO_sw_reset   : std_logic := '1';
  signal read_link_status    : std_logic := '0';  
  signal skip_MDIO_wait      : std_logic := '0';
  signal skip_phy_reset      : std_logic := '0';

  component config_register_block is
    generic (
      BLOCK_ADDRESS    : std_logic_vector(6 downto 0);
      DEFAULT_SETTINGS : config_word_array);
    port (
      clock            : in  std_logic;
      reset            : in  std_logic;
      config_data_in   : in  std_logic_vector(31 downto 0)                         := (others => '0');
      config_valid_in  : in  std_logic                                             := '0';
      config_data_out  : out std_logic_vector(31 downto 0)                         := (others => '0');
      config_valid_out : out std_logic                                             := '0';
      config_registers : out config_word_array(DEFAULT_SETTINGS'length-1 downto 0) := DEFAULT_SETTINGS;
      config_changed   : out std_logic                                             := '0';
      config_error     : out std_logic                                             := '0');
  end component config_register_block;

  component reset_controller is
    port (
      clock          : in  std_logic                     := '0';
      activate_reset : in  std_logic                     := '0';
      reset_out      : out std_logic                     := '0';
      reset_done     : out std_logic                     := '0';
      reset_cycles   : in  std_logic_vector(31 downto 0) := X"00_00_00_FF");
  end component reset_controller;

  -----------------------------------------------------------------------------
  -- Default settings for config register block
  -----------------------------------------------------------------------------  
  constant MDIO_CTRL0_AND         : std_logic_vector(15 downto 0) := X"93_7F";
  constant MDIO_CTRL0_OR          : std_logic_vector(15 downto 0) := X"01_40";
  constant MDIO_AN_AND            : std_logic_vector(15 downto 0) := X"FC_1F";
  constant MDIO_AN_OR             : std_logic_vector(15 downto 0) := X"00_00";
  constant MDIO_1000BASE_CTRL_AND : std_logic_vector(15 downto 0) := X"FE_FF";
  constant MDIO_1000BASE_CTRL_OR  : std_logic_vector(15 downto 0) := X"00_00";
  constant MDIO_PHYCTRL_AND       : std_logic_vector(15 downto 0) := X"FF_FF";
  constant MDIO_PHYCTRL_OR        : std_logic_vector(15 downto 0) := X"C0_00";
  constant MDIO_EPHYSTATUS_AND    : std_logic_vector(15 downto 0) := X"FF_F4";
  --Enable SGMII to copper mode
  constant MDIO_EPHYSTATUS_OR     : std_logic_vector(15 downto 0) := X"00_04";
  constant MDIO_EPHYCTRL_AND      : std_logic_vector(15 downto 0) := X"FF_FF";
  constant MDIO_EPHYCTRL_OR       : std_logic_vector(15 downto 0) := X"00_00";

  -----------------------------------------------------------------------------
  -- Configuration Register. Currently only used for MDIO settings
  -----------------------------------------------------------------------------
  constant DEFAULT_SETTINGS : config_word_array(7 downto 0) :=
    (0 => MDIO_CTRL0_AND & MDIO_CTRL0_OR,
     1 => MDIO_AN_AND & MDIO_AN_OR,
     2 => MDIO_1000BASE_CTRL_AND & MDIO_1000BASE_CTRL_OR,
     3 => MDIO_PHYCTRL_AND & MDIO_PHYCTRL_OR,
     4 => MDIO_EPHYSTATUS_AND & MDIO_EPHYSTATUS_OR,
     5 => MDIO_EPHYCTRL_AND & MDIO_EPHYCTRL_OR,
     6 => std_logic_vector(to_unsigned(HW_RESET_CYCLES, 32)),
     7 => std_logic_vector(to_unsigned(MDIO_WAIT_CYCLES, 32)));

  signal config_registers  : config_word_array(DEFAULT_SETTINGS'length-1 downto 0) := DEFAULT_SETTINGS;
  signal config_changed    : std_logic;
  signal config_error      : std_logic;
  signal MDIO_address_mask : tse_config_address                                    := X"00";
  signal iface_mode        : iface_type                                            := BASEX;
  signal link_status_sig   : std_logic                                             := '0';
  signal mdio_wait_time    : natural                                               := MDIO_WAIT_CYCLES;
  -----------------------------------------------------------------------------
  -- Reset Controller
  -----------------------------------------------------------------------------
  signal activate_reset    : std_logic                                             := '0';
  signal reset_done        : std_logic                                             := '0';
  signal reset_cycles      : std_logic_vector(31 downto 0)                         := X"00_00_00_FF";

begin
  reset_cycles   <= config_registers(6);
  mdio_wait_time <= to_integer(unsigned(config_registers(7)));
  --!Our HW reset controller (for resetting the PHY)
  reset_controller_1 : entity work.reset_controller
    port map (
      clock          => clock,
      activate_reset => activate_reset,
      reset_out      => hw_reset_out,
      reset_done     => reset_done,
      reset_cycles   => reset_cycles);

  --!Configuration block for various settings. Mostly used for MDIO settings
  config_register_block_1 : entity work.config_register_block
    generic map (
      BLOCK_ADDRESS    => TSE_CONFIG_ADDRESSES(port_id),
      DEFAULT_SETTINGS => DEFAULT_SETTINGS)
    port map (
      clock            => clock,
      reset            => reset,
      config_data_in   => config_data_in,
      config_valid_in  => config_valid_in,
      config_data_out  => config_data_out,
      config_valid_out => config_valid_out,
      config_registers => config_registers,
      config_changed   => config_changed,
      config_error     => config_error);

  --Wire up internal signals to external ports
  writedata     <= write_data_sig;
  read_data_sig <= readdata;
  reconfig_sig  <= reconfig or config_changed;
  read_req      <= read_req_sig;
  write_req     <= write_req_sig;
  address       <= address_sig;
  mac_ready     <= mac_ready_sig;
  mac_error     <= mac_error_sig;

  --Determine our interface mode from settings (could be hardcoded)
  iface_mode <= BASEX when (config_pcs = '1' and config_MDIO = '0') else
                RGMII when (config_pcs = '0' and config_MDIO = '1') else
                SGMII when (config_pcs = '1' and config_MDIO = '1') else
                BASEX;

  pcs_command_word <= PCS_COMMAND_WORD_ANOFF when enable_AN = '0' else PCS_COMMAND_WORD_ANON;
  pcs_reset_word   <= PCS_RESET_WORD_ANOFF   when enable_AN = '0' else PCS_RESET_WORD_ANON;

  --If we have a PCS function (in SGMII mode), the PHY chip occupies MDIO space 1
  MDIO_address_mask <= X"20"                       when iface_mode = SGMII else X"00";
  PCS_AN_LINK_TIMER <= PCS_1000BASEX_AN_LINK_TIMER when iface_mode = BASEX else
                       PCS_SGMII_AN_LINK_TIMER;
  PCS_IF_MODE <= PCS_1000BASEX_IF_MODE when iface_mode = BASEX else
                 PCS_SGMII_IF_MODE when iface_mode = SGMII and enable_AN = '1' else
                 PCS_SGMII_IF_AN_OFF;


  --!Pipeline external control logic
  config_dff : process(clock)
  begin
    if rising_edge(clock) then
      loop_ena            <= config(0);
      tx_addr_ins         <= config(1);
      promis_en           <= config(2);
      no_lgth_check       <= config(3);
      enable_AN           <= config(4);
      --crc_fwd       <= config(5);
      crc_fwd             <= '0';
      config_PCS          <= config(6);
      config_MDIO         <= config(7);
      set_MDIO_ctrl0      <= config(16);
      set_MDIO_AN         <= config(17);
      set_MDIO_1000base   <= config(18);
      set_MDIO_phyctrl    <= config(19);
      set_MDIO_ephystatus <= config(20);
      set_MDIO_ephyctrl   <= config(21);
      set_MDIO_sw_reset   <= config(22);
      read_link_status    <= config(29);
      skip_phy_reset      <= config(30);
      skip_mdio_wait      <= config(31);
      link_status         <= link_status_sig;
    end if;
  end process config_dff;


  -----------------------------------------------------------------------------
  --! The state machine that handles configuring the triple speed ethernet MAC.
  --! First sets the PCS registers (necessary in 1000BASE-X (i.e. optical fiber)
  --! or SGMII mode). Then sets the MDIO registers (necessary in SGMII/RGMII
  --! modes, though RGMII mode is not currently explicitly supported).
  --! Finally, set the TSE MAC registers (interface mode, FIFO almost full
  --! sizes, etc.). These settings are the recommended defaults from the TSE
  --! users guide. The state machine sends read/write requests to the TSE, and
  --! then waits for a response. If the SM continually doesn't get a response
  --! it is expecting for a read command, it is the responsiblity of the
  --! watchdog to handle resetting the SM or putting it into an error state.
  -----------------------------------------------------------------------------
  state_machine : process (reset, clock)
    --TODO: see if mac_command_word assignment can be cleaned up a bit
    variable mac_command_word   : tse_config_data;
    variable tx_ena             : std_logic := '0';
    variable rx_ena             : std_logic := '0';
    variable sw_reset           : std_logic := '0';
    variable counter_reset      : std_logic := '0';
    variable mdio_delay_counter : natural   := 0;
    variable link_read_timer    : natural   := 0;
  begin
    sm_clock_block : if (reset = '1') then
      state              <= HW_RESET;
      next_state         <= PRE_CONFIG;
      mac_ready_sig      <= '0';
      mac_error_sig      <= '0';
      write_req_sig      <= '0';
      read_req_sig       <= '0';
      in_mdio            <= '0';
      address_sig        <= (others => '0');
      write_data_sig     <= (others => '0');
      mdio_delay_counter := 0;
      link_read_timer    := 0;
      link_status_sig    <= '0';

    elsif (rising_edge(clock)) then
      --Check for signals from watchdog process
      if (state_machine_reset) then
        next_state <= PRE_CONFIG;
      elsif (state_machine_error) then
        next_state <= MAC_CONFIG_ERROR;
      --Reconfigure the TSE
      elsif (reconfig_sig = '1') then
        next_state    <= PRE_CONFIG;
        mac_ready_sig <= '0';
      --If we're waiting for a request to finish
      elsif (waitrequest = '1' and (read_req_sig = '1' or write_req_sig = '1')) then
        next_state <= next_state;
      else
        state <= next_state;
        case next_state is
          when HW_RESET =>
            next_state         <= PRE_CONFIG;
            mac_ready_sig      <= '0';
            mac_error_sig      <= '0';
            write_req_sig      <= '0';
            write_data_sig     <= (others => '0');
            read_req_sig       <= '0';
            address_sig        <= (others => '0');
            in_mdio            <= '0';
            mdio_delay_counter := 0;
            link_read_timer    := 0;
            link_status_sig    <= '0';
          when PRE_CONFIG =>
            --TODO: Maybe reset MAC command word to default values here?
            if (config_PCS = '1') then
              next_state <= PCS_CFG_AUTO_TM0;
            elsif (config_MDIO = '1') then
              next_state <= MAC_WRITE_MDIO_ADDR;
            else
              next_state <= MAC_CFG_WRITE_ENA_DB;
            end if;
            mac_ready_sig      <= '0';
            mac_error_sig      <= '0';
            write_req_sig      <= '0';
            write_data_sig     <= (others => '0');
            read_req_sig       <= '0';
            address_sig        <= (others => '0');
            in_mdio            <= '0';
            mdio_delay_counter := 0;
            link_read_timer    := 0;
            link_status_sig    <= '0';
          ---------------------------------------------------------------------
          -- Setup PCS Registers (for optical blocks or SGMII interface)
          ---------------------------------------------------------------------
          when PCS_CFG_AUTO_TM0 =>      --Sets lower 16 bits of AN timer
            write_req_sig  <= '1';
            address_sig    <= PCS_LINK_TIMER0_ADDR;
            write_data_sig <= X"00_00" & PCS_AN_LINK_TIMER(15 downto 0);
            next_state     <= PCS_CFG_AUTO_TM1;

          when PCS_CFG_AUTO_TM1 =>      --Sets upper 4 bits of AN timer
            write_req_sig  <= '1';
            address_sig    <= PCS_LINK_TIMER1_ADDR;
            write_data_sig <= X"00_00_00" & "000" & PCS_AN_LINK_TIMER(20 downto 16);
            next_state     <= PCS_CFG_IF_MODE;

          when PCS_CFG_IF_MODE =>       --Set gigabit ETH mode
            write_req_sig  <= '1';
            address_sig    <= PCS_IF_MODE_ADDR;
            write_data_sig <= PCS_IF_MODE;
            next_state     <= PCS_CFG_AN_EN;

          when PCS_CFG_AN_EN =>         --enable autonegotiation
            write_req_sig  <= '1';
            address_sig    <= PCS_CONTROL_ADDR;
            write_data_sig <= pcs_command_word;
            next_state     <= PCS_CFG_WRITE_RESET;

          when PCS_CFG_WRITE_RESET =>
            write_req_sig  <= '1';
            address_sig    <= PCS_CONTROL_ADDR;
            --TODO: make this configurable (for e.g. enable loopback)          
            write_data_sig <= pcs_reset_word;
            next_state     <= PCS_CFG_READ_RESET;

          --Perform software reset of PCS
          when PCS_CFG_READ_RESET =>
            write_req_sig <= '0';
            read_req_sig  <= '1';
            address_sig   <= PCS_CONTROL_ADDR;
            if (read_data_sig /= pcs_command_word) then
              next_state <= PCS_CFG_READ_RESET;
            else
              if (config_MDIO = '1') then
                next_state <= MAC_WRITE_MDIO_ADDR;
              else
                next_state <= MAC_CFG_WRITE_ENA_DB;
              end if;
            end if;
          ---------------------------------------------------------------------
          -- Set MDIO control registers
          -- Following the manual guidelines, we read each MDIO register and
          -- update them using a bitmask before writing the new settings. For a
          -- complete description of each register and what the settings do,
          -- see the Marvel 88E1111 datasheet.
          ---------------------------------------------------------------------
          when MAC_WRITE_MDIO_ADDR =>
            write_req_sig <= '1';
            read_req_sig  <= '0';
            if (MDIO_address_mask = X"00") then
              address_sig <= MDIO_ADDR0_ADDR;
            else
              address_sig <= MDIO_ADDR1_ADDR;
            end if;
            next_state         <= PHY_RESET_TRIGGER;
            mdio_delay_counter := 0;
            write_data_sig     <= MDIO_PHY_ADDR;
          --Trigger HW reset of PHY
          when PHY_RESET_TRIGGER =>
            in_mdio       <= '1';
            write_req_sig <= '0';
            read_req_sig  <= '0';
            if (skip_phy_reset = '0') then
              activate_reset <= '1';
            end if;
            next_state <= PHY_RESET_WAIT;
          --Wait for HW reset to finish
          when PHY_RESET_WAIT =>
            in_mdio        <= '1';
            write_req_sig  <= '0';
            read_req_sig   <= '0';
            activate_reset <= '0';
            if (skip_phy_reset = '1' or reset_done = '1') then
              next_state <= MDIO_WAIT;
            else
              next_state <= PHY_RESET_WAIT;
            end if;
          --Wait >5ms for MDIO interface
          when MDIO_WAIT =>
            in_mdio            <= '1';
            write_req_sig      <= '0';
            read_req_sig       <= '0';
            mdio_delay_counter := mdio_delay_counter + 1;
            if ((mdio_delay_counter >= mdio_wait_time) or
                skip_mdio_wait = '1') then
              next_state <= MDIO_READ_CTRL0;
            else
              next_state <= MDIO_WAIT;
            end if; 
          --Read our control register.
          when MDIO_READ_CTRL0 =>
            in_mdio <= '1';
            if (set_MDIO_ctrl0 = '1') then
              write_req_sig <= '0';
              read_req_sig  <= '1';
              address_sig   <= MDIO_CTRL_ADDR or MDIO_address_mask;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_WRITE_CTRL0;
          
          when MDIO_WRITE_CTRL0 =>
            if (set_MDIO_ctrl0 = '1') then
              write_req_sig    <= '1';
              read_req_sig     <= '0';
              address_sig      <= MDIO_CTRL_ADDR or MDIO_address_mask;
              --Initial registers + 1000Mbps, full duplex
              mac_command_word := X"00_00" & ((read_data_sig(15 downto 0) and config_registers(0)(31 downto 16)) or config_registers(0)(15 downto 0));
              write_data_sig   <= mac_command_word;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_READ_AN;

          --Read our autonegotiation register
          when MDIO_READ_AN =>
            if (set_MDIO_AN = '1') then
              write_req_sig <= '0';
              read_req_sig  <= '1';
              address_sig   <= MDIO_AN_ADDR or MDIO_address_mask;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_WRITE_AN;

          --Update our autonegotiation register
          when MDIO_WRITE_AN =>
            if (set_MDIO_AN = '1') then
              write_req_sig    <= '1';
              read_req_sig     <= '0';
              address_sig      <= MDIO_AN_ADDR or MDIO_address_mask;
              mac_command_word := X"00_00" & ((read_data_sig(15 downto 0) and config_registers(1)(31 downto 16)) or config_registers(1)(15 downto 0));
              write_data_sig   <= mac_command_word;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_READ_1000BASE_CTRL;

          when MDIO_READ_1000BASE_CTRL =>
            if (set_MDIO_1000base = '1') then
              write_req_sig <= '0';
              read_req_sig  <= '1';
              address_sig   <= MDIO_1000BASE_ADDR or MDIO_address_mask;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_WRITE_1000BASE_CTRL;

          when MDIO_WRITE_1000BASE_CTRL =>
            if (set_MDIO_1000base = '1') then
              write_req_sig    <= '1';
              read_req_sig     <= '0';
              address_sig      <= MDIO_1000BASE_ADDR or MDIO_address_mask;
              mac_command_word := X"00_00" & ((read_data_sig(15 downto 0) and config_registers(2)(31 downto 16)) or config_registers(2)(15 downto 0));
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_READ_PHYCTRL;

          --Read our PHY control register
          when MDIO_READ_PHYCTRL =>
            if (set_MDIO_phyctrl = '1') then
              write_req_sig <= '0';
              read_req_sig  <= '1';
              address_sig   <= MDIO_PHYCTRL_ADDR or MDIO_address_mask;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_WRITE_PHYCTRL;

          --Update it
          when MDIO_WRITE_PHYCTRL =>
            if (set_MDIO_phyctrl = '1') then
              write_req_sig    <= '1';
              read_req_sig     <= '0';
              address_sig      <= MDIO_PHYCTRL_ADDR or MDIO_address_mask;
              mac_command_word := X"00_00" & ((read_data_sig(15 downto 0) and config_registers(3)(31 downto 16)) or config_registers(3)(15 downto 0));
              write_data_sig   <= mac_command_word;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_READ_EPHYSTATUS;

          when MDIO_READ_EPHYSTATUS =>
            if (set_MDIO_ephystatus = '1') then
              write_req_sig <= '0';
              read_req_sig  <= '1';
              address_sig   <= MDIO_EPHYSTATUS_ADDR or MDIO_address_mask;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_WRITE_EPHYSTATUS;

          when MDIO_WRITE_EPHYSTATUS =>
            if (set_MDIO_ephystatus = '1') then
              write_req_sig    <= '1';
              read_req_sig     <= '0';
              address_sig      <= MDIO_EPHYSTATUS_ADDR or MDIO_address_mask;
              mac_command_word := X"00_00" & ((read_data_sig(15 downto 0) and config_registers(4)(31 downto 16)) or config_registers(4)(15 downto 0));
              write_data_sig   <= mac_command_word;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_READ_EPHYCTRL;

          when MDIO_READ_EPHYCTRL =>
            if (set_MDIO_ephyctrl = '1') then
              write_req_sig <= '0';
              read_req_sig  <= '1';
              address_sig   <= MDIO_EPHYCTRL_ADDR or MDIO_address_mask;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_WRITE_EPHYCTRL;

          when MDIO_WRITE_EPHYCTRL =>
            if (set_MDIO_ephyctrl = '1') then
              write_req_sig    <= '1';
              read_req_sig     <= '0';
              address_sig      <= MDIO_EPHYCTRL_ADDR or MDIO_address_mask;
              mac_command_word := X"00_00" & ((read_data_sig(15 downto 0) and config_registers(5)(31 downto 16)) or config_registers(5)(15 downto 0));
              write_data_sig   <= mac_command_word;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_READ_RESET;

          when MDIO_READ_RESET =>
            if (set_MDIO_sw_reset = '1') then
              write_req_sig <= '0';
              read_req_sig  <= '1';
              address_sig   <= MDIO_CTRL_ADDR or MDIO_address_mask;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MDIO_WRITE_RESET;

          when MDIO_WRITE_RESET =>
            if (set_MDIO_sw_reset = '1') then
              write_req_sig    <= '1';
              read_req_sig     <= '0';
              address_sig      <= MDIO_CTRL_ADDR or MDIO_address_mask;
              mac_command_word := (read_data_sig or MDIO_CTRL_RESET);
              write_data_sig   <= mac_command_word;
            else
              write_req_sig <= '0';
              read_req_sig  <= '0';
            end if;
            next_state <= MAC_CFG_WRITE_ENA_DB;
            in_mdio    <= '0';

          ---------------------------------------------------------------------
          -- Set MAC registers
          ---------------------------------------------------------------------
          --Disable tx/rx datapaths before making any changes
          when MAC_CFG_WRITE_ENA_DB =>
            write_req_sig    <= '1';
            read_req_sig     <= '0';
            address_sig      <= MAC_COMMAND_ADDR;
            in_mdio          <= '0';
            --Disable tx and rx channels
            tx_ena           := '0';
            rx_ena           := '0';
            sw_reset         := '0';
            mac_command_word := counter_reset & "000" &       --[31,30..27]
                                read_timeout & rx_err_disc &  --[26, 25]
                                ena_10 & no_lgth_check &      --[25,24]
                                cntl_frm_ena & xoff_gen &     --[23,22]
                                "0" &                         --[21]
                                sleep & magic_ena &           --[20, 19]
                                tx_addr_sel & loop_ena &      --[18..16,15]
                                mhash_sel & sw_reset &        --[14,13]
                                late_col & excess_col &       --[12,11]
                                hd_ena & tx_addr_ins &        --[10,9]
                                pause_ignore & pause_fwd &    --[8,7]
                                crc_fwd & pad_en &            --[6,5]
                                promis_en & eth_speed &       --[4,3]
                                xon_gen & rx_ena & tx_ena;    --[2,1,0]


            write_data_sig <= mac_command_word;
            next_state     <= MAC_CFG_WAIT_ENA_DB;

          --Check that TX/RX paths disabled
          when MAC_CFG_WAIT_ENA_DB =>
            write_req_sig <= '0';
            read_req_sig  <= '1';
            address_sig   <= MAC_COMMAND_ADDR;
            if (read_data_sig = mac_command_word) then
              next_state <= MAC_CFG_FIFO_TX_SE;
            else
              next_state <= MAC_CFG_WAIT_ENA_DB;
            end if;

          --Configure FIFO behavior
          --TX Buffers  
          when MAC_CFG_FIFO_TX_SE =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= TX_SECTION_EMPTY_ADDR;
            write_data_sig <= std_logic_vector(to_unsigned(TSE_FIFO_SIZE-16, write_data_sig'length));
            next_state     <= MAC_CFG_FIFO_TX_SF;

          when MAC_CFG_FIFO_TX_SF =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= TX_SECTION_FULL_ADDR;
            --Store and Forward mode          
            write_data_sig <= std_logic_vector(to_unsigned(0, write_data_sig'length));
            next_state     <= MAC_CFG_FIFO_TX_AE;

          when MAC_CFG_FIFO_TX_AE =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= TX_ALMOST_EMPTY_ADDR;
            write_data_sig <= std_logic_vector(to_unsigned(8, write_data_sig'length));
            next_state     <= MAC_CFG_FIFO_TX_AF;

          when MAC_CFG_FIFO_TX_AF =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= TX_ALMOST_FULL_ADDR;
            write_data_sig <= std_logic_vector(to_unsigned(3, write_data_sig'length));
            next_state     <= MAC_CFG_FIFO_RX_SE;

          --RX buffers
          when MAC_CFG_FIFO_RX_SE =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= RX_SECTION_EMPTY_ADDR;
            write_data_sig <= std_logic_vector(to_unsigned(TSE_FIFO_SIZE-16, write_data_sig'length));
            next_state     <= MAC_CFG_FIFO_RX_SF;

          when MAC_CFG_FIFO_RX_SF =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= RX_SECTION_FULL_ADDR;
            --Store and Forward mode
            write_data_sig <= std_logic_vector(to_unsigned(0, write_data_sig'length));
            next_state     <= MAC_CFG_FIFO_RX_AE;

          when MAC_CFG_FIFO_RX_AE =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= RX_ALMOST_EMPTY_ADDR;
            write_data_sig <= std_logic_vector(to_unsigned(8, write_data_sig'length));
            next_state     <= MAC_CFG_FIFO_RX_AF;

          when MAC_CFG_FIFO_RX_AF =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= RX_ALMOST_FULL_ADDR;
            write_data_sig <= std_logic_vector(to_unsigned(8, write_data_sig'length));
            next_state     <= MAC_CFG_MAC_ADDR0;

          --Set MAC addresses
          when MAC_CFG_MAC_ADDR0 =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= MAC0_ADDR;
            --write_data_sig <= mac_addr(31 downto 0);
            --Write them in reverse order
            write_data_sig <= mac_addr(23 downto 16) & mac_addr(31 downto 24) &
                              mac_addr(39 downto 32) & mac_addr(47 downto 40);
            next_state <= MAC_CFG_MAC_ADDR1;

          when MAC_CFG_MAC_ADDR1 =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= MAC1_ADDR;
            write_data_sig <= X"00_00" & mac_addr(7 downto 0) & mac_addr(15 downto 8);
            next_state     <= MAC_CFG_FRM_LENGTH;

          when MAC_CFG_FRM_LENGTH =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= FRAME_LENGTH_ADDR;
            write_data_sig <= std_logic_vector(to_unsigned(1518, write_data_sig'length));
            next_state     <= MAC_CFG_IPG_LENGTH;

          when MAC_CFG_IPG_LENGTH =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= TX_IPG_LENGTH_ADDR;
            write_data_sig <= std_logic_vector(to_unsigned(12, write_data_sig'length));
            next_state     <= MAC_CFG_PAUSE_QUANTA;

          when MAC_CFG_PAUSE_QUANTA =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= PAUSE_QUANTA_ADDR;
            write_data_sig <= PAUSE_QUANTA;
            next_state     <= MAC_CFG_TX_CMD_STAT;

          when MAC_CFG_TX_CMD_STAT =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= TX_CMD_STAT_ADDR;
            write_data_sig <= TX_CMD_STAT;
            next_state     <= MAC_CFG_RX_CMD_STAT;

          when MAC_CFG_RX_CMD_STAT =>
            read_req_sig   <= '0';
            write_req_sig  <= '1';
            address_sig    <= RX_CMD_STAT_ADDR;
            write_data_sig <= RX_CMD_STAT;
            next_state     <= MAC_CFG_SW_RESET;

          --Perform software reset of the MAC
          when MAC_CFG_SW_RESET =>
            read_req_sig  <= '0';
            write_req_sig <= '1';

            counter_reset := '0';
            sw_reset      := '1';

            address_sig      <= MAC_COMMAND_ADDR;
            mac_command_word := counter_reset & "000" &       --[31,30..27]
                                read_timeout & rx_err_disc &  --[26, 25]
                                ena_10 & no_lgth_check &      --[25,24]
                                cntl_frm_ena & xoff_gen &     --[23,22]
                                "0" &                         --[21]
                                sleep & magic_ena &           --[20, 19]
                                tx_addr_sel & loop_ena &      --[18..16,15]
                                mhash_sel & sw_reset &        --[14,13]
                                late_col & excess_col &       --[12,11]
                                hd_ena & tx_addr_ins &        --[10,9]
                                pause_ignore & pause_fwd &    --[8,7]
                                crc_fwd & pad_en &            --[6,5]
                                promis_en & eth_speed &       --[4,3]
                                xon_gen & rx_ena & tx_ena;    --[2,1,0]


            write_data_sig <= mac_command_word;
            next_state     <= MAC_CFG_WAIT_SW_RESET;

          when MAC_CFG_WAIT_SW_RESET =>
            read_req_sig     <= '1';
            write_req_sig    <= '0';
            sw_reset         := '0';
            mac_command_word := counter_reset & "000" &       --[31,30..27]
                                read_timeout & rx_err_disc &  --[26, 25]
                                ena_10 & no_lgth_check &      --[25,24]
                                cntl_frm_ena & xoff_gen &     --[23,22]
                                "0" &                         --[21]
                                sleep & magic_ena &           --[20, 19]
                                tx_addr_sel & loop_ena &      --[18..16,15]
                                mhash_sel & sw_reset &        --[14,13]
                                late_col & excess_col &       --[12,11]
                                hd_ena & tx_addr_ins &        --[10,9]
                                pause_ignore & pause_fwd &    --[8,7]
                                crc_fwd & pad_en &            --[6,5]
                                promis_en & eth_speed &       --[4,3]
                                xon_gen & rx_ena & tx_ena;    --[2,1,0]

            address_sig    <= MAC_COMMAND_ADDR;
            write_data_sig <= (others => '0');
            if (read_data_sig = mac_command_word) then
              next_state <= MAC_CFG_WRITE_ENA_EN;
            else
              next_state <= MAC_CFG_WAIT_SW_RESET;
            end if;

          --Enable the TX/RX paths
          when MAC_CFG_WRITE_ENA_EN =>
            read_req_sig     <= '0';
            write_req_sig    <= '1';
            address_sig      <= MAC_COMMAND_ADDR;
            tx_ena           := '1';
            rx_ena           := '1';
            mac_command_word := counter_reset & "000" &       --[31,30..27]
                                read_timeout & rx_err_disc &  --[26, 25]
                                ena_10 & no_lgth_check &      --[25,24]
                                cntl_frm_ena & xoff_gen &     --[23,22]
                                "0" &                         --[21]
                                sleep & magic_ena &           --[20, 19]
                                tx_addr_sel & loop_ena &      --[18..16,15]
                                mhash_sel & sw_reset &        --[14,13]
                                late_col & excess_col &       --[12,11]
                                hd_ena & tx_addr_ins &        --[10,9]
                                pause_ignore & pause_fwd &    --[8,7]
                                crc_fwd & pad_en &            --[6,5]
                                promis_en & eth_speed &       --[4,3]
                                xon_gen & rx_ena & tx_ena;    --[2,1,0]

            write_data_sig <= mac_command_word;
            next_state     <= MAC_CFG_WAIT_ENA_EN;

          when MAC_CFG_WAIT_ENA_EN =>
            read_req_sig  <= '1';
            write_req_sig <= '0';
            address_sig   <= MAC_COMMAND_ADDR;
            if (read_data_sig = mac_command_word) then
              next_state <= MAC_CFG_READY;
            else
              next_state <= MAC_CFG_WAIT_ENA_EN;
            end if;

          --Once the MAC is configured, enter a ready state. Here we signal the
          --MAC is ready, and periodically check the link status over MDIO if
          --we're using the copper interface.
          when MAC_CFG_READY =>
            read_req_sig   <= '0';
            write_req_sig  <= '0';
            write_data_sig <= (others => '0');
            address_sig    <= (others => '0');
            mac_ready_sig  <= '1';
            mac_error_sig  <= '0';
            --Periodically read the link status
            if (link_read_timer >= mdio_wait_time) then
              next_state <= MDIO_READ_PHYSTATUS;
            else
              next_state <= MAC_CFG_READY;
            end if;

            if (read_link_status = '1') then
              link_read_timer := link_read_timer +1;
            end if;

          when MAC_CONFIG_ERROR =>
            read_req_sig   <= '0';
            write_req_sig  <= '0';
            write_data_sig <= (others => '0');
            address_sig    <= (others => '0');
            mac_ready_sig  <= '0';
            mac_error_sig  <= '1';
            next_state     <= MAC_CONFIG_ERROR;

          when MDIO_READ_PHYSTATUS =>
            in_mdio         <= '1';
            write_req_sig   <= '0';
            read_req_sig    <= '1';
            address_sig     <= MDIO_PHYSTATUS_ADDR or MDIO_address_mask;
            next_state      <= MDIO_PROCESS_LINKSTATUS;
            link_read_timer := 0;

          when MDIO_PROCESS_LINKSTATUS =>
            in_mdio         <= '0';
            write_req_sig   <= '0';
            read_req_sig    <= '0';
            address_sig     <= (others => '0');
            next_state      <= MAC_CFG_READY;
            link_status_sig <= read_data_sig(10);

          when others =>
            next_state <= PRE_CONFIG;

        end case;
      end if;

    end if sm_clock_block;
  end process state_machine;

  -----------------------------------------------------------------------------
  --!Watchdog for the configuration process, in case the TSE gets stuck during
  --!the configuration process. Disabled during MDIO configuration and HW
  --!reset, as those take much longer than the watchdog trigger time.
  -----------------------------------------------------------------------------
  watch_dog : process (reset, clock)
    variable timer          : natural := 0;
    variable reset_attempts : natural := 0;
  begin
    if (reset = '1') then
      state_machine_reset <= false;
      state_machine_error <= false;
      timer               := 0;
      reset_attempts      := 0;
    elsif (rising_edge(clock)) then
      --If we're done or in an error state, don't do anything.
      if (next_state = PRE_CONFIG or mac_ready_sig = '1' or state_machine_error) then
        state_machine_reset <= false;
        timer               := 0;
        --If we stay in the same state for a while, that indicates a problem.
      elsif (state = next_state) then
        --MDIO config is slow, so don't watchdog it
        if (in_mdio = '0') then
          timer := timer+1;
        end if;
      else
        --Otherwise reset our timer, since our state machine is doing something.
        timer := 0;
      end if;
      --Perform the reset of our state machine
      if (timer >= STATE_MACHINE_TIMEOUT and not state_machine_reset) then
        state_machine_reset <= true;
        reset_attempts      := reset_attempts + 1;
      end if;
      --If we've already tried resetting the machine several times, indicate an
      --error.
      if (reset_attempts >= STATE_MACHINE_RESET_ATTEMPTS) then
        state_machine_error <= true;
      end if;
    end if;

  end process watch_dog;

end architecture RTL;
