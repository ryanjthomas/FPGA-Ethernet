-------------------------------------------------------------------------------
-- Title      : Ethernet UDP data buffer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : udp_data_buffer
-- Author     : Ryan Thomas 
-- Company    : University of Chicago
-- Created    : 2020-04-02
-- Last update: 2020-08-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Packet buffer that can hold data from multiple different UDP
-- sources. Data streams are stored in a flat FIFO, and the associated UDP port
-- and number of words that use that port are stored in a secondary FIFO. This
-- schema assumes that data transmission from multiple sources will have not
-- switch source frequently.
-------------------------------------------------------------------------------
--!\file udp_data_buffer.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief Buffer that holds UDP data for transmission over Ethernet interface.
--!
--! Since UDP data can come from multiple different sources sent to different
--! UDP destination ports, we need to buffer both the data and the destination
--! port until we have a complete packet to send. We will send a packet either
--! once we exceed the maximum size (350 32-bit words), if the UDP port changes
--! (so that we want to transmit data to a new UDP destination), or if we stop
--! writing data for a while (to prevent data from going too stale).

entity udp_data_buffer is
  port (
    --!Clock synchronous to data_in lines
    wrclock         : in  std_logic;
    --!Clock synchronous to data_out lines    
    rdclock         : in  std_logic;
    --!Asynchronous reset
    reset           : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Inputs
    --!\{
    ---------------------------------------------------------------------------
    data_in         : in  std_logic_vector(31 downto 0);
    --!Signal that data_in and data_port_in lines are valid
    data_valid_in   : in  std_logic;
    --!The current destination port for our data
    data_port_in    : in  std_logic_vector(15 downto 0);
    --!Data read request
    data_rdreq      : in  std_logic;
    --!End-of-packet signal (optional, can be used to force sending packet)
    data_eop_in     : in  std_logic;
    --!Signals we're done transmitting the packet and to move onto the next one.
    packet_finished : in  std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name Outputs
    --!\{
    ---------------------------------------------------------------------------
    --!Data for transmission
    data_out        : out std_logic_vector(31 downto 0)               := (others => '0');
    --!Data port for transmission
    data_port_out   : out std_logic_vector(15 downto 0)               := (others => '0');
    --!Length of our payload (needed for packet creation)
    payload_len     : out std_logic_vector(MAX_FRAME_BITS-1 downto 0) := (others => '0');
    --!Signal that a complete packet is ready for tranmission
    payload_rdy     : out std_logic                                   := '0'
    );
  --!\}
end entity udp_data_buffer;


architecture vhdl_rtl of udp_data_buffer is
  
  component fifo_32x2048 is
    port (
      aclr    : in  std_logic := '0';
      data    : in  std_logic_vector (31 downto 0);
      rdclk   : in  std_logic;
      rdreq   : in  std_logic;
      wrclk   : in  std_logic;
      wrreq   : in  std_logic;
      q       : out std_logic_vector (31 downto 0);
      rdempty : out std_logic;
      rdusedw : out std_logic_vector (10 downto 0);
      wrfull  : out std_logic);
  end component fifo_32x2048;

  component scfifo_sa_32x16 is
    port (
      aclr  : in  std_logic;
      clock : in  std_logic;
      data  : in  std_logic_vector (31 downto 0);
      rdreq : in  std_logic;
      wrreq : in  std_logic;
      empty : out std_logic;
      q     : out std_logic_vector (31 downto 0));
  end component scfifo_sa_32x16;

  constant MAX_PACKET_LENGTH                : natural                       := 350;
  -----------------------------------------------------------------------------
  -- Data FIFO signals
  -----------------------------------------------------------------------------
  signal rdempty                            : std_logic;
  signal rdusedw                            : std_logic_vector (10 downto 0);
  signal wrfull                             : std_logic;
  -----------------------------------------------------------------------------
  -- Info FIFO signals
  -----------------------------------------------------------------------------
  signal info_in                            : std_logic_vector(31 downto 0) := (others => '0');
  signal info_out                           : std_logic_vector(31 downto 0);
  signal info_rdreq, info_wrreq, info_empty : std_logic;
  -----------------------------------------------------------------------------
  -- Info writing process signals
  -----------------------------------------------------------------------------
  signal packet_length_in                   : natural                       := 0;
  signal info_valid                         : std_logic                     := '0';
  signal previous_udp_port                  : std_logic_vector(15 downto 0);
  signal last_udp_port                      : std_logic_vector(15 downto 0);
  signal last_packet_length                 : natural                       := 0;

begin

  --Packet is ready if INFO fifo is not empty
  payload_rdy   <= not info_empty;
  payload_len   <= info_out(payload_len'length-1+16 downto 16);
  data_port_out <= info_out(15 downto 0);
  --Signal to read info about next packet
  info_rdreq    <= packet_finished;

  --!Register input to info FIFO
  process (wrclock)
  begin
    if rising_edge(wrclock) then
      info_in    <= std_logic_vector(to_unsigned(last_packet_length, 16)) & last_udp_port;
      info_wrreq <= info_valid;
    end if;
  end process;

  --!Process that handles creating and writing information about our UDP data
  --!packets. Since we may have data coming in from multiple different sources,
  --!once a complete frame is ready (either because we have hit our maximum
  --!packet size, no data has been written for a while, or we want to send data
  --!to a new destination port), we write both the port number and number of
  --!words in the packet into our frame information buffer. This information can
  --!then be used to read the packet from the data FIFO buffer so that data is
  --!sent to the correct UDP destination.
  process (wrclock, reset)
    variable timeout_counter : natural := 0;
  begin
    if reset = '1' then
      packet_length_in   <= 0;
      timeout_counter    := 0;
      last_udp_port      <= (others => '0');
      last_packet_length <= 0;
      previous_udp_port  <= (others => '0');
    elsif rising_edge(wrclock) then
      info_valid <= '0';

      if data_valid_in = '1' then
        --Reset our counter if we have fresh data coming in.
        timeout_counter := 0;
        --If we exceed our maximum length, change UDP port, or an end-of-packet
        --is triggered, write our frame information.
        if (packet_length_in >= MAX_PACKET_LENGTH) or (previous_udp_port /= data_port_in) or (data_eop_in = '1') then
          --Marks the end of this packet
          if (packet_length_in >= 1) then
            --Special case, include the current word being written if EoP
            --strobe goes high
            if (data_eop_in = '1') then
              last_packet_length <= packet_length_in+1;
            else
              last_packet_length <= packet_length_in;
            end if;
            last_udp_port <= previous_udp_port;
            info_valid    <= '1';
          end if;
          --Reset things
          if (data_eop_in = '1') then
            --Standard is that eop includes the word EoP goes high on, so don't
            --include it in our next packet
            packet_length_in <= 0;
          else
            --Otherwise we have to include this word
            packet_length_in <= 1;
          end if;
          previous_udp_port <= data_port_in;
        else
          packet_length_in <= packet_length_in + 1;
        end if;
      --Counter so our data doesn't go stale
      elsif packet_length_in >= 1 and timeout_counter <= IN_FIFO_STALE_THRESHOLD then
        timeout_counter := timeout_counter + 1;
      --Trigger for stale data
      elsif (packet_length_in >= 1 and timeout_counter > IN_FIFO_STALE_THRESHOLD) then
        last_packet_length <= packet_length_in;
        last_udp_port      <= previous_udp_port;
        info_valid         <= '1';
        packet_length_in   <= 0;
        timeout_counter    := 0;
      else
        timeout_counter := 0;
      end if;
    end if;
  end process;

  --!Buffer to hold data for transmission
  fifo_32x2048_1 : entity work.fifo_32x2048
    port map (
      aclr    => reset,
      data    => data_in,
      rdclk   => rdclock,
      rdreq   => data_rdreq,
      wrclk   => wrclock,
      wrreq   => data_valid_in,
      q       => data_out,
      rdempty => rdempty,
      rdusedw => rdusedw,
      wrfull  => wrfull);

  --!Buffer holding information about each packet. Contains the UDP port and
  --!length of each packet. 
  scfifo_sa_32x16_1 : entity work.scfifo_sa_32x16
    port map (
      aclr  => reset,
      clock => wrclock,
      data  => info_in,
      rdreq => info_rdreq,
      wrreq => info_wrreq,
      empty => info_empty,
      q     => info_out);


end architecture vhdl_rtl;
