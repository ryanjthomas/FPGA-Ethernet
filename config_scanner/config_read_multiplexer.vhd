-------------------------------------------------------------------------------
-- Title      : Configuration Reading Multiplexer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : config_read_multiplexer.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-05-21
-- Last update: 2020-07-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Multiplexer to read many different configuration blocks. Meant
-- mostly for the config_block_scanner, but can be used for other tools as
-- well. Output is single registered.
-------------------------------------------------------------------------------
--!\file config_read_multiplexer.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.config_pkg.all;

--! \brief Simple multiplexer to handle reading data from multiple
--! configuration blocks.
--! 
--! Will output configuration data from a configuration
--! register block if any of them are outputing valid data. Note that it will
--! *not* arbitrate between multiple blocks if they output data simultaneously,
--! the final block will take priority.

entity config_read_multiplexer is
  generic (
    --! Number of lines to multiplex
    NCONFIG_LINES : natural := 5
    );
  port (
    clock            : in  std_logic;
    config_data_in   : in  config_word_array(NCONFIG_LINES-1 downto 0);
    config_valid_in  : in  std_logic_vector(NCONFIG_LINES-1 downto 0);
    config_data_out  : out config_word;
    config_valid_out : out std_logic
    );

end entity config_read_multiplexer;

architecture vhdl_rtl of config_read_multiplexer is
  constant NOVALID : std_logic_vector(NCONFIG_LINES-1 downto 0) := (others => '0');
  signal config_data_out_reg  : config_word := (others => '0');
  signal config_valid_out_reg : std_logic   := '0';
begin

  config_data_out  <= config_data_out_reg;
  config_valid_out <= config_valid_out_reg;

  multiplexer : process (clock)
  begin    
    if rising_edge(clock) then
      for I in 0 to NCONFIG_LINES-1 loop
        if (config_valid_in(I) = '1') then
          config_data_out_reg  <= config_data_in(I);
          config_valid_out_reg <= '1';
        end if;
      end loop;
      if (config_valid_in = NOVALID) then
        config_valid_out_reg <= '0';
      end if;
    end if;
  end process;
end architecture;


