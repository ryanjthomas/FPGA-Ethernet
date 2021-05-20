-------------------------------------------------------------------------------
-- Title      : ARP Reply generator
-- Project    : 
-------------------------------------------------------------------------------
-- File       : arp_replier.vhd
-- Author     : Ryan Thomas
-- Company    : University of Chicago
-- Created    : 2019-09-09
-- Last update: 2021-03-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generates ARP reply packets for sending over Ethernet.
-------------------------------------------------------------------------------

--!\file arp_replier.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief ARP reply generator.

--!Generates an Address Resolution Protocol response for converting IP
--!addresses (used by high level IP protocol) into low-level MAC addresses
--!needed to address clients at the hardware level.

entity arp_replier is
  port (
    clock           : in  std_logic;
    --!Asynchronous high reset
    reset           : in  std_logic;
    --! 32-bit wide data output
    data_out        : out std_logic_vector(31 downto 0);
    --! Data valid signal
    dval            : out std_logic;
    source_mac_addr : in  std_logic_vector(47 downto 0);
    dest_mac_addr   : in  std_logic_vector(47 downto 0);
    source_ip_addr  : in  std_logic_vector(31 downto 0);
    dest_ip_addr    : in  std_logic_vector(31 downto 0);
    --! Active high signal to start a reply
    start_reply     : in  std_logic;
    --! Active high signal that reply is finished
    end_reply       : out std_logic;
    is_request      : in  std_logic
    );
end arp_replier;

architecture RTL of arp_replier is
  type state_type is (IDLE, ARP0, ARP1,
                      ARP2, ARP3, ARP4,
                      ARP5, ARP6, DONE);

  --signal state      : state_type                    := IDLE;
  signal next_state : state_type                    := IDLE;
  --!\name ARP reply constants
  --! These are constants determined by the ARP protocol for Ethernet/IPV4
  --!\{
  constant HTYPE    : std_logic_vector(15 downto 0) := X"00_01";
  constant PTYPE    : std_logic_vector(15 downto 0) := X"08_00";
  constant HLEN     : std_logic_vector(7 downto 0)  := X"06";
  constant PLEN     : std_logic_vector(7 downto 0)  := X"04";
  --Indicates ARP reply
  signal OPTYPE   : std_logic_vector(15 downto 0) := ARP_REPLY;
  --!\}

begin

  --!A basic state machine. Generates the correct format for an ARP payload
  --!response, containing the client and requester MAC/IP addresses.
  state_machine : process(reset, clock)
  begin
    if (reset = '1') then
      next_state <= IDLE;
      dval       <= '0';
    elsif rising_edge(clock) then
      if is_request = '1' then
        OPTYPE <= ARP_REQUEST;
      else
        OPTYPE <= ARP_REPLY;
      end if;
      case next_state is
        when IDLE =>
          dval      <= '0';
          data_out  <= (others => '0');
          end_reply <= '0';
          if (start_reply = '1') then
            next_state <= ARP0;
          else
            next_state <= IDLE;
          end if;

        when ARP0 =>
          next_state <= ARP1;
          dval       <= '1';
          data_out   <= HTYPE & PTYPE;

        when ARP1 =>
          next_state <= ARP2;
          dval       <= '1';
          data_out   <= HLEN & PLEN & OPTYPE;

        when ARP2 =>
          next_state <= ARP3;
          dval       <= '1';
          data_out   <= source_mac_addr (47 downto 16);

        when ARP3 =>
          next_state <= ARP4;
          dval       <= '1';
          data_out   <= source_mac_addr (15 downto 0) & source_ip_addr(31 downto 16);

        when ARP4 =>
          next_state <= ARP5;
          dval       <= '1';
          data_out   <= source_ip_addr (15 downto 0) & dest_mac_addr(47 downto 32);

        when ARP5 =>
          next_state <= ARP6;
          dval       <= '1';
          data_out   <= dest_mac_addr(31 downto 0);

        when ARP6 =>
          next_state <= DONE;
          dval       <= '1';
          data_out   <= dest_ip_addr (31 downto 0);
          end_reply  <= '1';

        when DONE =>
          next_state <= IDLE;
          dval       <= '0';
          data_out   <= (others => '0');

        when others =>
          next_state <= IDLE;
          dval       <= '0';

      end case;
    --state <= next_state;
    end if;
  end process state_machine;

end architecture RTL;
