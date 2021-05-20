-------------------------------------------------------------------------------
-- Title      : ICMP Block
-- Project    : 
-------------------------------------------------------------------------------
-- File       : icmp_block.vhd
-- Author     : Ryan Thomas 
-- Company    : University of Chicago
-- Created    : 2019-09-19
-- Last update: 2020-07-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: ICMP Echo reply block. Handles generating replies to ICMP
-- (ping) echo requests. 
-------------------------------------------------------------------------------
--!\file icmp_block.vhd


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief Generates ICMP ping replies to ICMP requests from server.
--!
--! Handles generating responses to ICMP pings. This is useful for quick
--! testing of the Ethernet link with the ODILE board to verify functionality.

entity icmp_block is
  port (
    clock           : in  std_logic;
    reset           : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name TSE interface
    --\{
    ---------------------------------------------------------------------------
    data_out        : out word      := (others => '0');
    sop             : out std_logic := '0';
    eop             : out std_logic := '0';
    dval            : out std_logic := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name Inputs from frame reciever
    --!\{
    ---------------------------------------------------------------------------
    fr_data_out     : in  word      := (others => '0');
    fr_dval         : in  std_logic;
    fr_eop          : in  std_logic;
    icmp_ping       : in  std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!Transmit channel ready
    tx_ready        : in  std_logic;
    --!ICMP generator busy
    busy            : out std_logic := '0';
    ---------------------------------------------------------------------------
    --!\name Configuration inputs
    --!\{
    ---------------------------------------------------------------------------
    source_mac_addr : in  mac_addr;
    dest_mac_addr   : in  mac_addr;
    source_ip_addr  : in  ip_addr;
    dest_ip_addr    : in  ip_addr
    );
  --\}
end entity icmp_block;

architecture RTL of icmp_block is

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

  component fifo_32x256 is
    port (
      aclr  : in  std_logic;
      clock : in  std_logic;
      data  : in  std_logic_vector (31 downto 0);
      rdreq : in  std_logic;
      wrreq : in  std_logic;
      empty : out std_logic;
      full  : out std_logic;
      q     : out std_logic_vector (31 downto 0);
      usedw : out std_logic_vector (7 downto 0));
  end component fifo_32x256;

  -----------------------------------------------------------------------------
  -- Header Generator signals
  -----------------------------------------------------------------------------
  signal header_data  : std_logic_vector(31 downto 0);
  signal header_valid : std_logic;
  signal header_len   : std_logic_vector(8 downto 0);
  signal header_done  : std_logic;
  signal header_start : std_logic;
  --IPv4 type (ICMP)
  constant protocol   : std_logic_vector(7 downto 0) := X"01";
  --Only enable ethernet/IPv4 frame header generation
  constant hg_config : std_logic_vector(31 downto 0) := (0      => '1',
                                                         1      => '1',
                                                         others => '0');
  --These aren't used  
  constant app_header  : std_logic_vector(31 downto 0)               := (others => '0');
  signal payload_len   : std_logic_vector(MAX_FRAME_BITS-1 downto 0) := (others => '0');
  constant source_port : std_logic_vector(15 downto 0)               := (others => '0');
  constant dest_port   : std_logic_vector(15 downto 0)               := (others => '0');
  constant ether_type  : std_logic_vector(15 downto 0)               := X"08_00";

  -----------------------------------------------------------------------------
  -- Frame Generator Signals
  -----------------------------------------------------------------------------
  signal fg_data_in        : std_logic_vector(31 downto 0);
  signal usedw_in          : std_logic_vector (IN_FIFO_BITS-1 downto 0);
  signal payload_rdy       : std_logic;
  signal rdreq_in          : std_logic;
  signal wrreq_out         : std_logic;
  signal frame_length      : std_logic_vector (MAX_FRAME_BITS-1 downto 0);
  signal frame_rdy         : std_logic;
  signal fg_busy           : std_logic;
  --Constants for frame generator
  constant payload_max_len : std_logic_vector(MAX_FRAME_BITS-1 downto 0) := (others => '1');
  constant FIFO_in_dly     : std_logic_vector (3 downto 0)               := "0011";
  constant FIFO_out_dly    : std_logic_vector (3 downto 0)               := "0000";

  -----------------------------------------------------------------------------
  -- FIFO Signals
  -----------------------------------------------------------------------------
  signal fifo_rdreq        : std_logic;
  signal fifo_wrreq        : std_logic;
  signal fifo_empty        : std_logic;
  signal fifo_full         : std_logic;
  signal fifo_q            : std_logic_vector (31 downto 0);
  signal fifo_usedw        : std_logic_vector (7 downto 0);
  --Internal delayed signals
  signal fr_eop_delayed    : std_logic                     := '0';
  signal icmp_ping_delayed : std_logic                     := '0';
  signal checksum          : std_logic_vector(15 downto 0) := (others => '0');
  signal checksum_valid    : std_logic                     := '0';

  --Registers to hold values so we can reply
  signal dest_mac_addr_reg : std_logic_vector(47 downto 0);
  signal dest_ip_addr_reg  : std_logic_vector(31 downto 0);
  signal reply_wait        : std_logic;

begin
  --Only write if data is valid AND it is an ICMP ping request
  fifo_wrreq <= fr_dval and icmp_ping;
  fifo_rdreq <= rdreq_in;
  dval       <= wrreq_out;
  busy       <= fg_busy;
  usedw_in   <= std_logic_vector(resize(unsigned(fifo_usedw)+1, 11));

  --!Trigger to generate an ICMP response. We do so if there is a waiting
  --!request and the TSE MAC is ready to transmit data (and also we aren't busy
  --!sending another response).
  trigger_icmp : process(reset, clock)
  begin
    if (reset = '1') then
      payload_rdy <= '0';
    elsif rising_edge(clock) then
      --If we have a waiting ICMP request and the mac is ready, send the reply
      if (reply_wait = '1' and tx_ready = '1' and fg_busy = '0') then
        payload_rdy <= '1';
      else
        payload_rdy <= '0';
      end if;
    end if;
  end process trigger_icmp;

  --!Reads out our ICMP payload into the frame generator. The payload we return
  --!has to match what was sent to us.
  icmp_payload : process(reset, clock)
    variable word_num : natural := 0;
  begin
    if reset = '1' then
      word_num   := 0;
      fg_data_in <= (others => '0');
    elsif rising_edge(clock) then
      if (fifo_rdreq = '1') then
        if (word_num = 0) then
          fg_data_in <= ICMP_ECHO_REPLY & checksum;
        else
          fg_data_in <= fifo_q;
        end if;
        word_num := word_num + 1;
      elsif (fg_busy = '0') then
        word_num := 0;
      end if;
    end if;
  end process icmp_payload;

  --!Use our own header generator since ICMP packets differ from standard IPv4
  --!packets.
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
      dest_mac_addr   => dest_mac_addr_reg,
      ether_type      => ether_type,
      source_ip       => source_ip_addr,
      dest_ip         => dest_ip_addr_reg,
      source_port     => source_port,
      dest_port       => dest_port);

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

  --!Buffer that holds the ICMP payload that was sent to us.
  fifo : entity work.fifo_32x256
    port map (
      aclr  => reset,
      clock => clock,
      data  => fr_data_out,
      rdreq => fifo_rdreq,
      wrreq => fifo_wrreq,
      empty => fifo_empty,
      full  => fifo_full,
      q     => fifo_q,
      usedw => fifo_usedw);

  --!Computes our ICMP checksum on the payload as it comes in
  checksum_computer : process(reset, clock)
    --Worst case scenario we need 2 carry bits
    variable sum : unsigned (17 downto 0) := (others => '0');
  begin
    if (reset = '1') then
      sum               := (others => '0');
      checksum          <= (others => '0');
      checksum_valid    <= '0';
      fr_eop_delayed    <= '0';
      icmp_ping_delayed <= '0';
    elsif rising_edge(clock) then
      --Delay our EoP/icmp_ping by one clock cycle to allow time to compute checksum of
      --the last word from our frame reciever
      fr_eop_delayed    <= fr_eop;
      icmp_ping_delayed <= icmp_ping;
      if (fr_eop_delayed = '1' and icmp_ping_delayed = '1') then
        --Note: there is an edge case where this addition could generate a
        --carry, causing the wrong checksum.
        --TODO: fix this
        checksum       <= not std_logic_vector(sum(15 downto 0)+sum(17 downto 16));
        checksum_valid <= '1';
        sum := (others => '0');
      elsif (fr_dval = '1' and icmp_ping = '1') then
        checksum_valid <= '0';
        sum            := "00" & sum(15 downto 0) + unsigned(fr_data_out(31 downto 16)) +
               unsigned(fr_data_out(15 downto 0)) + sum(17 downto 16);

      end if;
    end if;
  end process checksum_computer;

  --!Buffers the signal that an ICMP request is waiting to be replied to, since we may not
  --!be able to respond immediately.
  reply_buffer : process(clock, reset)
  begin
    if (reset = '1') then
      dest_ip_addr_reg  <= (others => '0');
      dest_mac_addr_reg <= (others => '0');
      reply_wait        <= '0';
    elsif rising_edge(clock) then
      if (fg_busy = '1') then
        dest_mac_addr_reg <= dest_mac_addr_reg;
        dest_ip_addr_reg  <= dest_ip_addr_reg;
        reply_wait        <= '0';
      elsif (reply_wait = '1') then                  --Waiting to reply
        dest_mac_addr_reg <= dest_mac_addr_reg;
        dest_ip_addr_reg  <= dest_ip_addr_reg;
        reply_wait        <= '1';
      elsif (icmp_ping = '1' and fr_eop = '1') then  --A request came in
        dest_mac_addr_reg <= dest_mac_addr;
        dest_ip_addr_reg  <= dest_ip_addr;
        reply_wait        <= '1';
      end if;
    end if;
  end process reply_buffer;

end architecture RTL;
