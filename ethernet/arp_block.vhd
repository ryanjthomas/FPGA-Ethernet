-------------------------------------------------------------------------------
-- Title      : ARP Block
-- Project    : ODILE
-------------------------------------------------------------------------------
-- File       : arp_block.vhd
-- Author     : Ryan Thomas 
-- Company    : University of Chicago
-- Created    : 2019-09-10
-- Last update: 2021-03-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Handles replies to ARP requests.
-------------------------------------------------------------------------------

--! \file arp_block.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--! \brief ARP reply generating block.
--!
--! The Address Resolution Protocol ("ARP") is used by Ethernet to determine
--! the owner of an IP address (such as "192.168.0.1") and convert it into a
--! MAC address (such as 01:AE:32:01:4E) that is used at the hardware level to
--! resolve different clients. This block handles creating that reply. The
--! "source_mac_addr" and "source_ip_addr" should be set to the MAC and IP
--! addresses of the ODILE board interface being used, while the dest_* should
--! be supplied by an ethernet frame parsing block, which is also responsible
--! for setting the "generate_reply" signal high to signal that an ARP request
--! was made and should be replied to.
--!
--! This block generates a complete ethernet frame including header using the
--! 32-bit wide "data_out" bus. "sop" and "eop" are used to signal start and end
--! of packets, and "dval" indicates that data_out is valid.

entity arp_block is
  port (
    clock            : in  std_logic;
    --! Asynchronous (active high) reset
    reset            : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Interface to MAC
    --!\{
    ---------------------------------------------------------------------------
    data_out         : out word;
    sop              : out std_logic;
    eop              : out std_logic;
    dval             : out std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name State Signals
    --!@{    
    ---------------------------------------------------------------------------
    --! Transmit ready signal
    tx_ready         : in  std_logic;
    --! ARP block busy
    busy             : out std_logic;
    --! Generate ARP reply when high
    generate_reply   : in  std_logic;
    --! Generate ARP request when high
    generate_request : in  std_logic;
    --!@}
    ---------------------------------------------------------------------------
    --!\name Configuration Inputs
    --!\{    
    ---------------------------------------------------------------------------
    --! MAC address of ODILE interface
    source_mac_addr  : in  mac_addr;
    --! MAC address of whatever generated ARP request
    dest_mac_addr    : in  mac_addr;
    --! IP address of ODILE interface
    source_ip_addr   : in  ip_addr;
    --! IP address of whatever generated ARP request
    dest_ip_addr     : in  ip_addr;
    req_ip_addr      : in  ip_addr
    );
--!\}

end entity arp_block;

architecture RTL of arp_block is

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

  component arp_replier is
    port (
      clock           : in  std_logic;
      reset           : in  std_logic;
      data_out        : out std_logic_vector(31 downto 0);
      dval            : out std_logic;
      source_mac_addr : in  std_logic_vector(47 downto 0);
      dest_mac_addr   : in  std_logic_vector(47 downto 0);
      source_ip_addr  : in  std_logic_vector(31 downto 0);
      dest_ip_addr    : in  std_logic_vector(31 downto 0);
      start_reply     : in  std_logic;
      end_reply       : out std_logic;
      is_request      : in  std_logic);
  end component arp_replier;

  -----------------------------------------------------------------------------
  --!\name Header Generator signals
  --!\{
  -----------------------------------------------------------------------------
  signal header_data   : std_logic_vector(31 downto 0);
  signal header_valid  : std_logic;
  signal header_len    : std_logic_vector(8 downto 0);
  signal header_done   : std_logic;
  signal header_start  : std_logic;
  constant protocol    : std_logic_vector(7 downto 0)                := (others => '0');
  constant app_header  : std_logic_vector(31 downto 0)               := (others => '0');
  signal payload_len   : std_logic_vector(MAX_FRAME_BITS-1 downto 0) := (others => '0');
  constant source_port : std_logic_vector(15 downto 0)               := (others => '0');
  constant dest_port   : std_logic_vector(15 downto 0)               := (others => '0');
  --!\}

  --!Only enable ethernet frame header generation
  constant hg_config          : std_logic_vector(31 downto 0)               := (0      => '1', others => '0');
  --!ARP type
  constant ether_type         : std_logic_vector(15 downto 0)               := X"08_06";
  -----------------------------------------------------------------------------
  --!\name Frame Generator signals
  --!\{
  -----------------------------------------------------------------------------
  signal fg_data_in           : std_logic_vector(31 downto 0);
  signal usedw_in             : std_logic_vector (IN_FIFO_BITS-1 downto 0);
  signal payload_rdy          : std_logic;
  signal rdreq_in             : std_logic;
  signal wrreq_out            : std_logic;
  signal frame_length         : std_logic_vector (MAX_FRAME_BITS-1 downto 0);
  signal frame_rdy            : std_logic;
  signal fg_busy              : std_logic;
  --Constants for frame generator
  constant ARP_len            : std_logic_vector(IN_FIFO_BITS-1 downto 0)   := std_logic_vector(to_unsigned(7, IN_FIFO_BITS));
  constant payload_max_len    : std_logic_vector(MAX_FRAME_BITS-1 downto 0) := (others => '1');
  constant FIFO_in_dly        : std_logic_vector (3 downto 0)               := "0101";
  constant FIFO_out_dly       : std_logic_vector (3 downto 0)               := "0101";
  --!\}  
  -----------------------------------------------------------------------------
  --!\name ARP Reply generator signals
  --!\{
  -----------------------------------------------------------------------------
  signal arp_data_out         : std_logic_vector(31 downto 0);
  signal arp_dval             : std_logic;
  signal start_reply          : std_logic                                   := '0';
  signal end_reply            : std_logic;
  --!\}
  --Registers to hold values so we can reply
  signal dest_mac_addr_reg    : std_logic_vector(47 downto 0);
  signal dest_ip_addr_reg     : std_logic_vector(31 downto 0);
  signal reply_wait           : std_logic;
  signal is_request           : std_logic                                   := '0';
  signal generate_request_int : std_logic                                   := '0';

  constant ARP_REQ_WAITTIME : natural := 100000000;

begin

  busy        <= fg_busy;
  --Our ARP reply has a fixed length
  usedw_in    <= ARP_len;
  dval        <= wrreq_out;
  --Hook our ARP replied up to our FIFO read request
  start_reply <= rdreq_in;
  --Only transmit if we have a request waiting and TX is ready
  payload_rdy <= reply_wait and tx_ready;

  --!Ethernet header generator
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
      config          => hg_config,
      payload_len     => payload_len,
      source_mac_addr => source_mac_addr,
      dest_mac_addr   => dest_mac_addr,
      ether_type      => ether_type,
      source_ip       => source_ip_addr,
      dest_ip         => dest_ip_addr,
      source_port     => source_port,
      dest_port       => dest_port);

  --!Standard Ethernet frame generator to packetize our ARP response
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
      payload_len     => payload_len,
      data_in         => fg_data_in,
      usedw_in        => usedw_in,
      payload_rdy     => payload_rdy,
      rdreq_in        => rdreq_in,
      data_out        => data_out,
      wrreq_out       => wrreq_out,
      sop             => sop,
      eop             => eop,
      frame_length    => frame_length,
      frame_rdy       => frame_rdy,
      fg_busy         => fg_busy,
      payload_max_len => payload_max_len,
      FIFO_in_dly     => FIFO_in_dly,
      FIFO_out_dly    => FIFO_out_dly,
      gen_crc         => '0');

  --! Block responsible for generating the actual ARP response payload.
  arpgen : entity work.arp_replier
    port map (
      clock           => clock,
      reset           => reset,
      data_out        => arp_data_out,
      dval            => arp_dval,
      source_mac_addr => source_mac_addr,
      dest_mac_addr   => dest_mac_addr_reg,
      source_ip_addr  => source_ip_addr,
      dest_ip_addr    => dest_ip_addr_reg,
      start_reply     => start_reply,
      end_reply       => end_reply,
      is_request      => is_request);

  --!Register the output of our ARP generator to match the delay expected by the
  --!frame generator.
  frame_generator_register : process(clock)
  begin
    if rising_edge(clock) then
      fg_data_in <= arp_data_out;
    end if;
  end process;

  --! Register an ARP request signal so we don't continuously generate requests until we recieve a reply (as this floods the interface, very bad).
  ARP_request_waiter : process(clock)
    variable timer : natural := 0;
  begin
    if rising_edge(clock) then
      --Default value
      generate_request_int <= '0';
      if timer >= ARP_REQ_WAITTIME then
        timer := 0;
      elsif timer > 0 then
        timer := timer + 1;
      end if;
      if generate_request = '0' then
        timer := 0;
      elsif generate_request = '1' and timer = 0 then
        generate_request_int <= '1';
        timer                := 1;
      end if;
    end if;
  end process;

  --!Buffer that holds a reply request and registers the MAC/IP address of the
  --!requester until we are able to generate a response
  reply_buffer : process(clock, reset)
  begin
    if (reset = '1') then
      dest_ip_addr_reg  <= (others => '0');
      dest_mac_addr_reg <= (others => '0');
      reply_wait        <= '0';
      is_request        <= '0';
    elsif rising_edge(clock) then
      if (fg_busy = '1') then
        dest_mac_addr_reg <= dest_mac_addr_reg;
        dest_ip_addr_reg  <= dest_ip_addr_reg;
        reply_wait        <= '0';
      elsif (reply_wait = '1') then      --Waiting to reply
        dest_mac_addr_reg <= dest_mac_addr_reg;
        dest_ip_addr_reg  <= dest_ip_addr_reg;
        reply_wait        <= '1';
        is_request        <= is_request;
      elsif (generate_reply = '1') then  --A request came in
        dest_mac_addr_reg <= dest_mac_addr;
        dest_ip_addr_reg  <= dest_ip_addr;
        reply_wait        <= '1';
        is_request        <= '0';
      elsif (generate_request_int = '1') then
        dest_mac_addr_reg <= (others => '0');
        dest_ip_addr_reg  <= req_ip_addr;
        reply_wait        <= '1';
        is_request        <= '1';
      end if;
    end if;
  end process reply_buffer;

end architecture RTL;
