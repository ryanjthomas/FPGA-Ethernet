library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

entity testbench is
  generic (
    source_ip_addr  : std_logic_vector(31 downto 0) := X"C0_A8_00_01";
    dest_ip_addr    : std_logic_vector(31 downto 0) := X"C0_A8_00_02";
    source_mac_addr : std_logic_vector(47 downto 0) := X"EE_11_22_33_44_55";
    dest_mac_addr   : std_logic_vector(47 downto 0) := X"EE_11_22_33_44_56"
    );
end testbench;

architecture tb of testbench is
  constant NFIFOS             : natural                            := n_in_fifos;
  subtype word is std_logic_vector(31 downto 0);
  type time_array is array (integer range <>) of time;
  --Simulation signals
  constant clock_period       : time                               := 5 ns;
  signal clock                : std_logic;
  signal reset                : std_logic;
  signal sim_start            : std_logic                          := '0';
  signal sim_running          : std_logic                          := '0';
  signal sim_end              : std_logic                          := '0';
  constant wrclk_periods      : time_array(0 to NFIFOS-1)          := (0      => 30 ns, 1 => 50 ns, others => 60 ns);
  signal wrclks               : std_logic_vector(0 to NFIFOS-1)    := (others => '0');
  signal wrreq                : std_logic_vector(0 to NFIFOS-1)    := (others => '0');
  signal wrfull               : std_logic_vector(0 to NFIFOS-1)    := (others => '0');
  signal data_in              : data_array(0 to NFIFOS-1)          := (others => (others => '0'));
  signal tx_ready             : std_logic                          := '1';
  --Testbench parameters
  constant reset_start_t      : time                               := 50 ns;
  constant reset_end_t        : time                               := 100 ns;
  constant sim_start_t        : time                               := reset_end_t + 40 ns;
  --Ethernet FG config
  constant fg_payload_max_len : std_logic_vector(8 downto 0)       := std_logic_vector(to_unsigned(350, 9));
  constant fg_FIFO_in_dly     : std_logic_vector(3 downto 0)       := "0101";
  constant fg_FIFO_out_dly    : std_logic_vector(3 downto 0)       := "0000";
  --IFM parameters
  constant ifm_payload_size   : in_fifo_usedw_array(0 to NFIFOS-1) := (others => (std_logic_vector(to_unsigned(100, 11))));
  constant ifm_flags          : in_fifo_flag_array(0 to NFIFOS-1)  := (others => INFIFO_ENABLE);
  --Outputs
  signal data_out             : word;
  signal sop                  : std_logic;
  signal eop                  : std_logic;

  component ethernet_data_block is
    generic (
      NFIFOS : natural);
    port (
      clock              : in  std_logic;
      reset              : in  std_logic;
      wrclks             : in  std_logic_vector(0 to NFIFOS-1);
      wrreqs             : in  std_logic_vector(0 to NFIFOS-1);
      data_in            : in  data_array(0 to NFIFOS-1);
      wrfull             : out std_logic_vector(0 to NFIFOS-1);
      data_out           : out word;
      tx_ready           : in  std_logic;
      sop                : out std_logic;
      eop                : out std_logic;
      ifm_flags          : in  in_fifo_flag_array(0 to NFIFOS-1);
      ifm_payload_size   : in  in_fifo_usedw_array(0 to NFIFOS-1);
      source_mac_addr    : in  std_logic_vector(47 downto 0);
      dest_mac_addr      : in  std_logic_vector(47 downto 0);
      source_ip_addr     : in  std_logic_vector(31 downto 0);
      dest_ip_addr       : in  std_logic_vector(31 downto 0);
      fg_payload_max_len : in  std_logic_vector(8 downto 0);
      fg_FIFO_in_dly     : in  std_logic_vector(3 downto 0);
      fg_FIFO_out_dly    : in  std_logic_vector(3 downto 0);
      --Base UDP port
      base_udp_port      : in  udp_port;
      header_config      : in  std_logic_vector(31 downto 0));

  end component ethernet_data_block;

begin

  eblock : entity work.ethernet_data_block
    generic map (
      NFIFOS => NFIFOS)
    port map (
      clock              => clock,
      reset              => reset,
      wrclks             => wrclks,
      wrreqs              => wrreq,
      data_in            => data_in,
      wrfull             => wrfull,
      tx_ready           => tx_ready,
      data_out           => data_out,
      sop                => sop,
      eop                => eop,
      ifm_payload_size   => ifm_payload_size,
      ifm_flags          => ifm_flags,
      source_mac_addr    => source_mac_addr,
      dest_mac_addr      => dest_mac_addr,
      source_ip_addr     => source_ip_addr,
      dest_ip_addr       => dest_ip_addr,
      fg_payload_max_len => fg_payload_max_len,
      fg_FIFO_in_dly     => fg_FIFO_in_dly,
      fg_FIFO_out_dly    => fg_FIFO_out_dly,
      fg_gen_crc => '0',
      base_udp_port => X"1000",
      header_config => (others => '1'));

  reset       <= '0', '1' after reset_start_t, '0' after reset_end_t;
  sim_start   <= '0', '1' after sim_start_t;
  sim_running <= sim_start and not sim_end;


  --Clock generation  
  --Main clock, 100 MHz

  process
  begin
    clock <= '1'; wait for clock_period;
    clock <= '0'; wait for clock_period;
  end process;

  wrclk_gen : for I in wrclks'range generate
    process
    begin
      wrclks(I) <= '1'; wait for wrclk_periods(I);
      wrclks(I) <= '0'; wait for wrclk_periods(I);
    end process;
  end generate wrclk_gen;

  data_gen : for I in wrclks'range generate
    process (wrclks(I), reset)
      variable counter : natural := 0;
    begin
      if (reset = '1') then
        counter  := 0;
        wrreq(I) <= '0';
      elsif (rising_edge(wrclks(I))) then
        if (sim_start = '1') then
          data_in(I) <= std_logic_vector(to_unsigned(counter, data_in(0)'length));
          wrreq(I)   <= '1';
          counter    := counter+1;
        else
          wrreq(I) <= '0';
        end if;
      end if;

    end process;
  end generate data_gen;

  end_sim : process (clock)
    variable counter : natural := 0;
  begin
    if (rising_edge(clock)) then
      if (sim_end = '1') then
        counter := counter + 1;
      end if;
    -- if (counter > 5) then
    --   assert false report "end of simulation" severity failure;
    -- end if;                           
    end if;
  end process end_sim;

end architecture tb;




