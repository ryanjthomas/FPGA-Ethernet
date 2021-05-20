-------------------------------------------------------------------------------
-- Title      : Ethernet-CCDControl Interface
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_ccdcontrol_interface.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-01-06
-- Last update: 2020-10-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Interface between ethernet serial data and the CCD controller
-- top block. 
-------------------------------------------------------------------------------
--! \file ethernet_ccdcontrol_interface.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief Interface between Ethernet and CCD control logic.
--!
--! Handles translating serial data from the Ethernet interface into programing
--! the various sequencer and CABAC memories and registers. The interface
--! assumes data sent to specific UDP ports is targeted at the appropriate
--! sequencer memory or register, and forwards the data appropriately.

entity ethernet_ccdcontrol_interface is
  port (
    clock                    : in  std_logic;
    reset                    : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Input ethernet data
    --!\}
    ---------------------------------------------------------------------------
    data_in                  : in  std_logic_vector(31 downto 0)  := (others => '0');
    data_port                : in  std_logic_vector(15 downto 0)  := (others => '0');
    data_valid               : in  std_logic                      := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name Interface to UDP transmit
    --!\{
    ---------------------------------------------------------------------------
    udp_out_bus              : out std_logic_vector(52 downto 0)  := (others => '0');
    udp_ready                : in  std_logic                      := '0';
    --!\}
    --!Sequencer read done signal
    read_done                : out std_logic                      := '0';
    --!Sequencer erase done signal
    erase_done               : out std_logic                      := '0';
    ---------------------------------------------------------------------------
    --!\name CABAC Interface
    --!\{
    ---------------------------------------------------------------------------
    reg32b_cabacspi          : out std_logic_vector(31 downto 0)  := (others => '0');
    Reg32b_cabacspi_ReadOnly : in  std_logic_vector(31 downto 0)  := (others => '0');
    start_cabac_SPI          : out std_logic                      := '0';
    start_cabac_reset_SPI    : out std_logic                      := '0';
    cabacprog_busy           : in  std_logic                      := '1';
    reset_cabac              : in  std_logic                      := '0';
    data_from_cabacspi_ready : in  std_logic                      := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name CROC Interface
    --!\{
    ---------------------------------------------------------------------------
    reg96b_crocspi           : out std_logic_vector(95 downto 0)  := (others => '0');
    reg96b_crocspi_ReadOnly  : in  std_logic_vector(95 downto 0)  := (others => '0');
    write_croc_req           : out std_logic                      := '0';
    crocprog_busy            : in  std_logic                      := '0';
    ---------------------------------------------------------------------------
    --!\name Sequencer interface
    --!\{
    ---------------------------------------------------------------------------
    --!Memory address bus
    seq_mem_w_add            : out std_logic_vector(9 downto 0)   := (others => '0');
    --!Memory data bus
    seq_mem_data_in          : out std_logic_vector (31 downto 0) := (others => '0');
    --Write enables for different memories
    program_mem_we           : out std_logic                      := '0';  --!Write to program memory
    time_mem_w_en            : out std_logic                      := '0';  --!Write to time memory
    out_mem_w_en             : out std_logic                      := '0';  --!Write to output clock values
    --For pointer functionality (so we can use if need be)
    ind_func_mem_we          : out std_logic                      := '0';
    ind_rep_mem_we           : out std_logic                      := '0';
    ind_sub_add_mem_we       : out std_logic                      := '0';
    ind_sub_rep_mem_we       : out std_logic                      := '0';
    --Controls reading sequencer memory
    --!Read for various memories (see #read_multiplexer process for details)
    read_triggers            : in  std_logic_vector(15 downto 0)  := (others => '0');
    erase_sequencer          : in  std_logic                      := '0';
    prog_mem_redbk           : in  std_logic_vector(31 downto 0);
    time_mem_readbk          : in  std_logic_vector(15 downto 0);
    out_mem_readbk           : in  std_logic_vector(31 downto 0);
    ind_func_mem_redbk       : in  std_logic_vector(3 downto 0);
    ind_rep_mem_redbk        : in  std_logic_vector(23 downto 0);
    ind_sub_add_mem_redbk    : in  std_logic_vector(9 downto 0);
    ind_sub_rep_mem_redbk    : in  std_logic_vector(15 downto 0);
    --!\todo Move to ODILE controller?
    program_mem_init_add_in  : out std_logic_vector(9 downto 0)   := (others => '0');
    program_mem_init_add_rbk : in  std_logic_vector(9 downto 0);
    op_code_error_reset      : out std_logic                      := '0';
    op_code_error            : in  std_logic;
    op_code_error_add        : in  std_logic_vector(9 downto 0)
    );
--!\}    
end entity ethernet_ccdcontrol_interface;


architecture rtl of ethernet_ccdcontrol_interface is

  component ethernet_cabac_buffer is
    port (
      clock                    : in  std_logic;
      reset                    : in  std_logic;
      eth_data_in              : in  std_logic_vector(31 downto 0);
      eth_data_port            : in  std_logic_vector(15 downto 0);
      eth_data_valid           : in  std_logic;
      reset_cabac              : in  std_logic;
      reg32b_cabacspi          : out std_logic_vector(31 downto 0);
      start_cabac_SPI          : out std_logic;
      start_cabac_reset_SPI    : out std_logic;
      cabacprog_busy           : in  std_logic;
      data_from_cabacspi_ready : in  std_logic);
  end component ethernet_cabac_buffer;

  component ethernet_croc_buffer is
    port (
      clock                   : in  std_logic;
      reset                   : in  std_logic;
      eth_data_in             : in  std_logic_vector(31 downto 0);
      eth_data_port           : in  std_logic_vector(15 downto 0);
      eth_data_valid          : in  std_logic;
      reg96b_crocspi          : out std_logic_vector(95 downto 0);
      reg96b_crocspi_ReadOnly : in  std_logic_vector(95 downto 0);
      write_croc_req          : out std_logic;
      crocprog_busy           : in  std_logic);
  end component ethernet_croc_buffer;

  --!Internal register holding memory to write to
  signal seq_destination  : std_logic_vector(15 downto 0) := (others => '0');
  signal seq_mem_w_add_wr : std_logic_vector(9 downto 0)  := (others => '0');
  signal seq_mem_w_add_rd : std_logic_vector(9 downto 0)  := (others => '0');

  type read_state_type is (HW_RESET, IDLE, TX_REQ_WAIT, READ_ADDR, READ_DATA,
                           READ_CABAC_REG, READ_CROC_REG);
  signal next_read_state   : read_state_type               := HW_RESET;
  --!Read/write toggle
  signal is_write_mode     : boolean                       := false;
  signal read_mem_port     : udp_port                      := (others => '0');
  signal read_triggers_mem : std_logic_vector(15 downto 0) := (others => '0');
  signal data_out          : std_logic_vector(31 downto 0) := (others => '0');
  signal data_out_port     : std_logic_vector(15 downto 0) := (others => '0');
  signal data_out_valid    : std_logic                     := '0';
  signal tx_req, tx_busy   : std_logic                     := '0';
  signal data_out_eop      : std_logic                     := '0';
  signal data_erase        : std_logic_vector(31 downto 0) := (others => '0');
  constant data_erase_port : std_logic_vector(15 downto 0) := UDP_PORT_SEQ_SERIAL;
  signal data_erase_valid  : std_logic                     := '0';
  signal data_in_reg       : std_logic_vector(31 downto 0) := (others => '0');
  signal data_port_reg     : std_logic_vector(15 downto 0) := (others => '0');
  signal data_valid_reg    : std_logic                     := '0';


begin

  udp_out_bus(31 downto 0)  <= data_out;
  udp_out_bus(47 downto 32) <= data_out_port;
  udp_out_bus(48)           <= data_out_valid;
  udp_out_bus(49)           <= data_out_eop;
  udp_out_bus(50)           <= tx_req;
  udp_out_bus(51)           <= tx_busy;
  udp_out_bus(52)           <= '0';

  --!Responsible for handling interface to CABAC
  ethernet_cabac_buffer_1 : entity work.ethernet_cabac_buffer
    port map (
      clock                    => clock,
      reset                    => reset,
      eth_data_in              => data_in,
      eth_data_port            => data_port,
      eth_data_valid           => data_valid,
      reset_cabac              => reset_cabac,
      reg32b_cabacspi          => reg32b_cabacspi,
      Reg32b_cabacspi_ReadOnly => Reg32b_cabacspi_ReadOnly,
      start_cabac_SPI          => start_cabac_SPI,
      start_cabac_reset_SPI    => start_cabac_reset_SPI,
      cabacprog_busy           => cabacprog_busy,
      data_from_cabacspi_ready => data_from_cabacspi_ready);

  ethernet_croc_buffer_1 : entity work.ethernet_croc_buffer
    port map (
      clock                   => clock,
      reset                   => reset,
      eth_data_in             => data_in,
      eth_data_port           => data_port,
      eth_data_valid          => data_valid,
      reg96b_crocspi          => reg96b_crocspi,
      reg96b_crocspi_ReadOnly => reg96b_crocspi_ReadOnly,
      write_croc_req          => write_croc_req,
      crocprog_busy           => crocprog_busy);

  --This may need to be registered
  seq_mem_w_add <= seq_mem_w_add_wr when is_write_mode else
                   seq_mem_w_add_rd;

  --!Multiplexes data in and erase block data
  data_register : process (clock)
  begin
    if rising_edge(clock) then
      if data_valid = '1' then
        data_valid_reg <= '1';
        data_port_reg  <= data_port;
        data_in_reg    <= data_in;
      elsif data_erase_valid = '1' then
        data_valid_reg <= '1';
        data_port_reg  <= data_erase_port;
        data_in_reg    <= data_erase;
      else
        data_valid_reg <= '0';
        data_port_reg  <= (others => '0');
      end if;
    end if;

  end process;

  --!Handles translating 2-word UDP data into a form expected by the sequencer
  --!memory. Format expected is a string of 2 32-bit words: the first word
  --!contains the address of the memory to write to, the second the value to
  --!write to the memory. Note that we can select the memory by either sending
  --!data to the appropriate UDP port, or putting that same port information in
  --!the top 16 bits of the address word. The former will take priority over the
  --!latter to maintain backwards compatibility.
  write_multiplexer : process (clock)
    --When true, assume our data is an address word
    --The start of every packet is assumed to be an address word
    variable is_address : boolean := true;
  begin
    if rising_edge(clock) then
      program_mem_we      <= '0';
      time_mem_w_en       <= '0';
      out_mem_w_en        <= '0';
      ind_func_mem_we     <= '0';
      ind_rep_mem_we      <= '0';
      ind_sub_add_mem_we  <= '0';
      ind_sub_rep_mem_we  <= '0';
      op_code_error_reset <= '0';

      --Check if we should write data to sequencer
      if ((data_valid_reg = '1') and
          (data_port_reg = UDP_PORT_SEQ_SERIAL or data_port_reg(13 downto 6) = "10000000")) then
        is_write_mode       <= true;
        --Reset op code error, since we're writing new sequencer
        op_code_error_reset <= '1';
        if is_address then
          seq_mem_w_add_wr <= data_in_reg(9 downto 0);
          is_address       := false;
          if data_port_reg = UDP_PORT_SEQ_SERIAL then
            seq_destination <= data_in_reg(31 downto 16);
          else
            seq_destination <= data_port_reg;
          end if;
        else
          seq_mem_data_in <= data_in_reg;
          is_address      := true;
          --Select which memory to write to here
          if seq_destination = UDP_PORT_SEQ_PROGRAM then
            program_mem_we <= '1';
          elsif seq_destination = UDP_PORT_SEQ_TIME then
            time_mem_w_en <= '1';
          elsif seq_destination = UDP_PORT_SEQ_OUT then
            out_mem_w_en <= '1';
          elsif seq_destination = UDP_PORT_SEQ_IND_FUNC then
            ind_func_mem_we <= '1';
          elsif seq_destination = UDP_PORT_SEQ_IND_REP then
            ind_rep_mem_we <= '1';
          elsif seq_destination = UDP_PORT_SEQ_IND_SUB_ADD then
            ind_sub_add_mem_we <= '1';
          elsif seq_destination = UDP_PORT_SEQ_IND_SUB_REP then
            ind_sub_rep_mem_we <= '1';
          end if;
        end if;
      else
        --The first valid word of each packet is an address word
        is_address    := true;
        is_write_mode <= false;
      end if;
    end if;
  end process write_multiplexer;

  --!Responsible for handling reading from the sequencer memories. Uses the
  --!same 2-word format as the writing process above (with the information about
  --!which memory is being read from being encoded in the top 16 bits of the
  --!address word).
  read_multiplexer : process (clock, reset)
    variable address     : unsigned(9 downto 0) := (others => '0');
    variable max_address : unsigned(9 downto 0) := (others => '0');
    variable index       : natural range 0 to 2 := 0;
  begin
    if (reset = '1') then
      next_read_state <= HW_RESET;
      address         := (others => '0');

    elsif rising_edge(clock) then
      tx_req         <= '0';
      tx_busy        <= '0';
      data_out_valid <= '0';
      read_done      <= '0';
      if is_write_mode then
        next_read_state <= next_read_state;
      else
        case next_read_state is
          when HW_RESET =>
            next_read_state <= IDLE;
          when IDLE =>
            max_address       := (others => '0');
            --Move the read triggers into a memory register for later
            read_triggers_mem <= read_triggers;
            if read_triggers(0) = '1' then
              read_mem_port <= UDP_PORT_SEQ_PROGRAM;
              max_address   := "1111111111";
            elsif read_triggers(1) = '1' then
              read_mem_port <= UDP_PORT_SEQ_TIME;
              max_address   := "0011111111";
            elsif read_triggers(2) = '1' then
              read_mem_port <= UDP_PORT_SEQ_OUT;
              max_address   := "0011111111";
            elsif read_triggers(3) = '1' then
              read_mem_port <= UDP_PORT_SEQ_IND_FUNC;
              max_address   := "0000001111";
            elsif read_triggers(4) = '1' then
              read_mem_port <= UDP_PORT_SEQ_IND_REP;
              max_address   := "0000001111";
            elsif read_triggers(5) = '1' then
              read_mem_port <= UDP_PORT_SEQ_IND_SUB_ADD;
              max_address   := "0000001111";
            elsif read_triggers(6) = '1' then
              read_mem_port <= UDP_PORT_SEQ_IND_SUB_REP;
              max_address   := "0000001111";
            elsif read_triggers(7) = '1' then  --Read CABAC register
              read_mem_port <= UDP_PORT_CABAC_PROG;
            elsif read_triggers(8) = '1' then  --Read CROC register
              read_mem_port <= UDP_PORT_CROC_PROG;
            else
              read_mem_port <= (others => '0');
            end if;

            if (read_triggers(8 downto 0) /= "000000000") then
              next_read_state <= TX_REQ_WAIT;
              tx_req          <= '1';
              address         := (others => '0');
            else
              next_read_state <= IDLE;
            end if;

          when TX_REQ_WAIT =>
            tx_req <= '1';
            if (udp_ready = '1') then
              if (read_triggers_mem(7) = '1') then
                next_read_state <= READ_CABAC_REG;
              elsif (read_triggers_mem(8) = '1') then
                next_read_state <= READ_CROC_REG;
                index := 0;
              else
                next_read_state <= READ_ADDR;
              end if;
            else
              next_read_state <= TX_REQ_WAIT;
            end if;

          when READ_ADDR =>
            data_out        <= read_mem_port & "000000" & std_logic_vector(address);
            --data_out_port   <= read_mem_port;
            data_out_port   <= UDP_PORT_SEQ_SERIAL;
            data_out_valid  <= '1';
            next_read_state <= READ_DATA;
            tx_busy         <= '1';

          when READ_DATA =>
            if read_triggers_mem(0) = '1' then
              data_out <= prog_mem_redbk;
            elsif read_triggers_mem(1) = '1' then
              data_out <= X"00_00" & time_mem_readbk;
            elsif read_triggers_mem(2) = '1' then
              data_out <= out_mem_readbk;
            elsif read_triggers_mem(3) = '1' then
              data_out <= X"00_00_00_0" & ind_func_mem_redbk;
            elsif read_triggers_mem(4) = '1' then
              data_out <= X"00" & ind_rep_mem_redbk;
            elsif read_triggers_mem(5) = '1' then
              data_out <= X"00_00_0" & "00" & ind_sub_add_mem_redbk;
            elsif read_triggers_mem(6) = '1' then
              data_out <= X"00_00" & ind_sub_rep_mem_redbk;
            end if;
            data_out_port  <= UDP_PORT_SEQ_SERIAL;
            data_out_valid <= '1';
            tx_busy        <= '1';
            if (address = max_address) then
              next_read_state <= IDLE;
              read_done       <= '1';
            else
              address         := address+1;
              next_read_state <= READ_ADDR;
            end if;

          when READ_CABAC_REG =>
            data_out        <= Reg32b_cabacspi_ReadOnly;
            data_out_port   <= UDP_PORT_CABAC_PROG;
            data_out_valid  <= '1';
            tx_busy         <= '1';
            next_read_state <= IDLE;
            read_done       <= '1';

          when READ_CROC_REG =>
            index := index + 1;            
            data_out <= reg96b_crocspi_ReadOnly((index)*32-1 downto (index-1)*32);
            data_out_port <= UDP_PORT_CROC_PROG;
            data_out_valid <= '1';
            tx_busy <= '1';

            if index = 3 then
              next_read_state <= IDLE;
              read_done <= '1';
            else
              next_read_state <= READ_CROC_REG;
            end if;

        end case;
      end if;
      seq_mem_w_add_rd <= std_logic_vector(address);
    end if;  --Clock
  end process read_multiplexer;

  --!Handles erasing the sequencer memory. Will erase all sequencer memories.
  erase_data : process(clock)
    variable do_erase      : boolean                       := false;
    variable address       : unsigned(9 downto 0)          := (others => '0');
    variable max_address   : unsigned(9 downto 0)          := (others => '0');
    variable block_address : std_logic_vector(15 downto 0) := (others => '0');
    variable write_address : boolean                       := false;
  begin
    if rising_edge(clock) then
      --default value
      erase_done       <= '0';
      data_erase_valid <= '0';
      if do_erase then
        data_erase_valid <= '1';

        if write_address then
          data_erase <= std_logic_vector(block_address) & "000000" &
                        std_logic_vector(address);
          write_address := false;
        else
          data_erase    <= (others => '0');
          write_address := true;
          --Check if done with the block
          if address = max_address then
            --Check if done with the final block
            if block_address = UDP_PORT_SEQ_IND_SUB_REP then
              do_erase   := false;
              erase_done <= '1';
            else
              --Erase next memory block
              block_address := std_logic_vector(unsigned(block_address) + 1);
              if (block_address = UDP_PORT_SEQ_TIME) or (block_address = UDP_PORT_SEQ_OUT) then
                max_address := "0011111111";
              else
                max_address := "0000001111";
              end if;
            end if;
            address := (others => '0');
          else
            address := address + 1;
          end if;
        end if;

      --Start an erase cycle
      elsif erase_sequencer = '1' then
        do_erase      := true;
        write_address := true;
        block_address := UDP_PORT_SEQ_PROGRAM;
        max_address   := "1111111111";
        address       := (others => '0');
      end if;
    end if;
  end process erase_data;

end architecture rtl;

