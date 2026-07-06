library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library simmac;
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

  signal udp_rx_valid, udp_rx_ready, udp_rx_last, udp_tx_valid, udp_tx_ready, udp_tx_last : std_logic;
  signal udp_rx_data, udp_tx_data                                                         : std_logic_vector(width - 1 downto 0);
  signal udp_rx_keep, udp_tx_keep                                                         : std_logic_vector(width / 8 - 1 downto 0);

  signal udp_rx_id, udp_tx_dest : std_logic_vector(95 downto 0);

  signal mngr : axi4l_t(
    awaddr(31 downto 0),
    wdata(31 downto 0),
    araddr(31 downto 0),
    rdata(31 downto 0)
    ) := axi4l_default(32, 32);
begin

  udp_tx_valid <= udp_rx_valid;
  udp_tx_last  <= udp_rx_last;
  udp_tx_data  <= udp_rx_data;
  udp_tx_keep  <= udp_rx_keep;
  udp_tx_dest  <= udp_rx_id;
  udp_rx_ready <= udp_tx_ready;


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
      ntx          => 1,
      nrx          => 1,
      tx_ports     => (1 => x"1234"),
      rx_ports     => (0 => x"1234")
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

