-------------------------------------------------------------------------------
-- Title      : Ethernet Frame Generator
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_frame_generator.vhd
-- Author     : Ryan Thomas 
-- Company    : University of Chicago
-- Created    : 2018-10-01
-- Last update: 2020-07-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generates an ethernet frame by reading from an input FIFO into
-- an output FIFO.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-10-01  1.0      ryan  Created
-- 2019-08-20  2.0      ryan  Tested in testbench
-- 2019-08-20  2.0      ryan  Tested in ethernet block w/ IFM
-------------------------------------------------------------------------------
--!\file ethernet_frame_generator.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief Generates Ethernet frames from incoming data.
--!
--! 

entity ethernet_frame_generator is
  generic (
    --! Size of FIFO from input buffers
    IN_FIFO_BITS   : in natural := 11;
    --! Maximum size in words of generated frames
    MAX_FRAME_BITS : in natural := 9);
  port (
    --!The clock
    clock           : in  std_logic;
    --!Asynchronous reset
    reset           : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Header Generator interface
    --!\{
    ---------------------------------------------------------------------------
    header_data     : in  std_logic_vector(31 downto 0);
    header_valid    : in  std_logic;
    header_done     : in  std_logic;
    header_start    : out std_logic;
    payload_len     : out std_logic_vector(MAX_FRAME_BITS-1 downto 0);
    --!\}
    ---------------------------------------------------------------------------
    --!\name Interface to input FIFO buffer
    --!\{
    ---------------------------------------------------------------------------
    --!Data from input FIFO buffer
    data_in         : in  std_logic_vector (31 downto 0);
    --!Number of words in input FIFO
    usedw_in        : in  std_logic_vector (IN_FIFO_BITS-1 downto 0);
    --!Signals that payload is ready to start reading
    payload_rdy     : in  std_logic;
    --!Read request
    rdreq_in        : out std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name Outputs
    --!\{
    ---------------------------------------------------------------------------
    --!Interface to output FIFO
    data_out        : out std_logic_vector (31 downto 0) := (others => '0');
    --!Write data to output FIFO (indicates data_out is valid)
    wrreq_out       : out std_logic;
    --!High when start of packet is on data_out
    sop             : out std_logic;
    --!High when end-of-packet is on data_out
    eop             : out std_logic;
    --!Total length of output frame
    frame_length    : out std_logic_vector (MAX_FRAME_BITS-1 downto 0);
    --This isn't really necessary anymore
    frame_rdy       : out std_logic;
    --!Frame generator busy
    fg_busy         : out std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name Configuration Parameters
    --!\{
    ---------------------------------------------------------------------------
    --!Maximum length of payload (in words). Any payloads longer than this will
    --!be split into multiple frames.
    payload_max_len : in  std_logic_vector(MAX_FRAME_BITS-1 downto 0);
    --# of clock cycles between rdreq going high and data_in being valid
    FIFO_in_dly     : in  std_logic_vector (3 downto 0)  := "0101";
    FIFO_out_dly    : in  std_logic_vector (3 downto 0)  := "0101";
    --WARNING: this doesn't work (incorrectly computes CRC on leading padding)
    gen_crc         : in  std_logic
    );
  --!\}
end entity ethernet_frame_generator;

architecture RTL of ethernet_frame_generator is
  subtype octet is std_logic_vector (7 downto 0);

  type state_type is (IDLE, PAYLOAD_HEADER,
                      PAYLOAD_WAIT, PAYLOAD_START,
                      WRITE_PAYLOAD, WRITE_CRC, DONE);
  signal state      : state_type := IDLE;
  signal next_state : state_type := IDLE;

  signal in_fifo_delay  : unsigned (3 downto 0) := (others => '0');
  signal out_fifo_delay : unsigned (3 downto 0) := (others => '0');

  signal frame_word     : std_logic_vector (31 downto 0);
  --Internal signals
  signal rdreq_sig      : std_logic := '0';
  signal wrreq_sig      : std_logic := '0';
  signal payload_word   : std_logic_vector (31 downto 0);
  signal eop_sig        : std_logic := '0';
  signal sop_sig        : std_logic := '0';
  signal payload_length : natural;

  --Note: these were for testing creating our own CRC. They are currently
  --unused and don't do anything.
  signal crc_clear : std_logic;
  signal crc_din   : std_logic_vector(31 downto 0);
  signal crc_out   : std_logic_vector(31 downto 0);
  signal crc_en    : std_logic;

begin

  data_out <= frame_word;
  crc_din  <= frame_word;
  crc_out <= (others => '0');
  
  in_fifo_delay  <= unsigned(FIFO_in_dly);
  out_fifo_delay <= unsigned(FIFO_out_dly);
  rdreq_in       <= rdreq_sig;
  wrreq_out      <= wrreq_sig;
  sop            <= sop_sig;
  eop            <= eop_sig;
  payload_len    <= std_logic_vector(to_unsigned(payload_length, payload_len'length));

  --!State machine that generates an ethernet frame. Uses header generator for
  --!ethernet/UDP/IPv4 headers
  state_machine : process(reset, clock)
    variable delay_counter : integer := 0;
    --Size of our frame in 32-bit words
    variable frame_size    : natural := 0;
    variable words_read    : natural := 0;
  begin
    if (reset = '1') then
      state          <= IDLE;
      next_state     <= IDLE;
      delay_counter  := 0;
      frame_size     := 0;
      frame_length   <= (others => '1');
      wrreq_sig      <= '0';
      rdreq_sig      <= '0';
      frame_word     <= (others => '0');
      sop_sig        <= '0';
      eop_sig        <= '0';
      payload_length <= 0;
      words_read     := 0;

      crc_clear <= '1';
      crc_en    <= '0';
    elsif rising_edge(clock) then
      case next_state is
        when IDLE =>
          frame_rdy     <= '0';
          frame_size    := 0;
          frame_length  <= (others => '1');
          wrreq_sig     <= '0';
          rdreq_sig     <= '0';
          sop_sig       <= '0';
          eop_sig       <= '0';
          header_start  <= '0';
          delay_counter := 0;
          frame_size    := 0;
          words_read    := 0;
          crc_clear     <= '1';
          crc_en        <= '0';

          if (payload_rdy = '1') then
            next_state   <= PAYLOAD_HEADER;
            header_start <= '1';
            fg_busy      <= '1';

            --Here grab the length of the payload
            if (unsigned(usedw_in) >= unsigned(payload_max_len)) then
              payload_length <= to_integer(unsigned(payload_max_len));
            else
              payload_length <= to_integer(unsigned(usedw_in));
            end if;
          else
            next_state <= IDLE;
            fg_busy    <= '0';
          end if;

        when PAYLOAD_HEADER =>
          --TODO: maybe add timeout in case we miss header_done or the header
          --generator fails for some reason
          crc_clear    <= '0';
          crc_en       <= '1';
          header_start <= '0';
          --We can set this to be the header data even if it's not valid, as
          --wrreq is disabled
          frame_word   <= header_data;

          if (header_valid = '1') then
            --Write our header word and increment frame size by 1
            wrreq_sig <= '1';
            -- Strobe our start-of-packet on first word
            if (frame_size = 0) then
              sop_sig <= '1';
            else
              sop_sig <= '0';
            end if;
            frame_size := frame_size + 1;
          else
            --Don't write invalid data
            wrreq_sig <= '0';
          end if;

          --When the header is done, go to the payload writing
          if (header_done = '1') then
            --Handles bugs when payload_length is 0 (should never get here, but
            --we have in the past)
            if (payload_length=0) then
              next_state <= DONE;
              eop_sig <= '1';
            else
              next_state <= PAYLOAD_WAIT;
            end if;
          else
            next_state <= PAYLOAD_HEADER;
          end if;

        when PAYLOAD_WAIT =>
          --Start reading data from the FIFO
          --Delay counter here is # words read up to this clock cycle
          --This is done if the payload length < our input delay
          if (delay_counter >= payload_length) then
            rdreq_sig <= '0';
          else
            rdreq_sig <= '1';
          end if;          
          --Handle edge cases where header is only 1 word long
          sop_sig <= '0';
          if (delay_counter = 0) then
            frame_size := frame_size+payload_length;
          end if;
          delay_counter := delay_counter+1;
          if (delay_counter >= to_integer(in_fifo_delay)) then
            next_state <= PAYLOAD_START;
          end if;

          --Pause writing data to the output
          wrreq_sig  <= '0';
          words_read := 0;

        when PAYLOAD_START =>
          --Start writing our payload words
          wrreq_sig  <= '1';
          if (payload_length <= to_integer(in_fifo_delay)) then
            rdreq_sig <= '0';
          else
            rdreq_sig  <= '1';
          end if;
          frame_word <= payload_word;
          frame_length <= std_logic_vector(to_unsigned(frame_size, MAX_FRAME_BITS));          
          
          next_state   <= WRITE_PAYLOAD;
--          words_read := words_read + 1;
          --Special case, otherwise we never send EOP to our MAC
          if (payload_length=1) then
            eop_sig <= '1';
          end if;          

        when WRITE_PAYLOAD =>
          words_read := words_read+1;
          --End our payload writing
          if (words_read >= payload_length) then
            delay_counter := 0;
            --If we output the CRC, do it now
            if (gen_crc = '1') then
              next_state <= WRITE_CRC;
              eop_sig    <= '1';
              wrreq_sig  <= '1';
              frame_word <= crc_out;
            else
              --Otherwise let's finish up
              next_state <= DONE;
              wrreq_sig  <= '0';
              eop_sig    <= '0';
              frame_word <= (others => '0');
            end if;
          else
            frame_word <= payload_word;
            wrreq_sig  <= '1';
            next_state <= WRITE_PAYLOAD;
          end if;

          --EoP goes high when last word is on the data_out          
          if (words_read = payload_length-1 and gen_crc = '0') then
            eop_sig <= '1';
          end if;

          --The FIFO has some delay, so stop a few cycles early
          if (words_read >= (payload_length-to_integer(in_fifo_delay))) then
            rdreq_sig <= '0';
          else
            rdreq_sig <= '1';
          end if;

        when WRITE_CRC =>
          next_state <= DONE;
          eop_sig    <= '0';
          wrreq_sig  <= '0';
          frame_word <= (others => '0');

        when DONE =>
          if (delay_counter >= to_integer(out_fifo_delay)) then
            next_state    <= IDLE;
            frame_rdy     <= '1';
--            eop_sig       <= '1';
            delay_counter := 0;
          else
            delay_counter := delay_counter + 1;
          end if;
          eop_sig    <= '0';
          rdreq_sig  <= '0';
          wrreq_sig  <= '0';
          words_read := 0;

        --Fallthrough state
        when others =>
          next_state <= IDLE;

      end case;
      state <= next_state;
    end if;

  end process state_machine;

  --!Register output
  payload_word_register : process(clock, reset)
  begin
    if (reset = '1') then
      payload_word <= (others => '0');
    elsif (rising_edge(clock)) then
      payload_word <= data_in;
    end if;
  end process payload_word_register;


end architecture RTL;
