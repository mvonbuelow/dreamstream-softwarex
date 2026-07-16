-------------------------------------------------------------------------------
-- rx_bandwidth_tb
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This testbench measures the RX bandwidth of the UDP stacks auto-
--              matcially.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
library dsnet;
library dsbus;

use ds.types.all;
use dsbus.types.all;

entity rx_bandwidth_tb is
end;

architecture rx_bandwidth_tb_arch of rx_bandwidth_tb is
  signal clk, rst                : std_logic := '1';
  signal finished                : std_logic;
  signal link_active, udp_active : std_logic;

  constant my_mac      : std_logic_vector(47 downto 0) := x"112233445566";  -- Does not matter. You can use that in your DHCP server if you want.
  constant my_ip       : std_logic_vector              := x"11223344";  -- Configure 0.0.0.0 to use DHCP.
  constant burst       : boolean                       := true;
  constant udp_tx_dest : std_logic_vector(95 downto 0) := x"ffffffffffff" & x"ffffffff" & x"4321";

  constant packet_size : integer := work.compileconfig.string_to_integer(work.compileconfig.packet_size);
  constant width       : integer := work.compileconfig.string_to_integer(work.compileconfig.width);
  constant freq        : real    := real(work.compileconfig.string_to_integer(work.compileconfig.freq)) / 1000.0;  -- just for nice numbers

  constant estimate : real := real(7 * 1 + 312 / width) * 1000.0 / freq;

  signal rx_ready, rx_valid, rx_last, tx_ready, tx_valid, tx_last : std_logic;
  signal rx_data, tx_data                                         : std_logic_vector(width - 1 downto 0);
  signal rx_keep, tx_keep                                         : std_logic_vector(width / 8 - 1 downto 0);
  signal rx_user                                                  : std_logic_vector(0 downto 0);

  signal udp_rx_valid, udp_rx_ready, udp_rx_last, udp_tx_valid, udp_tx_ready, udp_tx_last, udp2_tx_valid, udp2_tx_ready, udp2_tx_last : std_logic;
  signal udp_rx_data, udp_tx_data, udp2_tx_data                                                                                       : std_logic_vector(width - 1 downto 0);
  signal udp_rx_keep, udp_tx_keep, udp2_tx_keep                                                                                       : std_logic_vector(width / 8 - 1 downto 0);

  signal udp_rx_id : std_logic_vector(95 downto 0);

  signal mngr : axi4l_t(
    awaddr(31 downto 0),
    wdata(31 downto 0),
    araddr(31 downto 0),
    rdata(31 downto 0)
    ) := axi4l_default(32, 32);

  constant udp_for_me : std_logic_vector := my_mac & my_mac & x"0800" & x"45000000" & x"00000000" & x"0011_0000" & x"00000000" & my_ip & x"12341234"& x"00000000";
begin
  mngr.awvalid <= '1';
  mngr.awaddr  <= x"0000_0200";
  mngr.wvalid  <= '1';
  mngr.wdata   <= my_ip;
  mngr.bready  <= '1';

  clk <= not clk and not finished after 4 ns;
  proc_rst : process
  begin
    wait for 123 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait;
  end process;

  bandwidth_measure_inst : entity work.bandwidth_measure generic map (
    width        => width,
    nprepend     => udp_for_me'length,
    prepend      => udp_for_me,
    packet_size  => packet_size,
    freq         => freq,
    estimate     => estimate,
    direction_in => false
    ) port map (
      clk       => clk,
      rst       => rst,
      out_valid => rx_valid,
      out_ready => rx_ready,
      out_data  => rx_data,
      out_last  => rx_last,
      out_keep  => rx_keep,
      in_valid  => udp_rx_valid,
      in_data   => udp_rx_data,
      in_last   => udp_rx_last,
      in_keep   => udp_rx_keep,
      in_ready  => udp_rx_ready,
      finished  => finished
      );

  udp_stack_inst : entity dsnet.udp_stack
    generic map (
      width        => width,
      drop_if_full => false,  -- use this for real MACs that have no back pressure
      ntx          => 1,
      nrx          => 1,
      tx_ports     => (0 => x"1234"),
      rx_ports     => (0 => x"1234"),
      rxfifo       => false,
      txfifo       => false
      )
    port map (
      clk     => clk,
      rst     => rst or not link_active,
      src_mac => my_mac,

      udp_tx_valid(0) => udp_tx_valid,
      udp_tx_ready(0) => udp_tx_ready,
      udp_tx_last(0)  => udp_tx_last,
      udp_tx_data(0)  => udp_tx_data,
      udp_tx_keep(0)  => udp_tx_keep,
      udp_tx_dest(0)  => udp_tx_dest,

      udp_rx_valid(0) => udp_rx_valid,
      udp_rx_ready(0) => udp_rx_ready,
      udp_rx_last(0)  => udp_rx_last,
      udp_rx_data(0)  => udp_rx_data,
      udp_rx_keep(0)  => udp_rx_keep,
      udp_rx_id(0)    => udp_rx_id,

      active   => udp_active,
      -- mac data stream
      rx_ready => rx_ready,
      rx_data  => rx_data,
      rx_valid => rx_valid,
      rx_last  => rx_last,
      rx_user  => rx_user,
      rx_keep  => rx_keep,
      tx_ready => tx_ready,
      tx_data  => tx_data,
      tx_last  => tx_last,
      tx_valid => tx_valid,
      tx_keep  => tx_keep,

      reg => mngr
      );
end architecture;

