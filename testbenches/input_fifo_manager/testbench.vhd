library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.eth_common.all;

entity testbench is

end testbench;

architecture tb of testbench is
  constant NFIFOS : natural := n_in_fifos;

  component input_fifo_manager is
    generic (
      NFIFOS : natural);
    port (
      clock        : in  std_logic;
      reset        : in  std_logic;
      data_out     : out word;
      usedw_out    : out in_fifo_usedw;
      payload_rdy  : out std_logic := '0';
      tx_busy      : in  std_logic;
      rdreq        : in  std_logic;
      payload_size : in  in_fifo_usedw_array(0 to NFIFOS-1);
      flags        : in  in_fifo_flag_array(0 to NFIFOS-1);
      wrclks       : in  std_logic_vector(0 to NFIFOS-1);
      wrreqs       : in  std_logic_vector(0 to NFIFOS-1);
      data_in      : in  data_array(0 to NFIFOS-1);
      wrfull       : out std_logic_vector(0 to NFIFOS-1);
      rdusedw      : out in_fifo_usedw_array(0 to NFIFOS-1);
      curr_fifo    : out std_logic_vector(0 to f_num_bits(NFIFOS)-1));
  end component input_fifo_manager;

  type time_array is array (integer range <>) of time;
  constant clock_period  : time                            := 5 ns;
  signal clock           : std_logic;
  signal reset           : std_logic;
  signal sim_start       : std_logic                       := '0';
  signal sim_running     : std_logic                       := '0';
  signal sim_end         : std_logic                       := '0';
  signal wrclks          : std_logic_vector(0 to NFIFOS-1) := (others => '0');
  signal wrreq           : std_logic_vector(0 to NFIFOS-1) := (others => '0');
  constant wrclk_periods : time_array(0 to NFIFOS-1)       := (0      => 30 ns, 1 => 20 ns, 2 => 45 ns, others => 60 ns);
  constant reset_start_t : time                            := 50 ns;
  constant reset_end_t   : time                            := 100 ns;
  constant sim_start_t   : time                            := reset_end_t + 40 ns;

  signal data_out     : word                               := (others => '0');
  signal usedw_out    : in_fifo_usedw;
  signal payload_rdy  : std_logic                          := '0';
  signal fg_busy      : std_logic                          := '0';
  signal rdreq        : std_logic                          := '0';
  signal payload_size : in_fifo_usedw_array(0 to NFIFOS-1) := (others => (others => '0'));
  signal data_in      : data_array(0 to NFIFOS-1)          := (others => (others => '0'));
  signal wrfull       : std_logic_vector(0 to NFIFOS-1);
  signal rdusedw      : in_fifo_usedw_array(0 to NFIFOS-1);
  constant fifo_flags : in_fifo_flag_array(0 to NFIFOS-1)  := (3      => INFIFO_PRIORITY, others => INFIFO_ENABLE);
  signal curr_fifo : std_logic_vector(0 to f_num_bits(NFIFOS)-1);
  
begin

  ifm : entity work.input_fifo_manager
    generic map (
      NFIFOS => NFIFOS)
    port map (
      clock        => clock,
      reset        => reset,
      data_out     => data_out,
      usedw_out    => usedw_out,
      payload_rdy  => payload_rdy,
      tx_busy => fg_busy,
      rdreq        => rdreq,
      payload_size => payload_size,
      wrclks       => wrclks,
      wrreqs        => wrreq,
      flags        => fifo_flags,
      data_in      => data_in,
      wrfull       => wrfull,
      rdusedw      => rdusedw,
      curr_fifo => curr_fifo);

  reset       <= '0', '1' after reset_start_t, '0' after reset_end_t;
  sim_start   <= '0', '1' after sim_start_t;
  sim_running <= sim_start and not sim_end;

  payload_size <= (others => (std_logic_vector(to_unsigned(250, payload_size(0)'length))));

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
    wrreq(I) <= '0' when sim_start = '0' else '1';
  end generate wrclk_gen;

  data_gen : for I in wrclks'range generate
    process (wrclks(I), reset)
      variable counter : natural := 0;
    begin
      if (reset = '1') then
        counter := 0;
        wrreq(I) <= '0';
      elsif (rising_edge(wrclks(I))) then
        if (sim_start = '1') then
          data_in(I) <= std_logic_vector(to_unsigned(counter, data_in(0)'length));
          wrreq(I) <= '1';
          counter := counter+1;           
        else
          wrreq(I) <= '0';
        end if;
      end if;
    end process;
  end generate data_gen;
  
  read_data : process(clock, reset)
    variable words_to_read : natural := 0;
    variable reading       : boolean := false;
  begin
    if reset = '1' then
      reading       := false;
      words_to_read := 0;
      fg_busy       <= '0';
    elsif rising_edge(clock) then
      if reading then
        fg_busy          <= '1';
        rdreq            <= '1';
        if words_to_read <= 0 then
          rdreq   <= '0';
          reading := false;
        else
          rdreq         <= '1';
          words_to_read := words_to_read-1;
        end if;
      elsif payload_rdy = '1' then
        reading       := true;
        words_to_read := to_integer(unsigned(usedw_out));
        rdreq         <= '1';
        fg_busy       <= '1';
      else
        fg_busy <= '0';
      end if;
    end if;
  end process read_data;

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




