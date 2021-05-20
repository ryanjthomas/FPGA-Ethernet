library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;
entity testbench is
  generic (
    src_ip          : std_logic_vector(31 downto 0) := X"C0_A8_00_01";
    dest_ip         : std_logic_vector(31 downto 0) := X"C0_A8_00_02";
    source_mac_addr : std_logic_vector(47 downto 0) := X"EE_11_22_33_44_55";
    dest_mac_addr   : std_logic_vector(47 downto 0) := X"EE_11_22_33_44_56"
    );
end testbench;

architecture tb of testbench is
  component header_generator is
    generic (
      MAX_FRAME_BITS : natural);
    port (
      --The clock
      clock           : in  std_logic;
      reset           : in  std_logic;
      --Output header
      header_data     : out std_logic_vector(31 downto 0);
      --High when header_data is valid
      header_valid    : out std_logic;
      --Probably doesn't need to be this long
      --This is for the retransmission modifier, so we know where the app header
      --is
      header_len      : out std_logic_vector(8 downto 0);
      header_done     : out std_logic;
      --Input to start generating header
      header_start    : in  std_logic;
      protocol        : in  std_logic_vector(7 downto 0);
      app_header      : in  std_logic_vector(31 downto 0);
      config          : in  std_logic_vector(31 downto 0);
      payload_len     : in  std_logic_vector(8 downto 0);
      --Ethernet frame header
      source_mac_addr : in  std_logic_vector(47 downto 0);
      dest_mac_addr   : in  std_logic_vector(47 downto 0);
      ether_type      : in  std_logic_vector(15 downto 0);      
      --IPv4 Header info
      source_ip       : in  std_logic_vector(31 downto 0);
      dest_ip         : in  std_logic_vector(31 downto 0);
      --UDP header info
      source_port     : in  std_logic_vector(15 downto 0);
      dest_port       : in  std_logic_vector(15 downto 0)
      );

  end component header_generator;

  subtype word is std_logic_vector(31 downto 0);

  constant clk_period : time := 5 ns;

  signal clk         : std_logic;
  signal reset       : std_logic;
  signal sim_start   : std_logic := '0';
  signal sim_running : std_logic := '0';
  signal sim_end     : std_logic := '0';

  signal header_data  : word;
  signal header_valid : std_logic;
  signal header_len   : std_logic_vector(8 downto 0);
  signal header_start : std_logic;
  signal header_done  : std_logic;

  signal protocol   : std_logic_vector(7 downto 0) := X"11";  --UDP
  signal frame_num  : std_logic_vector(6 downto 0) := (others => '0');
  signal app_header : std_logic_vector(31 downto 0);

  signal packet_len : std_logic_vector(15 downto 0);

  signal dest_port   : std_logic_vector(15 downto 0) := X"00_C0";
  signal source_port : std_logic_vector(15 downto 0) := X"00_00";
  signal payload_len : std_logic_vector(8 downto 0)  := std_logic_vector(to_unsigned(300, 9));

  constant reset_start_t  : time := 50 ns;
  constant reset_end_t    : time := 100 ns;
  constant sim_start_t    : time := reset_end_t + 40 ns;
  constant header_start_t : time := sim_start_t + 40 ns;
  constant header_end_t   : time := header_start_t + 2*clk_period;

begin

  hdgen : header_generator
    generic map (
      MAX_FRAME_BITS => MAX_FRAME_BITS)
    port map (
      clock           => clk,
      reset           => reset,
      header_data     => header_data,
      header_valid    => header_valid,
      header_len      => header_len,
      header_start    => header_start,
      header_done     => header_done,
      protocol        => protocol,
      app_header      => app_header,
      config => (others => '1'),
      payload_len     => payload_len,
      source_mac_addr => source_mac_addr,
      dest_mac_addr   => dest_mac_addr,
      ether_type => X"0800",
      source_ip       => src_ip,
      dest_ip         => dest_ip,
      source_port     => source_port,
      dest_port       => dest_port
      );

  reset        <= '0', '1' after reset_start_t, '0' after reset_end_t;
  sim_start    <= '0', '1' after sim_start_t;
  header_start <= '0', '1' after header_start_t, '0' after header_end_t;
--   sim_end <= sim_start and header_done;
  sim_running  <= sim_start and not sim_end;
  app_header   <= X"00_12_34_56";
  packet_len   <= std_logic_vector(to_unsigned(300, packet_len'length));

  --Clock generation  
  --Main clock, 100 MHz

  process
  begin
    clk <= '1'; wait for clk_period;
    clk <= '0'; wait for clk_period;
  end process;


  end_sim : process (clk)
    variable counter : natural := 0;
  begin
    if (rising_edge(clk)) then
      if (header_done = '1') then
        sim_end <= '1';
      end if;
      if (sim_end = '1') then

        counter := counter + 1;
      end if;

      if (counter > 5) then
        assert false report "end of simulation" severity failure;
      end if;
    end if;
  end process end_sim;

end architecture tb;




