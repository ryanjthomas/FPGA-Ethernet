-------------------------------------------------------------------------------
-- Title      : ODILE Control Registers
-- Project    : 
-------------------------------------------------------------------------------
-- File       : config_register_block.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2019-09-27
-- Last update: 2021-04-13
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Control register block for the ODILE board. Read/write
-- interface is 32 bits wide with a dval flag, with the config word format
-- documented below. The design goal is to allow data read from the registers
-- to be easily saved to either the FPGA flash or a server and fed back in to
-- the ODILE board to configure it. 
-------------------------------------------------------------------------------
--!\file config_register_block.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package config_pkg is
  subtype config_word is std_logic_vector(31 downto 0);
  type config_word_array is array(natural range <>) of config_word;
end package config_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.config_pkg.all;

--!\brief Block that holds configuration registers for various components on the ODILE board.
--!
--! Designed to be flexible and programmable through a 32-bit serial interface. There can be
--! up to 128 blocks, each with up to 127 32-bit registers. Note that in practice, each register
--! is addressed as 2 16-bit registers. 
-------------------------------------------------------------------------------
--! The structure of our configuration commands is as follows:
--! config_data[31]     = write/read flag (write=0, read=1)
--! config_data[30:24]  = register block address
--! config_data[23:17]  = register address. Note that an address of "1111111"
--! when config_data[31]=1 will trigger a block read of all registers.
--! config_data[16]     = lower ('0') or upper ('1') 16 bits of config word
--! config_data[15:0]   = configuration data (the upper 16 bits if config_data[16]='1',
--! the lower 16 bits if config_data[16]='0').
-------------------------------------------------------------------------------

entity config_register_block is
  generic (
    --!Address for the configuration block
    BLOCK_ADDRESS    : std_logic_vector(6 downto 0) := (others => '0');
    --!The default values for each configuration register. The size of this sets the number of registers.
    DEFAULT_SETTINGS : config_word_array
    );
  port (
    clock            : in  std_logic;
    reset            : in  std_logic;
    --!Configuration data input
    config_data_in   : in  std_logic_vector(31 downto 0)                         := (others => '0');
    --!Configuration data valid flag
    config_valid_in  : in  std_logic                                             := '0';
    --!Configuration data output
    config_data_out  : out std_logic_vector(31 downto 0)                         := (others => '0');
    --!Configuration data output valid flag
    config_valid_out : out std_logic                                             := '0';
    --!Configuration registers
    config_registers : out config_word_array(DEFAULT_SETTINGS'length-1 downto 0) := DEFAULT_SETTINGS;
    --!Signal indicating configuration has changed
    config_changed   : out std_logic                                             := '0';
    --!Configuration error (occurs if you try to write to an invalid configuration register).
    config_error     : out std_logic                                             := '0'
    );
end entity config_register_block;

architecture rtl of config_register_block is
  signal config_registers_reg : config_word_array(DEFAULT_SETTINGS'length-1 downto 0) := DEFAULT_SETTINGS;
  signal config_changed_regs  : std_logic_vector(3 downto 0);
  signal config_valid_in_reg  : std_logic;
  signal config_data_in_reg   : std_logic_vector(31 downto 0);
  signal reconfiged           : std_logic;
  constant num_registers      : natural                                               := DEFAULT_SETTINGS'length;
  signal block_read_index     : natural                                               := 0;
  signal write_error          : std_logic                                             := '0';
  signal read_error           : std_logic                                             := '0';

begin

  --!Register the output of our block
  config_dff : process(clock)
  begin
    if rising_edge(clock) then
      config_registers    <= config_registers_reg;
      config_changed      <= reconfiged or config_changed_regs(0);
      config_error        <= write_error or read_error;
      config_valid_in_reg <= config_valid_in;
      config_data_in_reg  <= config_data_in;
    end if;
  end process config_dff;

  --!Process to write our configuration registers
  register_writer : process (clock, reset)
    variable register_int : natural := 0;
  begin
    if (reset = '1') then
      --Reset our registers
      config_registers_reg <= DEFAULT_SETTINGS;
      write_error          <= '0';
      reconfiged           <= '1';
    elsif rising_edge(clock) then
      if (config_valid_in_reg = '1') then
        if (config_data_in_reg(31) = '1') then
          write_error <= '0';
          reconfiged  <= '0';
        --If the command block address matches ours, do something
        elsif (config_data_in_reg(30 downto 24) = BLOCK_ADDRESS) then
          register_int := to_integer(unsigned(config_data_in_reg(23 downto 17)));
          --Check that it's a valid register
          if (register_int >= DEFAULT_SETTINGS'length) then
            write_error <= '1';
            reconfiged  <= '0';
          --If so, write lower/upper register as required
          elsif (config_data_in_reg(16) = '0') then
            config_registers_reg(register_int)(15 downto 0) <= config_data_in_reg(15 downto 0);
            reconfiged                                      <= '1';
            write_error                                     <= '0';
          elsif (config_data_in_reg(16) = '1') then
            config_registers_reg(register_int)(31 downto 16) <= config_data_in_reg(15 downto 0);
            reconfiged                                       <= '1';
            write_error                                      <= '0';
          end if;
        else
          write_error <= '0';
          reconfiged  <= '0';
        end if;
      else
        write_error <= '0';
        reconfiged  <= '0';
      end if;
    end if;

  end process register_writer;

  --!Extends our config_changed signal
  config_change_ff : process(clock, reset)
  begin
    if (reset = '1') then
      config_changed_regs <= (others => '1');
    elsif rising_edge(clock) then
      if (reconfiged = '1') then
        config_changed_regs <= (others => '1');
      else
        config_changed_regs(config_changed_regs'length-1) <= '0';
        for I in 0 to config_changed_regs'length-2 loop
          config_changed_regs(I) <= config_changed_regs(I+1);
        end loop;
      end if;
    end if;
  end process config_change_ff;

  --!Process to output the serial register contents in our 32-bit format.
  register_reader : process(clock, reset)
    variable read_reg         : natural := 0;
    variable block_read_reg   : integer := 0;
    variable block_read_upper : boolean := false;
  begin
    if reset = '1' then
      block_read_index <= 0;
      config_valid_out <= '0';
      config_data_out  <= (others => '0');
      block_read_reg   := 0;
      block_read_upper := false;
      read_error       <= '0';
    elsif rising_edge(clock) then
      read_reg := to_integer(unsigned(config_data_in_reg(23 downto 17)));
      -------------------------------------------------------------------------
      -- Read the entire configuration block
      -------------------------------------------------------------------------
      if (block_read_index = 0 and config_data_in_reg(31) = '1' and
          config_valid_in_reg = '1' and config_data_in_reg(30 downto 24) = BLOCK_ADDRESS and read_reg = 127) then
        --Start reading our registers
        config_valid_out <= '1';
        config_data_out  <= "0" & BLOCK_ADDRESS & "00000000" & config_registers_reg(0)(15 downto 0);
        block_read_index <= 1;
        block_read_upper := true;
        block_read_reg   := 0;
      elsif block_read_index >= 2*num_registers then
        --Finish our read
        config_valid_out <= '0';
        config_data_out  <= (others => '0');
        block_read_index <= 0;
        block_read_reg   := 0;
      elsif block_read_index >= 1 then
        if block_read_upper then
          --Read upper 16 bits & increment register
          config_data_out  <= "0" & BLOCK_ADDRESS & std_logic_vector(to_unsigned(block_read_index, 8)) & config_registers_reg(block_read_reg)(31 downto 16);
          block_read_reg   := block_read_reg + 1;
          block_read_upper := false;
        else
          config_data_out  <= "0" & BLOCK_ADDRESS & std_logic_vector(to_unsigned(block_read_index, 8)) & config_registers_reg(block_read_reg)(15 downto 0);
          block_read_upper := true;
        end if;
        config_valid_out <= '1';
        block_read_index <= block_read_index + 1;
      -------------------------------------------------------------------------
      -- Read a single configuration register.
      -------------------------------------------------------------------------
      elsif (config_data_in_reg(31) = '1' and config_valid_in_reg = '1' and config_data_in_reg(30 downto 24) = BLOCK_ADDRESS) then
        if (read_reg >= num_registers) then
          read_error       <= '1';
          config_valid_out <= '0';
          config_data_out  <= (others => '0');
        elsif (config_data_in_reg(16) = '0') then
          read_error       <= '0';
          --Read lower bits
          config_data_out  <= "0" & config_data_in_reg(30 downto 16) & config_registers_reg(read_reg)(15 downto 0);
          config_valid_out <= '1';
        elsif (config_data_in_reg(16) = '1') then
          read_error       <= '0';
          --Read upper bits
          config_data_out  <= "0" & config_data_in_reg(30 downto 16) & config_registers_reg(read_reg)(31 downto 16);
          config_valid_out <= '1';
        end if;
      else
        config_valid_out <= '0';
        config_data_out  <= (others => '0');
        read_error       <= '0';
      end if;
    end if;
  end process;

end architecture;


