-------------------------------------------------------------------------------
-- Title      : Ethernet Input Fifo Manager
-- Project    : 
-------------------------------------------------------------------------------
-- File       : input_fifo_manager.vhd
-- Author     : Ryan Thomas 
-- Company    : 
-- Created    : 2019-08-20
-- Last update: 2020-07-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: A multiplexer that contains several FIFOs which trigger
-- generation of ethernet frames when one of them exceeds a configurable
-- threshold. Will trigger packets from the fullest FIFOs first, unless one of
-- them has a priority flag set (in which case it will trigger if enabled and
-- above threshold, even if not the fullest)
-------------------------------------------------------------------------------
-- Copyright (c) 2019 Ryan Thomas 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-08-20  1.0      ryan  Created
-- 2019-08-23  2.0      ryan  Added enable/priority flags (validated)
-------------------------------------------------------------------------------
--!\file input_fifo_manager.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--Note: this library is not necessarily synthesizable, use only for compiletime
--stuff
use ieee.math_real.all;
use work.eth_common.all;

--!\brief Manages reading data from the FIFO buffers used to hold data from the
--!ADCs.
--!
--!Handles the data bufers that hold the data stream from the ADCs or CDS of
--!the CCD video stream. Will hold n_in_fifos data streams (note: the system
--!was designed to allow changing this, it was designed and tested with 5
--!buffers, using another number may work but has not been tested).
--!
--!Buffers will hold data until one of them contains more than payload_size
--!number of words, or if a buffer is not written to for more than a
--!configurable time. At that point, payload_rdy will go high to indicate that an
--!Ethernet frame payload is ready. The external frame generator is then free
--!to read the data by raising rdreq high.
--!
--!When rdreq goes high, the most full FIFO is read from until it is empty,
--!unless one of the buffers has it
--!priority flag (flags[1]) set high. In that case, that buffer will be read
--!from first if it has more than payload_size words in it.
--!
--!Any FIFO can be disabled by setting the flags[0] bit to zero. In that case,
--!it will not be read from or cause the payload_rdy signal to go high, but it
--!can still be written to. The manager will monitor the number of words in each
--!buffer and prevent writing to a buffer if it gets overfull to prevent
--!overfilling a FIFO.

entity input_fifo_manager is
  generic (
    --!Number of buffers to create. Only tested with 5, but should work with
    --!any number
    NFIFOS : natural := n_in_fifos
    );
  port (
    --!Clock
    clock        : in  std_logic;
    --!Asynchronous reset
    reset        : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Outputs
    --!\{
    ---------------------------------------------------------------------------
    data_out     : out word;
    usedw_out    : out in_fifo_usedw;
    payload_rdy  : out std_logic := '0';
    --!\}
    tx_busy      : in  std_logic;
    rdreq        : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Configuration Input
    --!\{
    ---------------------------------------------------------------------------
    payload_size : in  in_fifo_usedw_array(0 to NFIFOS-1);
    flags        : in  in_fifo_flag_array(0 to NFIFOS-1);
    --!\}
    ---------------------------------------------------------------------------
    --!\name Data inputs
    --!\{
    ---------------------------------------------------------------------------
    --!Write clock for FIFOs. wrreqs and data_in lines should be synchronous to
    --!each respective clock.
    wrclks       : in  std_logic_vector(0 to NFIFOS-1);
    --!Write requests for each FIFO.
    wrreqs       : in  std_logic_vector(0 to NFIFOS-1);
    --!Data inputs
    data_in      : in  data_array(0 to NFIFOS-1);
    --!\}
    ---------------------------------------------------------------------------
    --!\name Status lines
    --!\{
    ---------------------------------------------------------------------------
    --!Indicates a buffer is full and should not be written to
    wrfull       : out std_logic_vector(0 to NFIFOS-1);
    --!Read-side words currently contained in each FIFO
    rdusedw      : out in_fifo_usedw_array(0 to NFIFOS-1);
    --!Current FIFO that is or would be read from
    curr_fifo    : out std_logic_vector(0 to f_num_bits(NFIFOS)-1)
    );
  --\}

end entity input_fifo_manager;

architecture rtl of input_fifo_manager is

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
      rdusedw : out in_fifo_usedw;
      wrfull  : out std_logic);
  end component fifo_32x2048;

  signal data_out_sig     : word                               := (others => '0');  -- Registered data out line
  --Outputs of our FIFOs
  type data_array is array (0 to NFIFOS-1) of word;
  type usedw_array is array (0 to NFIFOS-1) of in_fifo_usedw;
  type sig_array is array (0 to NFIFOS-1) of std_logic;
  type size_array is array (0 to NFIFOS-1) of natural;
  constant mux_len        : natural                            := f_num_bits(NFIFOS)-1;
  constant rdusedw_max    : in_fifo_usedw                      := (others => '1');
  signal fifo_outs        : data_array;
  signal rdusedw_sig      : usedw_array;
  signal rdreqs           : sig_array                          := (others => '0');
  signal payload_min_size : size_array                         := (others => 0);
  signal rdempty          : sig_array;
  signal fifo_nearfull    : sig_array                          := (others => '0');
  --Multiplexer
  signal mux_sel          : std_logic_vector(mux_len downto 0) := (others => '0');
  signal mux_out          : word;
  signal fifo_flush       : std_logic_vector(0 to NFIFOS-1)    := (others => '0');
  signal fifo_flush_reg   : std_logic_vector(0 to NFIFOS-1)    := (others => '0');
  signal wrfull_sig       : std_logic_vector(0 to NFIFOS-1)    := (others => '0');
  signal wrreqs_sig       : std_logic_vector(0 to NFIFOS-1)    := (others => '0');
  signal data_in_sig      : data_array;

begin  -- architecture rtl
-------------------------------------------------------------------------------
-- Entity instantiations
-------------------------------------------------------------------------------  
  --!Fifo buffers to hold data ready to be sent to DAQ
  fifo_gen : for I in 0 to NFIFOS-1 generate
    fifo_32x2048_0 : entity work.fifo_32x2048
      port map (
        aclr    => reset,
        data    => data_in_sig(I),
        rdclk   => clock,
        rdreq   => rdreqs(I),
        wrclk   => wrclks(I),
        wrreq   => wrreqs_sig(I),
        q       => fifo_outs(I),
        rdempty => rdempty(I),
        rdusedw => rdusedw_sig(I),
        wrfull  => wrfull_sig(I));
    --Wire up our output to our usedw signal
    rdusedw(I)          <= rdusedw_sig(I);
    payload_min_size(I) <= to_integer(unsigned(payload_size(I)));
    --!Pipeline our data in to reduce combinational logic timing requirements.
    --!\todo fix this to apply proper backpressure
    --!This will prevent FIFO overflow, but won't signal that we're at FIFO maximum
    fifo_in_reg : process (wrclks(I))
    begin
      if rising_edge(wrclks(I)) then
        if fifo_nearfull(I) = '1' then
          wrreqs_sig(I) <= '0';
        else
          wrreqs_sig(I) <= wrreqs(I);
        end if;
        data_in_sig(I) <= data_in(I);
      end if;
    end process;
  end generate fifo_gen;

-------------------------------------------------------------------------------
-- Combinatorial logic
-------------------------------------------------------------------------------

  data_out  <= data_out_sig;
  curr_fifo <= mux_sel;
  --Control line multiplexers
  usedw_out <= rdusedw_sig(to_integer(unsigned(mux_sel)));
  wrfull    <= wrfull_sig;

-------------------------------------------------------------------------------
-- Sequential logic
-------------------------------------------------------------------------------  


  fifo_full_signaller_gen : for I in 0 to NFIFOS-1 generate
    --!Checker for our FIFO size to make sure they aren't overfull    
    fifo_full_signaller : process(wrclks(I), reset)
    begin
      if reset = '1' then
        fifo_nearfull(I) <= '0';
      elsif rising_edge(wrclks(I)) then
        --Disables if >1920 words used (for 2048 bit FIFO)
        if rdusedw_sig(I)(rdusedw_sig(I)'length-1 downto 7) = rdusedw_max(rdusedw_sig(I)'length-1 downto 7) then
          fifo_nearfull(I) <= '1';
        else
          fifo_nearfull(I) <= '0';
        end if;
      end if;
    end process;
  end generate fifo_full_signaller_gen;

  flush_stale_gen : for I in 0 to NFIFOS-1 generate
    --!Triggers a flush of stale or overfull FIFOs    
    flush_stale : process (wrclks(I), reset)
      variable counter : integer := 0;
    begin  -- process flush_stale
      if reset = '1' then               -- asynchronous reset (active high)
        fifo_flush(I) <= '0';
        counter       := 0;
      elsif rising_edge(wrclks(I)) then     -- rising clock edge
        --By default don't flush anything
        fifo_flush(I) <= '0';
        --Reset our counter if we're actively reading/writing to the FIFO        
        if wrreqs_sig(I) = '1' or rdreqs(I) = '1' then
          counter := 0;
        --Otherwise trigger a flush if we're over our threshold *or* we're
        --excessively full
        elsif (counter >= IN_FIFO_STALE_THRESHOLD) or
          (to_integer(unsigned(rdusedw_sig(I))) >= IN_FIFO_AFULL) then
          fifo_flush(I) <= '1';
        --Increment our counter if the FIFO contains any data
        elsif to_integer(unsigned(rdusedw_sig(I))) > 0 then
          counter := counter+1;
        end if;
      end if;
    end process;
  end generate flush_stale_gen;

  --!Registers our fifo_flush signal, and sets the register low if we start
  --!reading from the FIFO (since the process that handles that signal is often
  --!on a much slower clock than the rdreq signal)
  flush_sig_synch : process(clock, reset)
    variable flush_latch : std_logic_vector(0 to NFIFOS-1) := (others => '0');
  begin
    if reset = '1' then
      fifo_flush_reg <= (others => '0');
      flush_latch    := (others => '0');
    elsif rising_edge(clock) then
      for I in 0 to NFIFOS-1 loop
        if fifo_flush(I) = '0' then
          --Clear our latch
          flush_latch(I)  := '0';
          fifo_flush_reg(I) <= '0';
        elsif fifo_flush(I) = '1' and flush_latch(I) = '0' then
          --Set the latch if we're reading
          if rdreqs(I) = '1' then
            fifo_flush_reg(I) <= '0';
            flush_latch(I)    := '1';
          --otherwise, signal we should read
          else
            fifo_flush_reg(I) <= '1';
          end if;
        end if;
      end loop;
    end if;
  end process;


  --!Trigger for determining when one of the buffers is full enough to send a packet over Ethernet
  trigger_payload_rdy : process (clock, reset) is
    type fifo_used_array is array (0 to NFIFOS) of natural;
    variable fifo_used_words : fifo_used_array := (others => 0);
    variable fullest_fifo    : natural         := NFIFOS;
    --Steps for our size checking
    variable step            : integer range -1 to NFIFOS;
  begin  -- process trigger_payload_rdy
    if (reset = '1') then
      payload_rdy  <= '0';
      mux_sel      <= (others => '0');
      fullest_fifo := NFIFOS;
      for I in fifo_used_words'range loop
        fifo_used_words(I) := 0;
      end loop;

    elsif rising_edge(clock) then
      --Note: this algorithm uses NFIFOS+2 clock cycles to find the fullest
      --FIFO, which is not particularly fast (should be ~log_2(NFIFOS))
      if (step = -1) then
        for I in rdusedw_sig'range loop
          fifo_used_words(I) := to_integer(unsigned(rdusedw_sig(I)));
        end loop;
        fifo_used_words(NFIFOS) := 0;
        fullest_fifo            := NFIFOS;
      elsif (step = NFIFOS) then
        if (fullest_fifo /= NFIFOS) then
          --First determine if we're already reading from a FIFO
          if (tx_busy /= '1') then
            --If not trigger a payload read and set the multiplexer
            mux_sel     <= std_logic_vector(to_unsigned(fullest_fifo, mux_sel'length));
            payload_rdy <= '1';
          --TODO: explore possiblity of multiple frame generators for
          --different buffers
          else
            payload_rdy <= '0';
          end if;
        else
          payload_rdy <= '0';
        end if;
      else
        if (((flags(step)(1 downto 0) = INFIFO_PRIORITY) and
             (fifo_used_words(step) >= payload_min_size(step))) or
            --Flush stale or overfull FIFOs
            fifo_flush_reg(step) = '1') then
          fullest_fifo := step;
          --Goto end (NFIFOS-1 because we add +1 at end)
          step         := NFIFOS-1;
        --Checks if FIFO enabled, fuller than others, and above minimum payload
        --size          
        elsif ((flags(step)(0) = '1') and
               (fifo_used_words(fullest_fifo) < fifo_used_words(step)) and
               (fifo_used_words(step) >= payload_min_size(step))) then
          fullest_fifo := step;
        end if;
      end if;

      if (step >= NFIFOS) then
        step := -1;
      else
        step := step+1;
      end if;
    end if;
  end process trigger_payload_rdy;


  --!Multiplexer/register to pass read request through from frame generator
  --!Note that this introduces 1 clock of latency, on top of whatever other
  --!latencies are in the FIFO/frame generator
  read_req_multiplexer : process (clock, reset)
  begin
    if (reset = '1') then
      for I in rdusedw_sig'range loop
        rdreqs(I) <= '0';
      end loop;
    elsif rising_edge(clock) then
      for I in rdusedw_sig'range loop
        if (I = to_integer(unsigned(mux_sel))) then
          rdreqs(I) <= rdreq;           --Pass signal to that FIFO
        else
          rdreqs(I) <= '0';             --Others should not be reading
        end if;
      end loop;
    end if;
  end process read_req_multiplexer;

  --!Register to buffer the output from the MUX
  out_register : process (clock, reset) is
  begin  -- process out_register
    if reset = '1' then                 -- asynchronous reset (active hi)
      data_out_sig <= (others => '0');
    elsif rising_edge(clock) then       -- rising clock edge
      data_out_sig <= fifo_outs(to_integer(unsigned(mux_sel)));
    end if;
  end process out_register;


end architecture rtl;
