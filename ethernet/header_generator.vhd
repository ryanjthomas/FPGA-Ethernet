-------------------------------------------------------------------------------
-- Title      : Ethernet Header Generator
-- Project    : 
-------------------------------------------------------------------------------
-- File       : header_generator.vhd
-- Author     : Ryan Thomas 
-- Company    : University of Chicago
-- Created    : 2019-08-15
-- Last update: 2020-07-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generates ethernet, IPv4, and UDP headers for transmission over
-- ethernet line. Configuration line bits [0..3] enable generation of Ethernet,
-- IPv4, UDP, and application headers (respectively)
-------------------------------------------------------------------------------
--!\file header_generator.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--!\brief Generates Ethernet and IPv4/UDP frame headers.
--!
--!Generates both Ethernet frame headers containing MAC destination and source
--!addresses, and IPv4/UDP headers for UDP packets. Can also insert an
--!application header after the UDP packet header.

entity header_generator is
  generic (
    --!Bits required to represent the max words in a frame 
    MAX_FRAME_BITS : natural := 9
    );
  port (
    --The clock
    clock           : in  std_logic;
    --!Asynchrouns active high reset
    reset           : in  std_logic;
    --!Output header data
    header_data     : out std_logic_vector(31 downto 0);
    --!High when header_data is valid
    header_valid    : out std_logic;
    --!Probably doesn't need to be this long
    --!This is for the retransmission modifier, so we know where the app header
    --!is
    header_len      : out std_logic_vector(8 downto 0);
    --!Strobes hi when final header word is on the header_data bus
    header_done     : out std_logic;
    --!Input to start generating header
    header_start    : in  std_logic;
    --!IP datagram protocol type (see list here: https://en.wikipedia.org/wiki/List_of_IP_protocol_numbers)
    protocol        : in  std_logic_vector(7 downto 0);
    --!32-bit word to add to payload after rest of header
    app_header      : in  std_logic_vector(31 downto 0);
    --!Configuration for header mode. bit 0 enables Ethernet header, bit 1
    --!enables IP header, bit 2 enables UDP header, bit 3 enables application header
    config          : in  std_logic_vector(31 downto 0);
    --!Length of payload, in 32-bit words (for UDP header)
    payload_len     : in  std_logic_vector(MAX_FRAME_BITS-1 downto 0);
    --!Ethernet MAC address of ODILE board interface
    source_mac_addr : in  std_logic_vector(47 downto 0);
    --!Ethernet MAC address of server
    dest_mac_addr   : in  std_logic_vector(47 downto 0);
    --!Type of packet contained in Ethernet frame (see list here: https://en.wikipedia.org/wiki/EtherType)
    ether_type      : in  std_logic_vector(15 downto 0);
    --!IP address of ODILE board interface
    source_ip       : in  std_logic_vector(31 downto 0);
    --!IP address of destination server
    dest_ip         : in  std_logic_vector(31 downto 0);
    --!UDP source header
    source_port     : in  std_logic_vector(15 downto 0);
    --!UDP destination source
    dest_port       : in  std_logic_vector(15 downto 0)
    );
end header_generator;

architecture rtl of header_generator is

  subtype word is std_logic_vector(31 downto 0);
  type header is array(integer range <>) of word;
  type state_type is (IDLE, ETH0, ETH1, ETH2, ETH3,
                      IP0, IP1, IP_PAUSE0, IP_PAUSE1,  --Pause for checksum computation
                      IP2, IP3, IP4,
                      UDP0, UDP1,
                      HD0, DONE
                      );
  signal state      : state_type := IDLE;
  signal next_state : state_type := IDLE;

  signal app_header_sig      : std_logic_vector(31 downto 0) := X"00_00_00_00";
  -----------------------------------------------------------------------------
  -- Ethernet Header
  -----------------------------------------------------------------------------
  constant padding           : std_logic_vector(31 downto 0) := (others => '0');
  signal eth_header          : header(0 to 3)                := (others => (others => '0'));
  -----------------------------------------------------------------------------
  -- IPv4 Header
  -----------------------------------------------------------------------------
  signal ip_header           : header(0 to 4)                := (others => (others => '0'));
  --First header word
  --IPv4 version
  constant version           : std_logic_vector(3 downto 0)  := "0100";
  --Header is only 5 words long, as long as we don't have any options
  constant ip_header_len     : std_logic_vector(3 downto 0)  := "0101";
  constant diff_serv         : std_logic_vector(7 downto 0)  := (others => '0');
  signal packet_len          : std_logic_vector(15 downto 0) := (others => '0');
  signal ether_type_sig      : std_logic_vector(15 downto 0) := X"0800";
  --Second header word
  --This field may be useable for our retransmission controller, not sure yet...
  constant id_field            : std_logic_vector(15 downto 0) := (others => '0');
  constant frag_field          : std_logic_vector(15 downto 0) := (others => '0');
  --Third header word
  constant ip_ttl              : std_logic_vector(7 downto 0)  := (others => '1');
  signal protocol_sig        : std_logic_vector(7 downto 0)  := (others => '0');
  signal ip_checksum         : std_logic_vector(15 downto 0) := (others => '0');
  -----------------------------------------------------------------------------
  -- Internal Signals
  -----------------------------------------------------------------------------
  signal header_len_sig      : std_logic_vector(header_len'length-1 downto 0);
  signal payload_octets      : std_logic_vector(15 downto 0);
  signal source_mac_addr_sig : std_logic_vector(47 downto 0);
  signal dest_mac_addr_sig   : std_logic_vector(47 downto 0);
  
  --!Function to compute next state whenever we finish a header segment (since
  --!we have several different header generating sequences)
  function f_next_state(
    curr_state : state_type;
    config     : std_logic_vector(31 downto 0))
    return state_type is
  begin
    if (curr_state = IDLE) then
      if (config(0) = '1') then
        return ETH0;
      elsif (config(1) = '1') then
        return IP0;
      elsif (config(2) = '1') then
        return UDP0;
      elsif (config(3) = '1') then
        return HD0;
      else
        return DONE;
      end if;
    elsif (curr_state = ETH3) then
      if (config(1) = '1') then
        return IP0;
      elsif (config(2) = '1') then
        return UDP0;
      elsif (config(3) = '1') then
        return HD0;
      else
        return DONE;
      end if;
    elsif (curr_state = IP4) then
      if (config(2) = '1') then
        return UDP0;
      elsif (config(3) = '1') then
        return HD0;
      else
        return DONE;
      end if;
    elsif (curr_state = UDP1) then
      if (config(3) = '1') then
        return HD0;
      else
        return DONE;
      end if;
    end if;
  end function f_next_state;


begin
  app_header_sig      <= app_header;
  ether_type_sig      <= ether_type;
  protocol_sig        <= protocol;
  --Note: this is in words
  header_len_sig      <= std_logic_vector(to_unsigned(7, header_len'length)) when (config(1)='1' and config(2)='1') else
                         std_logic_vector(to_unsigned(5, header_len'length)) when (config(1)='1' and config(2)='0') else
                         std_logic_vector(to_unsigned(2, header_len'length)) when (config(1)='0' and config(2)='1') else
                         std_logic_vector(to_unsigned(0, header_len'length)) when (config(1)='0' and config(2)='0') else
                         (others => '0');
                         
  header_len          <= header_len_sig;
  --Note: this is in *bytes*
  packet_len          <= std_logic_vector(resize(unsigned(header_len_sig)+unsigned(payload_len), packet_len'length-2)) & "00";
  source_mac_addr_sig <= source_mac_addr;
  dest_mac_addr_sig   <= dest_mac_addr;

  --!Responsible for generating the header.
  state_machine : process(reset, clock)
    variable nstate : state_type := IDLE;
  begin
    if (reset = '1') then
      state        <= IDLE;
      next_state   <= IDLE;
      header_data  <= (others => '0');
      header_valid <= '0';
      header_done  <= '0';
    elsif rising_edge(clock) then
      case next_state is
        when IDLE =>
          header_data   <= (others => '0');
          header_valid  <= '0';
          header_done   <= '0';
          --Register our data before we start header generating to guarantee
          --checksum validity
          ip_header(0)  <= version & ip_header_len & diff_serv & packet_len;
          ip_header(1)  <= id_field & frag_field;
          --Last 2 bytes 0 for checksum computing later
          ip_header(2)  <= ip_ttl & protocol_sig & X"00_00";
          ip_header(3)  <= source_ip;
          ip_header(4)  <= dest_ip;
          eth_header(0) <= padding(31 downto 16) & dest_mac_addr_sig (47 downto 32);
          eth_header(1) <= dest_mac_addr_sig (31 downto 0);
          eth_header(2) <= source_mac_addr (47 downto 16);
          eth_header(3) <= source_mac_addr (15 downto 0) & ether_type_sig;

          if (header_start = '1') then
            nstate := f_next_state(next_state, config);
            next_state <= nstate;
          else
            next_state <= IDLE;
          end if;
        -----------------------------------------------------------------------
        -- Ethernet frame header
        -----------------------------------------------------------------------
        when ETH0 =>
          header_data  <= eth_header(0);
          header_valid <= '1';
          next_state   <= ETH1;

        when ETH1 =>
          header_data  <= eth_header(1);
          header_valid <= '1';
          next_state   <= ETH2;

        when ETH2 =>
          header_data  <= eth_header(2);
          header_valid <= '1';
          next_state   <= ETH3;

        when ETH3 =>
          header_data  <= eth_header(3);
          header_valid <= '1';
          nstate := f_next_state(next_state, config);
          next_state   <= nstate;
          if (nstate = DONE) then
            header_done <= '1';
          end if;

        -----------------------------------------------------------------------
        -- IPv4 header
        -----------------------------------------------------------------------
        when IP0 =>
          header_data  <= ip_header(0);
          header_valid <= '1';
          next_state   <= IP1;

        when IP1 =>
          header_data  <= ip_header(1);
          header_valid <= '1';
          next_state   <= IP_PAUSE0;

        when IP_PAUSE0 =>
          header_data <= (others => '1');
          header_valid <= '0';
          next_state <= IP_PAUSE1;

        --Wait one clock cycle for checksum generation to finish
        when IP_PAUSE1 =>
          header_data <= (others => '1');
          header_valid <= '0';
          next_state <= IP2;          

        when IP2 =>
          header_data  <= ip_ttl & protocol_sig & ip_checksum;
          header_valid <= '1';
          next_state   <= IP3;

        when IP3 =>
          header_data  <= ip_header(3);
          header_valid <= '1';
          next_state   <= IP4;

        when IP4 =>
          header_data  <= ip_header(4);
          header_valid <= '1';
          nstate := f_next_state(next_state, config);
          next_state   <= nstate;
          if (nstate = DONE) then
            header_done <= '1';
          end if;

        -----------------------------------------------------------------------
        -- UDP header
        -----------------------------------------------------------------------
        when UDP0 =>
          header_data  <= source_port & dest_port;
          header_valid <= '1';
          next_state   <= UDP1;

        when UDP1 =>
          --Length in bytes followed by (unused) checksum
          header_data  <= std_logic_vector(resize(unsigned(payload_len)+to_unsigned(2, payload_len'length), 14))& "00" & X"00_00";
          header_valid <= '1';
          nstate := f_next_state(next_state, config);
          next_state   <= nstate;
          if (nstate = DONE) then
            header_done <= '1';
          end if;

        -----------------------------------------------------------------------
        -- Payload header (usually unused)
        -----------------------------------------------------------------------
        when HD0 =>
          header_data  <= app_header;
          header_valid <= '1';
          header_done  <= '1';
          next_state   <= DONE;

        when DONE =>
          header_data  <= (others => '0');
          header_valid <= '0';
          header_done  <= '0';
          next_state   <= IDLE;

      end case;
      state <= next_state;
    end if;

  end process state_machine;

  --!Constantly generates the 16-bit checksum for the IPv4 header (since it's
  --!required by IPv4)
  checksum_computer : process (reset, clock)
    --Checksum computer for ipv4 header
    --Only really need 19 bits for a 5 word header, extra is just cause
    variable sum   : unsigned(22 downto 0) := (others => '0');
    variable carry : unsigned(6 downto 0)  := (others => '0');
    variable step  : integer               := -1;
  begin
    if (reset = '1') then
      sum         := (others => '0');
      step        := -1;
      ip_checksum <= (others => '0');
    elsif rising_edge(clock) then
      if (step = -1) then
        --Reset our sum
        sum  := (others => '0');
        --Start generating our checksum when we start our header
        if (header_start='1') then
          step := 0;
        else
          step := -1;
        end if;
      elsif (step <= ip_header'length-1) then
        --Add everything to our sum
        sum  := sum + unsigned(ip_header(step)(31 downto 16))+unsigned(ip_header(step)(15 downto 0));
        step := step +1;
      elsif (step <= ip_header'length+1) then
        --Now add our carry
        carry := sum(22 downto 16);
        sum   := resize(sum(15 downto 0) + sum(22 downto 16), 23);
        step  := step +1;
      elsif (step = ip_header'length +2) then
        ip_checksum <= not(std_logic_vector(sum(15 downto 0)));
        step        := -1;
      end if;
    end if;
  end process checksum_computer;


end architecture rtl;




