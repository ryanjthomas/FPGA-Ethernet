-------------------------------------------------------------------------------
-- Title      : Ethernet Frame Reciever
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_frame_reciever.vhd
-- Author     : Ryan Thomas
-- Company    : University of Chicago
-- Created    : 2019-08-30
-- Last update: 2021-03-09
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Frame reciever for ethernet IPv4 frames. Currently strips off
-- IPv4/UDP header and forwards the application data.
-------------------------------------------------------------------------------
--!\file ethernet_frame_reciever.vhd

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.eth_common.all;

--!\brief Recieves and decodes Ethernet frames from the TSE MAC.
--!Capable of interpreting ARP, ICMP ping, and UDP packets. Strips off header
--!and forwards payload.

entity ethernet_frame_reciever is
  port (
    --!Clock synchronous to rx_data signal
    rd_clk             : in  std_logic;
    reset              : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Interface to MAC function
    --!\{
    ---------------------------------------------------------------------------
    rx_data            : in  std_logic_vector(31 downto 0);
    rx_eop             : in  std_logic;
    rx_err             : in  std_logic_vector(5 downto 0);
    rx_mod             : in  std_logic_vector(1 downto 0);
    rx_rdy             : out std_logic;
    rx_sop             : in  std_logic;
    rx_dval            : in  std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name Output from decoded frame
    --!\{
    ---------------------------------------------------------------------------
    --!Paylaod data
    data_out           : out std_logic_vector(31 downto 0) := (others => '0');
    --!Payload data valid
    dval               : out std_logic                     := '0';
    --!Payload end-of-packet (high when last word of packet on data_out)
    eop                : out std_logic                     := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name Frame information
    --!\{
    ---------------------------------------------------------------------------
    source_mac_addr    : out std_logic_vector(47 downto 0) := (others => '0');
    dest_mac_addr      : out std_logic_vector(47 downto 0) := (others => '0');
    source_ip_addr     : out std_logic_vector(31 downto 0) := (others => '0');
    dest_ip_addr       : out std_logic_vector(31 downto 0) := (others => '0');
    source_port        : out std_logic_vector(15 downto 0) := (others => '0');
    dest_port          : out std_logic_vector(15 downto 0) := (others => '0');
    ethertype          : out std_logic_vector(15 downto 0) := (others => '0');
    packet_length      : out std_logic_vector(15 downto 0) := (others => '0');
    --!\}
    ---------------------------------------------------------------------------
    --!Interface IP address (used to determine if we should reply to ICMP/ARP)
    our_ip_addr        : in  std_logic_vector(31 downto 0) := (others => '0');
    --!Signals to generate ARP reply
    generate_arp_reply : out std_logic                     := '0';
    arp_reply_recieved : out std_logic                     := '0';
    --!IPv4 protocol of packet
    ip_protocol        : out std_logic_vector(7 downto 0)  := (others => '0');
    --!Signals the data on the line is an ICMP ping request
    icmp_ping          : out std_logic                     := '0'
    );
  --!\}

end entity ethernet_frame_reciever;

architecture rtl of ethernet_frame_reciever is

  subtype octet is std_logic_vector(7 downto 0);
  subtype word is std_logic_vector(31 downto 0);

  signal frame_word  : word      := (others => '0');
  signal word_num    : natural   := 0;
  signal data_valid  : std_logic := '0';
  signal rdy_sig     : std_logic := '0';
  signal payload_len : integer := 0;

  --Used for ARP optype
  signal optype           : std_logic_vector(15 downto 0) := (others => '0');
  --For ICMP type of message
  signal icmptype         : std_logic_vector(15 downto 0) := (others => '0');
  signal ethertype_sig    : std_logic_vector(15 downto 0) := (others => '0');
  signal dest_ip_addr_sig : std_logic_vector(31 downto 0) := (others => '0');
  signal IPv4_protocol    : std_logic_vector(7 downto 0)  := (others => '0');

begin

  rx_rdy       <= rdy_sig;
  data_out     <= frame_word;
  ethertype    <= ethertype_sig;
  dest_ip_addr <= dest_ip_addr_sig;
  ip_protocol  <= IPv4_protocol;

  -- Delay the eop output one cycle
  eop_delay : process (rd_clk)
  begin
    if (rising_edge(rd_clk)) then
      eop <= rx_eop;
    end if;
  end process;
  dval <= data_valid;

  frame_reader : process (reset, rd_clk)
    --For use in the process;
    variable word_num_var : natural := 0;
  begin
    clock : if (reset = '1') then
      frame_word         <= (others => '0');
      word_num           <= 0;
      word_num_var       := 0;
      payload_len        <= 0;
      data_valid         <= '0';
      rdy_sig            <= '0';
      source_mac_addr    <= (others => '0');
      dest_mac_addr      <= (others => '0');
      source_ip_addr     <= (others => '0');
      dest_ip_addr_sig   <= (others => '0');
      source_port        <= (others => '0');
      dest_port          <= (others => '0');
      ethertype_sig      <= (others => '0');
      generate_arp_reply <= '0';
      icmp_ping          <= '0';
      arp_reply_recieved <= '0';


    elsif (rising_edge(rd_clk)) then
      rdy_sig <= '1';
      dval_conditional : if (rx_dval = '1') then
        frame_word <= rx_data;
        -----------------------------------------------------------------------
        -- Ethernet Header
        -----------------------------------------------------------------------
        word_parser : if (word_num = 0) then
          dest_mac_addr(47 downto 32) <= rx_data(15 downto 0);
          data_valid                  <= '0';
          --Reset everything from last time
          optype                      <= (others => '0');
          icmptype                    <= (others => '0');
          generate_arp_reply          <= '0';
          arp_reply_recieved <= '0';          
          icmp_ping                   <= '0';
          payload_len                 <= 0;
          source_mac_addr             <= (others => '0');
          source_ip_addr              <= (others => '0');
          dest_ip_addr_sig            <= (others => '0');
          source_port                 <= (others => '0');
          dest_port                   <= (others => '0');
          ethertype_sig               <= (others => '0');
        elsif (word_num = 1) then
          dest_mac_addr(31 downto 0) <= rx_data(31 downto 0);
        elsif (word_num = 2) then
          source_mac_addr(47 downto 16) <= rx_data(31 downto 0);
        elsif (word_num = 3) then
          source_mac_addr(15 downto 0) <= rx_data(31 downto 16);
          ethertype_sig                <= rx_data(15 downto 0);
        ---------------------------------------------------------------------
        -- IPv4/UDP Header Parser
        ---------------------------------------------------------------------
        elsif (word_num >= 4 and ethertype_sig = ETH_IPv4) then
          if (word_num = 4) then
            --31 downto 16 is ip version + header length + DCSP/ECN codes                                        
            packet_length <= rx_data(15 downto 0);
          --words 5 don't care
          elsif (word_num = 6) then
            IPv4_protocol <= rx_data(23 downto 16);
          elsif (word_num = 7) then
            source_ip_addr <= rx_data(31 downto 0);
          elsif (word_num = 8) then
            dest_ip_addr_sig <= rx_data(31 downto 0);
          ---------------------------------------------------------------------
          -- UDP Parser
          ---------------------------------------------------------------------
          elsif (word_num >= 9 and IPv4_protocol = PROTO_UDP) then
            if (word_num = 9) then
              source_port <= rx_data(31 downto 16);
              dest_port   <= rx_data(15 downto 0);
            --Word 10 is length & checksum
            elsif (word_num = 10) then
              payload_len <= to_integer(unsigned(rx_data(31 downto 16)))/4-2;
            elsif (word_num >= 11 and word_num <= payload_len+10) then
            --elsif (word_num >= 11) then
              data_valid <= '1';
            else
              data_valid <= '0';
            end if;
          ---------------------------------------------------------------------
          -- ICMP Parser
          ---------------------------------------------------------------------
          elsif (word_num >= 9 and IPv4_protocol = PROTO_ICMP) then
            if (word_num = 9) then
              icmptype <= rx_data (31 downto 16);
            elsif (word_num >= 10 and dest_ip_addr_sig = our_ip_addr and
                   icmptype = ICMP_ECHO_REQUEST) then
              icmp_ping  <= '1';
              data_valid <= '1';
            end if;
          end if;
        -----------------------------------------------------------------------
        -- ARP Parser
        -----------------------------------------------------------------------
        elsif (word_num >= 4 and ethertype_sig = ETH_ARP) then
          if (word_num = 5) then
            optype <= rx_data (15 downto 0);
          elsif (word_num = 6) then
            source_mac_addr(47 downto 16) <= rx_data;
          elsif (word_num = 7) then
            source_mac_addr(15 downto 0) <= rx_data(31 downto 16);
            source_ip_addr(31 downto 16) <= rx_data(15 downto 0);
          elsif (word_num = 8) then
            source_ip_addr(15 downto 0) <= rx_data(31 downto 16);
          --Rest of 8+9 is dest_mac_addr, already have that
          elsif (word_num = 10) then
            dest_ip_addr_sig <= rx_data;
          end if;
        end if word_parser;

        word_num_counter : if (rx_sop = '1') then
          --Start with 1 because it doesn't appear on word_num till next clock
          word_num_var := 1;
        elsif (rx_eop = '1') then
          word_num_var := 0;
          --Here trigger our ARP requester
          --TODO: move to ARP parser maybe?
          if (optype = ARP_REQUEST and dest_ip_addr_sig = our_ip_addr) then
            generate_arp_reply <= '1';
          end if;
          if (optype = ARP_REPLY and dest_ip_addr_sig = our_ip_addr) then
            arp_reply_recieved <= '1';
          end if;
        else
          word_num_var       := word_num_var + 1;
          generate_arp_reply <= '0';
          arp_reply_recieved <= '0';
        end if word_num_counter;

        word_num <= word_num_var;
      else                              --dval==0
        arp_reply_recieved <= '0';        
        generate_arp_reply <= '0';
        data_valid         <= '0';
        icmp_ping          <= '0';
        frame_word         <= (others => '0');
      end if dval_conditional;
    end if clock;

  end process frame_reader;

end architecture rtl;




