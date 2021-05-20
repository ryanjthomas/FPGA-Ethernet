library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

entity testbench is
  generic (
    source_ip_addr  : ip_addr  := X"C0_A8_00_03";
    dest_ip_addr    : ip_addr  := X"C0_A8_00_01";
    source_mac_addr : mac_addr := X"EE_11_22_33_44_55";
    dest_mac_addr   : mac_addr := X"EE_11_22_33_44_56";
    req_ip_addr     : ip_addr  := X"C0_A8_00_07"
    );
end testbench;

architecture tb of testbench is

  component arp_block is
    port (
      clock            : in  std_logic;
      reset            : in  std_logic;
      data_out         : out word;
      sop              : out std_logic;
      eop              : out std_logic;
      dval             : out std_logic;
      tx_ready         : in  std_logic;
      busy             : out std_logic;
      generate_reply   : in  std_logic;
      generate_request : in  std_logic;
      source_mac_addr  : in  mac_addr;
      dest_mac_addr    : in  mac_addr;
      source_ip_addr   : in  ip_addr;
      dest_ip_addr     : in  ip_addr;
      req_ip_addr      : in  ip_addr);
  end component arp_block;

  constant clock_period : time := 5 ns;

  signal clock            : std_logic;
  signal reset            : std_logic;
  signal sim_start        : std_logic := '0';
  signal sim_running      : std_logic := '0';
  signal sim_end          : std_logic := '0';
  constant reset_start_t  : time      := 50 ns;
  constant reset_end_t    : time      := 100 ns;
  constant sim_start_t    : time      := reset_end_t + 40 ns;
  constant header_start_t : time      := sim_start_t + 40 ns;
  constant header_end_t   : time      := header_start_t + 2*clock_period;
  constant tx_ready_delay : time      := 100 ns;

  signal data_out         : word;
  signal sop              : std_logic;
  signal eop              : std_logic;
  signal dval             : std_logic;
  signal busy             : std_logic;
  signal generate_reply   : std_logic;
  signal tx_ready         : std_logic;
  signal generate_request : std_logic;


begin

  arpblock : entity work.arp_block
    port map (
      clock            => clock,
      reset            => reset,
      data_out         => data_out,
      sop              => sop,
      eop              => eop,
      dval             => dval,
      tx_ready         => tx_ready,
      busy             => busy,
      generate_reply   => generate_reply,
      generate_request => generate_request,
      source_mac_addr  => source_mac_addr,
      dest_mac_addr    => dest_mac_addr,
      source_ip_addr   => source_ip_addr,
      dest_ip_addr     => dest_ip_addr,
      req_ip_addr      => req_ip_addr);

  reset          <= '0', '1' after reset_start_t, '0' after reset_end_t;
  sim_start      <= '0', '1' after sim_start_t;
  generate_reply <= '0', '1' after header_start_t, '0' after header_end_t;
  tx_ready       <= '0', '1' after header_end_t+tx_ready_delay;
  sim_running    <= sim_start and not sim_end;

  --Clock generation  
  --Main clock, 100 MHz

  process
  begin
    clock <= '1'; wait for clock_period;
    clock <= '0'; wait for clock_period;
  end process;

  end_sim : process (clock)
    variable counter : natural := 0;
  begin
    if (rising_edge(clock)) then
      if (eop = '1') then
        sim_end <= '1';
      end if;
      if (sim_end = '1') then
        counter := counter + 1;
      end if;

      if (counter > 15) then
        assert false report "end of simulation" severity failure;
      end if;
    end if;
  end process end_sim;

end architecture tb;




