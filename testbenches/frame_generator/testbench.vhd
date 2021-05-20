library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

entity testbench is
  generic (
    src_ip          : std_logic_vector(31 downto 0) := X"C0_A8_00_01";
    dest_ip         : std_logic_vector(31 downto 0) := X"C0_A8_00_02";
    source_mac_addr : std_logic_vector(47 downto 0) := X"EE_11_22_33_44_55";
    dest_mac_addr   : std_logic_vector(47 downto 0) := X"EE_11_22_33_44_56";
    gen_crc         : std_logic                     := '1'
    );
end testbench;

architecture tb of testbench is
  component header_generator is
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

  component ethernet_frame_generator is
    generic (
      IN_FIFO_BITS   : in natural;
      MAX_FRAME_BITS : in natural);
    port (
      clock           : in  std_logic;
      reset           : in  std_logic;
      header_data     : in  std_logic_vector(31 downto 0);
      header_valid    : in  std_logic;
      header_done     : in  std_logic;
      header_start    : out std_logic;
      payload_len     : out std_logic_vector(MAX_FRAME_BITS-1 downto 0);
      data_in         : in  std_logic_vector (31 downto 0);
      usedw_in        : in  std_logic_vector (IN_FIFO_BITS-1 downto 0);
      payload_rdy     : in  std_logic;
      rdreq_in        : out std_logic;
      data_out        : out std_logic_vector (31 downto 0) := (others => '0');
      wrreq_out       : out std_logic;
      sop             : out std_logic;
      eop             : out std_logic;
      frame_length    : out std_logic_vector (MAX_FRAME_BITS-1 downto 0);
      frame_rdy       : out std_logic;
      fg_busy         : out std_logic;
      payload_max_len : in  std_logic_vector(MAX_FRAME_BITS-1 downto 0);
      FIFO_in_dly     : in  std_logic_vector (3 downto 0)  := "0101";
      FIFO_out_dly    : in  std_logic_vector (3 downto 0)  := "0101";
      gen_crc         : in  std_logic                      := '0');

  end component ethernet_frame_generator;

  subtype word is std_logic_vector(31 downto 0);

  constant clock_period : time := 5 ns;

  signal clock       : std_logic;
  signal reset       : std_logic;
  signal sim_start   : std_logic := '0';
  signal sim_running : std_logic := '0';
  signal sim_end     : std_logic := '0';


  --Header generator signals
  signal header_data  : word;
  signal header_valid : std_logic;
  signal header_len   : std_logic_vector(8 downto 0);
  signal header_start : std_logic;
  signal header_done  : std_logic;

  signal protocol   : std_logic_vector(7 downto 0) := X"11";  --UDP
  signal frame_num  : std_logic_vector(6 downto 0) := (others => '0');
  signal app_header : std_logic_vector(31 downto 0);

  signal dest_port   : std_logic_vector(15 downto 0)               := X"00_C0";
  signal source_port : std_logic_vector(15 downto 0)               := X"00_00";
  signal payload_len : std_logic_vector(MAX_FRAME_BITS-1 downto 0) := std_logic_vector(to_unsigned(300, MAX_FRAME_BITS));

  --Frame generator signals
  signal data_in     : word;
  signal usedw_in    : std_logic_vector(IN_FIFO_BITS-1 downto 0);
  signal payload_rdy : std_logic := '0';
  signal rdreq_in    : std_logic;
  signal data_out    : word;
  signal wrreq_out   : std_logic;

  signal sop          : std_logic;
  signal eop          : std_logic;
  signal frame_length : std_logic_vector(MAX_FRAME_BITS-1 downto 0);
  signal frame_rdy    : std_logic;
  signal fg_busy      : std_logic;

  constant payload_max_len : std_logic_vector(MAX_FRAME_BITS-1 downto 0) := std_logic_vector(to_unsigned(330, MAX_FRAME_BITS));
  constant FIFO_in_dly     : std_logic_vector(3 downto 0)                := "0011";
  constant FIFO_out_dly    : std_logic_vector(3 downto 0)                := "0000";

  constant reset_start_t  : time := 50 ns;
  constant reset_end_t    : time := 100 ns;
  constant sim_start_t    : time := reset_end_t + 40 ns;
  constant header_start_t : time := sim_start_t + 40 ns;
  constant header_end_t   : time := header_start_t + 2*clock_period;


begin

  hdgen : header_generator
    port map (
      clock           => clock,
      reset           => reset,
      header_data     => header_data,
      header_valid    => header_valid,
      header_len      => header_len,
      header_start    => header_start,
      header_done     => header_done,
      protocol        => protocol,
      app_header      => app_header,
      payload_len     => payload_len,
      config          => (others => '1'),  --Enable all parts of the header
      source_mac_addr => source_mac_addr,
      dest_mac_addr   => dest_mac_addr,
      ether_type      => X"08_00",         --IPv4
      source_ip       => src_ip,
      dest_ip         => dest_ip,
      source_port     => source_port,
      dest_port       => dest_port
      );

  frame_gen : ethernet_frame_generator
    generic map (
      IN_FIFO_BITS   => IN_FIFO_BITS,
      MAX_FRAME_BITS => MAX_FRAME_BITS)
    port map (
      clock           => clock,
      reset           => reset,
      header_data     => header_data,
      header_valid    => header_valid,
      header_done     => header_done,
      header_start    => header_start,
      payload_len     => payload_len,
      data_in         => data_in,
      usedw_in        => usedw_in,
      payload_rdy     => payload_rdy,
      rdreq_in        => rdreq_in,
      data_out        => data_out,
      wrreq_out       => wrreq_out,
      eop             => eop,
      sop             => sop,
      frame_length    => frame_length,
      frame_rdy       => frame_rdy,
      fg_busy         => fg_busy,
      payload_max_len => payload_max_len,
      FIFO_in_dly     => FIFO_in_dly,
      FIFO_out_dly    => FIFO_out_dly,
      gen_crc         => gen_crc
      );

  reset       <= '0', '1' after reset_start_t, '0' after reset_end_t;
  sim_start   <= '0', '1' after sim_start_t;
  payload_rdy <= '0', '1' after header_start_t, '0' after header_end_t;
  sim_running <= sim_start and not sim_end;
  app_header  <= X"00_12_34_56";

  usedw_in <= std_logic_vector(to_unsigned(103, usedw_in'length));

  --Clock generation  
  --Main clock, 100 MHz

  process
  begin
    clock <= '1'; wait for clock_period;
    clock <= '0'; wait for clock_period;
  end process;

  data_gen : process(clock, rdreq_in, reset)
    variable counter : natural := 0;
  begin

    if (reset = '1') then
      counter := 0;
      data_in <= std_logic_vector(to_unsigned(counter, data_in'length));
    elsif (rising_edge(clock) and rdreq_in = '1') then
      data_in <= std_logic_vector(to_unsigned(counter, data_in'length));
      if (rdreq_in = '1') then
        counter := counter + 1;
      end if;
    end if;


  end process data_gen;

  end_sim : process (clock)
    variable counter : natural := 0;
  begin
    if (rising_edge(clock)) then
      if (frame_rdy = '1') then
        sim_end <= '1';
      end if;
      if (sim_end = '1') then
        counter := counter + 1;
      end if;
    -- if (counter > 5) then
    --   assert false report "end of simulation" severity failure;
    -- end if;                           
    end if;
  end process end_sim;

end architecture tb;




