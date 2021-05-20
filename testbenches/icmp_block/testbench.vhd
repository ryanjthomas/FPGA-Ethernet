library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

entity testbench is
  generic (
    source_ip_addr  : ip_addr  := X"C0_A8_00_03";
    dest_ip_addr    : ip_addr  := X"C0_A8_00_01";
    source_mac_addr : mac_addr := X"EE_11_22_33_44_55";
    dest_mac_addr   : mac_addr := X"EE_11_22_33_44_56"
    );
end testbench;

architecture tb of testbench is

  component icmp_block is
    port (
      clock           : in  std_logic;
      reset           : in  std_logic;
      data_out        : out word      := (others => '0');
      sop             : out std_logic := '0';
      eop             : out std_logic := '0';
      dval            : out std_logic := '0';
      fr_data_out      : in  word      := (others => '0');
      fr_dval         : in  std_logic;
      fr_eop          : in  std_logic;
      icmp_ping       : in  std_logic;
      tx_ready        : in  std_logic;
      busy            : out std_logic := '0';
      source_mac_addr : in  mac_addr;
      dest_mac_addr   : in  mac_addr;
      source_ip_addr  : in  ip_addr;
      dest_ip_addr    : in  ip_addr);
  end component icmp_block;

  constant clock_period : time := 5 ns;

  signal clock            : std_logic := '0';
  signal reset            : std_logic := '0';
  signal sim_start        : std_logic := '0';
  signal sim_running      : std_logic := '0';
  signal sim_end          : std_logic := '0';
  constant reset_start_t  : time      := 50 ns;
  constant reset_end_t    : time      := 100 ns;
  constant sim_start_t    : time      := reset_end_t + 40 ns;
  constant header_start_t : time      := sim_start_t + 40 ns;
  constant header_end_t   : time      := header_start_t + 2*clock_period;
  constant tx_ready_delay : time      := 100 ns;

  signal data_out       : word := (others => '0');
  signal sop            : std_logic := '0';
  signal eop            : std_logic := '0';
  signal dval           : std_logic := '0';
  signal busy           : std_logic := '0';
  signal icmp_ping : std_logic := '0';
  signal tx_ready       : std_logic := '0';
  signal fr_data_out : word := (others => '0');
  signal fr_dval : std_logic := '0';
  signal fr_eop : std_logic := '0';
  
begin

  icmpblock: entity work.icmp_block
    port map (
      clock           => clock,
      reset           => reset,
      data_out        => data_out,
      sop             => sop,
      eop             => eop,
      dval            => dval,
      fr_data_out      => fr_data_out,
      fr_dval         => fr_dval,
      fr_eop          => fr_eop,
      icmp_ping       => icmp_ping,
      tx_ready        => tx_ready,
      busy            => busy,
      source_mac_addr => source_mac_addr,
      dest_mac_addr   => dest_mac_addr,
      source_ip_addr  => source_ip_addr,
      dest_ip_addr    => dest_ip_addr);
  
  reset          <= '0', '1' after reset_start_t, '0' after reset_end_t;
  sim_start      <= '0', '1' after sim_start_t;
  tx_ready       <= '0', '1' after header_end_t+tx_ready_delay;
  sim_running    <= sim_start and not sim_end;

  --Clock generation  
  --Main clock, 100 MHz

  process
  begin
    clock <= '1'; wait for clock_period;
    clock <= '0'; wait for clock_period;
  end process;

  --Generate a simulated ICMP payload
  icmp_requester : process(clock, reset)
    variable word_num : natural := 0;
  begin
    if reset = '1' then
      fr_data_out <= (others => '0');
      fr_dval <= '0';
    elsif rising_edge(clock) and sim_start = '1' then
      --Send an ICMP request
      --The ICMP payload
      if word_num = 30 then
        fr_data_out <= X"58_f1_00_01";
        icmp_ping <= '1';
        fr_dval <= '1';
      --ARP Payload
      elsif word_num = 31 then
        fr_data_out <= X"92_19_85_5d";
      elsif word_num = 32 then
        fr_data_out <= X"00_00_00_00";
      elsif word_num = 33 then
        fr_data_out <= X"1b_8c_03_00";
      elsif word_num = 34 then
        fr_data_out <= X"00_00_00_00";
      elsif word_num = 35 then
        fr_data_out <= X"10_11_12_13";
      elsif word_num = 36 then
        fr_data_out <= X"14_15_16_17";
      elsif word_num = 37 then
        fr_data_out <= X"18_19_1a_1b";
      elsif word_num = 38 then
        fr_data_out <= X"1c_1d_1e_1f";
      elsif word_num = 39 then
        fr_data_out <= X"20_21_22_23";
      elsif word_num = 40 then
        fr_data_out <= X"24_25_26_27";
      elsif word_num = 41 then
        fr_data_out <= X"28_29_2a_2b";
      elsif word_num = 42 then
        fr_data_out <= X"2c_2d_2e_2f";
      elsif word_num = 43 then
        fr_data_out <= X"30_31_32_33";
      elsif word_num = 44 then
        fr_data_out <= X"34_35_36_37";
        fr_eop  <= '1';        
      else
        fr_data_out <= (others => '0');
        fr_dval <= '0';
        fr_eop <= '0';
      end if;

      if word_num < 100 then
        word_num := word_num + 1;
      end if;
    end if;
  end process icmp_requester;
  
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




