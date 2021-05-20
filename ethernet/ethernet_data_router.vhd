-------------------------------------------------------------------------------
-- Title      : Ethernet Data Router
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ethernet_data_router.vhd
-- Author     : Ryan Thomas 
-- Company    : University of Chicago
-- Created    : 2019-09-27
-- Last update: 2020-08-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Routes data from the 3x ethernet interfaces to different
-- components (based on destination UDP addresses). Currently only routes
-- serial configuration data and data loopback and passes through everything
-- else (so downstream blocks can use it).
-------------------------------------------------------------------------------

--!\file ethernet_data_router.vhd


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

--!\brief Routes UDP data from DAQ to other components based on UDP port.
--!
--! Not all data is routed in this block. Data not routed to other locations
--! is sent out on eth_data lines and can be used by other logic on the ODILE
--! board.

entity ethernet_data_router is
  port (
    clock           : in  std_logic;
    reset           : in  std_logic;
    ---------------------------------------------------------------------------
    --!\name Inputs
    --!\{
    ---------------------------------------------------------------------------
    --Interface 0
    data_in0        : in  std_logic_vector(31 downto 0);
    data_valid0     : in  std_logic;
    data_port0      : in  std_logic_vector(15 downto 0);
    data_addr0      : in  std_logic_vector(79 downto 0);
    --Interface 1
    data_in1        : in  std_logic_vector(31 downto 0);
    data_valid1     : in  std_logic;
    data_port1      : in  std_logic_vector(15 downto 0);
    data_addr1      : in  std_logic_vector(79 downto 0);
    --Interface 2
    data_in2        : in  std_logic_vector(31 downto 0);
    data_valid2     : in  std_logic;
    data_port2      : in  std_logic_vector(15 downto 0);
    data_addr2      : in  std_logic_vector(79 downto 0);
    --For internally generated data
    int_data_in     : in  std_logic_vector(31 downto 0);
    int_valid_in    : in  std_logic;
    int_port_in     : in  std_logic_vector(15 downto 0);
    --!\}
    ---------------------------------------------------------------------------
    -- Outputs
    ---------------------------------------------------------------------------
    --!\name Configuration register data
    --!\{
    config_data_out : out std_logic_vector(31 downto 0) := (others => '0');
    config_valid    : out std_logic                     := '0';
    --!\}
    --Loopback
    --!\name Loopback data to other interfaces
    --!\{
    loopback_data0  : out std_logic_vector(31 downto 0) := (others => '0');
    loopback_wrreq0 : out std_logic                     := '0';
    loopback_data1  : out std_logic_vector(31 downto 0) := (others => '0');
    loopback_wrreq1 : out std_logic                     := '0';
    loopback_data2  : out std_logic_vector(31 downto 0) := (others => '0');
    loopback_wrreq2 : out std_logic                     := '0';
    --!\}
    --!\name Write to flash memory
    --!\{
    --Write to EPCQIO directly
    epcqio_data_out : out std_logic_vector(31 downto 0) := (others => '0');
    epcqio_valid    : out std_logic                     := '0';
    --!\}
    --!\name Passthrough data that isn't routed here
    --!\{
    eth_data_out    : out std_logic_vector(31 downto 0) := (others => '0');
    eth_data_port   : out std_logic_vector(15 downto 0) := (others => '0');
    eth_data_valid  : out std_logic                     := '0';
    eth_data_addr   : out std_logic_vector(79 downto 0) := (others => '0');
    --\}
    --! Source interface for data on data_out lines
    source_iface    : out std_logic_vector(3 downto 0)  := (others => '0')
    );

end entity ethernet_data_router;

architecture vhdl_rtl of ethernet_data_router is
  signal loopback_data    : data_array(2 downto 0)       := (others => (others => '0'));
  signal loopback_wrreqs  : std_logic_vector(2 downto 0) := (others => '0');
  signal source_iface_reg : std_logic_vector(3 downto 0) := (others => '0');
begin
  loopback_data0  <= loopback_data(0);
  loopback_data1  <= loopback_data(1);
  loopback_data2  <= loopback_data(2);
  loopback_wrreq0 <= loopback_wrreqs(0);
  loopback_wrreq1 <= loopback_wrreqs(1);
  loopback_wrreq2 <= loopback_wrreqs(2);
  source_iface    <= source_iface_reg;

  -----------------------------------------------------------------------------
  --!Routes incoming data from the appropriate UDP port to the configuration lines
  -----------------------------------------------------------------------------
  config_router : process(clock, reset)
  begin
    if (reset = '1') then
      config_valid    <= '0';
      config_data_out <= (others => '0');
    elsif rising_edge(clock) then
      -------------------------------------------------------------------------
      -- Interface 0 (fiber)
      -------------------------------------------------------------------------
      if data_valid0 = '1' and data_port0 = UDP_PORT_CONFIG then
        config_data_out <= data_in0;
        config_valid    <= '1';
      -------------------------------------------------------------------------
      -- Interface 1 (fiber)
      -------------------------------------------------------------------------
      elsif data_valid1 = '1' and data_port1 = UDP_PORT_CONFIG then
        config_data_out <= data_in1;
        config_valid    <= '1';
      -------------------------------------------------------------------------
      -- Interface 2 (copper)
      -------------------------------------------------------------------------
      elsif data_valid2 = '1' and data_port2 = UDP_PORT_CONFIG then
        config_data_out <= data_in2;
        config_valid    <= '1';
      -------------------------------------------------------------------------
      -- Internally generated data
      -------------------------------------------------------------------------        
      elsif int_valid_in = '1' and int_port_in = UDP_PORT_CONFIG then
        config_data_out <= int_data_in;
        config_valid    <= '1';        
      else
        config_data_out <= (others => '0');
        config_valid    <= '0';
      end if;
    end if;
  end process config_router;

  -----------------------------------------------------------------------------
  --!Routes incoming data to the appropriate loopback interface
  -----------------------------------------------------------------------------
  loopback_routers : process(clock, reset)
  begin
    if (reset = '1') then
      loopback_wrreqs <= (others => '0');
      loopback_data   <= (others => (others => '0'));
    elsif rising_edge(clock) then
      for I in 0 to 2 loop
        -------------------------------------------------------------------------
        -- Interface 0 (fiber)
        -------------------------------------------------------------------------
        if data_valid0 = '1' and data_port0 = UDP_PORT_LOOPBACKS(I) then
          loopback_data(I)   <= data_in0;
          loopback_wrreqs(I) <= '1';
        -------------------------------------------------------------------------
        -- Interface 1 (fiber)
        -------------------------------------------------------------------------
        elsif data_valid1 = '1' and data_port1 = UDP_PORT_LOOPBACKS(I) then
          loopback_data(I)   <= data_in1;
          loopback_wrreqs(I) <= '1';
        -------------------------------------------------------------------------
        -- Interface 2 (copper)
        -------------------------------------------------------------------------
        elsif data_valid2 = '1' and data_port2 = UDP_PORT_LOOPBACKS(I) then
          loopback_data(I)   <= data_in2;
          loopback_wrreqs(I) <= '1';
        -------------------------------------------------------------------------
        -- Internally generated data. Generally shouldn't ever be used
        -------------------------------------------------------------------------        
        elsif int_valid_in = '1' and int_port_in = UDP_PORT_LOOPBACKS(I) then
          loopback_data(I)   <= int_data_in;
          loopback_wrreqs(I) <= '1';
        else
          loopback_data(I)   <= (others => '0');
          loopback_wrreqs(I) <= '0';
        end if;
      end loop;
    end if;
  end process loopback_routers;

  -----------------------------------------------------------------------------
  --! Routes incoming data from the appropriate UDP port to the EPCQIO control
  --! interface. Note that this data is only written to a write buffer, a write
  --! command is usually required to actually write the data
  -----------------------------------------------------------------------------
  epcqio_router : process(clock, reset)
  begin
    if (reset = '1') then
      epcqio_valid    <= '0';
      epcqio_data_out <= (others => '0');
    elsif rising_edge(clock) then
      -------------------------------------------------------------------------
      -- Interface 0 (fiber)
      -------------------------------------------------------------------------
      if data_valid0 = '1' and data_port0 = UDP_PORT_EPCQIO then
        epcqio_data_out <= data_in0;
        epcqio_valid    <= '1';
      -------------------------------------------------------------------------
      -- Interface 1 (fiber)
      -------------------------------------------------------------------------
      elsif data_valid1 = '1' and data_port1 = UDP_PORT_EPCQIO then
        epcqio_data_out <= data_in1;
        epcqio_valid    <= '1';
      -------------------------------------------------------------------------
      -- Interface 2 (copper)
      -------------------------------------------------------------------------
      elsif data_valid2 = '1' and data_port2 = UDP_PORT_EPCQIO then
        epcqio_data_out <= data_in2;
        epcqio_valid    <= '1';
      -------------------------------------------------------------------------
      -- Internal data. Currently disabled
      -------------------------------------------------------------------------        
      elsif int_valid_in = '1' and int_port_in = UDP_PORT_EPCQIO then
        epcqio_data_out <= int_data_in;
        epcqio_valid    <= '0';
      else
        epcqio_data_out <= (others => '0');
        epcqio_valid    <= '0';
      end if;
    end if;
  end process epcqio_router;

  -----------------------------------------------------------------------------
  --! Passes through all valid data from Ethernet interfaces. Note it is the
  --! reponsibility of the downstream block to ensure the information is
  --! directed at it or not.
  -----------------------------------------------------------------------------
  data_passthrough : process(clock)
  begin
    if rising_edge(clock) then
      if data_valid0 = '1' then
        eth_data_out   <= data_in0;
        eth_data_port  <= data_port0;
        eth_data_valid <= '1';
        eth_data_addr  <= data_addr0;
      elsif data_valid1 = '1' then
        eth_data_out   <= data_in1;
        eth_data_port  <= data_port1;
        eth_data_valid <= '1';
        eth_data_addr  <= data_addr1;
      elsif data_valid2 = '1' then
        eth_data_out   <= data_in2;
        eth_data_port  <= data_port2;
        eth_data_valid <= '1';
        eth_data_addr  <= data_addr2;
      elsif int_valid_in = '1' then
        eth_data_out <= int_data_in;
        eth_data_port <= int_port_in;
        eth_data_valid <= '1';
        --No mac address, IP address 127.0.0.1
        eth_data_addr <= X"00_00_00_00_00_00_7F_00_00_01";
      else
        eth_data_out   <= (others => '0');
        eth_data_valid <= '0';
        --We can hold previous port/address values
      end if;
    end if;
  end process data_passthrough;

  --! Source interface register. Sends out the current interface which is recieving valid data.
  --! "0001" is port 0, "0010" is port 1, and "0100" is port 2. 
  source_iface_register : process (clock)
  begin
    if rising_edge(clock) then
      if data_valid0 = '1' then
        source_iface_reg <= "0001";
      elsif data_valid1 = '1' then
        source_iface_reg <= "0010";
      elsif data_valid2 = '1' then
        source_iface_reg <= "0100";
      elsif int_valid_in = '1' then
        source_iface_reg <= "1000";
      else
        source_iface_reg <= "0000";
      end if;
    end if;
  end process;


end architecture vhdl_rtl;


