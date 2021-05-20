-------------------------------------------------------------------------------
-- Title      : Ethernet Data Block
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_data_block.vhd
-- Author     : Ryan Thomas
-- Company    : University of Chicago
-- Created    : 2019-08-22
-- Last update: 2020-07-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Block that wires together all the components for data transfer
-- for the Ethernet interface.
-------------------------------------------------------------------------------
--!\file ethernet_data_block.vhd

--Glossary:
--ifm - inpute fifo manager
--fg - (ethernet) frame generator
--hdgen - ethernet/ipv4/udp header generator
--n_in_fifos - number of FIFOs to be connected to data lines

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief Handler for the ADC data from CCD video signal.
--!
--! This block is responsible for buffering and packetizing the data streams
--! coming from the ADC blocks (it can also handle loopback data or any other
--! semi-continous data stream, depending on how many n_in_fifos as specified).

entity ethernet_data_block is
  generic (
    --!\brief Number of data streams to accept.
    --! All data port widths are defined with
    --! respect to this number. It is usually defined to be 5, and while the
    --! block should adjust to numbers other than 5, there may be places were 5
    --! streams were assumed that do not properly adjust.
    NFIFOS : natural := n_in_fifos
    );
  port (
    --Logic clock
    clock              : in  std_logic;
    --Asynchronous reset
    reset              : in  std_logic;
    --!Clocks synchronous to incoming data
    wrclks             : in  std_logic_vector(0 to NFIFOS-1);
    --!Valid flags for incoming data
    wrreqs             : in  std_logic_vector(0 to NFIFOS-1);
    --!Data to transmit
    data_in            : in  data_array(0 to NFIFOS-1);
    --!Transmit buffer full flags.
    wrfull             : out std_logic_vector(0 to NFIFOS-1);
    --!Ready to transmit signal
    tx_ready           : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Raw data packets from Ethernet interface.
    --!\{
    ---------------------------------------------------------------------------
    data_out           : out word;
    --!Start of packet flag
    sop                : out std_logic;
    --!End of packet flag
    eop                : out std_logic;
    --!Data valid flag
    dval               : out std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!Indicates transmit line is busy
    busy               : out std_logic;
    ---------------------------------------------------------------------------
    --!\name Configuration Lines
    --!\{
    ---------------------------------------------------------------------------
    --!Flags for data streams. bit 0 enables data transmit, bit 1 sets high priority.
    ifm_flags          : in  in_fifo_flag_array(0 to NFIFOS-1);
    --!\brief Minimum size of packets to create. Data will be transmitted when a FIFO exceeds
    --!this threshold.
    ifm_payload_size   : in  in_fifo_usedw_array(0 to NFIFOS-1);
    --!MAC address to send from
    source_mac_addr    : in  std_logic_vector(47 downto 0);
    --!MAC address to send data to
    dest_mac_addr      : in  std_logic_vector(47 downto 0);
    --IPv4
    --!IP address to send data from
    source_ip_addr     : in  std_logic_vector(31 downto 0);
    --!IP address to send data to
    dest_ip_addr       : in  std_logic_vector(31 downto 0);
    --Frame Generator Configuration
    --!Maximum payload length for each packet
    fg_payload_max_len : in  std_logic_vector(8 downto 0);
    --!Clock latency on input data FIFO
    fg_FIFO_in_dly     : in  std_logic_vector(3 downto 0);
    --!Clock latency on transmit FIFO (TSE MAC)
    fg_FIFO_out_dly    : in  std_logic_vector(3 downto 0);
    --!Generate Crc32 during packet creation. Does not work, do not use.
    fg_gen_crc         : in  std_logic;
    --!Base UDP port for interface. Data is transmitted to ports based on this
    --!(so stream 0 is base_udp_port, stream 1 is base_udp_port+1, etc).
    base_udp_port      : in  udp_port;
    --!Configuration for Ethernet header generator (see header_generator.vhd)
    header_config      : in  std_logic_vector(31 downto 0)
    );
--\}
end entity ethernet_data_block;

architecture vhdl_rtl of ethernet_data_block is

  component input_fifo_manager is
    generic (
      NFIFOS : natural := NFIFOS);
    port (
      clock        : in  std_logic;
      reset        : in  std_logic;
      data_out     : out word;
      usedw_out    : out in_fifo_usedw;
      payload_rdy  : out std_logic := '0';
      tx_busy      : in  std_logic;
      rdreq        : in  std_logic;
      payload_size : in  in_fifo_usedw_array(0 to NFIFOS-1);
      flags        : in  in_fifo_flag_array(0 to NFIFOS-1);
      wrclks       : in  std_logic_vector(0 to NFIFOS-1);
      wrreqs       : in  std_logic_vector(0 to NFIFOS-1);
      data_in      : in  data_array(0 to NFIFOS-1);
      wrfull       : out std_logic_vector(0 to NFIFOS-1);
      rdusedw      : out in_fifo_usedw_array(0 to NFIFOS-1);
      curr_fifo    : out std_logic_vector(0 to f_num_bits(NFIFOS)-1));
  end component input_fifo_manager;

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
      gen_crc         : in  std_logic
      );
  end component ethernet_frame_generator;

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  --Interface between header generator and frame generator
  signal header_data     : std_logic_vector(31 downto 0);
  signal header_valid    : std_logic;
  signal header_done     : std_logic;
  signal header_start    : std_logic;
  signal fg_payload_len  : std_logic_vector(MAX_FRAME_BITS-1 downto 0);
  --Interface between ifm and frame generator
  signal ifm_data_out    : std_logic_vector (31 downto 0);
  signal ifm_usedw_out   : in_fifo_usedw;
  signal ifm_payload_rdy : std_logic;
  signal ifm_rdreq       : std_logic;
  signal fg_busy         : std_logic;
  signal tx_busy         : std_logic;
  --Output of frame generator
  signal fg_data_out     : std_logic_vector (31 downto 0) := (others => '0');
  signal fg_sop          : std_logic;
  signal fg_eop          : std_logic;
  signal fg_frame_length : std_logic_vector (MAX_FRAME_BITS-1 downto 0);
  signal fg_frame_rdy    : std_logic;
  signal fg_wrreq_out    : std_logic;
  --Unused, currently
  constant protocol      : std_logic_vector(7 downto 0)   := X"11";
  signal ifm_rdusedw     : in_fifo_usedw_array(0 to N_IN_FIFOS-1);
  signal ifm_curr_fifo   : std_logic_vector(0 to f_num_bits(N_IN_FIFOS)-1);
  signal header_len      : std_logic_vector(8 downto 0);
  constant app_header    : word                           := X"00_12_34_56";
  signal source_port     : std_logic_vector(15 downto 0)  := X"00_10";
  signal dest_port       : std_logic_vector(15 downto 0)  := X"00_11";

begin

  data_out <= fg_data_out;
  sop      <= fg_sop;
  eop      <= fg_eop;
  dval     <= fg_wrreq_out;
  busy     <= fg_busy;
  tx_busy  <= fg_busy or not tx_ready;

  source_port(ifm_curr_fifo'length-1 downto 0) <= ifm_curr_fifo;
  source_port(15 downto ifm_curr_fifo'length)  <= base_udp_port(15 downto ifm_curr_fifo'length);

  dest_port(ifm_curr_fifo'length-1 downto 0) <= ifm_curr_fifo;
  dest_port(15 downto ifm_curr_fifo'length)  <= base_udp_port(15 downto ifm_curr_fifo'length);


  -----------------------------------------------------------------------------
  -- Entity Instantiations
  -----------------------------------------------------------------------------

  --! Handles the FIFO buffers for all the data streams. Triggers creation of
  --! packets and data transmission when a) tx_busy is low, and b) one of the
  --! buffers contains more than payload_size words of data.
  ifm : entity work.input_fifo_manager
    generic map (
      NFIFOS => NFIFOS)
    port map (
      clock        => clock,
      reset        => reset,
      data_out     => ifm_data_out,
      usedw_out    => ifm_usedw_out,
      payload_rdy  => ifm_payload_rdy,
      tx_busy      => tx_busy,
      rdreq        => ifm_rdreq,
      payload_size => ifm_payload_size,
      flags        => ifm_flags,
      wrclks       => wrclks,
      wrreqs       => wrreqs,
      data_in      => data_in,
      wrfull       => wrfull,
      rdusedw      => ifm_rdusedw,
      curr_fifo    => ifm_curr_fifo);
  --!Generates headers for Ethernet frames
  hdgen : entity work.header_generator
    generic map (
      MAX_FRAME_BITS => MAX_FRAME_BITS)
    port map (
      clock           => clock,
      reset           => reset,
      header_data     => header_data,
      header_valid    => header_valid,
      header_len      => header_len,
      header_done     => header_done,
      header_start    => header_start,
      protocol        => protocol,
      app_header      => app_header,
      config          => header_config,
      payload_len     => fg_payload_len,
      source_mac_addr => source_mac_addr,
      dest_mac_addr   => dest_mac_addr,
      --IPv4 by default
      ether_type      => X"08_00",
      source_ip       => source_ip_addr,
      dest_ip         => dest_ip_addr,
      source_port     => source_port,
      dest_port       => dest_port);

  --!Generates ethernet frames
  fg : entity work.ethernet_frame_generator
    generic map (
      IN_FIFO_BITS   => IN_FIFO_BITS,
      MAX_FRAME_BITS => MAX_FRAME_BITS)
    port map (
      clock           => clock,
      reset           => reset,
      header_data     => header_data,
      header_valid    => header_valid,
      header_done     => header_done,
      header_start    => header_start,
      payload_len     => fg_payload_len,
      data_in         => ifm_data_out,
      usedw_in        => ifm_usedw_out,
      payload_rdy     => ifm_payload_rdy,
      rdreq_in        => ifm_rdreq,
      data_out        => fg_data_out,
      wrreq_out       => fg_wrreq_out,
      sop             => fg_sop,
      eop             => fg_eop,
      frame_length    => fg_frame_length,
      frame_rdy       => fg_frame_rdy,
      fg_busy         => fg_busy,
      payload_max_len => fg_payload_max_len,
      FIFO_in_dly     => fg_FIFO_in_dly,
      FIFO_out_dly    => fg_FIFO_out_dly,
      gen_crc         => fg_gen_crc);

end architecture vhdl_rtl;
