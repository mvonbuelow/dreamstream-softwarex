library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library simmac;
library ds;
library dsnet;
library dsbus;
use dsbus.types.all;

entity tb is
end;

architecture tb_arch of tb is
  signal clk, rst                : std_logic := '1';
  signal link_active, udp_active : std_logic;

  signal my_mac : std_logic_vector(47 downto 0) := x"112233445566";

  constant width : integer := 8;

  signal rx_ready, rx_valid, rx_last, tx_ready, tx_valid, tx_last : std_logic;
  signal rx_data, tx_data                                         : std_logic_vector(width - 1 downto 0);
  signal rx_keep, tx_keep                                         : std_logic_vector(width / 8 - 1 downto 0);
  signal rx_user                                                  : std_logic_vector(0 downto 0);

  signal udp_rx_valid, udp_rx_ready, udp_rx_last, udp_tx_valid, udp_tx_ready, udp_tx_last, udp2_tx_valid, udp2_tx_ready, udp2_tx_last : std_logic;
  signal udp_rx_data, udp_tx_data, udp2_tx_data                                                                                       : std_logic_vector(width - 1 downto 0);
  signal udp_rx_keep, udp_tx_keep, udp2_tx_keep                                                                                       : std_logic_vector(width / 8 - 1 downto 0);

  signal udp_rx_id, udp_tx_dest : std_logic_vector(95 downto 0);

  signal mngr : axi4l_t(
    awaddr(31 downto 0),
    wdata(31 downto 0),
    araddr(31 downto 0),
    rdata(31 downto 0)
    ) := axi4l_default(32, 32);

  signal packet_data         : std_logic_vector(2048 * 8 - 1 downto 0)                             := (others => '0');
  constant packet_size       : integer                                                             := 1472;
  constant packet_keep_ones  : std_logic_vector(packet_size - 1 downto 0)                          := (others => '1');
  constant packet_keep_zeros : std_logic_vector(packet_data'length / 8 - packet_size - 1 downto 0) := (others => '0');
  signal packet_keep         : std_logic_vector(2047 downto 0)                                     := packet_keep_ones & packet_keep_zeros;

  constant udp2_tx_dest : std_logic_vector(95 downto 0) := (others => '1');
begin
  -- udp port 0x1234 echos
  udp_tx_valid <= udp_rx_valid;
  udp_tx_last  <= udp_rx_last;
  udp_tx_data  <= udp_rx_data;
  udp_tx_keep  <= udp_rx_keep;
  udp_tx_dest  <= udp_rx_id;
  udp_rx_ready <= udp_tx_ready;

  -- udp port 0x4321 sends big packets
  resizer_inst : entity ds.resizer generic map (
    width     => packet_data'length,
    out_width => width
    ) port map (
      clk => clk,
      rst => rst,

      in_data  => packet_data,
      in_keep  => packet_keep,
      in_last  => '1',
      in_valid => '1',

      out_valid => udp2_tx_valid,
      out_ready => udp2_tx_ready,
      out_data  => udp2_tx_data,
      out_last  => udp2_tx_last
      );


  clk <= not clk after 4 ns;
  proc_rst : process
  begin
    wait for 123 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait;
  end process;

  simmac_inst : entity simmac.simmac generic map (
    ifname => "ds",
    width  => width
    ) port map (
      clk           => clk,
      rst_n         => not rst,
      link_active_o => link_active,
      -- usr_clk_o => usr_clk,
      rx_valid      => rx_valid,
      rx_ready      => rx_ready,
      rx_data       => rx_data,
      rx_last       => rx_last,
      rx_keep       => rx_keep,
      tx_data       => tx_data,
      tx_ready      => tx_ready,
      tx_valid      => tx_valid,
      tx_last       => tx_last,
      rx_error      => rx_user(0)
      );


  udp_stack_inst : entity dsnet.udp_stack
    generic map (
      width        => width,
      drop_if_full => false,  -- use this for real MACs that have no back pressure
      ntx          => 2,
      nrx          => 1,
      tx_ports     => (0 => x"1234", 1 => x"4321"),
      rx_ports     => (0 => x"1234")
      )
    port map (
      clk     => clk,
      rst     => rst or not link_active,
      src_mac => my_mac,

      udp_tx_valid(0) => udp_tx_valid,
      udp_tx_valid(1) => udp2_tx_valid,
      udp_tx_ready(0) => udp_tx_ready,
      udp_tx_ready(1) => udp2_tx_ready,
      udp_tx_last(0)  => udp_tx_last,
      udp_tx_last(1)  => udp2_tx_last,
      udp_tx_data(0)  => udp_tx_data,
      udp_tx_data(1)  => udp2_tx_data,
      udp_tx_keep(0)  => udp_tx_keep,
      udp_tx_keep(1)  => udp2_tx_keep,
      udp_tx_dest(0)  => udp_tx_dest,
      udp_tx_dest(1)  => udp2_tx_dest,

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

