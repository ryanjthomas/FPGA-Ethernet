-- (C) 2001-2013 Altera Corporation. All rights reserved.
-- Your use of Altera Corporation's design tools, logic functions and other 
-- software and tools, and its AMPP partner logic functions, and any output 
-- files any of the foregoing (including device programming or simulation 
-- files), and any associated documentation or information are expressly subject 
-- to the terms and conditions of the Altera Program License Subscription 
-- Agreement, Altera MegaCore Function License Agreement, or other applicable 
-- license agreement, including, without limitation, that your use is for the 
-- sole purpose of programming logic devices manufactured by Altera and sold by 
-- Altera or its authorized distributors.  Please refer to the applicable 
-- agreement for further details.


-- -------------------------------------------------------------------------
-- -------------------------------------------------------------------------
--
-- Revision Control Information
--
-- $RCSfile: mdio_reg.vhd,v $
-- $Source: /ipbu/cvs/sio/projects/TriSpeedEthernet/src/testbench/models/vhdl/mdio/mdio_reg.vhd,v $
--
-- $Revision: #1 $
-- $Date: 2013/03/07 $
-- Check in by : $Author: swbranch $
-- Author      : SKNg/TTChong
--
-- Project     : Triple Speed Ethernet - 10/100/1000 MAC
--
-- Description : (Simulation only)
--
-- MDIO Slave's Register Map
-- Instantiated in top_mdio_slave (top_mdio_slave.vhd)
--
-- 
-- ALTERA Confidential and Proprietary
-- Copyright 2006 (c) Altera Corporation
-- All rights reserved
--
-- -------------------------------------------------------------------------
-- -------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity mdio_reg_sim is port (

  reset : in std_logic;
  clk   : in std_logic;                 -- MDIO 2.5MHz Clock

  -- MDIO Controller Interface
  -- -------------------------

  reg_addr  : in  std_logic_vector(4 downto 0);   -- Address Register
  reg_write : in  std_logic;                      -- Write Register       
  reg_read  : in  std_logic;                      -- Read Register        
  reg_dout  : out std_logic_vector(15 downto 0);  -- Data Bus OUT
  reg_din   : in  std_logic_vector(15 downto 0);  -- Data Bus IN

  -- Status
  -- ------

  conf_done : out std_logic);           -- PHY Config Done

end mdio_reg_sim;

architecture a of mdio_reg_sim is
  constant pattern : std_logic_vector(15 downto 0) := "1010101010101010";
  signal reg_0     : std_logic_vector(15 downto 0);
  signal reg_1     : std_logic_vector(15 downto 0);
  signal reg_2     : std_logic_vector(15 downto 0);
  signal reg_3     : std_logic_vector(15 downto 0);
  signal reg_4     : std_logic_vector(15 downto 0);
  signal reg_5     : std_logic_vector(15 downto 0);
  signal reg_6     : std_logic_vector(15 downto 0);
  signal reg_7     : std_logic_vector(15 downto 0);
  signal reg_8     : std_logic_vector(15 downto 0);
  signal reg_9     : std_logic_vector(15 downto 0);
  signal reg_10    : std_logic_vector(15 downto 0);
  signal reg_11    : std_logic_vector(15 downto 0);
  signal reg_12    : std_logic_vector(15 downto 0);
  signal reg_13    : std_logic_vector(15 downto 0);
  signal reg_14    : std_logic_vector(15 downto 0);
  signal reg_15    : std_logic_vector(15 downto 0);
  signal reg_16    : std_logic_vector(15 downto 0);
  signal reg_17    : std_logic_vector(15 downto 0);
  signal reg_18    : std_logic_vector(15 downto 0);
  signal reg_19    : std_logic_vector(15 downto 0);
  signal reg_20    : std_logic_vector(15 downto 0);
  signal reg_21    : std_logic_vector(15 downto 0);
  signal reg_22    : std_logic_vector(15 downto 0);
  signal reg_23    : std_logic_vector(15 downto 0);
  signal reg_24    : std_logic_vector(15 downto 0);
  signal reg_25    : std_logic_vector(15 downto 0);
  signal reg_26    : std_logic_vector(15 downto 0);
  signal reg_27    : std_logic_vector(15 downto 0);
  signal reg_28    : std_logic_vector(15 downto 0);
  signal reg_29    : std_logic_vector(15 downto 0);
  signal reg_30    : std_logic_vector(15 downto 0);
  signal reg_31    : std_logic_vector(15 downto 0);

begin

  -- MDIO Registers
  -- --------------

  process(reset, clk)
  begin

    if (reset = '1') then

      reg_0  <= pattern;
      reg_1  <= pattern;
      reg_2  <= pattern;
      reg_3  <= pattern;
      reg_4  <= pattern;
      reg_5  <= pattern;
      reg_6  <= pattern;
      reg_7  <= pattern;
      reg_8  <= pattern;
      reg_9  <= pattern;
      reg_10 <= pattern;
      reg_11 <= pattern;
      reg_12 <= pattern;
      reg_13 <= pattern;
      reg_14 <= pattern;
      reg_15 <= pattern;
      reg_16 <= pattern;
      reg_17 <= pattern;
      reg_18 <= pattern;
      reg_19 <= pattern;
      reg_20 <= pattern;
      reg_21 <= pattern;
      reg_22 <= pattern;
      reg_23 <= pattern;
      reg_24 <= pattern;
      reg_25 <= pattern;
      reg_26 <= pattern;
      reg_27 <= pattern;
      reg_28 <= pattern;
      reg_29 <= pattern;
      reg_30 <= pattern;
      reg_31 <= pattern;

      conf_done <= '0';

    elsif (clk = '1') and (clk'event) then

      if (reg_write = '1') then

        if (reg_addr = "00000") then

          reg_0     <= reg_din;
          conf_done <= '1';

        elsif (reg_addr = "00001") then

          reg_1 <= reg_din;

        elsif (reg_addr = "00010") then

          reg_2 <= reg_din;

        elsif (reg_addr = "00011") then

          reg_3 <= reg_din;

        elsif (reg_addr = "00100") then

          reg_4 <= reg_din;

        elsif (reg_addr = "00101") then

          reg_5 <= reg_din;

        elsif (reg_addr = "00110") then

          reg_6 <= reg_din;

        elsif (reg_addr = "00111") then

          reg_7 <= reg_din;

        elsif (reg_addr = "01000") then

          reg_8 <= reg_din;

        elsif (reg_addr = "01001") then

          reg_9 <= reg_din;

        elsif (reg_addr = "01010") then

          reg_10 <= reg_din;

        elsif (reg_addr = "01011") then

          reg_11 <= reg_din;

        elsif (reg_addr = "01100") then

          reg_12 <= reg_din;

        elsif (reg_addr = "01101") then

          reg_13 <= reg_din;

        elsif (reg_addr = "01110") then

          reg_14 <= reg_din;

        elsif (reg_addr = "01111") then

          reg_15 <= reg_din;

        elsif (reg_addr = "10000") then

          reg_16 <= reg_din;

        elsif (reg_addr = "10001") then

          reg_17 <= reg_din;

        elsif (reg_addr = "10010") then

          reg_18 <= reg_din;

        elsif (reg_addr = "10011") then

          reg_19 <= reg_din;

        elsif (reg_addr = "10100") then

          reg_20 <= reg_din;

        elsif (reg_addr = "10101") then

          reg_21 <= reg_din;

        elsif (reg_addr = "10110") then

          reg_22 <= reg_din;

        elsif (reg_addr = "10111") then

          reg_23 <= reg_din;

        elsif (reg_addr = "11000") then

          reg_24 <= reg_din;

        elsif (reg_addr = "11001") then

          reg_25 <= reg_din;

        elsif (reg_addr = "11010") then

          reg_26 <= reg_din;

        elsif (reg_addr = "11011") then

          reg_27 <= reg_din;

        elsif (reg_addr = "11100") then

          reg_28 <= reg_din;

        elsif (reg_addr = "11101") then

          reg_29 <= reg_din;

        elsif (reg_addr = "11110") then

          reg_30 <= reg_din;

        elsif (reg_addr = "11111") then

          reg_31 <= reg_din;

        end if;

      end if;

    end if;

  end process;

  -- Data MUX
  -- --------

  process(reg_addr, reg_write)
  begin

    if (reg_addr = "00000") then

      reg_dout <= reg_0;

    elsif (reg_addr = "00001") then

      reg_dout <= reg_1;

    elsif (reg_addr = "00010") then

      reg_dout <= reg_2;

    elsif (reg_addr = "00011") then

      reg_dout <= reg_3;

    elsif (reg_addr = "00100") then

      reg_dout <= reg_4;

    elsif (reg_addr = "00101") then

      reg_dout <= reg_5;

    elsif (reg_addr = "00110") then

      reg_dout <= reg_6;

    elsif (reg_addr = "00111") then

      reg_dout <= reg_7;

    elsif (reg_addr = "01000") then

      reg_dout <= reg_8;

    elsif (reg_addr = "01001") then

      reg_dout <= reg_9;

    elsif (reg_addr = "01010") then

      reg_dout <= reg_10;

    elsif (reg_addr = "01011") then

      reg_dout <= reg_11;

    elsif (reg_addr = "01100") then

      reg_dout <= reg_12;

    elsif (reg_addr = "01101") then

      reg_dout <= reg_13;

    elsif (reg_addr = "01110") then

      reg_dout <= reg_14;

    elsif (reg_addr = "01111") then

      reg_dout <= reg_15;

    elsif (reg_addr = "10000") then

      reg_dout <= reg_16;

    elsif (reg_addr = "10001") then

      reg_dout <= reg_17;

    elsif (reg_addr = "10010") then

      reg_dout <= reg_18;

    elsif (reg_addr = "10011") then

      reg_dout <= reg_19;

    elsif (reg_addr = "10100") then

      reg_dout <= reg_20;

    elsif (reg_addr = "10101") then

      reg_dout <= reg_21;

    elsif (reg_addr = "10110") then

      reg_dout <= reg_22;

    elsif (reg_addr = "10111") then

      reg_dout <= reg_23;

    elsif (reg_addr = "11000") then

      reg_dout <= reg_24;

    elsif (reg_addr = "11001") then

      reg_dout <= reg_25;

    elsif (reg_addr = "11010") then

      reg_dout <= reg_26;

    elsif (reg_addr = "11011") then

      reg_dout <= reg_27;

    elsif (reg_addr = "11100") then

      reg_dout <= reg_28;

    elsif (reg_addr = "11101") then

      reg_dout <= reg_29;

    elsif (reg_addr = "11110") then

      reg_dout <= reg_30;

    elsif (reg_addr = "11111") then

      reg_dout <= reg_31;

    end if;

  end process;

end a;
