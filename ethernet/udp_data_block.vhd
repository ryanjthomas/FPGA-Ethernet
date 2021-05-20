-------------------------------------------------------------------------------
-- Title      : Ethernet UDP data block
-- Project    : 
-------------------------------------------------------------------------------
-- File       : udp_data_block.vhd
-- Author     : Ryan Thomas 
-- Company    : University of Chicago
-- Created    : 2020-04-03
-- Last update: 2020-08-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Data block that hols UDP data buffer and frame/header generator
-------------------------------------------------------------------------------
--! \file udp_data_block.vhd
--! \brief Data block that handles UDP data buffer and frame/header generator


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;


--!\brief A block that handles components for the packetization of UDP data.
--! 
--! Data incoming should specify the port it is meant to go to. Data will be
--! transmitted as a packet once a complete packet is ready, if no data is
--! written for some time, or if the port changes.

entity udp_data_block is
  port (
    --!@name Clocks
    --!@{
    wrclock         : in  std_logic;
    rdclock         : in  std_logic;
    --!@}    
    reset           : in  std_logic;
    ---------------------------------------------------------------------------
    -- Inputs
    ---------------------------------------------------------------------------
    --!@name Inputs
    --!@{
    data_in         : in  std_logic_vector(31 downto 0);  
    data_valid_in   : in  std_logic;
    data_port_in    : in  std_logic_vector(15 downto 0);
    --!Data end of packet trigger    
    data_eop_in     : in  std_logic;    
    --!Transmit ready trigger
    tx_ready        : in  std_logic;        
    --!@}
    ---------------------------------------------------------------------------
    -- Outputs
    ---------------------------------------------------------------------------
    --!@name Outputs
    --!@{
    data_out        : out word;
    sop             : out std_logic := '0';
    eop             : out std_logic := '0';
    dval            : out std_logic := '0';
    busy            : out std_logic := '0';
    --!Transmit request
    tx_req          : out std_logic := '0';
    --!@}
    ---------------------------------------------------------------------------
    -- Configuration
    ---------------------------------------------------------------------------
    --!@name Configuration Inputs
    --!@{
    source_mac_addr : in  mac_addr;
    dest_mac_addr   : in  mac_addr;
    source_ip_addr  : in  ip_addr;
    dest_ip_addr    : in  ip_addr );
    --!@}
end entity udp_data_block;

architecture vhdl_rtl of udp_data_block is

  component header_generator is
    generic (
      MAX_FRAME_BITS : natural);
    port (
      clock           : in  std_logic;
      reset           : in  std_logic;
      header_data     : out std_logic_vector(31 downto 0);
      header_valid    : out std_logic;
      header_len      : out std_logic_vector(8 downto 0);
      header_done     : out std_logic;
      header_start    : in  std_logic;
      protocol        : in  std_logic_vector(7 downto 0);
      app_header      : in  std_logic_vector(31 downto 0);
      config          : in  std_logic_vector(31 downto 0);
      payload_len     : in  std_logic_vector(MAX_FRAME_BITS-1 downto 0);
      source_mac_addr : in  std_logic_vector(47 downto 0);
      dest_mac_addr   : in  std_logic_vector(47 downto 0);
      ether_type      : in  std_logic_vector(15 downto 0);
      source_ip       : in  std_logic_vector(31 downto 0);
      dest_ip         : in  std_logic_vector(31 downto 0);
      source_port     : in  std_logic_vector(15 downto 0);
      dest_port       : in  std_logic_vector(15 downto 0));
  end component header_generator;

  component ethernet_frame_generator is
    generic (
      IN_FIFO_BITS   : in natural;
      MAX_FRAME_BITS : in natural);
    port (
      clock           : in  std_logic;
      reset           : in  std_logic;
      header_data     : in  std_logic_vector(31 downto 0);
      header_valid    : in  std_logic;
      header_done     : in  std_logic;
      header_start    : out std_logic;
      payload_len     : out std_logic_vector(MAX_FRAME_BITS-1 downto 0);
      data_in         : in  std_logic_vector (31 downto 0);
      usedw_in        : in  std_logic_vector (IN_FIFO_BITS-1 downto 0);
      payload_rdy     : in  std_logic;
      rdreq_in        : out std_logic;
      data_out        : out std_logic_vector (31 downto 0) := (others => '0');
      wrreq_out       : out std_logic;
      sop             : out std_logic;
      eop             : out std_logic;
      frame_length    : out std_logic_vector (MAX_FRAME_BITS-1 downto 0);
      frame_rdy       : out std_logic;
      fg_busy         : out std_logic;
      payload_max_len : in  std_logic_vector(MAX_FRAME_BITS-1 downto 0);
      FIFO_in_dly     : in  std_logic_vector (3 downto 0)  := "0101";
      FIFO_out_dly    : in  std_logic_vector (3 downto 0)  := "0101";
      gen_crc         : in  std_logic);
  end component ethernet_frame_generator;

  component udp_data_buffer is
    port (
      wrclock         : in  std_logic;
      rdclock         : in  std_logic;
      reset           : in  std_logic;
      data_in         : in  std_logic_vector(31 downto 0);
      data_valid_in   : in  std_logic;
      data_port_in    : in  std_logic_vector(15 downto 0);
      data_rdreq      : in  std_logic;
      data_eop_in     : in  std_logic;
      packet_finished : in  std_logic;
      data_out        : out std_logic_vector(31 downto 0)               := (others => '0');
      data_port_out   : out std_logic_vector(15 downto 0)               := (others => '0');
      payload_len     : out std_logic_vector(MAX_FRAME_BITS-1 downto 0) := (others => '0');
      payload_rdy     : out std_logic                                   := '0');
  end component udp_data_buffer;

  -----------------------------------------------------------------------------
  -- Frame Generator signals
  -----------------------------------------------------------------------------
  signal header_data     : std_logic_vector(31 downto 0);
  signal header_valid    : std_logic;
  signal header_done     : std_logic;
  signal header_start    : std_logic;
  signal fg_payload_len  : std_logic_vector(MAX_FRAME_BITS-1 downto 0);
  signal fg_data_in      : std_logic_vector (31 downto 0);
  signal fg_usedw_in     : std_logic_vector (IN_FIFO_BITS-1 downto 0);
  signal fg_payload_rdy  : std_logic                                   := '0';
  signal payload_rdy     : std_logic;
  signal data_rdreq      : std_logic;
  signal wrreq_out       : std_logic;
  signal eop_sig         : std_logic;
  signal frame_length    : std_logic_vector (MAX_FRAME_BITS-1 downto 0);
  signal frame_rdy       : std_logic;
  signal fg_busy         : std_logic;
  signal payload_max_len : std_logic_vector(MAX_FRAME_BITS-1 downto 0) := (others => '1');
  signal FIFO_in_dly     : std_logic_vector (3 downto 0)               := "0011";
  signal FIFO_out_dly    : std_logic_vector (3 downto 0)               := "0000";
  constant gen_crc       : std_logic                                   := '0';
  -----------------------------------------------------------------------------
  -- Header config
  -----------------------------------------------------------------------------
  constant protocol      : std_logic_vector(7 downto 0)                := X"11";
  constant app_header    : std_logic_vector(31 downto 0)               := X"00_12_34_56";
  constant config        : std_logic_vector(31 downto 0)               := X"00_00_00_07";
  constant ether_type    : std_logic_vector(15 downto 0)               := X"08_00";
  signal udp_payload_len : std_logic_vector(MAX_FRAME_BITS-1 downto 0);
  signal header_len      : std_logic_vector(8 downto 0);
  signal source_port     : std_logic_vector(15 downto 0);
  signal dest_port       : std_logic_vector(15 downto 0);
  signal data_port_out   : std_logic_vector(15 downto 0)               := (others => '0');

begin

  tx_req         <= payload_rdy;
  dval           <= wrreq_out;
  eop            <= eop_sig;
  busy           <= fg_busy;
  dest_port      <= data_port_out;
  source_port    <= data_port_out;
  --Frame generator uses this to figure out how long payload is
  fg_usedw_in    <= "00" & udp_payload_len;
  fg_payload_rdy <= payload_rdy and tx_ready;

  udp_data_buffer_1 : entity work.udp_data_buffer
    port map (
      wrclock         => wrclock,
      rdclock         => rdclock,
      reset           => reset,
      data_in         => data_in,
      data_valid_in   => data_valid_in,
      data_port_in    => data_port_in,
      data_rdreq      => data_rdreq,
      data_eop_in     => data_eop_in,
      packet_finished => eop_sig,
      data_out        => fg_data_in,
      data_port_out   => data_port_out,
      payload_len     => udp_payload_len,
      payload_rdy     => payload_rdy);

  fg : entity work.ethernet_frame_generator
    generic map (
      IN_FIFO_BITS   => IN_FIFO_BITS,
      MAX_FRAME_BITS => MAX_FRAME_BITS)
    port map (
      clock           => rdclock,
      reset           => reset,
      header_data     => header_data,
      header_valid    => header_valid,
      header_done     => header_done,
      header_start    => header_start,
      payload_len     => fg_payload_len,
      data_in         => fg_data_in,
      usedw_in        => fg_usedw_in,
      payload_rdy     => fg_payload_rdy,
      rdreq_in        => data_rdreq,
      data_out        => data_out,
      wrreq_out       => wrreq_out,
      sop             => sop,
      eop             => eop_sig,
      frame_length    => frame_length,
      frame_rdy       => frame_rdy,
      fg_busy         => fg_busy,
      payload_max_len => payload_max_len,
      FIFO_in_dly     => FIFO_in_dly,
      FIFO_out_dly    => FIFO_out_dly,
      gen_crc         => gen_crc);

  hdgen : entity work.header_generator
    generic map (
      MAX_FRAME_BITS => MAX_FRAME_BITS)
    port map (
      clock           => rdclock,
      reset           => reset,
      header_data     => header_data,
      header_valid    => header_valid,
      header_len      => header_len,
      header_done     => header_done,
      header_start    => header_start,
      protocol        => protocol,
      app_header      => app_header,
      config          => config,
      payload_len     => fg_payload_len,
      source_mac_addr => source_mac_addr,
      dest_mac_addr   => dest_mac_addr,
      ether_type      => ether_type,
      source_ip       => source_ip_addr,
      dest_ip         => dest_ip_addr,
      source_port     => source_port,
      dest_port       => dest_port);


end architecture;

