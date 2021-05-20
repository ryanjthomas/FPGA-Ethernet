-------------------------------------------------------------------------------
-- Title      : Ethernet-CABAC buffer
-- Project    : ODILE
-------------------------------------------------------------------------------
-- File       : ethernet_cabac_buffer.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-02-04
-- Last update: 2020-10-19
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Interface between the Ethernet block and the CABAC programmer
-- contained in the top_ccdcontrol block
-------------------------------------------------------------------------------
--! \file ethernet_cabac_buffer.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief Interface between Ethernet and CABAC logic.
--!
--! Simple interface responsible for writing the CABAC registers
--! based on signals from the Ethernet interface. 

entity ethernet_cabac_buffer is
  port (
    clock                    : in  std_logic;
    reset                    : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Interface to UDP data router
    --!\{
    ---------------------------------------------------------------------------
    eth_data_in              : in  std_logic_vector(31 downto 0);
    eth_data_port            : in  std_logic_vector(15 downto 0);
    eth_data_valid           : in  std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name Interface to top_ccdcontrol
    --!\{
    ---------------------------------------------------------------------------
    reset_cabac              : in  std_logic;
    reg32b_cabacspi          : out std_logic_vector(31 downto 0);
    Reg32b_cabacspi_ReadOnly : in  std_logic_vector(31 downto 0);
    start_cabac_SPI          : out std_logic;
    start_cabac_reset_SPI    : out std_logic;
    cabacprog_busy           : in  std_logic;
    data_from_cabacspi_ready : in std_logic
    );
    --!\}

end entity ethernet_cabac_buffer;


architecture rtl_vhdl of ethernet_cabac_buffer is


  component scfifo_32x512 is
    port (
      aclr  : in  std_logic;
      clock : in  std_logic;
      data  : in  std_logic_vector (31 downto 0);
      rdreq : in  std_logic;
      wrreq : in  std_logic;
      empty : out std_logic;
      full  : out std_logic;
      q     : out std_logic_vector (31 downto 0);
      usedw : out std_logic_vector (8 downto 0));
  end component scfifo_32x512;


  signal fifo_data    : std_logic_vector (31 downto 0);
  signal fifo_rdclk   : std_logic;
  signal fifo_rdreq   : std_logic;
  signal fifo_wrclk   : std_logic;
  signal fifo_wrreq   : std_logic;
  signal fifo_q       : std_logic_vector (31 downto 0);
  signal fifo_rdempty : std_logic;
  signal fifo_rdusedw : std_logic_vector (8 downto 0);
  signal fifo_wrfull  : std_logic;

  type state_type is (HW_RESET, IDLE, START_RESET, READ_WORD, START_SPI,
                      WAIT_SPI, WAIT_BUSY);
  signal state      : state_type := IDLE;
  signal next_state : state_type := IDLE;


begin

  --! FIFO that holds data to be written to the CABAC
  fifo_32x512_1 : entity work.scfifo_32x512
    port map (
      aclr  => reset,
      clock => clock,
      data  => fifo_data,
      rdreq => fifo_rdreq,
      wrreq => fifo_wrreq,
      empty => fifo_rdempty,
      full  => fifo_wrfull,
      q     => fifo_q,
      usedw => fifo_rdusedw);

  fifo_rdclk <= clock;
  fifo_wrclk <= clock;

  --! Writes data that comes in on the appropriate UDP port to the CABAC FIFO buffer.
  fifo_writer : process (clock)
  begin
    if rising_edge(clock) then
      if eth_data_valid = '1' and eth_data_port = UDP_PORT_CABAC_PROG then
        fifo_wrreq <= '1';
        fifo_data  <= eth_data_in;
      else
        fifo_data  <= (others => '0');
        fifo_wrreq <= '0';
      end if;
    end if;
  end process fifo_writer;

  reg32b_cabacspi <= fifo_q;

  --!State machine that handles writing CABAC data from our buffer to the programmer
  cabac_writer_state_machine : process (reset, clock)
  begin
    if reset = '1' then
      start_cabac_reset_SPI <= '0';
      start_cabac_SPI       <= '0';
      fifo_rdreq            <= '0';
      next_state            <= HW_RESET;
    elsif rising_edge(clock) then
      --Default outputs
      start_cabac_reset_SPI <= '0';
      start_cabac_SPI       <= '0';
      fifo_rdreq            <= '0';

      case next_state is
        when HW_RESET =>
          next_state <= IDLE;
        when IDLE =>
          --If our buffer is not empty, start writing data
          if fifo_rdempty = '0' then
            next_state <= READ_WORD;
          else
            next_state <= IDLE;
          end if;
          
          if reset_cabac = '1' then
            next_state <= START_RESET;
          end if;

        when START_RESET =>
          start_cabac_reset_SPI <= '1';
          next_state            <= IDLE;

        when READ_WORD =>
          fifo_rdreq <= '1';
          next_state <= START_SPI;

        when START_SPI =>
          fifo_rdreq      <= '0';
          start_cabac_SPI <= '1';
          next_state      <= WAIT_SPI;

        when WAIT_SPI =>
          start_cabac_SPI <= '1';
          if cabacprog_busy = '1' then
            next_state <= WAIT_BUSY;
          else
            next_state <= WAIT_SPI;
          end if;

        when WAIT_BUSY =>
          if cabacprog_busy = '1' then
            next_state <= WAIT_BUSY;
          else
            if fifo_rdempty = '0' then
              next_state <= READ_WORD;
            else
              next_state <= IDLE;
            end if;
          end if;

        when others =>
          next_state <= IDLE;
      end case;
      state <= next_state;

    end if;
  end process;

end architecture rtl_vhdl;
