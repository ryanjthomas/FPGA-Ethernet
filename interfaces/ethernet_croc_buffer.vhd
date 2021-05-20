-------------------------------------------------------------------------------
-- Title      : Ethernet-CROC buffer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_roc_buffer.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-02-04
-- Last update: 2020-10-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Interface responsible for handling writing data from the
-- Ethernet interface to the CROC
-------------------------------------------------------------------------------
-- Copyright (c) 2020 Ryan Thomas <ryant@uchicago.edu>
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-02-04  1.0      ryan  Created
-------------------------------------------------------------------------------
--!\file ethernet_croc_buffer.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief Ethernet-CROC interface
--!
--!Handles data coming in on the appropriate Ethernet UDP port and stores it in a FIFO buffer. When we have 3 32 bit words, it fills the
--!96-bit CROC register (with the 1st word filling bits [31..0], the 2nd filling bits [63..32], and the 3rd filling [95..64]). It then
--!initiates a write request to the CROC block.

entity ethernet_croc_buffer is
  port (
    --!Clock synchronous to top_ccdcontrol and Ethernet data lines
    clock                   : in  std_logic;
    --!Asynchronous reset
    reset                   : in  std_logic;
    -------------------------------------------------------------------------------
    --!\name Input from Ethernet lines
    --!\{
    -------------------------------------------------------------------------------
    eth_data_in             : in  std_logic_vector(31 downto 0);
    eth_data_port           : in  std_logic_vector(15 downto 0);
    eth_data_valid          : in  std_logic;
    --!\}
    -------------------------------------------------------------------------------
    --!\name Interface to top_ccdcontrol
    --!\{
    -------------------------------------------------------------------------------
    reg96b_crocspi          : out std_logic_vector(95 downto 0);
    reg96b_crocspi_ReadOnly : in  std_logic_vector(95 downto 0);
    write_croc_req          : out std_logic;
    crocprog_busy           : in  std_logic
    );
--!\}
end entity ethernet_croc_buffer;


architecture rtl_vhdl of ethernet_croc_buffer is

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
  signal fifo_rdreq   : std_logic;
  signal fifo_wrreq   : std_logic;
  signal fifo_q       : std_logic_vector (31 downto 0);
  signal fifo_rdempty : std_logic;
  signal fifo_rdusedw : std_logic_vector (8 downto 0);
  signal fifo_wrfull  : std_logic;

  type state_type is (HW_RESET, IDLE, START_FIFO_READ, WAIT_FIFO, LOAD_REGISTER, WRITE_REGISTER, CROC_READBACK);
  signal next_state : state_type := IDLE;

  signal reg96b_crocspi_reg          : std_logic_vector(95 downto 0);
  signal reg96b_crocspi_ReadOnly_reg : std_logic_vector(95 downto 0);
  signal write_croc_req_reg          : std_logic;

begin

  --!Buffer to hold data for writing to the CROC
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

  --!Writes data coming in the correct UDP port to the FIFO buffer.
  fifo_writer : process (clock)
  begin
    if rising_edge(clock) then
      if eth_data_valid = '1' and eth_data_port = UDP_PORT_CROC_PROG then
        fifo_wrreq <= '1';
        fifo_data  <= eth_data_in;
      else
        fifo_data  <= (others => '0');
        fifo_wrreq <= '0';
      end if;
    end if;
  end process fifo_writer;

  reg96b_crocspi              <= reg96b_crocspi_reg;
  reg96b_crocspi_ReadOnly_reg <= reg96b_crocspi_ReadOnly;
  write_croc_req              <= write_croc_req_reg;

  --!State machine that handles writing CROC data from our buffer to the programmer
  croc_writer_state_machine : process (reset, clock)
    variable words_read : natural range 0 to 2 := 0;
  begin
    if reset = '1' then
      write_croc_req_reg <= '0';
      fifo_rdreq         <= '0';
      next_state         <= HW_RESET;
    elsif rising_edge(clock) then
      --Default outputs
      write_croc_req_reg <= '0';
      fifo_rdreq         <= '0';

      case next_state is
        when HW_RESET =>
          next_state <= IDLE;
        when IDLE =>
          --Start writing if we have 3+ words in the buffer.
          if to_integer(unsigned(fifo_rdusedw)) >= 3 and crocprog_busy = '0' then
            next_state <= START_FIFO_READ;
            words_read := 0;
          else
            next_state <= IDLE;
          end if;
        --Start reading from our FIFO
        when START_FIFO_READ =>
          fifo_rdreq <= '1';
          next_state <= WAIT_FIFO;
        --Takes 1 clock cycle for our first word to become available
        when WAIT_FIFO =>
          fifo_rdreq <= '1';
          next_state <= LOAD_REGISTER;

        --Converts the 32-bit words into our 96-bit register
        when LOAD_REGISTER =>
          words_read                                                     := words_read + 1;
          --Load the appropriate bits
          reg96b_crocspi_reg((words_read)*32-1 downto (words_read-1)*32) <= fifo_q;
          if words_read >= 2 then
            next_state <= WRITE_REGISTER;
            fifo_rdreq <= '0';
          else
            fifo_rdreq <= '1';
          end if;

        when WRITE_REGISTER =>
          --Our last word should have just come on the FIFO data line
          reg96b_crocspi_reg(95 downto 64) <= fifo_q;
          write_croc_req_reg               <= '1';
          next_state                       <= IDLE;
          fifo_rdreq                       <= '0';

        when others =>
          next_state <= IDLE;
      end case;

    end if;
  end process;

end architecture rtl_vhdl;
