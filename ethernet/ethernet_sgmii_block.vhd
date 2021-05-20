-------------------------------------------------------------------------------
-- Title      : Ethernet Block
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_sgmii_block.vhd
-- Author     : Ryan Thomas
-- Company    : University of Chicago
-- Created    : 2019-08-26
-- Last update: 2020-08-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Block for holding data interface and TSE megafunction with an
-- SGMII interface. Note this is identical to the optical interface, except
-- with additional MDIO interface to set up the PHY.
-------------------------------------------------------------------------------

--!\file ethernet_sgmii_block.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--Note: this library is not necessarily synthesizable, use only for compiletime
--stuff
use ieee.math_real.all;
use work.eth_common.all;

--!\brief Block that hodls components for copper Ethernet using SGMII interface.


entity ethernet_sgmii_block is
  generic (
    --!For testbench testing
    is_testbench : boolean := false;
    --!Number of continuous data channels (i.e. ADC, loopback data)
    NFIFOS       : natural := N_IN_FIFOS;
    --!Port ID (typically 0,1 for fiber, 2 for copper)
    port_id      : natural := 2
    );
  port (
    clock             : in    std_logic;
    reset             : in    std_logic;
    ---------------------------------------------------------------------------
    --!\name Configuration data in/out
    --!\{
    ---------------------------------------------------------------------------
    config_data_in    : in    std_logic_vector(31 downto 0);
    config_valid_in   : in    std_logic;
    config_data_out   : out   std_logic_vector(31 downto 0);
    config_valid_out  : out   std_logic;
    --\}
    ---------------------------------------------------------------------------
    --\name MDIO interface for setting up PHY controller
    ---------------------------------------------------------------------------
    mdc               : out   std_logic;
    mdio              : inout std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name Transciver lines
    --\{
    ---------------------------------------------------------------------------
    ref_clk           : in    std_logic;
    rxp               : in    std_logic;
    txp               : out   std_logic;
    --\}
    ---------------------------------------------------------------------------
    --!\name Data input
    --!\{
    ---------------------------------------------------------------------------    
    --Data lines
    data_in           : in    data_array(0 to NFIFOS-1);
    wrreqs_in         : in    std_logic_vector(0 to NFIFOS-1);
    wrclks_in         : in    std_logic_vector(0 to NFIFOS-1);
    --General purpose UDP lines
    udp_data_in       : in    std_logic_vector(31 downto 0);
    udp_data_valid_in : in    std_logic;
    udp_data_port_in  : in    udp_port;
    udp_eop_in        : in    std_logic;
    --! UDP data destination address
    udp_addr_in       : in    std_logic_vector(79 downto 0);
    --!\}
    ---------------------------------------------------------------------------
    --!\name Output
    --!\{
    ---------------------------------------------------------------------------    
    --Output lines
    data_out          : out   word;
    data_valid        : out   std_logic;
    data_eop          : out   std_logic;
    data_port         : out   std_logic_vector(15 downto 0);
    --! Data output source address (IP bits [31..0], mac bits [79..32])
    data_addr_out     : out   std_logic_vector(79 downto 0);
    --\}
    --!Reset line for PHY chip
    hw_reset_out      : out   std_logic;
    --LED Lines
    led_link          : out   std_logic;
    led_act           : out   std_logic;
    --Status
    eth_ready         : out   std_logic
    );


end entity ethernet_sgmii_block;

architecture RTL of ethernet_sgmii_block is

  component ethernet_block is
    generic (
      is_testbench : boolean;
      iface_mode   : iface_type;
      NFIFOS       : natural;
      port_id      : natural);
    port (
      clock             : in  std_logic;
      reset             : in  std_logic;
      config_data_in    : in  std_logic_vector(31 downto 0);
      config_valid_in   : in  std_logic;
      config_data_out   : out std_logic_vector(31 downto 0);
      config_valid_out  : out std_logic;
      readdata          : in  std_logic_vector(31 downto 0);
      read              : out std_logic                     := '0';
      writedata         : out std_logic_vector(31 downto 0) := (others => '0');
      write             : out std_logic                     := '0';
      waitrequest       : in  std_logic;
      address           : out std_logic_vector(7 downto 0)  := (others => '0');
      ff_tx_data        : out std_logic_vector(31 downto 0) := (others => '0');
      ff_tx_eop         : out std_logic                     := '0';
      ff_tx_err         : out std_logic                     := '0';
      ff_tx_mod         : out std_logic_vector(1 downto 0)  := (others => '0');
      ff_tx_rdy         : in  std_logic;
      ff_tx_sop         : out std_logic                     := '0';
      ff_tx_wren        : out std_logic                     := '0';
      ff_tx_crc_fwd     : out std_logic                     := '0';
      ff_rx_data        : in  std_logic_vector(31 downto 0);
      ff_rx_eop         : in  std_logic;
      rx_err            : in  std_logic_vector(5 downto 0);
      ff_rx_mod         : in  std_logic_vector(1 downto 0);
      ff_rx_rdy         : out std_logic                     := '0';
      ff_rx_sop         : in  std_logic;
      ff_rx_dval        : in  std_logic;
      data_in           : in  data_array(0 to NFIFOS-1);
      wrreqs_in         : in  std_logic_vector(0 to NFIFOS-1);
      wrclks_in         : in  std_logic_vector(0 to NFIFOS-1);
      udp_data_in       : in  std_logic_vector(31 downto 0);
      udp_data_valid_in : in  std_logic;
      udp_data_port_in  : in  udp_port;
      udp_eop_in        : in  std_logic;
      udp_addr_in       : in  std_logic_vector(79 downto 0);
      data_out          : out word;
      data_valid        : out std_logic;
      data_eop          : out std_logic;
      data_port         : out std_logic_vector(15 downto 0);
      data_addr_out     : out std_logic_vector(79 downto 0);
      hw_reset_out      : out std_logic;
      error_out         : out std_logic                     := '0';
      link_status_out   : out std_logic                     := '0');
  end component ethernet_block;

  component tse_sgmii is
    port (
      clk            : in  std_logic                     := '0';
      reset          : in  std_logic                     := '0';
      readdata       : out std_logic_vector(31 downto 0);
      read           : in  std_logic                     := '0';
      writedata      : in  std_logic_vector(31 downto 0) := (others => '0');
      write          : in  std_logic                     := '0';
      waitrequest    : out std_logic;
      address        : in  std_logic_vector(7 downto 0)  := (others => '0');
      ff_rx_clk      : in  std_logic                     := '0';
      ff_tx_clk      : in  std_logic                     := '0';
      ff_rx_data     : out std_logic_vector(31 downto 0);
      ff_rx_eop      : out std_logic;
      rx_err         : out std_logic_vector(5 downto 0);
      ff_rx_mod      : out std_logic_vector(1 downto 0);
      ff_rx_rdy      : in  std_logic                     := '0';
      ff_rx_sop      : out std_logic;
      ff_rx_dval     : out std_logic;
      ff_tx_data     : in  std_logic_vector(31 downto 0) := (others => '0');
      ff_tx_eop      : in  std_logic                     := '0';
      ff_tx_err      : in  std_logic                     := '0';
      ff_tx_mod      : in  std_logic_vector(1 downto 0)  := (others => '0');
      ff_tx_rdy      : out std_logic;
      ff_tx_sop      : in  std_logic                     := '0';
      ff_tx_wren     : in  std_logic                     := '0';
      mdc            : out std_logic;
      mdio_in        : in  std_logic                     := '0';
      mdio_out       : out std_logic;
      mdio_oen       : out std_logic;
      xon_gen        : in  std_logic                     := '0';
      xoff_gen       : in  std_logic                     := '0';
      magic_wakeup   : out std_logic;
      magic_sleep_n  : in  std_logic                     := '0';
      ff_tx_crc_fwd  : in  std_logic                     := '0';
      ff_tx_septy    : out std_logic;
      tx_ff_uflow    : out std_logic;
      ff_tx_a_full   : out std_logic;
      ff_tx_a_empty  : out std_logic;
      rx_err_stat    : out std_logic_vector(17 downto 0);
      rx_frm_type    : out std_logic_vector(3 downto 0);
      ff_rx_dsav     : out std_logic;
      ff_rx_a_full   : out std_logic;
      ff_rx_a_empty  : out std_logic;
      ref_clk        : in  std_logic                     := '0';
      led_crs        : out std_logic;
      led_link       : out std_logic;
      led_col        : out std_logic;
      led_an         : out std_logic;
      led_char_err   : out std_logic;
      led_disp_err   : out std_logic;
      rx_recovclkout : out std_logic;
      txp            : out std_logic;
      rxp            : in  std_logic                     := '0');
  end component tse_sgmii;

  component mdio_buffer_iobuf_bidir_nho is
    port (
      datain  : in    std_logic_vector (0 downto 0);
      dataio  : inout std_logic_vector (0 downto 0);
      dataout : out   std_logic_vector (0 downto 0);
      oe      : in    std_logic_vector (0 downto 0));
  end component mdio_buffer_iobuf_bidir_nho;

  -----------------------------------------------------------------------------
  -- Triple speed ethernet signals
  -----------------------------------------------------------------------------
  signal readdata         : std_logic_vector(31 downto 0);
  signal read             : std_logic                      := '0';
  signal writedata        : std_logic_vector(31 downto 0)  := (others => '0');
  signal write            : std_logic                      := '0';
  signal waitrequest      : std_logic;
  signal address          : std_logic_vector(7 downto 0)   := (others => '0');
  signal ff_rx_data       : std_logic_vector(31 downto 0);
  signal ff_rx_eop        : std_logic;
  signal rx_err           : std_logic_vector(5 downto 0);
  signal ff_rx_mod        : std_logic_vector(1 downto 0);
  signal ff_rx_rdy        : std_logic                      := '0';
  signal ff_rx_sop        : std_logic;
  signal ff_rx_dval       : std_logic;
  signal ff_tx_data       : std_logic_vector(31 downto 0)  := (others => '0');
  signal ff_tx_eop        : std_logic                      := '0';
  signal ff_tx_err        : std_logic                      := '0';
  signal ff_tx_mod        : std_logic_vector(1 downto 0)   := (others => '0');
  signal ff_tx_rdy        : std_logic;
  signal ff_tx_sop        : std_logic                      := '0';
  signal ff_tx_wren       : std_logic                      := '0';
  signal mdio_in          : std_logic                      := '0';
  signal mdio_out         : std_logic;
  signal mdio_oen         : std_logic;
  signal xon_gen          : std_logic                      := '0';
  signal xoff_gen         : std_logic                      := '0';
  signal magic_wakeup     : std_logic;
  signal magic_sleep_n    : std_logic                      := '0';
  signal ff_tx_crc_fwd    : std_logic                      := '0';
  signal ff_tx_septy      : std_logic;
  signal tx_ff_uflow      : std_logic;
  signal ff_tx_a_full     : std_logic;
  signal ff_tx_a_empty    : std_logic;
  signal rx_err_stat      : std_logic_vector(17 downto 0);
  signal rx_frm_type      : std_logic_vector(3 downto 0);
  signal ff_rx_dsav       : std_logic;
  signal ff_rx_a_full     : std_logic;
  signal ff_rx_a_empty    : std_logic;
  signal led_crs          : std_logic;
  signal led_link_sig     : std_logic;
  signal led_col          : std_logic;
  signal led_an           : std_logic;
  signal led_char_err     : std_logic;
  signal led_disp_err     : std_logic;
  signal rx_recovclkout   : std_logic;
  signal reconfig_togxb   : std_logic_vector(139 downto 0) := (others => '0');
  signal reconfig_fromgxb : std_logic_vector(91 downto 0);

  signal datain  : std_logic_vector (0 downto 0);
  signal dataio  : std_logic_vector (0 downto 0);
  signal dataout : std_logic_vector (0 downto 0);
  signal oe      : std_logic_vector (0 downto 0);

  signal eth_ready_sig   : std_logic := '0';
  signal link_status_out : std_logic := '0';

begin
  led_link_sig <= link_status_out;

  --Register our output LEDs (since latency is irrelevant)
  LED_register : process(clock)
  begin
    if rising_edge(clock) then
      led_link      <= led_link_sig;
      led_act       <= led_crs;
      eth_ready     <= eth_ready_sig;
      --maybe temporary
      eth_ready_sig <= led_link_sig;
    end if;
  end process LED_register;

  --Note: not sure if we actually needs this or tri-state below would work, but
  --this does work so I'm not going to change it --RT
  mdio_buffer_iobuf_bidir_nho_2 : entity work.mdio_buffer_iobuf_bidir_nho
    port map (
      datain    => datain,
      dataio(0) => mdio,
      dataout   => dataout,
      oe        => oe);

  datain(0) <= mdio_out;
  mdio_in   <= dataout(0);
  oe(0)     <= not mdio_oen;
  -- -- Tri-state our MDIO pin
  -- mdio    <= mdio_out when mdio_oen = '0' else 'Z';
  -- mdio_in <= mdio;

  eblock : entity work.ethernet_block
    generic map (
      is_testbench => is_testbench,
      iface_mode   => SGMII,
      NFIFOS       => NFIFOS,
      port_id      => port_id)
    port map (
      clock             => clock,
      reset             => reset,
      config_data_in    => config_data_in,
      config_valid_in   => config_valid_in,
      config_data_out   => config_data_out,
      config_valid_out  => config_valid_out,
      readdata          => readdata,
      read              => read,
      writedata         => writedata,
      write             => write,
      waitrequest       => waitrequest,
      address           => address,
      ff_tx_data        => ff_tx_data,
      ff_tx_eop         => ff_tx_eop,
      ff_tx_err         => ff_tx_err,
      ff_tx_mod         => ff_tx_mod,
      ff_tx_rdy         => ff_tx_rdy,
      ff_tx_sop         => ff_tx_sop,
      ff_tx_wren        => ff_tx_wren,
      ff_tx_crc_fwd     => ff_tx_crc_fwd,
      ff_rx_data        => ff_rx_data,
      ff_rx_eop         => ff_rx_eop,
      rx_err            => rx_err,
      ff_rx_mod         => ff_rx_mod,
      ff_rx_rdy         => ff_rx_rdy,
      ff_rx_sop         => ff_rx_sop,
      ff_rx_dval        => ff_rx_dval,
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
      error_out         => open,
      link_status_out   => link_status_out);

  tse : component tse_sgmii
    port map (
      clk            => clock,
      reset          => reset,
      readdata       => readdata,
      read           => read,
      writedata      => writedata,
      write          => write,
      waitrequest    => waitrequest,
      address        => address,
      ff_rx_clk      => clock,
      ff_tx_clk      => clock,
      ff_rx_data     => ff_rx_data,
      ff_rx_eop      => ff_rx_eop,
      rx_err         => rx_err,
      ff_rx_mod      => ff_rx_mod,
      ff_rx_rdy      => ff_rx_rdy,
      ff_rx_sop      => ff_rx_sop,
      ff_rx_dval     => ff_rx_dval,
      ff_tx_data     => ff_tx_data,
      ff_tx_eop      => ff_tx_eop,
      ff_tx_err      => ff_tx_err,
      ff_tx_mod      => ff_tx_mod,
      ff_tx_rdy      => ff_tx_rdy,
      ff_tx_sop      => ff_tx_sop,
      ff_tx_wren     => ff_tx_wren,
      mdc            => mdc,
      mdio_in        => mdio_in,
      mdio_out       => mdio_out,
      mdio_oen       => mdio_oen,
      xon_gen        => xon_gen,
      xoff_gen       => xoff_gen,
      magic_wakeup   => magic_wakeup,
      magic_sleep_n  => magic_sleep_n,
      ff_tx_crc_fwd  => ff_tx_crc_fwd,
      ff_tx_septy    => ff_tx_septy,
      tx_ff_uflow    => tx_ff_uflow,
      ff_tx_a_full   => ff_tx_a_full,
      ff_tx_a_empty  => ff_tx_a_empty,
      rx_err_stat    => rx_err_stat,
      rx_frm_type    => rx_frm_type,
      ff_rx_dsav     => ff_rx_dsav,
      ff_rx_a_full   => ff_rx_a_full,
      ff_rx_a_empty  => ff_rx_a_empty,
      ref_clk        => ref_clk,
      led_crs        => led_crs,
      led_link       => open,
      led_col        => led_col,
      led_an         => led_an,
      led_char_err   => led_char_err,
      led_disp_err   => led_disp_err,
      rx_recovclkout => rx_recovclkout,
      txp            => txp,
      rxp            => rxp);


end architecture RTL;







