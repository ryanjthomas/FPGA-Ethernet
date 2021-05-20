-------------------------------------------------------------------------------
-- Title      : Ethernet Block
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_block.vhd
-- Author     : Ryan Thomas 
-- Company    : University of Chicago
-- Created    : 2019-08-26
-- Last update: 2021-05-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Ethernet block that wires up a data, ICMP, and ARP generating
-- blocks to hook up to the TSE MAC. 
-------------------------------------------------------------------------------
--! \file ethernet_block.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--Note: this library is not necessarily synthesizable, use only for compiletime
--stuff
use ieee.math_real.all;
use work.eth_common.all;
use work.config_pkg.all;

--! \brief Block responsible for holding subblocks that generate data for
--! Ethernet interface.
--!
--! Block that holds all Ethernet data logic and interfaces with the
--! Altera TSE MAC. Holds no interface-specific logic (except for setting
--! default configuration registers), that should be contained in the higher
--! level block. Also contains several subblocks that respond to varios
--! link-level communications with the DAQ (ARP and ICMP replies, currently).
--! Higher level or ODILE specific communication should be done through the UDP
--! data interface.
--!
--! The frame-reciever will de-packetize incoming Ethernet frames and depending
--! on the detected protocol will either send signals to generate appropriate
--! responses, or forward any UDP data to the data_out lines for other blocks to
--! handle.

entity ethernet_block is
  generic (
    --!Set true to generate testbench code
    is_testbench : boolean    := false;
    --!Interface mode, one of BASEX, SGMII, RGMII (RGMII not implemented)
    iface_mode   : iface_type := BASEX;
    --!Number of FIFOs for ADC/loopback data
    NFIFOS       : natural    := N_IN_FIFOS;
    --!Interface ID (0,1, for fiber, 2 for copper)
    port_id      : natural    := 0
    );
  port (
    clock             : in  std_logic;
    reset             : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Configuration register control lines
    --!\{
    config_data_in    : in  std_logic_vector(31 downto 0);
    config_valid_in   : in  std_logic;
    config_data_out   : out std_logic_vector(31 downto 0);
    config_valid_out  : out std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name TSE Configuration interface
    --!\{
    readdata          : in  std_logic_vector(31 downto 0);
    read              : out std_logic                     := '0';
    writedata         : out std_logic_vector(31 downto 0) := (others => '0');
    write             : out std_logic                     := '0';
    waitrequest       : in  std_logic;
    address           : out std_logic_vector(7 downto 0)  := (others => '0');
    --!\}
    ---------------------------------------------------------------------------
    --!\name TSE transmit interface
    --!\{
    ff_tx_data        : out std_logic_vector(31 downto 0) := (others => '0');
    ff_tx_eop         : out std_logic                     := '0';
    ff_tx_err         : out std_logic                     := '0';
    ff_tx_mod         : out std_logic_vector(1 downto 0)  := (others => '0');
    ff_tx_rdy         : in  std_logic;
    ff_tx_sop         : out std_logic                     := '0';
    ff_tx_wren        : out std_logic                     := '0';
    ff_tx_crc_fwd     : out std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name TSE recieve interface
    --!\{
    ff_rx_data        : in  std_logic_vector(31 downto 0);
    ff_rx_eop         : in  std_logic;
    rx_err            : in  std_logic_vector(5 downto 0);
    ff_rx_mod         : in  std_logic_vector(1 downto 0);
    ff_rx_rdy         : out std_logic                     := '0';
    ff_rx_sop         : in  std_logic;
    ff_rx_dval        : in  std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --! ADC data line
    data_in           : in  data_array(0 to NFIFOS-1);
    --! ADC data valid lines
    wrreqs_in         : in  std_logic_vector(0 to NFIFOS-1);
    --! ADC data clocks
    wrclks_in         : in  std_logic_vector(0 to NFIFOS-1);
    --! General purpose UDP datain
    udp_data_in       : in  std_logic_vector(31 downto 0);
    --! General purpose UDP data valid
    udp_data_valid_in : in  std_logic;
    --! UDP data port
    udp_data_port_in  : in  udp_port;
    --! UDP end-of-packet signal
    udp_eop_in        : in  std_logic;
    --! UDP data destination address
    udp_addr_in       : in  std_logic_vector(79 downto 0);
    --! Data output
    data_out          : out word;
    --! Data output valid
    data_valid        : out std_logic;
    --! Data output end-of-packet
    data_eop          : out std_logic;
    --! Data output port
    data_port         : out std_logic_vector(15 downto 0);
    --! Data output source address (IP bits [31..0], mac bits [79..32])
    data_addr_out     : out std_logic_vector(79 downto 0);
    --! HW reset for ethernet PHY
    hw_reset_out      : out std_logic;
    --! Error status
    error_out         : out std_logic                     := '0';
    --! Ethernet link status
    link_status_out   : out std_logic                     := '0'
    );

end entity ethernet_block;

architecture RTL of ethernet_block is

  component ethernet_data_block is
    generic (
      NFIFOS : natural);
    port (
      clock              : in  std_logic;
      reset              : in  std_logic;
      wrclks             : in  std_logic_vector(0 to NFIFOS-1);
      wrreq              : in  std_logic_vector(0 to NFIFOS-1);
      data_in            : in  data_array(0 to NFIFOS-1);
      wrfull             : out std_logic_vector(0 to NFIFOS-1);
      tx_ready           : in  std_logic;
      data_out           : out word;
      sop                : out std_logic;
      eop                : out std_logic;
      dval               : out std_logic;
      busy               : out std_logic;
      ifm_flags          : in  in_fifo_flag_array(0 to NFIFOS-1);
      ifm_payload_size   : in  in_fifo_usedw_array(0 to NFIFOS-1);
      source_mac_addr    : in  std_logic_vector(47 downto 0);
      dest_mac_addr      : in  std_logic_vector(47 downto 0);
      source_ip_addr     : in  std_logic_vector(31 downto 0);
      dest_ip_addr       : in  std_logic_vector(31 downto 0);
      fg_payload_max_len : in  std_logic_vector(8 downto 0);
      fg_FIFO_in_dly     : in  std_logic_vector(3 downto 0);
      fg_FIFO_out_dly    : in  std_logic_vector(3 downto 0);
      fg_gen_crc         : in  std_logic;
      base_udp_port      : in  udp_port;
      header_config      : in  std_logic_vector(31 downto 0));
  end component ethernet_data_block;

  component ethernet_frame_reciever is
    port (
      rd_clk             : in  std_logic;
      reset              : in  std_logic;
      rx_data            : in  std_logic_vector(31 downto 0);
      rx_eop             : in  std_logic;
      rx_err             : in  std_logic_vector(5 downto 0);
      rx_mod             : in  std_logic_vector(1 downto 0);
      rx_rdy             : out std_logic;
      rx_sop             : in  std_logic;
      rx_dval            : in  std_logic;
      data_out           : out std_logic_vector(31 downto 0) := (others => '0');
      dval               : out std_logic                     := '0';
      eop                : out std_logic                     := '0';
      source_mac_addr    : out std_logic_vector(47 downto 0) := (others => '0');
      dest_mac_addr      : out std_logic_vector(47 downto 0) := (others => '0');
      source_ip_addr     : out std_logic_vector(31 downto 0) := (others => '0');
      dest_ip_addr       : out std_logic_vector(31 downto 0) := (others => '0');
      source_port        : out std_logic_vector(15 downto 0) := (others => '0');
      dest_port          : out std_logic_vector(15 downto 0) := (others => '0');
      ethertype          : out std_logic_vector(15 downto 0) := (others => '0');
      packet_length      : out std_logic_vector(15 downto 0) := (others => '0');
      our_ip_addr        : in  std_logic_vector(31 downto 0) := (others => '0');
      generate_arp_reply : out std_logic                     := '0';
      arp_reply_recieved : out std_logic                     := '0';
      ip_protocol        : out std_logic_vector(7 downto 0)  := (others => '0');
      icmp_ping          : out std_logic
      );
  end component ethernet_frame_reciever;

  component arp_block is
    port (
      clock            : in  std_logic;
      reset            : in  std_logic;
      data_out         : out word;
      sop              : out std_logic;
      eop              : out std_logic;
      dval             : out std_logic;
      tx_ready         : in  std_logic;
      busy             : out std_logic;
      generate_reply   : in  std_logic;
      generate_request : in  std_logic;
      source_mac_addr  : in  mac_addr;
      dest_mac_addr    : in  mac_addr;
      source_ip_addr   : in  ip_addr;
      dest_ip_addr     : in  ip_addr;
      req_ip_addr      : in  ip_addr);
  end component arp_block;

  component icmp_block is
    port (
      clock           : in  std_logic;
      reset           : in  std_logic;
      data_out        : out word      := (others => '0');
      sop             : out std_logic := '0';
      eop             : out std_logic := '0';
      dval            : out std_logic := '0';
      fr_data_out     : in  word      := (others => '0');
      fr_dval         : in  std_logic;
      fr_eop          : in  std_logic;
      icmp_ping       : in  std_logic;
      tx_ready        : in  std_logic;
      busy            : out std_logic := '0';
      source_mac_addr : in  mac_addr;
      dest_mac_addr   : in  mac_addr;
      source_ip_addr  : in  ip_addr;
      dest_ip_addr    : in  ip_addr);
  end component icmp_block;

  component tse_config_controller is
    generic (
      TSE_FIFO_SIZE : natural;
      port_id       : natural);
    port (
      clock            : in  std_logic;
      reset            : in  std_logic;
      mac_sw_reset     : in  std_logic;
      reconfig         : in  std_logic;
      readdata         : in  std_logic_vector(31 downto 0);
      read_req         : out std_logic;
      writedata        : out std_logic_vector(31 downto 0);
      write_req        : out std_logic;
      waitrequest      : in  std_logic;
      address          : out std_logic_vector(7 downto 0);
      hw_reset_out     : out std_logic;
      config_data_in   : in  std_logic_vector(31 downto 0);
      config_valid_in  : in  std_logic;
      config_data_out  : out std_logic_vector(31 downto 0);
      config_valid_out : out std_logic;
      config           : in  std_logic_vector(31 downto 0);
      mac_addr         : in  std_logic_vector(47 downto 0);
      mac_ready        : out std_logic;
      mac_error        : out std_logic;
      link_status      : out std_logic);
  end component tse_config_controller;

  component udp_data_block is
    port (
      wrclock         : in  std_logic;
      rdclock         : in  std_logic;
      reset           : in  std_logic;
      data_in         : in  std_logic_vector(31 downto 0);
      data_valid_in   : in  std_logic;
      data_port_in    : in  std_logic_vector(15 downto 0);
      data_eop_in     : in  std_logic;
      tx_ready        : in  std_logic;
      data_out        : out word;
      sop             : out std_logic := '0';
      eop             : out std_logic := '0';
      dval            : out std_logic := '0';
      busy            : out std_logic := '0';
      tx_req          : out std_logic := '0';
      source_mac_addr : in  mac_addr;
      dest_mac_addr   : in  mac_addr;
      source_ip_addr  : in  ip_addr;
      dest_ip_addr    : in  ip_addr);
  end component udp_data_block;

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

  component arp_cache is
    generic (
      clock_speed_mhz : natural;
      timeout_ms      : natural);
    port (
      reset             : in  std_logic;
      clock             : in  std_logic;
      server_ip_addr    : in  std_logic_vector(31 downto 0);
      source_mac_addr   : in  std_logic_vector(47 downto 0);
      source_ip_addr    : in  std_logic_vector(31 downto 0);
      source_addr_valid : in  std_logic                     := '0';
      ARP_cache_reset   : in  std_logic                     := '0';
      ARP_cache_value   : out std_logic_vector(47 downto 0) := (others => '0');
      ARP_cache_valid   : out std_logic                     := '0';
      ARP_cache_stale   : out std_logic                     := '0');
  end component arp_cache;

  function To_Std_Logic(L : boolean) return std_ulogic is
  begin
    if L then
      return('1');
    else
      return('0');
    end if;
  end function To_Std_Logic;

  signal mac_config          : std_logic_vector(31 downto 0) := X"00_00_00_1C";
  constant mac_loop_ena      : std_logic                     := '0';
  constant mac_tx_addr_ins   : std_logic                     := '0';
  constant mac_promis_tb     : std_logic                     := '1';
  constant mac_promis_hw     : std_logic                     := '0';
  constant mac_no_lgth_check : std_logic                     := '1';
  constant mac_tb_AN         : std_logic                     := '0';
  constant mac_hw_AN         : std_logic                     := '1';
  constant mac_crc_fwd       : std_logic                     := '0';
  constant mac_PCS_op        : std_logic                     := '1';
  constant mac_PCS_cu        : std_logic                     := '0';
  constant mac_MDIO_op       : std_logic                     := '0';
  constant mac_MDIO_cu       : std_logic                     := '1';

  signal wrreqs                : std_logic_vector(0 to NFIFOS-1);
  signal counters              : data_array(0 to NFIFOS-1)       := (others => (others => '0'));
  signal counter_wrreqs        : std_logic_vector(0 to NFIFOS-1) := (others => '0');
  signal counter_speed         : std_logic_vector(7 downto 0)    := (others => '0');
  signal ifm_data_in           : data_array(0 to NFIFOS-1)       := (others => (others => '0'));
  signal tx_ready              : std_logic;
  signal mac_ready_reg         : std_logic_vector(3 downto 0)    := (others => '0');
  -----------------------------------------------------------------------------
  -- Testbench only signals
  -----------------------------------------------------------------------------
  signal arp_req_data          : std_logic_vector(31 downto 0)   := (others => '0');
  signal arp_req_dval          : std_logic                       := '0';
  signal arp_req_sop           : std_logic                       := '0';
  signal arp_req_eop           : std_logic                       := '0';
  signal arp_req_busy          : std_logic                       := '0';
  -----------------------------------------------------------------------------
  -- Configuration constants.
  -----------------------------------------------------------------------------
  constant def_source_mac_addr : std_logic_vector(47 downto 0)   := IFACE_MAC_ADDRESSES(port_id);
  constant def_dest_mac_addr   : std_logic_vector(47 downto 0)   := DEST_MAC_ADDRESSES(port_id);
  constant def_source_ip_addr  : std_logic_vector(31 downto 0)   := IFACE_IP_ADDRESSES(port_id);
  constant def_dest_ip_addr    : std_logic_vector(31 downto 0)   := DEST_IP_ADDRESSES(port_id);
  constant def_base_udp_port   : udp_port                        := UDP_PORT_BASES(port_id);
  constant DEFAULT_SETTINGS    : config_word_array (10 downto 0) :=
    (0  => def_source_mac_addr(31 downto 0),
     1  => X"00_00" & def_source_mac_addr(47 downto 32),
     2  => def_dest_mac_addr(31 downto 0),
     3  => X"00_00" & def_dest_mac_addr(47 downto 32),
     4  => def_source_ip_addr,
     5  => def_dest_ip_addr,
     --MAC configuration word
     6  => To_Std_Logic(is_testbench) &                                     --31 (skip MDIO wait)
     "0" &                                                                  --30
     To_Std_Logic(iface_mode = RGMII or iface_mode = SGMII) &               --29
     "0000001010000" &                                                      --28:16
     "00000000" &                                                           --15:8
     To_Std_Logic(iface_mode = RGMII or iface_mode = SGMII) &               --7
     To_Std_Logic(iface_mode = BASEX or iface_mode = SGMII) &mac_crc_fwd &  --6,5     
     To_Std_Logic(not is_testbench) &                                       --4
     mac_no_lgth_check &                                                    --3
     ((mac_promis_hw and To_Std_Logic(not is_testbench)) or                 --2
      (mac_promis_tb and To_Std_Logic(is_testbench))) &
     mac_tx_addr_ins & mac_loop_ena,                                        --1,0
     7  => X"00_00" & def_base_udp_port,
     8  => X"00_00_01_55",                                                  --19:16=counter enables, 9:0 IFM flags (0x1_55 to enable all buffers)
     9  => X"00_00_00_fa",                                                  --Minimum packet size
     10 => X"FF_FF_FF_F7");                                                 --Header configuration

  -----------------------------------------------------------------------------
  -- Configuration Signals
  -----------------------------------------------------------------------------
  signal source_mac_addr      : std_logic_vector(47 downto 0)                         := IFACE_MAC_ADDRESSES(port_id);
  signal dest_mac_addr        : std_logic_vector(47 downto 0)                         := X"6C_B3_11_51_74_34";
  signal source_ip_addr       : std_logic_vector(31 downto 0)                         := IFACE_IP_ADDRESSES(port_id);  --192.168.0.3
  signal dest_ip_addr         : std_logic_vector(31 downto 0)                         := X"C0_A8_00_01";               --192.168.0.1
  signal base_udp_port        : udp_port                                              := UDP_PORT_BASES(port_id);
  signal header_config        : std_logic_vector(31 downto 0)                         := (others => '1');
  signal counter_enables      : std_logic_vector(0 to NFIFOS-1)                       := (others => '0');
  signal ifm_flags            : in_fifo_flag_array(0 to NFIFOS-1)                     := (others => INFIFO_ENABLE);
  signal ifm_payload_size     : in_fifo_usedw_array(0 to NFIFOS-1)                    := (others => (std_logic_vector(to_unsigned(250, 11))));
  -----------------------------------------------------------------------------
  -- Fixed (non-configurable) constants
  -----------------------------------------------------------------------------
  constant fg_payload_max_len : std_logic_vector(8 downto 0)                          := std_logic_vector(to_unsigned(300, 9));
  constant fg_FIFO_in_dly     : std_logic_vector(3 downto 0)                          := "0101";
  constant fg_FIFO_out_dly    : std_logic_vector(3 downto 0)                          := "0000";
  -----------------------------------------------------------------------------
  -- Ethernet block outputs
  -----------------------------------------------------------------------------
  signal wrfull               : std_logic_vector(0 to NFIFOS-1);
  signal datablock_busy       : std_logic;
  signal datablock_data       : word;
  signal datablock_eop        : std_logic;
  signal datablock_sop        : std_logic;
  signal datablock_dval       : std_logic;
  -----------------------------------------------------------------------------
  -- Frame Reciever Outputs
  -----------------------------------------------------------------------------
  signal fr_data_out          : std_logic_vector(31 downto 0)                         := (others => '0');
  signal fr_dval              : std_logic                                             := '0';
  signal fr_eop               : std_logic                                             := '0';
  signal fr_source_mac_addr   : std_logic_vector(47 downto 0)                         := (others => '0');
  signal fr_dest_mac_addr     : std_logic_vector(47 downto 0)                         := (others => '0');
  signal fr_source_ip_addr    : std_logic_vector(31 downto 0)                         := (others => '0');
  signal fr_dest_ip_addr      : std_logic_vector(31 downto 0)                         := (others => '0');
  signal fr_source_port       : std_logic_vector(15 downto 0)                         := (others => '0');
  signal fr_dest_port         : std_logic_vector(15 downto 0)                         := (others => '0');
  signal fr_ethertype         : std_logic_vector(15 downto 0)                         := (others => '0');
  signal fr_packet_length     : std_logic_vector(15 downto 0)                         := (others => '0');
  signal fg_gen_crc           : std_logic                                             := '0';
  signal fr_ip_protocol       : std_logic_vector(7 downto 0)                          := (others => '0');
  signal fr_icmp_ping         : std_logic;
  -----------------------------------------------------------------------------
  -- ARP Reply block
  -----------------------------------------------------------------------------
  signal arpblock_data        : word;
  signal arpblock_sop         : std_logic;
  signal arpblock_eop         : std_logic;
  signal arpblock_dval        : std_logic;
  signal arpblock_busy        : std_logic;
  signal generate_arp_reply   : std_logic;
  signal generate_arp_request : std_logic;
  signal arp_reply_recieved   : std_logic;
  signal arp_dest_mac_addr    : mac_addr;
  signal arp_dest_ip_addr     : ip_addr;
  -----------------------------------------------------------------------------
  -- ARP Cache block
  -----------------------------------------------------------------------------  
  signal ARP_cache_reset      : std_logic                                             := '0';
  signal ARP_cache_value      : std_logic_vector(47 downto 0)                         := (others => '0');
  signal ARP_cache_valid      : std_logic                                             := '0';
  signal ARP_cache_stale      : std_logic                                             := '0';
  signal ARP_disable          : std_logic                                             := '0';
  signal ARP_source_ip_valid  : std_logic                                             := '0';
  -----------------------------------------------------------------------------
  -- ICMP Reply block
  -----------------------------------------------------------------------------
  signal icmpblock_data       : word                                                  := (others => '0');
  signal icmpblock_sop        : std_logic                                             := '0';
  signal icmpblock_eop        : std_logic                                             := '0';
  signal icmpblock_dval       : std_logic                                             := '0';
  signal icmpblock_busy       : std_logic                                             := '0';
  signal icmp_dest_mac_addr   : mac_addr;
  signal icmp_dest_ip_addr    : ip_addr;
  -----------------------------------------------------------------------------
  -- UDP Data block
  -----------------------------------------------------------------------------
  signal udpblock_data        : word;
  signal udpblock_sop         : std_logic                                             := '0';
  signal udpblock_eop         : std_logic                                             := '0';
  signal udpblock_dval        : std_logic                                             := '0';
  signal udpblock_busy        : std_logic                                             := '0';
  signal udpblock_tx_req      : std_logic                                             := '0';
  signal udp_dest_mac_addr    : mac_addr;
  signal udp_dest_ip_addr     : ip_addr;
  -----------------------------------------------------------------------------
  -- TSE Config Signals
  -----------------------------------------------------------------------------
  signal mac_ready            : std_logic                                             := '0';
  signal mac_error            : std_logic                                             := '0';
  signal link_status          : std_logic                                             := '0';
  constant TSE_FIFO_SIZE      : natural                                               := 2018;
  signal hw_reset_sig         : std_logic                                             := '0';
  signal config_data_out_tse  : config_word                                           := (others => '0');
  signal config_valid_out_tse : std_logic                                             := '0';
  -----------------------------------------------------------------------------
  -- Configuration register block signals
  -----------------------------------------------------------------------------
  signal config_registers     : config_word_array(DEFAULT_SETTINGS'length-1 downto 0) := DEFAULT_SETTINGS;
  signal config_changed       : std_logic                                             := '0';
  signal config_error         : std_logic                                             := '0';
  signal ff_tx_wren_sig       : std_logic                                             := '0';
  signal config_data_out_reg  : config_word                                           := (others => '0');
  signal config_valid_out_reg : std_logic                                             := '0';

begin
  ff_tx_crc_fwd   <= fg_gen_crc;
  --TODO: this will cause packet corruption, figure out a better way to handle
  --backpressure.
  ff_tx_wren      <= ff_tx_wren_sig and ff_tx_rdy;
  tx_ready        <= mac_ready_reg(0) and ff_tx_rdy and not datablock_busy and not arp_req_busy and not arpblock_busy and not icmpblock_busy;
  hw_reset_out    <= hw_reset_sig;
  config_data_out <= config_data_out_reg when config_valid_out_reg = '1' else
                     config_data_out_tse when config_valid_out_tse = '1' else
                     X"00_00_00_00";
  config_valid_out     <= config_valid_out_reg or config_valid_out_tse;
  --!Reset our cache if the config changes. Should also reset if the link goes down, but not yet
  ARP_cache_reset      <= config_changed;
  ARP_source_ip_valid  <= generate_arp_reply or arp_reply_recieved;
  generate_arp_request <= ARP_cache_stale or not ARP_cache_valid;

  --!Pipeline our control logic
  config_dff : process(clock)
  begin
    if rising_edge(clock) then
      source_mac_addr <= config_registers(1)(15 downto 0) & config_registers(0);
      --User our ARP cache value if set to that and the cache is valid
      if ARP_disable = '0' and ARP_cache_valid = '1' then
        dest_mac_addr <= ARP_cache_value;
      else
        dest_mac_addr <= config_registers(3)(15 downto 0) & config_registers(2);
      end if;
      ARP_disable     <= config_registers(3)(16);
      source_ip_addr  <= config_registers(4);
      dest_ip_addr    <= config_registers(5);
      mac_config      <= config_registers(6);
      base_udp_port   <= config_registers(7)(15 downto 0);
      header_config   <= config_registers(10);
      error_out       <= mac_error;
      link_status_out <= link_status;
      counter_speed   <= config_registers(8)(31 downto 24);
    end if;
  end process config_dff;

  --!Pipeline data going to our IFM
  ifm_gen : for I in 0 to NFIFOS-1 generate
    process (wrclks_in(I))
    begin
      if (rising_edge(wrclks_in(I))) then
        ifm_flags(I)        <= config_registers(8)(I*2+1 downto I*2);
        counter_enables(I)  <= config_registers(8)(16+I);
        -- if I=NFIFOS-1 then
        --   wrreqs(I)           <= wrreqs_in(I) and ifm_flags(I)(0);
        -- else
        wrreqs(I)           <= (wrreqs_in(I) or (counter_enables(I) and counter_wrreqs(I))) and ifm_flags(I)(0) and mac_ready_reg(0);
        -- end if;
        ifm_payload_size(I) <= config_registers(9)(ifm_payload_size(I)'length-1 downto 0);

        if counter_enables(I) = '1' then
          ifm_data_in(I) <= counters(I);
        else
          ifm_data_in(I) <= data_in(I);
        end if;
      end if;
    end process;
  end generate ifm_gen;

  data_out                    <= fr_data_out;
  data_valid                  <= fr_dval;
  data_eop                    <= fr_eop;
  data_port                   <= fr_dest_port;
  data_addr_out(31 downto 0)  <= fr_source_ip_addr;
  data_addr_out(79 downto 32) <= fr_source_mac_addr;

  arp_dest_ip_addr   <= fr_source_ip_addr;
  arp_dest_mac_addr  <= fr_source_mac_addr;
  icmp_dest_ip_addr  <= fr_source_ip_addr;
  icmp_dest_mac_addr <= fr_source_mac_addr;
  udp_dest_ip_addr   <= udp_addr_in(31 downto 0);
  udp_dest_mac_addr  <= udp_addr_in(79 downto 32);

  --! \brief Responsible for sending our ADC/CDS data from CCD video signal back to
  --! our DAQ system. 
  datablock : entity work.ethernet_data_block
    generic map (
      NFIFOS => NFIFOS)
    port map (
      clock              => clock,
      reset              => reset,
      wrclks             => wrclks_in,
      wrreqs             => wrreqs,
      data_in            => ifm_data_in,
      wrfull             => wrfull,
      tx_ready           => tx_ready,
      data_out           => datablock_data,
      sop                => datablock_sop,
      eop                => datablock_eop,
      dval               => datablock_dval,
      busy               => datablock_busy,
      ifm_flags          => ifm_flags,
      ifm_payload_size   => ifm_payload_size,
      source_mac_addr    => source_mac_addr,
      dest_mac_addr      => dest_mac_addr,
      source_ip_addr     => source_ip_addr,
      dest_ip_addr       => dest_ip_addr,
      fg_payload_max_len => fg_payload_max_len,
      fg_FIFO_in_dly     => fg_FIFO_in_dly,
      fg_FIFO_out_dly    => fg_FIFO_out_dly,
      fg_gen_crc         => fg_gen_crc,
      base_udp_port      => base_udp_port,
      header_config      => header_config);

  --! \brief Recieves and decodes ethernet packets. Interprets and generates signals
  --! to ICMP and ARP blocks directly, and forwards other data to the data router.
  reciever : entity work.ethernet_frame_reciever
    port map (
      rd_clk             => clock,
      reset              => reset,
      rx_data            => ff_rx_data,
      rx_eop             => ff_rx_eop,
      rx_err             => rx_err,
      rx_mod             => ff_rx_mod,
      rx_rdy             => ff_rx_rdy,
      rx_sop             => ff_rx_sop,
      rx_dval            => ff_rx_dval,
      data_out           => fr_data_out,
      dval               => fr_dval,
      eop                => fr_eop,
      source_mac_addr    => fr_source_mac_addr,
      dest_mac_addr      => fr_dest_mac_addr,
      source_ip_addr     => fr_source_ip_addr,
      dest_ip_addr       => fr_dest_ip_addr,
      source_port        => fr_source_port,
      dest_port          => fr_dest_port,
      ethertype          => fr_ethertype,
      packet_length      => fr_packet_length,
      our_ip_addr        => source_ip_addr,
      generate_arp_reply => generate_arp_reply,
      arp_reply_recieved => arp_reply_recieved,
      ip_protocol        => fr_ip_protocol,
      icmp_ping          => fr_icmp_ping
      );

  --! \brief Generates replies to ARP request packets
  arpblock : entity work.arp_block
    port map (
      clock            => clock,
      reset            => reset,
      data_out         => arpblock_data,
      sop              => arpblock_sop,
      eop              => arpblock_eop,
      dval             => arpblock_dval,
      tx_ready         => tx_ready,
      busy             => arpblock_busy,
      generate_reply   => generate_arp_reply,
      generate_request => generate_arp_request,
      source_mac_addr  => source_mac_addr,
      dest_mac_addr    => arp_dest_mac_addr,
      source_ip_addr   => source_ip_addr,
      dest_ip_addr     => arp_dest_ip_addr,
      req_ip_addr      => dest_ip_addr);

  --! \brief Generates replies to ICMP ping packets
  icmpblock : entity work.icmp_block
    port map (
      clock           => clock,
      reset           => reset,
      data_out        => icmpblock_data,
      sop             => icmpblock_sop,
      eop             => icmpblock_eop,
      dval            => icmpblock_dval,
      fr_data_out     => fr_data_out,
      fr_dval         => fr_dval,
      fr_eop          => fr_eop,
      icmp_ping       => fr_icmp_ping,
      tx_ready        => tx_ready,
      busy            => icmpblock_busy,
      source_mac_addr => source_mac_addr,
      dest_mac_addr   => icmp_dest_mac_addr,
      source_ip_addr  => source_ip_addr,
      dest_ip_addr    => icmp_dest_ip_addr);

  --! \brief Responsible for configuring the Altera TSE MAC
  tse_config : entity work.tse_config_controller
    generic map (
      TSE_FIFO_SIZE => TSE_FIFO_SIZE,
      port_id       => port_id)
    port map (
      clock            => clock,
      reset            => reset,
      mac_sw_reset     => '0',
      reconfig         => config_changed,
      readdata         => readdata,
      read_req         => read,
      writedata        => writedata,
      write_req        => write,
      waitrequest      => waitrequest,
      address          => address,
      hw_reset_out     => hw_reset_sig,
      config_data_in   => config_data_in,
      config_valid_in  => config_valid_in,
      config_data_out  => config_data_out_tse,
      config_valid_out => config_valid_out_tse,
      config           => mac_config,
      mac_addr         => source_mac_addr,
      mac_ready        => mac_ready,
      mac_error        => mac_error,
      link_status      => link_status);

  --! \brief Block responsible for general purpose data transmission
  udp_data_block_1 : entity work.udp_data_block
    port map (
      wrclock         => clock,
      rdclock         => clock,
      reset           => reset,
      data_in         => udp_data_in,
      data_valid_in   => udp_data_valid_in,
      data_port_in    => udp_data_port_in,
      data_eop_in     => udp_eop_in,
      tx_ready        => tx_ready,
      data_out        => udpblock_data,
      sop             => udpblock_sop,
      eop             => udpblock_eop,
      dval            => udpblock_dval,
      busy            => udpblock_busy,
      tx_req          => udpblock_tx_req,
      source_mac_addr => source_mac_addr,
      dest_mac_addr   => udp_dest_mac_addr,
      source_ip_addr  => source_ip_addr,
      dest_ip_addr    => udp_dest_ip_addr);

  --! \brief Configuration block that holds various Ethernet settings, such as MAC
  --! address or packet configuration
  configblock : entity work.config_register_block
    generic map (
      BLOCK_ADDRESS    => ENET_CONFIG_ADDRESSES(port_id),
      DEFAULT_SETTINGS => DEFAULT_SETTINGS)
    port map (
      clock            => clock,
      reset            => reset,
      config_data_in   => config_data_in,
      config_valid_in  => config_valid_in,
      config_data_out  => config_data_out_reg,
      config_valid_out => config_valid_out_reg,
      config_registers => config_registers,
      config_changed   => config_changed,
      config_error     => config_error);

  --!\brief Simple ARP cache to hold MAC address of our server
  arp_cache_1 : entity work.arp_cache
    generic map (
      clock_speed_mhz => 100,
      timeout_ms      => 600000)
    port map (
      reset             => reset,
      clock             => clock,
      server_ip_addr    => dest_ip_addr,
      source_mac_addr   => fr_source_mac_addr,
      source_ip_addr    => fr_source_ip_addr,
      source_addr_valid => ARP_source_ip_valid,
      ARP_cache_reset   => ARP_cache_reset,
      ARP_cache_value   => ARP_cache_value,
      ARP_cache_valid   => ARP_cache_valid,
      ARP_cache_stale   => ARP_cache_stale);

  --!Register our mac_ready signal
  mac_ready_DFF : process(clock, reset)
  begin
    if (reset = '1') then
      mac_ready_reg <= (others => '0');
    elsif rising_edge(clock) then
      for I in 0 to mac_ready_reg'length-2 loop
        mac_ready_reg(I) <= mac_ready_reg(I+1);
      end loop;
      mac_ready_reg(mac_ready_reg'length-1) <= mac_ready;
    end if;
  end process mac_ready_DFF;



  --!Multiplex our TSE inputs from various different data blocks.
  tse_multiplexer : process (clock, reset)
  begin
    if reset = '1' then
      ff_tx_wren_sig <= '0';
      ff_tx_data     <= (others => '0');
      ff_tx_sop      <= '0';
      ff_tx_eop      <= '0';
    elsif rising_edge(clock) then
      if (datablock_busy = '1') then     --Ethernet data stream
        ff_tx_wren_sig <= datablock_dval;
        ff_tx_data     <= datablock_data;
        ff_tx_sop      <= datablock_sop;
        ff_tx_eop      <= datablock_eop;
      elsif (udpblock_busy = '1') then
        ff_tx_wren_sig <= udpblock_dval;
        ff_tx_data     <= udpblock_data;
        ff_tx_sop      <= udpblock_sop;
        ff_tx_eop      <= udpblock_eop;
      elsif (arp_req_busy = '1') then    --Hardcoded ARP/ICMP generator
        ff_tx_wren_sig <= arp_req_dval;
        ff_tx_data     <= arp_req_data;
        ff_tx_sop      <= arp_req_sop;
        ff_tx_eop      <= arp_req_eop;
      elsif (arpblock_busy = '1') then   --ARP replier
        ff_tx_wren_sig <= arpblock_dval;
        ff_tx_data     <= arpblock_data;
        ff_tx_sop      <= arpblock_sop;
        ff_tx_eop      <= arpblock_eop;
      elsif (icmpblock_busy = '1') then  --ICMP replier
        ff_tx_wren_sig <= icmpblock_dval;
        ff_tx_data     <= icmpblock_data;
        ff_tx_sop      <= icmpblock_sop;
        ff_tx_eop      <= icmpblock_eop;
      else
        ff_tx_wren_sig <= '0';
        ff_tx_data     <= (others => '0');
        ff_tx_sop      <= '0';
        ff_tx_eop      <= '0';
      end if;
    end if;

  end process tse_multiplexer;

  --!Generates a hardcoded simulated ARP request. In testbench, this will be fed back
  --!through the loopback and cause an ARP reply to be generated. Only generated
  --!in testbench to minimize register usage.
  testbench_code : if is_testbench generate
    arp_requester : process(clock, reset)
      variable word_num : natural := 0;
    begin
      if reset = '1' or not is_testbench then
        arp_req_data <= (others => '0');
        arp_req_dval <= '0';
        arp_req_busy <= '0';
        arp_req_sop  <= '0';
        arp_req_eop  <= '0';
      elsif rising_edge(clock) and mac_ready_reg(0) = '1' then
        if word_num = 0 then
          arp_req_dval <= '1';
          arp_req_data <= X"00_00_FF_FF";
          arp_req_sop  <= '1';
          arp_req_eop  <= '0';
        elsif word_num = 1 then
          arp_req_data <= X"FF_FF_FF_FF";
          arp_req_sop  <= '0';
        elsif word_num = 2 then
          arp_req_data <= source_mac_addr(47 downto 16);
        elsif word_num = 3 then
          arp_req_data <= source_mac_addr(15 downto 0) & X"08_06";
        elsif word_num = 4 then
          arp_req_data <= X"00_01" & X"0800";
        elsif word_num = 5 then
          arp_req_data <= X"06_04_00_01";
        elsif word_num = 6 then
          --Destination because we pretend it came from the server
          arp_req_data <= dest_mac_addr(47 downto 16);
        elsif word_num = 7 then
          arp_req_data <= dest_mac_addr(15 downto 0) & dest_ip_addr(31 downto 16);
        elsif word_num = 8 then
          arp_req_data <= dest_ip_addr(15 downto 0) & X"00_00";
        elsif word_num = 9 then
          arp_req_data <= (others => '0');
        elsif word_num = 10 then
          arp_req_data <= source_ip_addr;
          arp_req_eop  <= '1';
        --Send an ICMP request
        elsif word_num = 20 then
          arp_req_dval <= '1';
          arp_req_data <= X"00_00_EE_11";
          arp_req_sop  <= '1';
          arp_req_eop  <= '0';
        elsif word_num = 21 then
          arp_req_data <= X"22_33_44_55";
          arp_req_sop  <= '0';
        elsif word_num = 22 then
          arp_req_data <= dest_mac_addr(47 downto 16);
        elsif word_num = 23 then
          arp_req_data <= dest_mac_addr(15 downto 0) & X"08_00";
        elsif word_num = 24 then
          arp_req_data <= X"45_00_00_54";
        elsif word_num = 25 then
          arp_req_data <= X"00_00_00_00";
        elsif word_num = 26 then
          arp_req_data <= X"FF_01" & X"00_00";
        elsif word_num = 27 then
          arp_req_data <= X"C0_A8_00_01";
        elsif word_num = 28 then
          arp_req_data <= X"C0_A8_00_03";
        --Now the actual ICMP ping
        elsif word_num = 29 then
          arp_req_data <= X"08_00_03_20";
        elsif word_num = 30 then
          arp_req_data <= X"3f_a9_00_01";
        --ICMP Payload
        elsif word_num = 31 then
          arp_req_data <= X"90_c5_83_5d";
        elsif word_num = 32 then
          arp_req_data <= X"21_22_23_24";
        elsif word_num = 33 then
          arp_req_data <= X"d3_3f_0f_00";
        elsif word_num = 34 then
          arp_req_data <= X"31_32_33_34";
        elsif word_num = 35 then
          arp_req_data <= X"10_11_12_13";
        elsif word_num = 36 then
          arp_req_data <= X"14_15_16_17";
        elsif word_num = 37 then
          arp_req_data <= X"18_19_1a_1b";
        elsif word_num = 38 then
          arp_req_data <= X"1c_1d_1e_1f";
          arp_req_eop  <= '1';
        -----------------------------------------------------------------------
        -- Send short UDP packet
        -----------------------------------------------------------------------
        elsif word_num = 50 then
          arp_req_dval <= '1';
          arp_req_data <= X"00_00_EE_11";
          arp_req_sop  <= '1';
          arp_req_eop  <= '0';
        elsif word_num = 51 then
          arp_req_data <= X"22_33_44_55";
          arp_req_sop  <= '0';
        elsif word_num = 52 then
          arp_req_data <= dest_mac_addr(47 downto 16);
        elsif word_num = 53 then
          arp_req_data <= dest_mac_addr(15 downto 0) & X"08_00";
        elsif word_num = 54 then
          arp_req_data <= X"45_00_00_54";
        elsif word_num = 55 then
          arp_req_data <= X"00_00_00_00";
        elsif word_num = 56 then
          arp_req_data <= X"FF_11" & X"00_00";
        elsif word_num = 57 then
          arp_req_data <= X"C0_A8_00_01";
        elsif word_num = 58 then
          arp_req_data <= X"C0_A8_00_03";
        elsif word_num = 59 then
          arp_req_data <= X"00_81_00_81";  --Source + destination port
        elsif word_num = 60 then
          arp_req_data <= X"00_0F_AA_BB";  --Length + fake checksum
        elsif word_num = 61 then
          arp_req_data <= X"01_23_45_67";  --payload
          arp_req_eop  <= '1';
        else
          arp_req_data <= (others => '0');
          arp_req_dval <= '0';
          arp_req_eop  <= '0';
          arp_req_sop  <= '0';
        end if;
        if word_num < 70 and word_num >= 0 then
          arp_req_busy <= '1';
        else
          arp_req_busy <= '0';
        end if;
        if word_num < 100 then
          word_num := word_num + 1;
        end if;
      end if;
    end process arp_requester;
  end generate testbench_code;

  --!Generate counters to create simulated data
  counter_gen : for I in 0 to NFIFOS-1 generate
    process(wrclks_in(I), reset)
      variable speed_counter : integer range 0 to 255 := 0;
    begin
      if reset = '1' then
        counters(I) <= (others => '0');
      elsif rising_edge(wrclks_in(I)) then
        if (speed_counter = 255) then
          speed_counter := 0;
        else
          speed_counter := speed_counter+1;
        end if;
        if (speed_counter >= to_integer(unsigned(counter_speed))) then
          counters(I)       <= std_logic_vector(unsigned(counters(I)) + 1);
          counter_wrreqs(I) <= '1';
        else
          counter_wrreqs(I) <= '0';
        end if;
      end if;
    end process;
  end generate counter_gen;


end architecture RTL;







