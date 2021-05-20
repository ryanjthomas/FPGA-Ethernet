-------------------------------------------------------------------------------
-- Title      : top_ethernet
-- Project    : ODILE
-------------------------------------------------------------------------------
-- File       : top_ethernet.vhd
-- Author     : Ryan Thomas  <ryant@uchicago.edu>
-- Company    : University of Chicago
-- Created    : 2020-01-28
-- Last update: 2021-05-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Ethernet top block. Holds the three (2 optical, 1 copper)
-- ethernet blocks, plus a data routing block recieving ethernet data
-------------------------------------------------------------------------------
--!\file top_ethernet.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ltc2945_package.all;
use work.eth_common.all;
use work.config_pkg.all;

--!\brief Top level for our Ethernet and related firmware.
--!
--!Mostly a simple container that wires together different blocks containing
--!logic for Ethernet. Also contains remote update/EPCQ writing code for updaing
--!firmware remotely. The top block contains minimal logic.

entity top_ethernet is
  generic (
    --!To enable loopback. If disabled, leaves data_in(4) free
    enable_loopback : boolean := true;
    --!Number of ADC data channels to create
    NFIFOS          : natural := 5
    );
  port (
    clock                    : in    std_logic;
    reset                    : in    std_logic;
    ---------------------------------------------------------------------------
    --!\name Config data lines
    --!\{
    ---------------------------------------------------------------------------
    --!Input lines, only for reading configuration
    config_data_in           : in    std_logic_vector(31 downto 0);
    config_valid_in          : in    std_logic;
    config_data_out          : out   std_logic_vector(31 downto 0);
    config_valid_out         : out   std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name Data inputs
    --!\{
    ---------------------------------------------------------------------------
    data_in                  : in    data_array(0 to NFIFOS-1);
    wrreqs_in                : in    std_logic_vector(0 to NFIFOS-1);
    wrclks_in                : in    std_logic_vector(0 to NFIFOS-1);
    --!\}
    ---------------------------------------------------------------------------
    --!\name Ethernet data passthrough
    --!\{
    ---------------------------------------------------------------------------
    data_out                 : out   std_logic_vector(31 downto 0);
    data_out_udp             : out   std_logic_vector(15 downto 0);
    data_out_valid           : out   std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name LED outputs
    --!\{
    ---------------------------------------------------------------------------
    led_acts                 : out   std_logic_vector(2 downto 0);
    led_links                : out   std_logic_vector(2 downto 0);
    led_combined             : out   std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name Transciever lines (to SFP transcievers)
    --!\{
    ---------------------------------------------------------------------------
    --!External 125 MHz reference clock
    ref_clk0                 : in    std_logic;
    rxp0                     : in    std_logic;
    txp0                     : out   std_logic;
    --!External 125 MHz reference clock
    ref_clk1                 : in    std_logic;
    rxp1                     : in    std_logic;
    txp1                     : out   std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name Transciever lines (to copper PHY SGMII interface)
    --!\{
    ---------------------------------------------------------------------------
    --!FPGA internal 125 MHz reference clock
    ref_clk2                 : in    std_logic;
    rxp2                     : in    std_logic;
    txp2                     : out   std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name MDIO config lines
    --!\{
    ---------------------------------------------------------------------------
    mdc                      : out   std_logic;
    mdio                     : inout std_logic;
    hw_reset_out             : out   std_logic;
    --!\}
    ---------------------------------------------------------------------------
    --!\name Ethernet ready lines
    --!\{
    ---------------------------------------------------------------------------
    eth0_ready               : out   std_logic                      := '0';
    eth1_ready               : out   std_logic                      := '0';
    eth2_ready               : out   std_logic                      := '0';
    --!\}
    ---------------------------------------------------------------------------
    --!\name CABAC Interface
    --!\{
    ---------------------------------------------------------------------------
    reg32b_cabacspi          : out   std_logic_vector(31 downto 0)  := (others => '0');
    Reg32b_cabacspi_ReadOnly : in    std_logic_vector(31 downto 0)  := (others => '0');
    start_cabac_SPI          : out   std_logic                      := '0';
    start_cabac_reset_SPI    : out   std_logic                      := '0';
    cabacprog_busy           : in    std_logic                      := '1';
    data_from_cabacspi_ready : in    std_logic                      := '0';
    --!\}    
    ---------------------------------------------------------------------------
    --!\name Sequencer interface
    --!\{
    ---------------------------------------------------------------------------
    --Generic buses with address/data for different parts of the sequencer
    seq_mem_w_add            : out   std_logic_vector(9 downto 0)   := (others => '0');
    seq_mem_data_in          : out   std_logic_vector (31 downto 0) := (others => '0');
    --Write enables for different memories
    program_mem_we           : out   std_logic                      := '0';  --Write to program memory
    time_mem_w_en            : out   std_logic                      := '0';  --Write to time memory
    out_mem_w_en             : out   std_logic                      := '0';  --Write to output clock values
    --For pointer functionality (so we can use if need be)
    ind_func_mem_we          : out   std_logic                      := '0';
    ind_rep_mem_we           : out   std_logic                      := '0';
    ind_sub_add_mem_we       : out   std_logic                      := '0';
    ind_sub_rep_mem_we       : out   std_logic                      := '0';
    --Sequencer start/stop/step signals
    start_sequence           : out   std_logic                      := '0';
    step_sequence            : out   std_logic                      := '0';
    stop_sequence            : out   std_logic                      := '0';
    end_sequence             : in    std_logic                      := '0';
    prog_mem_redbk           : in    std_logic_vector(31 downto 0);
    time_mem_readbk          : in    std_logic_vector(15 downto 0);
    out_mem_readbk           : in    std_logic_vector(31 downto 0);
    ind_func_mem_redbk       : in    std_logic_vector(3 downto 0);
    ind_rep_mem_redbk        : in    std_logic_vector(23 downto 0);
    ind_sub_add_mem_redbk    : in    std_logic_vector(9 downto 0);
    ind_sub_rep_mem_redbk    : in    std_logic_vector(15 downto 0);
    program_mem_init_add_in  : out   std_logic_vector(9 downto 0)   := (others => '0');
    program_mem_init_add_rbk : in    std_logic_vector(9 downto 0);
    op_code_error_reset      : out   std_logic                      := '0';
    op_code_error            : in    std_logic;
    op_code_error_add        : in    std_logic_vector(9 downto 0);
    epcqio_clock             : in    std_logic                      := '0';  --Max 20 MHz clock
    --!\}
    ---------------------------------------------------------------------------
    --!\name Monitoring Interface
    --!\{
    ---------------------------------------------------------------------------
    start_monitoring         : out   std_logic                      := '0';
    monitoring_busy          : in    std_logic                      := '0';
    Reg32b_monitoring        : in    array18x32b                    := (others => X"CAFEAAAA");
    switches                 : out   std_logic_vector(7 downto 0);
    --!\>
    ---------------------------------------------------------------------------
    --!\name CROC Interface
    --!\{
    reg96b_crocspi           : out   std_logic_vector(95 downto 0);
    reg96b_crocspi_ReadOnly  : in    std_logic_vector(95 downto 0);
    write_croc_req           : out   std_logic;
    read_croc_req            : out   std_logic;
    crocprog_busy            : in    std_logic
    );
--!\}
end entity top_ethernet;

architecture vhdl_rtl of top_ethernet is

  component odile_controller is
    port (
      clock                  : in  std_logic;
      reset                  : in  std_logic;
      data_in                : in  std_logic_vector(31 downto 0);
      data_valid             : in  std_logic;
      data_port              : in  std_logic_vector(15 downto 0);
      data_addr              : in  std_logic_vector(79 downto 0);
      source_iface           : in  std_logic_vector(3 downto 0);
      start_sequence         : out std_logic;
      step_sequence          : out std_logic;
      stop_sequence          : out std_logic;
      read_triggers          : out std_logic_vector(15 downto 0);
      clear_error            : out std_logic;
      reset_cabac            : out std_logic;
      erase_sequencer        : out std_logic;
      epcqio_read_data       : out std_logic;
      epcqio_write_data      : out std_logic;
      epcqio_enable_4byte    : out std_logic;
      epcqio_erase_sector    : out std_logic;
      epcqio_clear_buffers   : out std_logic;
      epcqio_address         : out std_logic_vector(31 downto 0);
      epcqio_num_words       : out std_logic_vector(6 downto 0);
      ru_do_reconfig         : out std_logic;
      ru_application_address : out std_logic_vector(23 downto 0);
      ru_reread_params       : out std_logic;
      start_monitoring       : out std_logic;
      read_monitoring        : out std_logic;
      read_croc              : out std_logic;
      send_cmd_ack           : out std_logic;
      cmd_to_ack             : out std_logic_vector(31 downto 0);
      cm_load_config         : out std_logic;
      cm_config_page         : out std_logic_vector(3 downto 0);
      read_config            : out std_logic;
      reply_iface            : out std_logic_vector(3 downto 0);
      reply_addr             : out std_logic_vector(79 downto 0);
      switches               : out std_logic_vector(7 downto 0)
      );
  end component odile_controller;
  
  component command_response_generator is
    port (
      clock         : in  std_logic;
      reset         : in  std_logic;
      send_cmd_ack  : in  std_logic;
      data_in       : in  std_logic_vector(31 downto 0);
      command_done  : in  std_logic;
      command_error : in  std_logic;
      error_code    : in  std_logic_vector(31 downto 0);
      udp_out_bus   : out std_logic_vector(52 downto 0) := (others => '0');
      udp_ready     : in  std_logic                     := '0';
      busy          : out std_logic                     := '0');
  end component command_response_generator;


  component ethernet_sgmii_block is
    generic (
      is_testbench : boolean;
      NFIFOS       : natural;
      port_id      : natural);
    port (
      clock             : in    std_logic;
      reset             : in    std_logic;
      config_data_in    : in    std_logic_vector(31 downto 0);
      config_valid_in   : in    std_logic;
      config_data_out   : out   std_logic_vector(31 downto 0);
      config_valid_out  : out   std_logic;
      mdc               : out   std_logic;
      mdio              : inout std_logic;
      ref_clk           : in    std_logic;
      rxp               : in    std_logic;
      txp               : out   std_logic;
      udp_data_in       : in    std_logic_vector(31 downto 0);
      udp_data_valid_in : in    std_logic;
      udp_data_port_in  : in    udp_port;
      udp_eop_in        : in    std_logic;
      udp_addr_in       : in    std_logic_vector(79 downto 0);
      data_in           : in    data_array(0 to NFIFOS-1);
      wrreqs_in         : in    std_logic_vector(0 to NFIFOS-1);
      wrclks_in         : in    std_logic_vector(0 to NFIFOS-1);
      data_out          : out   word;
      data_valid        : out   std_logic;
      data_eop          : out   std_logic;
      data_port         : out   std_logic_vector(15 downto 0);
      data_addr_out     : out   std_logic_vector(79 downto 0);
      hw_reset_out      : out   std_logic;
      led_link          : out   std_logic;
      led_act           : out   std_logic;
      eth_ready         : out   std_logic);
  end component ethernet_sgmii_block;

  component ethernet_optical_block is
    generic (
      is_testbench : boolean;
      NFIFOS       : natural;
      port_id      : natural);
    port (
      clock             : in  std_logic;
      reset             : in  std_logic;
      config_data_in    : in  std_logic_vector(31 downto 0);
      config_valid_in   : in  std_logic;
      config_data_out   : out std_logic_vector(31 downto 0);
      config_valid_out  : out std_logic;
      ref_clk           : in  std_logic;
      rxp               : in  std_logic;
      txp               : out std_logic;
      data_in           : in  data_array(0 to NFIFOS-1);
      wrreqs_in         : in  std_logic_vector(0 to NFIFOS-1);
      wrclks_in         : in  std_logic_vector(0 to NFIFOS-1);
      udp_data_in       : in  std_logic_vector(31 downto 0);
      udp_data_valid_in : in  std_logic;
      udp_data_port_in  : in  udp_port;
      udp_eop_in        : in  std_logic;
      udp_addr_in       : in  std_logic_vector(79 downto 0);
      data_out          : out word;
      data_valid        : out std_logic;
      data_eop          : out std_logic;
      data_port         : out std_logic_vector(15 downto 0);
      data_addr_out     : out std_logic_vector(79 downto 0);
      led_link          : out std_logic;
      led_act           : out std_logic;
      eth_ready         : out std_logic;
      rx_recovclkout : out std_logic);
  end component ethernet_optical_block;

  component ethernet_data_router is
    port (
      clock           : in  std_logic;
      reset           : in  std_logic;
      data_in0        : in  std_logic_vector(31 downto 0);
      data_valid0     : in  std_logic;
      data_port0      : in  std_logic_vector(15 downto 0);
      data_addr0      : in  std_logic_vector(79 downto 0);
      data_in1        : in  std_logic_vector(31 downto 0);
      data_valid1     : in  std_logic;
      data_port1      : in  std_logic_vector(15 downto 0);
      data_addr1      : in  std_logic_vector(79 downto 0);
      data_in2        : in  std_logic_vector(31 downto 0);
      data_valid2     : in  std_logic;
      data_port2      : in  std_logic_vector(15 downto 0);
      data_addr2      : in  std_logic_vector(79 downto 0);
      int_data_in     : in  std_logic_vector(31 downto 0);
      int_valid_in    : in  std_logic;
      int_port_in     : in  std_logic_vector(15 downto 0);
      config_data_out : out std_logic_vector(31 downto 0) := (others => '0');
      config_valid    : out std_logic                     := '0';
      loopback_data0  : out std_logic_vector(31 downto 0) := (others => '0');
      loopback_wrreq0 : out std_logic                     := '0';
      loopback_data1  : out std_logic_vector(31 downto 0) := (others => '0');
      loopback_wrreq1 : out std_logic                     := '0';
      loopback_data2  : out std_logic_vector(31 downto 0) := (others => '0');
      loopback_wrreq2 : out std_logic                     := '0';
      epcqio_data_out : out std_logic_vector(31 downto 0) := (others => '0');
      epcqio_valid    : out std_logic                     := '0';
      eth_data_out    : out std_logic_vector(31 downto 0) := (others => '0');
      eth_data_port   : out std_logic_vector(15 downto 0) := (others => '0');
      eth_data_valid  : out std_logic                     := '0';
      eth_data_addr   : out std_logic_vector(79 downto 0) := (others => '0');
      source_iface    : out std_logic_vector(3 downto 0)  := (others => '0'));
  end component ethernet_data_router;

  component ethernet_led_signaler is
    generic (
      blink_cycles : natural);
    port (
      clock            : in  std_logic;
      led0_link        : in  std_logic;
      led0_act         : in  std_logic;
      led1_link        : in  std_logic;
      led1_act         : in  std_logic;
      led2_link        : in  std_logic;
      led2_act         : in  std_logic;
      led_link_out     : out std_logic;
      led_act_out      : out std_logic;
      led_combined_out : out std_logic);
  end component ethernet_led_signaler;

  component ethernet_ccdcontrol_interface is
    port (
      clock                    : in  std_logic;
      reset                    : in  std_logic;
      data_in                  : in  std_logic_vector(31 downto 0)  := (others => '0');
      data_port                : in  std_logic_vector(15 downto 0)  := (others => '0');
      data_valid               : in  std_logic                      := '0';
      udp_out_bus              : out std_logic_vector(52 downto 0)  := (others => '0');
      udp_ready                : in  std_logic                      := '0';
      read_done                : out std_logic                      := '0';
      erase_done               : out std_logic                      := '0';
      reg32b_cabacspi          : out std_logic_vector(31 downto 0)  := (others => '0');
      Reg32b_cabacspi_ReadOnly : in  std_logic_vector(31 downto 0)  := (others => '0');
      start_cabac_SPI          : out std_logic                      := '0';
      start_cabac_reset_SPI    : out std_logic                      := '0';
      cabacprog_busy           : in  std_logic                      := '1';
      reset_cabac              : in  std_logic                      := '0';
      data_from_cabacspi_ready : in  std_logic                      := '0';
      reg96b_crocspi           : out std_logic_vector(95 downto 0)  := (others => '0');
      reg96b_crocspi_ReadOnly  : in  std_logic_vector(95 downto 0)  := (others => '0');
      write_croc_req           : out std_logic                      := '0';
      read_croc_req            : out std_logic                      := '0';
      crocprog_busy            : in  std_logic                      := '0';
      seq_mem_w_add            : out std_logic_vector(9 downto 0)   := (others => '0');
      seq_mem_data_in          : out std_logic_vector (31 downto 0) := (others => '0');
      program_mem_we           : out std_logic                      := '0';
      time_mem_w_en            : out std_logic                      := '0';
      out_mem_w_en             : out std_logic                      := '0';
      ind_func_mem_we          : out std_logic                      := '0';
      ind_rep_mem_we           : out std_logic                      := '0';
      ind_sub_add_mem_we       : out std_logic                      := '0';
      ind_sub_rep_mem_we       : out std_logic                      := '0';
      read_triggers            : in  std_logic_vector(15 downto 0)  := (others => '0');
      erase_sequencer          : in  std_logic                      := '0';
      prog_mem_redbk           : in  std_logic_vector(31 downto 0);
      time_mem_readbk          : in  std_logic_vector(15 downto 0);
      out_mem_readbk           : in  std_logic_vector(31 downto 0);
      ind_func_mem_redbk       : in  std_logic_vector(3 downto 0);
      ind_rep_mem_redbk        : in  std_logic_vector(23 downto 0);
      ind_sub_add_mem_redbk    : in  std_logic_vector(9 downto 0);
      ind_sub_rep_mem_redbk    : in  std_logic_vector(15 downto 0);
      program_mem_init_add_in  : out std_logic_vector(9 downto 0)   := (others => '0');
      program_mem_init_add_rbk : in  std_logic_vector(9 downto 0);
      op_code_error_reset      : out std_logic                      := '0';
      op_code_error            : in  std_logic;
      op_code_error_add        : in  std_logic_vector(9 downto 0));
  end component ethernet_ccdcontrol_interface;

  component udp_data_arbiter is
    port (
      clock             : in  std_logic;
      reset             : in  std_logic;
      udp_data_out      : out std_logic_vector(31 downto 0) := (others => '0');
      udp_port_out      : out std_logic_vector(15 downto 0) := (others => '0');
      udp_valid_out     : out std_logic                     := '0';
      udp_eop_out       : out std_logic                     := '0';
      udp_dest_iface    : out std_logic_vector(3 downto 0)  := (others => '0');
      udp_dest_addr     : out std_logic_vector(79 downto 0) := (others => '0');
      udp_in_bus_cmd    : in  std_logic_vector(52 downto 0);
      udp_ready_cmd     : out std_logic                     := '0';
      udp_in_bus_ccdint : in  std_logic_vector(52 downto 0);
      udp_ready_ccdint  : out std_logic                     := '0';
      udp_in_bus_scan   : in  std_logic_vector(52 downto 0);
      udp_ready_scan    : out std_logic                     := '0';
      udp_in_bus_epcqio : in  std_logic_vector(52 downto 0);
      udp_ready_epcqio  : out std_logic                     := '0';
      udp_in_bus_monit  : in  std_logic_vector(52 downto 0);
      udp_ready_monit   : out std_logic                     := '0';
      udp_tx_busy       : out std_logic                     := '0';
      dest_iface        : in  std_logic_vector(3 downto 0)  := (others => '0');
      dest_addr         : in  std_logic_vector(79 downto 0) := (others => '0'));
  end component udp_data_arbiter;


  component config_block_scanner is
    port (
      clock               : in  std_logic;
      reset               : in  std_logic;
      config_data_in      : in  std_logic_vector(31 downto 0) := (others => '0');
      config_valid_in     : in  std_logic                     := '0';
      config_data_out     : out std_logic_vector(31 downto 0) := (others => '0');
      config_valid_out    : out std_logic                     := '0';
      udp_out_bus         : out std_logic_vector(52 downto 0) := (others => '0');
      udp_ready           : in  std_logic                     := '0';
      start_scan_blocks   : in  std_logic                     := '0';
      scan_finished       : out std_logic                     := '0';
      start_scan_single   : in  std_logic                     := '0';
      start_block_address : in  std_logic_vector(6 downto 0)  := (others => '0');
      busy                : out std_logic                     := '0');
  end component config_block_scanner;

  component config_read_multiplexer is
    generic (
      NCONFIG_LINES : natural);
    port (
      clock            : in  std_logic;
      config_data_in   : in  config_word_array(NCONFIG_LINES-1 downto 0);
      config_valid_in  : in  std_logic_vector(NCONFIG_LINES-1 downto 0);
      config_data_out  : out config_word;
      config_valid_out : out std_logic);
  end component config_read_multiplexer;

  component epcqio_control is
    port (
      epcq_clock        : in  std_logic;
      data_clock        : in  std_logic;
      reset             : in  std_logic;
      data_in           : in  std_logic_vector(31 downto 0) := (others => '0');
      data_in_valid     : in  std_logic                     := '0';
      write_buffer_full : out std_logic                     := '0';
      data_out          : out std_logic_vector(31 downto 0) := (others => '0');
      data_out_valid    : out std_logic                     := '0';
      data_out_rdreq    : in  std_logic                     := '0';
      address           : in  std_logic_vector(31 downto 0) := (others => '0');
      num_words         : in  std_logic_vector(8 downto 0)  := (others => '0');
      read_data         : in  std_logic                     := '0';
      write_data        : in  std_logic                     := '0';
      enable_4byte      : in  std_logic                     := '0';
      erase_sector      : in  std_logic                     := '0';
      read_busy         : out std_logic                     := '0';
      write_busy        : out std_logic                     := '0';
      done              : out std_logic                     := '0';
      error_code        : out std_logic_vector(31 downto 0) := (others => '0');
      error_status      : out std_logic                     := '0';
      clear_buffers     : in  std_logic                     := '0');
  end component epcqio_control;

  component remote_update_control is
    port (
      clock               : in  std_logic;
      reset               : in  std_logic;
      do_reconfig         : in  std_logic                     := '0';
      reread_params       : in  std_logic                     := '0';
      application_address : in  std_logic_vector(23 downto 0) := (others => '1');
      is_anf              : out std_logic                     := '0';
      reconfig_error      : out std_logic                     := '0');
  end component remote_update_control;

  component config_data_manager is
    port (
      clock          : in  std_logic;
      reset          : in  std_logic;
      load_config    : in  std_logic                    := '0';
      config_page    : in  std_logic_vector(3 downto 0) := (others => '0');
      epcq_address   : out std_logic_vector(31 downto 0);
      epcq_numwords  : out std_logic_vector(6 downto 0);
      epcq_read_data : out std_logic                    := '0';
      eth_data_out   : out std_logic_vector(31 downto 0);
      eth_port_out   : out std_logic_vector(15 downto 0);
      eth_dval_out   : out std_logic;
      eth_data_in    : in  std_logic_vector(31 downto 0);
      eth_port_in    : in  std_logic_vector(15 downto 0);
      eth_dval_in    : in  std_logic;
      config_busy    : out std_logic                    := '0';
      config_done    : out std_logic                    := '0');
  end component config_data_manager;

  component ethernet_monitoring_interface is
    port (
      clock                : in  std_logic;
      reset                : in  std_logic;
      read_register        : in  std_logic                     := '0';
      start_monitoring_cmd : in  std_logic                     := '0';
      start_monitoring     : out std_logic                     := '0';
      monitoring_busy      : in  std_logic                     := '0';
      Reg32b_monitoring    : in  array18x32b;
      udp_out_bus          : out std_logic_vector(52 downto 0) := (others => '0');
      udp_ready            : in  std_logic);
  end component ethernet_monitoring_interface;
  
  -----------------------------------------------------------------------------
  -- LED Signals
  -----------------------------------------------------------------------------
  signal led0_link        : std_logic;
  signal led0_act         : std_logic;
  signal led1_link        : std_logic;
  signal led1_act         : std_logic;
  signal led2_link        : std_logic;
  signal led2_act         : std_logic;
  signal led_link_sig     : std_logic;
  signal led_act_sig      : std_logic;
  signal led_combined_sig : std_logic;

  -----------------------------------------------------------------------------
  -- Outputs from ethernet blocks
  -----------------------------------------------------------------------------
  signal data0_out         : word;
  signal data0_valid       : std_logic;
  signal data0_eop         : std_logic;
  signal data0_port        : std_logic_vector(15 downto 0);
  signal data0_addr_out    : std_logic_vector(79 downto 0);
  signal config_data_out0  : std_logic_vector(31 downto 0);
  signal config_valid_out0 : std_logic;

  signal data1_out         : word;
  signal data1_valid       : std_logic;
  signal data1_eop         : std_logic;
  signal data1_port        : std_logic_vector(15 downto 0);
  signal data1_addr_out    : std_logic_vector(79 downto 0);
  signal config_data_out1  : std_logic_vector(31 downto 0);
  signal config_valid_out1 : std_logic;

  signal data2_out         : word;
  signal data2_valid       : std_logic;
  signal data2_eop         : std_logic;
  signal data2_port        : std_logic_vector(15 downto 0);
  signal data2_addr_out    : std_logic_vector(79 downto 0);
  signal config_data_out2  : std_logic_vector(31 downto 0);
  signal config_valid_out2 : std_logic;

  -----------------------------------------------------------------------------
  -- Inputs to Ethernet blocks
  -----------------------------------------------------------------------------

  signal data0_in   : data_array(0 to NFIFOS-1);
  signal wrreqs0_in : std_logic_vector(0 to NFIFOS-1);
  signal wrclks0_in : std_logic_vector(0 to NFIFOS-1);

  signal data1_in   : data_array(0 to NFIFOS-1);
  signal wrreqs1_in : std_logic_vector(0 to NFIFOS-1);
  signal wrclks1_in : std_logic_vector(0 to NFIFOS-1);

  signal data2_in   : data_array(0 to NFIFOS-1);
  signal wrreqs2_in : std_logic_vector(0 to NFIFOS-1);
  signal wrclks2_in : std_logic_vector(0 to NFIFOS-1);

  -----------------------------------------------------------------------------
  -- Data router signals
  -----------------------------------------------------------------------------
  signal config_data_out_eth  : std_logic_vector(31 downto 0) := (others => '0');
  signal config_valid_out_eth : std_logic                     := '0';
  signal loopback_data0       : std_logic_vector(31 downto 0) := (others => '0');
  signal loopback_wrreq0      : std_logic                     := '0';
  signal loopback_data1       : std_logic_vector(31 downto 0) := (others => '0');
  signal loopback_wrreq1      : std_logic                     := '0';
  signal loopback_data2       : std_logic_vector(31 downto 0) := (others => '0');
  signal loopback_wrreq2      : std_logic                     := '0';
  signal eth_data_out         : std_logic_vector(31 downto 0) := (others => '0');
  signal eth_data_port        : std_logic_vector(15 downto 0) := (others => '0');
  signal eth_data_valid       : std_logic                     := '0';
  signal eth_data_addr        : std_logic_vector(79 downto 0) := (others => '0');
  signal epcqio_data_in       : std_logic_vector(31 downto 0) := (others => '0');
  signal epcqio_data_in_valid : std_logic                     := '0';
  signal source_iface         : std_logic_vector(3 downto 0)  := (others => '0');
  signal int_eth_data_in      : std_logic_vector(31 downto 0) := (others => '0');
  signal int_eth_port_in      : std_logic_vector(15 downto 0) := (others => '0');
  signal int_eth_dval_in      : std_logic                     := '0';

  -----------------------------------------------------------------------------
  -- UDP Data signals
  -----------------------------------------------------------------------------
  signal udp_data_in       : std_logic_vector(31 downto 0);
  signal udp_data_valid_in : std_logic;
  signal udp_data_port_in  : udp_port;
  signal udp_eop_in        : std_logic;
  signal udp_addr_in       : std_logic_vector(79 downto 0);
  signal send_cmd_ack      : std_logic;
  signal cmd_to_ack        : std_logic_vector(31 downto 0);
  signal command_done      : std_logic;
  signal command_error     : std_logic;
  signal udp_data_out      : std_logic_vector(31 downto 0) := (others => '0');
  signal udp_valid_out     : std_logic                     := '0';
  signal udp_port_out      : udp_port                      := (others => '0');
  signal udp_eop_out       : std_logic                     := '0';
  signal udp_addr_out      : std_logic_vector(79 downto 0) := (others => '0');
  signal udp_dest_iface    : std_logic_vector(3 downto 0)  := (others => '0');
  signal udp_gen_busy      : std_logic                     := '0';

  signal udp_in_bus_cmd    : std_logic_vector(52 downto 0);
  signal udp_ready_cmd     : std_logic                     := '0';
  signal udp_in_bus_ccdint : std_logic_vector(52 downto 0);
  signal udp_ready_ccdint  : std_logic                     := '0';
  signal udp_tx_busy       : std_logic                     := '0';
  signal udp_in_bus_monit  : std_logic_vector(52 downto 0) := (others => '0');
  signal udp_ready_monit   : std_logic                     := '0';

  signal udp_in_bus_scan : std_logic_vector(52 downto 0) := (others => '0');
  signal udp_ready_scan  : std_logic                     := '0';

  signal cmd_reply_iface : std_logic_vector(3 downto 0)  := (others => '0');
  signal cmd_reply_addr  : std_logic_vector(79 downto 0) := (others => '0');


  -----------------------------------------------------------------------------
  -- CCDControl Signals
  -----------------------------------------------------------------------------
  signal read_triggers              : std_logic_vector(15 downto 0) := (others => '0');
  signal ccdint_read_done           : std_logic                     := '0';
  signal ccdint_erase_done          : std_logic                     := '0';
  signal ccdint_op_code_error_reset : std_logic                     := '0';
  signal reset_cabac                : std_logic                     := '0';

  signal clear_error     : std_logic                     := '0';
  signal error_code      : std_logic_vector(31 downto 0) := (others => '0');
  signal erase_sequencer : std_logic                     := '0';

  -----------------------------------------------------------------------------
  -- Configuration reader
  -----------------------------------------------------------------------------
  signal config_data_in_scan   : std_logic_vector(31 downto 0) := (others => '0');
  signal config_valid_in_scan  : std_logic                     := '0';
  signal config_data_out_scan  : std_logic_vector(31 downto 0) := (others => '0');
  signal config_valid_out_scan : std_logic                     := '0';
  signal start_scan_blocks     : std_logic                     := '0';
  signal scan_finished         : std_logic                     := '0';
  signal start_scan_single     : std_logic                     := '0';
  signal start_block_address   : std_logic_vector(6 downto 0)  := (others => '0');
  signal busy                  : std_logic                     := '0';
  -----------------------------------------------------------------------------
  -- Configuration multiplexer
  -----------------------------------------------------------------------------
  constant NCONFIG_LINES       : natural                       := 4;
  signal config_data_in_mult   : config_word_array(NCONFIG_LINES-1 downto 0);
  signal config_valid_in_mult  : std_logic_vector(NCONFIG_LINES-1 downto 0);
  signal config_data_out_sig   : std_logic_vector(31 downto 0) := (others => '0');
  signal config_valid_out_sig  : std_logic                     := '0';

  -----------------------------------------------------------------------------
  -- EPCQIO Interface
  -----------------------------------------------------------------------------
  signal epcqio_epcq_clock        : std_logic;
  signal epcqio_data_clock        : std_logic;
  signal epcqio_write_buffer_full : std_logic                     := '0';
  signal udp_in_bus_epcqio        : std_logic_vector(52 downto 0) := (others => '0');
  signal udp_ready_epcqio         : std_logic                     := '0';
  signal epcqio_address           : std_logic_vector(31 downto 0) := (others => '0');
  signal epcqio_num_words         : std_logic_vector(6 downto 0)  := (others => '0');
  signal epcqio_read_data         : std_logic                     := '0';
  signal epcqio_write_data        : std_logic                     := '0';
  signal epcqio_erase_sector      : std_logic                     := '0';
  signal epcqio_enable_4byte      : std_logic                     := '0';
  signal epcqio_read_busy         : std_logic                     := '0';
  signal epcqio_write_busy        : std_logic                     := '0';
  signal epcqio_done              : std_logic                     := '0';
  signal epcqio_error_code        : std_logic_vector(31 downto 0) := (others => '0');
  signal epcqio_error_status      : std_logic                     := '0';
  signal epcqio_clear_buffers     : std_logic                     := '0';

  signal con_epcqio_address      : std_logic_vector(31 downto 0) := (others => '0');
  signal con_epcqio_num_words    : std_logic_vector(6 downto 0)  := (others => '0');
  signal con_epcqio_read_data    : std_logic                     := '0';
  signal con_epcqio_write_data   : std_logic                     := '0';
  signal con_epcqio_erase_sector : std_logic                     := '0';
  signal con_epcqio_enable_4byte : std_logic                     := '0';

  -----------------------------------------------------------------------------
  -- Remote update controller
  -----------------------------------------------------------------------------
  signal ru_do_reconfig         : std_logic                     := '0';
  signal ru_reread_params       : std_logic                     := '0';
  signal ru_application_address : std_logic_vector(23 downto 0) := (others => '1');
  signal ru_is_anf              : std_logic                     := '0';
  signal ru_reconfig_error      : std_logic                     := '0';

  -----------------------------------------------------------------------------
  -- Configuration data manager (for loading configuration registers from flash
  -- memory
  -----------------------------------------------------------------------------
  signal cm_load_config      : std_logic                    := '0';
  signal cm_config_page      : std_logic_vector(3 downto 0) := (others => '0');
  signal cm_epcqio_address   : std_logic_vector(31 downto 0);
  signal cm_epcqio_numwords  : std_logic_vector(6 downto 0);
  signal cm_epcqio_read_data : std_logic                    := '0';
  signal cm_eth_data_out     : std_logic_vector(31 downto 0);
  signal cm_eth_port_out     : std_logic_vector(15 downto 0);
  signal cm_eth_dval_out     : std_logic;
  signal cm_eth_data_in      : std_logic_vector(31 downto 0);
  signal cm_eth_port_in      : std_logic_vector(15 downto 0);
  signal cm_eth_dval_in      : std_logic;
  signal cm_config_busy      : std_logic                    := '0';
  signal cm_config_done      : std_logic                    := '0';

  -----------------------------------------------------------------------------
  -- External configuration data inputs
  -----------------------------------------------------------------------------

  signal config_data_in_ext  : std_logic_vector(31 downto 0) := (others => '0');
  signal config_valid_in_ext : std_logic                     := '0';

  -----------------------------------------------------------------------------
  -- Monitoring block interface
  -----------------------------------------------------------------------------
  signal start_monitoring_cmd     : std_logic := '0';
  signal read_monitoring_register : std_logic := '0';

  constant Reg32b_monitoring_const : array18x32b                   := (others => X"DE_AD_BE_BE");
  constant reg96b_const            : std_logic_vector(95 downto 0) := X"01_23_45_67_89_AB_CD_EF_00_11_22_33";

  
begin
  
  -----------------------------------------------------------------------------
  -- Ethernet data passthrough
  -----------------------------------------------------------------------------
  data_out       <= eth_data_out;
  data_out_valid <= eth_data_valid;
  data_out_udp   <= eth_data_port;
  -----------------------------------------------------------------------------
  -- LED/config outputs
  -----------------------------------------------------------------------------
  led_acts(0)    <= led0_act;
  led_acts(1)    <= led1_act;
  led_acts(2)    <= led2_act;

  led_links(0) <= led0_link;
  led_links(1) <= led1_link;
  led_links(2) <= led2_link;

  led_combined <= led_combined_sig;

  config_data_out_sig <= config_data_out_eth when config_valid_out_eth = '1' else
                         config_data_out_scan when config_valid_out_scan = '1' else
                         X"00_00_00_00";
  config_valid_out_sig <= config_valid_out_eth or config_valid_out_scan;

  config_data_out  <= config_data_out_sig;
  config_valid_out <= config_valid_out_sig;


  -----------------------------------------------------------------------------
  -- Data input fanouts
  -----------------------------------------------------------------------------

  data0_in(0 to NFIFOS-2)   <= data_in(0 to NFIFOS-2);
  wrreqs0_in(0 to NFIFOS-2) <= wrreqs_in(0 to NFIFOS-2);

  data1_in(0 to NFIFOS-2)   <= data_in(0 to NFIFOS-2);
  wrreqs1_in(0 to NFIFOS-2) <= wrreqs_in(0 to NFIFOS-2);

  data2_in(0 to NFIFOS-2)   <= data_in(0 to NFIFOS-2);
  wrreqs2_in(0 to NFIFOS-2) <= wrreqs_in(0 to NFIFOS-2);

  --Our loopback data/external data multiplexer
  data0_in(NFIFOS-1)   <= loopback_data0  when enable_loopback else data_in(NFIFOS-1);
  wrreqs0_in(NFIFOS-1) <= loopback_wrreq0 when enable_loopback else wrreqs_in(NFIFOS-1);

  data1_in(NFIFOS-1)   <= loopback_data1  when enable_loopback else data_in(NFIFOS-1);
  wrreqs1_in(NFIFOS-1) <= loopback_wrreq1 when enable_loopback else wrreqs_in(NFIFOS-1);

  data2_in(NFIFOS-1)   <= loopback_data2  when enable_loopback else data_in(NFIFOS-1);
  wrreqs2_in(NFIFOS-1) <= loopback_wrreq2 when enable_loopback else wrreqs_in(NFIFOS-1);

  wrclks0_in <= wrclks_in;
  wrclks1_in <= wrclks_in;
  wrclks2_in <= wrclks_in;

  -----------------------------------------------------------------------------
  -- UDP data 
  -----------------------------------------------------------------------------
  udp_eop_in        <= udp_eop_out;
  udp_data_port_in  <= udp_port_out;
  udp_data_valid_in <= udp_valid_out;
  udp_data_in       <= udp_data_out;
  udp_addr_in       <= udp_addr_out;

  -----------------------------------------------------------------------------
  -- Command signals
  -----------------------------------------------------------------------------
  command_error <= op_code_error;
  command_done  <= ccdint_read_done or end_sequence or scan_finished or
                  ccdint_erase_done or epcqio_done;
  error_code          <= X"00_00_0" & "00" & op_code_error_add;
  op_code_error_reset <= clear_error or ccdint_op_code_error_reset;

  -----------------------------------------------------------------------------
  -- Configuration outputs
  -----------------------------------------------------------------------------
  --!Register inputs from external configuration lines
  external_config_register : process(clock)
  begin
    if rising_edge(clock) then
      config_data_in_ext  <= config_data_in;
      config_valid_in_ext <= config_valid_in;
    end if;
  end process;

  config_data_in_mult(0)  <= config_data_out0;
  config_valid_in_mult(0) <= config_valid_out0;
  config_data_in_mult(1)  <= config_data_out1;
  config_valid_in_mult(1) <= config_valid_out1;
  config_data_in_mult(2)  <= config_data_out2;
  config_valid_in_mult(2) <= config_valid_out2;
  config_data_in_mult(3)  <= config_data_in_ext;
  config_valid_in_mult(3) <= config_valid_in_ext;

  -----------------------------------------------------------------------------
  -- EPCQIO Interface
  -----------------------------------------------------------------------------
  epcqio_epcq_clock <= epcqio_clock;

  epcqio_multiplexer : process(clock)
  begin
    if rising_edge(clock) then
      epcqio_write_data   <= con_epcqio_write_data;
      epcqio_erase_sector <= con_epcqio_erase_sector;
      epcqio_enable_4byte <= con_epcqio_enable_4byte;
      if cm_epcqio_read_data = '1' then
        epcqio_address   <= cm_epcqio_address;
        epcqio_num_words <= cm_epcqio_numwords;
        epcqio_read_data <= '1';
      else
        epcqio_address   <= con_epcqio_address;
        epcqio_num_words <= con_epcqio_num_words;
        epcqio_read_data <= con_epcqio_read_data;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Configuration data manager
  -----------------------------------------------------------------------------
  cm_eth_dval_in  <= udp_data_valid_in;
  cm_eth_port_in  <= udp_data_port_in;
  cm_eth_data_in  <= udp_data_in;
  --If we have another source these will need to be multiplexed
  int_eth_dval_in <= cm_eth_dval_out;
  int_eth_data_in <= cm_eth_data_out;
  int_eth_port_in <= cm_eth_port_out;

  -----------------------------------------------------------------------------
  -- Components
  -----------------------------------------------------------------------------

  ethernet_optical_block_0 : entity work.ethernet_optical_block
    generic map (
      is_testbench => false,
      NFIFOS       => N_IN_FIFOS,
      port_id      => 0)
    port map (
      clock             => clock,
      reset             => reset,
      config_data_in    => config_data_out_sig,
      config_valid_in   => config_valid_out_sig,
      config_data_out   => config_data_out0,
      config_valid_out  => config_valid_out0,
      ref_clk           => ref_clk0,
      rxp               => rxp0,
      txp               => txp0,
      data_in           => data0_in,
      wrreqs_in         => wrreqs0_in,
      wrclks_in         => wrclks0_in,
      udp_data_in       => udp_data_in,
      udp_data_valid_in => udp_data_valid_in and udp_dest_iface(0),
      udp_data_port_in  => udp_data_port_in,
      udp_eop_in        => udp_eop_in,
      udp_addr_in       => udp_addr_in,
      data_out          => data0_out,
      data_valid        => data0_valid,
      data_eop          => data0_eop,
      data_port         => data0_port,
      data_addr_out     => data0_addr_out,
      led_link          => led0_link,
      led_act           => led0_act,
      eth_ready         => eth0_ready,
      rx_recovclkout => rx_recovclkout0);

  ethernet_optical_block_1 : entity work.ethernet_optical_block
    generic map (
      is_testbench => false,
      NFIFOS       => N_IN_FIFOS,
      port_id      => 1)
    port map (
      clock             => clock,
      reset             => reset,
      config_data_in    => config_data_out_sig,
      config_valid_in   => config_valid_out_sig,
      config_data_out   => config_data_out1,
      config_valid_out  => config_valid_out1,
      ref_clk           => ref_clk1,
      rxp               => rxp1,
      txp               => txp1,
      data_in           => data1_in,
      wrreqs_in         => wrreqs1_in,
      wrclks_in         => wrclks1_in,
      udp_data_in       => udp_data_in,
      udp_data_valid_in => udp_data_valid_in and udp_dest_iface(1),
      udp_data_port_in  => udp_data_port_in,
      udp_addr_in       => udp_addr_in,
      udp_eop_in        => udp_eop_in,
      data_out          => data1_out,
      data_valid        => data1_valid,
      data_eop          => data1_eop,
      data_port         => data1_port,
      data_addr_out     => data1_addr_out,
      led_link          => led1_link,
      led_act           => led1_act,
      eth_ready         => eth1_ready,
      rx_recovclkout => rx_recovclkout1);

  ethernet_copper_block : entity work.ethernet_sgmii_block
    generic map (
      is_testbench => false,
      NFIFOS       => N_IN_FIFOS,
      port_id      => 2)
    port map (
      clock             => clock,
      reset             => reset,
      config_data_in    => config_data_out_sig,
      config_valid_in   => config_valid_out_sig,
      config_data_out   => config_data_out2,
      config_valid_out  => config_valid_out2,
      mdc               => mdc,
      mdio              => mdio,
      ref_clk           => ref_clk2,
      rxp               => rxp2,
      txp               => txp2,
      data_in           => data2_in,
      wrreqs_in         => wrreqs2_in,
      wrclks_in         => wrclks2_in,
      udp_data_in       => udp_data_in,
      udp_data_valid_in => udp_data_valid_in and udp_dest_iface(2),
      udp_data_port_in  => udp_data_port_in,
      udp_eop_in        => udp_eop_in,
      udp_addr_in       => udp_addr_in,
      data_out          => data2_out,
      data_valid        => data2_valid,
      data_eop          => data2_eop,
      data_port         => data2_port,
      data_addr_out     => data2_addr_out,
      hw_reset_out      => hw_reset_out,
      led_link          => led2_link,
      led_act           => led2_act,
      eth_ready         => eth2_ready);

  ethernet_led_signaler_1 : entity work.ethernet_led_signaler
    generic map (
      blink_cycles => LED_BLINK_CYCLES)
    port map (
      clock            => clock,
      led0_link        => led0_link,
      led0_act         => led0_act,
      led1_link        => led1_link,
      led1_act         => led1_act,
      led2_link        => led2_link,
      led2_act         => led2_act,
      led_link_out     => led_link_sig,
      led_act_out      => led_act_sig,
      led_combined_out => led_combined_sig);

  ethernet_data_router_1 : entity work.ethernet_data_router
    port map (
      clock           => clock,
      reset           => reset,
      data_in0        => data0_out,
      data_valid0     => data0_valid,
      data_port0      => data0_port,
      data_addr0      => data0_addr_out,
      data_in1        => data1_out,
      data_valid1     => data1_valid,
      data_port1      => data1_port,
      data_addr1      => data1_addr_out,
      data_in2        => data2_out,
      data_valid2     => data2_valid,
      data_port2      => data2_port,
      data_addr2      => data2_addr_out,
      int_data_in     => int_eth_data_in,
      int_valid_in    => int_eth_dval_in,
      int_port_in     => int_eth_port_in,
      config_data_out => config_data_out_eth,
      config_valid    => config_valid_out_eth,
      epcqio_data_out => epcqio_data_in,
      epcqio_valid    => epcqio_data_in_valid,
      loopback_data0  => loopback_data0,
      loopback_wrreq0 => loopback_wrreq0,
      loopback_data1  => loopback_data1,
      loopback_wrreq1 => loopback_wrreq1,
      loopback_data2  => loopback_data2,
      loopback_wrreq2 => loopback_wrreq2,
      eth_data_out    => eth_data_out,
      eth_data_port   => eth_data_port,
      eth_data_valid  => eth_data_valid,
      eth_data_addr   => eth_data_addr,
      source_iface    => source_iface);

  -----------------------------------------------------------------------------
  -- Interface to CCD Control
  -----------------------------------------------------------------------------
  ethernet_ccdcontrol_interface_1 : entity work.ethernet_ccdcontrol_interface
    port map (
      clock                    => clock,
      reset                    => reset,
      data_in                  => eth_data_out,
      data_port                => eth_data_port,
      data_valid               => eth_data_valid,
      -- data_out                 => data_out,
      -- data_out_port            => data_out_port,
      -- data_out_valid           => data_out_valid,
      udp_out_bus              => udp_in_bus_ccdint,
      udp_ready                => udp_ready_ccdint,
      read_done                => ccdint_read_done,
      erase_done               => ccdint_erase_done,
      reg32b_cabacspi          => reg32b_cabacspi,
      Reg32b_cabacspi_ReadOnly => Reg32b_cabacspi_ReadOnly,
      start_cabac_SPI          => start_cabac_SPI,
      start_cabac_reset_SPI    => start_cabac_reset_SPI,
      cabacprog_busy           => cabacprog_busy,
      data_from_cabacspi_ready => data_from_cabacspi_ready,
      reset_cabac              => reset_cabac,
      reg96b_crocspi           => reg96b_crocspi,
      reg96b_crocspi_ReadOnly  => reg96b_crocspi_ReadOnly,
      --reg96b_crocspi_ReadOnly  => reg96b_const,
      write_croc_req           => write_croc_req,
      crocprog_busy            => crocprog_busy,
      seq_mem_w_add            => seq_mem_w_add,
      seq_mem_data_in          => seq_mem_data_in,
      program_mem_we           => program_mem_we,
      time_mem_w_en            => time_mem_w_en,
      out_mem_w_en             => out_mem_w_en,
      ind_func_mem_we          => ind_func_mem_we,
      ind_rep_mem_we           => ind_rep_mem_we,
      ind_sub_add_mem_we       => ind_sub_add_mem_we,
      ind_sub_rep_mem_we       => ind_sub_rep_mem_we,
      read_triggers            => read_triggers,
      erase_sequencer          => erase_sequencer,
      prog_mem_redbk           => prog_mem_redbk,
      time_mem_readbk          => time_mem_readbk,
      out_mem_readbk           => out_mem_readbk,
      ind_func_mem_redbk       => ind_func_mem_redbk,
      ind_rep_mem_redbk        => ind_rep_mem_redbk,
      ind_sub_add_mem_redbk    => ind_sub_add_mem_redbk,
      ind_sub_rep_mem_redbk    => ind_sub_rep_mem_redbk,
      program_mem_init_add_in  => program_mem_init_add_in,
      program_mem_init_add_rbk => program_mem_init_add_rbk,
      op_code_error_reset      => ccdint_op_code_error_reset,
      op_code_error            => op_code_error,
      op_code_error_add        => op_code_error_add);

  odile_controller_1 : entity work.odile_controller
    port map (
      clock                  => clock,
      reset                  => reset,
      data_in                => eth_data_out,
      data_valid             => eth_data_valid,
      data_port              => eth_data_port,
      data_addr              => eth_data_addr,
      source_iface           => source_iface,
      start_sequence         => start_sequence,
      step_sequence          => step_sequence,
      stop_sequence          => stop_sequence,
      read_triggers          => read_triggers,
      clear_error            => clear_error,
      reset_cabac            => reset_cabac,
      read_config            => start_scan_blocks,
      erase_sequencer        => erase_sequencer,
      epcqio_read_data       => con_epcqio_read_data,
      epcqio_write_data      => con_epcqio_write_data,
      epcqio_enable_4byte    => con_epcqio_enable_4byte,
      epcqio_erase_sector    => con_epcqio_erase_sector,
      epcqio_clear_buffers   => epcqio_clear_buffers,
      epcqio_address         => con_epcqio_address,
      epcqio_num_words       => con_epcqio_num_words,
      ru_do_reconfig         => ru_do_reconfig,
      ru_application_address => ru_application_address,
      ru_reread_params       => ru_reread_params,
      start_monitoring       => start_monitoring_cmd,
      read_monitoring        => read_monitoring_register,
      read_croc              => read_croc_req,
      cm_load_config         => cm_load_config,
      cm_config_page         => cm_config_page,
      send_cmd_ack           => send_cmd_ack,
      cmd_to_ack             => cmd_to_ack,
      reply_iface            => cmd_reply_iface,
      reply_addr             => cmd_reply_addr,
      switches               => switches);

  command_response_generator_1 : entity work.command_response_generator
    port map (
      clock         => clock,
      reset         => reset,
      send_cmd_ack  => send_cmd_ack,
      data_in       => cmd_to_ack,
      command_done  => command_done,
      command_error => command_error,
      error_code    => error_code,
      udp_out_bus   => udp_in_bus_cmd,
      udp_ready     => udp_ready_cmd,
      busy          => udp_gen_busy);

  udp_data_arbiter_1 : entity work.udp_data_arbiter
    port map (
      clock             => clock,
      reset             => reset,
      udp_data_out      => udp_data_out,
      udp_port_out      => udp_port_out,
      udp_valid_out     => udp_valid_out,
      udp_eop_out       => udp_eop_out,
      udp_addr_out      => udp_addr_out,
      udp_dest_iface    => udp_dest_iface,
      udp_in_bus_cmd    => udp_in_bus_cmd,
      udp_ready_cmd     => udp_ready_cmd,
      udp_in_bus_ccdint => udp_in_bus_ccdint,
      udp_ready_ccdint  => udp_ready_ccdint,
      udp_in_bus_scan   => udp_in_bus_scan,
      udp_ready_scan    => udp_ready_scan,
      udp_in_bus_epcqio => udp_in_bus_epcqio,
      udp_ready_epcqio  => udp_ready_epcqio,
      udp_in_bus_monit  => udp_in_bus_monit,
      udp_ready_monit   => udp_ready_monit,
      udp_tx_busy       => udp_tx_busy,
      dest_iface        => cmd_reply_iface,
      dest_addr         => cmd_reply_addr);


  config_block_scanner_1 : entity work.config_block_scanner
    port map (
      clock               => clock,
      reset               => reset,
      config_data_in      => config_data_in_scan,
      config_valid_in     => config_valid_in_scan,
      config_data_out     => config_data_out_scan,
      config_valid_out    => config_valid_out_scan,
      udp_out_bus         => udp_in_bus_scan,
      udp_ready           => udp_ready_scan,
      start_scan_blocks   => start_scan_blocks,
      scan_finished       => scan_finished,
      start_scan_single   => start_scan_single,
      start_block_address => start_block_address,
      busy                => busy);

  config_read_multiplexer_1 : entity work.config_read_multiplexer
    generic map (
      NCONFIG_LINES => NCONFIG_LINES)
    port map (
      clock            => clock,
      config_data_in   => config_data_in_mult,
      config_valid_in  => config_valid_in_mult,
      config_data_out  => config_data_in_scan,
      config_valid_out => config_valid_in_scan);

  epcqio_control_1 : entity work.epcqio_control
    port map (
      epcq_clock        => epcqio_epcq_clock,
      data_clock        => clock,
      reset             => reset,
      data_in           => epcqio_data_in,
      data_in_valid     => epcqio_data_in_valid,
      write_buffer_full => epcqio_write_buffer_full,
      udp_out_bus       => udp_in_bus_epcqio,
      udp_ready         => udp_ready_epcqio,
      address           => epcqio_address,
      num_words         => epcqio_num_words,
      read_data         => epcqio_read_data,
      write_data        => epcqio_write_data,
      enable_4byte      => epcqio_enable_4byte,
      erase_sector      => epcqio_erase_sector,
      read_busy         => epcqio_read_busy,
      write_busy        => epcqio_write_busy,
      done              => epcqio_done,
      error_code        => epcqio_error_code,
      error_status      => epcqio_error_status,
      clear_buffers     => epcqio_clear_buffers);

  remote_update_control_1 : entity work.remote_update_control
    port map (
      clock               => clock,
      reset               => reset,
      do_reconfig         => ru_do_reconfig,
      reread_params       => ru_reread_params,
      application_address => ru_application_address,
      is_anf              => ru_is_anf,
      reconfig_error      => ru_reconfig_error);

  config_data_manager_1 : entity work.config_data_manager
    port map (
      clock          => clock,
      reset          => reset,
      load_config    => cm_load_config,
      config_page    => cm_config_page,
      epcq_address   => cm_epcqio_address,
      epcq_numwords  => cm_epcqio_numwords,
      epcq_read_data => cm_epcqio_read_data,
      eth_data_out   => cm_eth_data_out,
      eth_port_out   => cm_eth_port_out,
      eth_dval_out   => cm_eth_dval_out,
      eth_data_in    => cm_eth_data_in,
      eth_port_in    => cm_eth_port_in,
      eth_dval_in    => cm_eth_dval_in,
      config_busy    => cm_config_busy,
      config_done    => cm_config_done);

  ethernet_monitoring_interface_1 : entity work.ethernet_monitoring_interface
    port map (
      clock                => clock,
      reset                => reset,
      read_register        => read_monitoring_register,
      start_monitoring_cmd => start_monitoring_cmd,
      start_monitoring     => start_monitoring,
      monitoring_busy      => monitoring_busy,
      Reg32b_monitoring    => Reg32b_monitoring,
      udp_out_bus          => udp_in_bus_monit,
      udp_ready            => udp_ready_monit);

  
end architecture;
