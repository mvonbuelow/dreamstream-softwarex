-------------------------------------------------------------------------------
-- udp_stack
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This includes all modules required for a full UDP pipeline.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;
library dsnet;
library dsbus;
use dsbus.types.all;

entity udp_stack is
  generic (
    width        : integer := 64;
    vendor_bytes : integer := 8;
    drop_if_full : boolean := true;
    ntx          : integer;
    nrx          : integer;
    tx_ports     : std_logic_vector_array(0 to ntx - 1)(15 downto 0);
    rx_ports     : std_logic_vector_array(0 to nrx - 1)(15 downto 0);
    rxfifo       : boolean := true;
    txfifo       : boolean := true
    );
  port (
    clk         : in std_logic;
    rst         : in std_logic;
    link_active : in std_logic := '1';  -- deprecated

    udp_tx_valid : in  std_logic_vector(ntx - 1 downto 0);
    udp_tx_ready : out std_logic_vector(ntx - 1 downto 0);
    udp_tx_data  : in  std_logic_vector_array(0 to ntx - 1)(width - 1 downto 0);
    udp_tx_keep  : in  std_logic_vector_array(0 to ntx - 1)(width / 8 - 1 downto 0);
    udp_tx_last  : in  std_logic_vector(ntx - 1 downto 0);
    udp_tx_dest  : in  std_logic_vector_array(0 to ntx - 1)(95 downto 0);
    udp_rx_valid : out std_logic_vector(nrx - 1 downto 0);
    udp_rx_ready : in  std_logic_vector(nrx - 1 downto 0);
    udp_rx_data  : out std_logic_vector_array(0 to nrx - 1)(width - 1 downto 0);
    udp_rx_keep  : out std_logic_vector_array(0 to nrx - 1)(width / 8 - 1 downto 0);
    udp_rx_last  : out std_logic_vector(nrx - 1 downto 0);
    udp_rx_id    : out std_logic_vector_array(0 to nrx - 1)(95 downto 0);

    rx_ready : out std_logic;
    rx_valid : in  std_logic;
    rx_data  : in  std_logic_vector(width - 1 downto 0);
    rx_keep  : in  std_logic_vector(width / 8 - 1 downto 0) := (others => '1');
    rx_last  : in  std_logic;
    rx_user  : in  std_logic_vector(0 downto 0);

    tx_ready  : in  std_logic;
    tx_valid  : out std_logic;
    tx_data   : out std_logic_vector(width - 1 downto 0);
    tx_keep   : out std_logic_vector(width / 8 - 1 downto 0)        := (others => '1');
    tx_last   : out std_logic;
    src_mac   : in  std_logic_vector(47 downto 0);
    vendor_id : in  std_logic_vector(vendor_bytes * 8 - 1 downto 0) := (others => '0');  -- just an ID that is broadcasted by DHCP
    reg       :     view axi4l_mngr_v;

    active : out std_logic := '0'
    );
end;

architecture udp_stack_arch of udp_stack is
  signal eth_valid, eth_ready, eth_last, ip_valid, ip_ready, ip_last, udp_valid, udp_ready, udp_last,
    ipv4eth_valid, ipv4eth_ready, ipv4eth_last, arpeth_valid, arpeth_ready, arpeth_last,
    icmpipv4_valid, icmpipv4_ready, icmpipv4_last, udpipv4_valid, udpipv4_ready, udpipv4_last,
    igmpipv4_valid, igmpipv4_ready, igmpipv4_last,
    rx_eth_valid, rx_eth_valid2, rx_eth_ready, rx_eth_last,
    dhcpudp_valid, dhcpudp_ready, dhcpudp_last,
    rx_ipv4_filtered_valid, rx_ipv4_filtered_ready, rx_ipv4_filtered_last,
    rx_ipv4_valid, rx_ipv4_ready, rx_ipv4_last,
    rx_udp_valid, rx_udp_ready, rx_udp_last : std_logic;
  signal eth_data, ip_data, udp_data,
    ipv4eth_data, icmpipv4_data, igmpipv4_data, udpipv4_data, arpeth_data, dhcpudp_data,
    rx_eth_data, rx_ipv4_data, rx_ipv4_filtered_data, rx_udp_data : std_logic_vector(width - 1 downto 0);
  signal eth_keep, ip_keep, udp_keep,
    ipv4eth_keep, icmpipv4_keep, igmpipv4_keep, udpipv4_keep, arpeth_keep, dhcpudp_keep,
    rx_eth_keep, rx_ipv4_keep, rx_ipv4_filtered_keep, rx_udp_keep : std_logic_vector(width / 8 - 1 downto 0);

  signal src_mac_r                                                                            : std_logic_vector(47 downto 0);
  signal vendor_id_r                                                                          : std_logic_vector(vendor_id'range);
  signal src_ip, static_ip, src_ip_r, src_subnetmask, src_subnetmask_r, static_mask           : std_logic_vector(31 downto 0) := (others => '0');
  signal eth_dest, ipv4eth_dest, arpeth_dest, rx_eth_dest, rx_eth_id                          : std_logic_vector(47 downto 0);
  signal eth_user, ipv4eth_user, arpeth_user                                                  : std_logic_vector(15 downto 0);
  signal rx_eth_user                                                                          : std_logic_vector(18 downto 0);
  signal ip_dest, icmpipv4_dest, igmpipv4_dest, udpipv4_dest, rx_ipv4_id, rx_ipv4_filtered_id : std_logic_vector(48 + 32 - 1 downto 0);
  signal ip_user, icmpipv4_user, igmpipv4_user, udpipv4_user                                  : std_logic_vector(15 + 8 downto 0);
  signal udp_dest, dhcpudp_dest, rx_udp_id                                                    : std_logic_vector(16 + 48 + 32 - 1 downto 0);
  signal udp_id, dhcpudp_user, dhcpudp_id                                                     : std_logic_vector(15 downto 0);
  signal rx_udp_user                                                                          : std_logic_vector(1 + log2_ceil(nrx + 2) - 1 downto 0);
  signal rx_ipv4_user                                                                         : std_logic_vector(9 downto 0);
  signal rx_ipv4_filtered_user                                                                : std_logic_vector(10 downto 0);
  signal rx_ipv4_dest, rx_ipv4_filtered_dest                                                  : std_logic_vector(31 downto 0);
  signal rx_udp_dest                                                                          : std_logic_vector(15 + 32 downto 0);

  signal use_static                                                                                                                                             : boolean;
  signal arbiter_user0, arbiter_user1                                                                                                                           : std_logic_vector(47 + 16 downto 0);
  signal ipv4arbiter_user0, ipv4arbiter_user1                                                                                                                   : std_logic_vector(80 + 23 downto 0);
  signal rx_eth_valid_arp, rx_eth_valid_ipv4, rx_eth_ready_ipv4, rx_eth_ready_arp                                                                               : std_logic;
  signal rx_ipv4_filtered_valid_udp, rx_ipv4_filtered_valid_icmp, rx_ipv4_filtered_ready_udp, rx_ipv4_filtered_ready_icmp, rx_udp_valid_dhcp, rx_udp_ready_dhcp : std_logic;

  signal dhcp_done, have_ip : std_logic := '0';

  signal subs : axi4l_array_t(0 to 1)(
    awaddr(reg.awaddr'range),
    wdata(reg.wdata'range),
    araddr(reg.araddr'range),
    rdata(reg.rdata'range)
    ) := (others => axi4l_default(reg.araddr'length, reg.rdata'length));

  signal txfifo_data                                                                : std_logic_vector(rx_data'range);
  signal txfifo_keep                                                                : std_logic_vector(rx_keep'range) := (others => '1');
  signal txfifo_valid, txfifo_ready, txfifo_last                                    : std_logic;
  signal txreg_data, rxreg_data                                                     : std_logic_vector(rx_data'range);
  signal txreg_keep, rxreg_keep                                                     : std_logic_vector(rx_keep'range) := (others => '1');
  signal txreg_valid, rxreg_valid, txreg_ready, rxreg_ready, txreg_last, rxreg_last : std_logic;
  signal rxfrontreg_data                                                            : std_logic_vector(rx_data'range);
  signal rxfrontreg_keep                                                            : std_logic_vector(rx_keep'range) := (others => '1');
  signal rxfrontreg_valid, rxfrontreg_ready, rxfrontreg_last                        : std_logic;
  signal rxfrontreg_user                                                            : std_logic_vector(0 downto 0);
  signal int_rst                                                                    : std_logic;
  signal drop                                                                       : std_logic;
begin
  addr_regs : block
    signal ipmux, maskmux : std_logic_vector(31 downto 0);
  begin
    int_rst          <= rst or not link_active when rising_edge(clk);
    have_ip          <= dhcp_done or ite_l(use_static, '1', '0');
    active           <= have_ip                when rising_edge(clk);
    use_static       <= static_ip /= x"00000000";
    ipmux            <= static_ip              when use_static else src_ip;
    maskmux          <= static_mask            when use_static else src_subnetmask;
    src_mac_r        <= src_mac                when rising_edge(clk);
    vendor_id_r      <= vendor_id              when rising_edge(clk);
    src_ip_r         <= ipmux                  when rising_edge(clk);
    src_subnetmask_r <= maskmux                when rising_edge(clk);
  end block;
  -- rxfrontreg_inst : entity ds.reg2 generic map (
  --   width => width,
  --   user  => 1
  --   ) port map (
  --     clk       => clk,
  --     rst       => int_rst,
  --     in_ready  => rx_ready,
  --     in_valid  => rx_valid,
  --     in_data   => rx_data,
  --     in_last   => rx_last,
  --     in_keep   => rx_keep,
  --     in_user   => rx_user,
  --     out_ready => rxfrontreg_ready,
  --     out_valid => rxfrontreg_valid,
  --     out_data  => rxfrontreg_data,
  --     out_last  => rxfrontreg_last,
  --     out_keep  => rxfrontreg_keep,
  --     out_user  => rxfrontreg_user
  --     );

  ifrxfifo : if rxfifo generate
    rxfifo_inst : entity ds.fifo generic map (
      width           => width,
      depth           => 256 * 64 / width,
      use_last        => true,
      packet_mode     => true,
      drop_packet     => true,
      max_packets     => 2,
      outreg          => true,
      use_keep        => true,
      ignore_keep_msb => true
      ) port map (
        clk       => clk,
        rst       => int_rst,
        in_ready  => rx_ready,
        in_valid  => rx_valid,
        in_data   => rx_data,
        in_keep   => rx_keep,
        in_last   => rx_last,
        in_drop   => drop,
        out_ready => rxreg_ready,
        out_valid => rxreg_valid,
        out_data  => rxreg_data,
        out_last  => rxreg_last,
        out_keep  => rxreg_keep
        );
    drop <= '1' when (rx_valid = '1' and rx_ready = '0' and drop_if_full) else '0';  --(rx_valid = '1' and rx_user(0) = '1') or 
  else generate
    rx_ready    <= rxreg_ready;
    rxreg_valid <= rx_valid;
    rxreg_data  <= rx_data;
    rxreg_keep  <= rx_keep;
    rxreg_last  <= rx_last;
  end generate;

  iftxfifo : if txfifo generate
    txfifo_inst : entity ds.fifo generic map (
      width           => width,
      depth           => 256 * 64 / width,
      use_last        => true,
      packet_mode     => true,
      max_packets     => 2,
      use_keep        => true,
      ignore_keep_msb => true
      ) port map (
        clk       => clk,
        rst       => int_rst,
        in_ready  => txfifo_ready,
        in_valid  => txfifo_valid,
        in_data   => txfifo_data,
        in_keep   => txfifo_keep,
        in_last   => txfifo_last,
        out_ready => txreg_ready,
        out_valid => txreg_valid,
        out_data  => txreg_data,
        out_keep  => txreg_keep,
        out_last  => txreg_last
        );
    txreg_inst : entity ds.reg2 generic map (
      width => width
      ) port map (
        clk       => clk,
        rst       => int_rst,
        in_ready  => txreg_ready,
        in_valid  => txreg_valid,
        in_data   => txreg_data,
        in_last   => txreg_last,
        in_keep   => txreg_keep,
        out_ready => tx_ready,
        out_valid => tx_valid,
        out_data  => tx_data,
        out_last  => tx_last,
        out_keep  => tx_keep
        );
  else generate
    txfifo_ready <= tx_ready;
    tx_valid     <= txfifo_valid;
    tx_data      <= txfifo_data;
    tx_keep      <= txfifo_keep;
    tx_last      <= txfifo_last;
  end generate;

  crossbar_inst : entity dsbus.crossbar generic map (
    addr_off => 10,
    addr_len => 2
    ) port map (
      clk => clk,
      rst => int_rst,

      mngr => reg,
      subs => subs
      );
  regbank_inst : entity dsbus.regbank generic map (
    nwregs        => 2,
    nrregs        => 4,
    addr_off      => 0,
    addr_len      => 8,
    wreg_addr_bit => 9,
    wreg_defaults => (0 => x"00000000", 1 => x"ffffff00")
    ) port map (
      clk      => clk,
      rst      => int_rst,
      reg      => subs(0),
      wregs(0) => static_ip,
      wregs(1) => static_mask,
      rregs(0) => x"0000" & src_mac_r(47 downto 32),
      rregs(1) => src_mac_r(31 downto 0),
      rregs(2) => src_ip_r,
      rregs(3) => src_subnetmask_r
      );

  -- rx
  net_rx_eth_inst : entity dsnet.rx_eth generic map (
    width     => width,
    nethtypes => 2,
    ethtypes  => (x"0800", x"0806")
    ) port map (
      clk       => clk,
      in_ready  => rxreg_ready,
      in_valid  => rxreg_valid,
      in_data   => rxreg_data,
      in_keep   => rxreg_keep,
      in_last   => rxreg_last,
      out_ready => rx_eth_ready,
      out_valid => rx_eth_valid,
      out_data  => rx_eth_data,
      out_keep  => rx_eth_keep,
      out_last  => rx_eth_last,
      out_dest  => rx_eth_dest,
      out_id    => rx_eth_id,
      out_user  => rx_eth_user,
      my_mac    => src_mac
      );

  eth_filter : block
  begin
    rx_eth_valid2     <= rx_eth_valid and (rx_eth_user(18) or rx_eth_dest(40));  -- check if my MAC or broadcast/MC
    rx_eth_valid_arp  <= '1' when rx_eth_valid2 = '1' and rx_eth_user(17 downto 16) = "01" else '0';
    rx_eth_valid_ipv4 <= '1' when rx_eth_valid2 = '1' and rx_eth_user(17 downto 16) = "00" else '0';
    rx_eth_ready      <= (rx_eth_ready_ipv4 and rx_eth_valid_ipv4) or (rx_eth_ready_arp and rx_eth_valid_arp) or (not rx_eth_valid_ipv4 and not rx_eth_valid_arp);
  end block;

  net_arp_inst : entity dsnet.arp generic map (
    width => width
    ) port map (
      clk       => clk,
      rst       => int_rst,
      in_ready  => rx_eth_ready_arp,
      in_valid  => rx_eth_valid_arp,
      in_data   => rx_eth_data,
      in_keep   => rx_eth_keep,
      in_last   => rx_eth_last,
      in_id     => rx_eth_id,
      out_ready => arpeth_ready,
      out_valid => arpeth_valid,
      out_data  => arpeth_data,
      out_keep  => arpeth_keep,
      out_last  => arpeth_last,
      out_dest  => arpeth_dest,
      out_user  => arpeth_user,
      my_id     => src_mac_r & src_ip_r
      );

  net_rx_ipv4_inst : entity dsnet.rx_ipv4 generic map (
    width   => width,
    nprotos => 2,
    protos  => (x"01", x"11")
    ) port map (
      clk       => clk,
      rst       => int_rst,
      in_valid  => rx_eth_valid_ipv4,
      in_ready  => rx_eth_ready_ipv4,
      in_data   => rx_eth_data,
      in_keep   => rx_eth_keep,
      in_last   => rx_eth_last,
      in_id     => rx_eth_id,
      out_ready => rx_ipv4_ready,
      out_valid => rx_ipv4_valid,
      out_data  => rx_ipv4_data,
      out_keep  => rx_ipv4_keep,
      out_last  => rx_ipv4_last,
      out_id    => rx_ipv4_id,
      out_dest  => rx_ipv4_dest,
      out_user  => rx_ipv4_user
      );
  net_ipv4_address_engine_inst : entity dsnet.ipv4_address_engine generic map (
    width => width,
    user  => 10
    ) port map (
      clk           => clk,
      rst           => int_rst,
      in_data       => rx_ipv4_data,
      in_keep       => rx_ipv4_keep,
      in_dest       => rx_ipv4_dest,
      in_id         => rx_ipv4_id,
      in_user       => rx_ipv4_user,
      in_valid      => rx_ipv4_valid,
      in_ready      => rx_ipv4_ready,
      in_last       => rx_ipv4_last,
      out_data      => rx_ipv4_filtered_data,
      out_keep      => rx_ipv4_filtered_keep,
      out_dest      => rx_ipv4_filtered_dest,
      out_id        => rx_ipv4_filtered_id,
      out_user      => rx_ipv4_filtered_user,
      out_valid     => rx_ipv4_filtered_valid,
      out_ready     => rx_ipv4_filtered_ready,
      out_last      => rx_ipv4_filtered_last,
      mc_out_ready  => igmpipv4_ready,
      mc_out_valid  => igmpipv4_valid,
      mc_out_data   => igmpipv4_data,
      mc_out_keep   => igmpipv4_keep,
      mc_out_last   => igmpipv4_last,
      mc_out_dest   => igmpipv4_dest,
      mc_out_user   => igmpipv4_user,
      my_address    => src_ip_r,
      my_subnetmask => src_subnetmask_r,
      my_valid      => have_ip,
      reg           => subs(1)
      );

  ipv4_anno : block
  begin
    rx_ipv4_filtered_valid_udp  <= rx_ipv4_filtered_valid and ite_l(rx_ipv4_filtered_user(9 downto 8) = "01", '1', '0');
    rx_ipv4_filtered_valid_icmp <= rx_ipv4_filtered_valid and ite_l(rx_ipv4_filtered_user(9 downto 8) = "00" and rx_ipv4_filtered_user(10) = '0', '1', '0');
    rx_ipv4_filtered_ready      <= (rx_ipv4_filtered_ready_udp and rx_ipv4_filtered_valid_udp) or (rx_ipv4_filtered_ready_icmp and rx_ipv4_filtered_valid_icmp) or (not rx_ipv4_filtered_valid_udp and not rx_ipv4_filtered_valid_icmp);
  end block;

  net_icmp_inst : entity dsnet.icmp generic map (
    width => width
    ) port map (
      clk       => clk,
      rst       => int_rst,
      in_ready  => rx_ipv4_filtered_ready_icmp,
      in_valid  => rx_ipv4_filtered_valid_icmp,
      in_data   => rx_ipv4_filtered_data,
      in_keep   => rx_ipv4_filtered_keep,
      in_last   => rx_ipv4_filtered_last,
      in_id     => rx_ipv4_filtered_id,
      out_ready => icmpipv4_ready,
      out_valid => icmpipv4_valid,
      out_data  => icmpipv4_data,
      out_keep  => icmpipv4_keep,
      out_last  => icmpipv4_last,
      out_dest  => icmpipv4_dest,
      out_user  => icmpipv4_user,
      my_id     => src_mac_r & src_ip_r
      );

  net_rx_udp_inst : entity dsnet.rx_udp generic map (
    width  => width,
    user   => 1,
    nports => 2,
    ports  => rx_ports & (x"0044")
    ) port map (
      clk        => clk,
      rst        => int_rst,
      in_ready   => rx_ipv4_filtered_ready_udp,
      in_valid   => rx_ipv4_filtered_valid_udp,
      in_data    => rx_ipv4_filtered_data,
      in_keep    => rx_ipv4_filtered_keep,
      in_last    => rx_ipv4_filtered_last,
      in_id      => rx_ipv4_filtered_id,
      in_dest    => rx_ipv4_filtered_dest,
      in_user(0) => rx_ipv4_filtered_user(10),
      out_ready  => rx_udp_ready,
      out_valid  => rx_udp_valid,
      out_data   => rx_udp_data,
      out_keep   => rx_udp_keep,
      out_last   => rx_udp_last,
      out_id     => rx_udp_id,
      out_dest   => rx_udp_dest,
      out_user   => rx_udp_user
      );

  udp_filter : block
  begin
    rx_udp_valid_dhcp <= '1' when rx_udp_valid = '1' and unsigned(rx_udp_user(rx_udp_user'left - 1 downto 0)) = nrx else '0';

    udp_rx_data <= (others => rx_udp_data);
    udp_rx_keep <= (others => rx_udp_keep);
    udp_rx_last <= (others => rx_udp_last);
    udp_rx_id   <= (others => rx_udp_id);
    forout : for i in 0 to nrx - 1 generate
      udp_rx_valid(i) <= rx_udp_valid and not rx_udp_user(rx_udp_user'left) and ite_l(unsigned(rx_udp_user(rx_udp_user'left - 1 downto 0)) = i, '1', '0');
    end generate;
    rx_udp_ready <= (rx_udp_ready_dhcp and rx_udp_valid_dhcp) or or (udp_rx_valid and udp_rx_ready) or (not (or udp_rx_valid) and not rx_udp_valid_dhcp);
  end block;

  net_dhcp_inst : entity dsnet.dhcp generic map (
    width        => width,
    vendor_bytes => vendor_bytes
    ) port map (
      clk           => clk,
      rst           => int_rst,
      in_ready      => rx_udp_ready_dhcp,
      in_valid      => rx_udp_valid_dhcp,
      in_data       => rx_udp_data,
      in_keep       => rx_udp_keep,
      in_last       => rx_udp_last,
      in_id         => rx_udp_id,
      out_ready     => dhcpudp_ready,
      out_valid     => dhcpudp_valid,
      out_data      => dhcpudp_data,
      out_keep      => dhcpudp_keep,
      out_last      => dhcpudp_last,
      out_id        => dhcpudp_id,
      out_dest      => dhcpudp_dest,
      out_user      => dhcpudp_user,
      my_id_mac     => src_mac_r,
      my_id_vendor  => vendor_id_r,
      my_id_ip      => src_ip,
      my_subnetmask => src_subnetmask,
      done          => dhcp_done,
      have_ip       => have_ip
      );

  -- tx
  net_eth_inst : entity dsnet.tx_eth generic map (
    width => width
    ) port map (
      clk       => clk,
      rst       => int_rst,
      in_ready  => eth_ready,
      in_valid  => eth_valid,
      in_data   => eth_data,
      in_keep   => eth_keep,
      in_last   => eth_last,
      in_id     => src_mac,
      in_dest   => eth_dest,
      in_user   => eth_user,
      out_ready => txfifo_ready,
      out_valid => txfifo_valid,
      out_data  => txfifo_data,
      out_keep  => txfifo_keep,
      out_last  => txfifo_last
      );
  arbiter_user0 <= ipv4eth_user & ipv4eth_dest;
  arbiter_user1 <= arpeth_user & arpeth_dest;
  arbiter_inst : entity ds.arbiter generic map (
    n           => 2,
    width       => width,
    user        => 48 + 16,
    include_reg => true
    ) port map (
      clk                         => clk,
      rst                         => int_rst,
      in_valid(0)                 => ipv4eth_valid,
      in_valid(1)                 => arpeth_valid,
      in_ready(0)                 => ipv4eth_ready,
      in_ready(1)                 => arpeth_ready,
      in_data(0)                  => ipv4eth_data,
      in_data(1)                  => arpeth_data,
      in_last(0)                  => ipv4eth_last,
      in_last(1)                  => arpeth_last,
      in_keep(0)                  => ipv4eth_keep,
      in_keep(1)                  => arpeth_keep,
      in_user(0)                  => arbiter_user0,
      in_user(1)                  => arbiter_user1,
      out_valid                   => eth_valid,
      out_ready                   => eth_ready,
      out_data                    => eth_data,
      out_last                    => eth_last,
      out_keep                    => eth_keep,
      out_user(47 downto 0)       => eth_dest,
      out_user(47 + 16 downto 48) => eth_user
      );
  net_ipv4_inst : entity dsnet.tx_ipv4 generic map (
    width => width
    ) port map (
      clk       => clk,
      rst       => int_rst,
      in_ready  => ip_ready,
      in_valid  => ip_valid,
      in_data   => ip_data,
      in_keep   => ip_keep,
      in_last   => ip_last,
      in_dest   => ip_dest,
      in_user   => ip_user,
      in_id     => src_ip_r,
      out_ready => ipv4eth_ready,
      out_valid => ipv4eth_valid,
      out_data  => ipv4eth_data,
      out_keep  => ipv4eth_keep,
      out_last  => ipv4eth_last,
      out_dest  => ipv4eth_dest,
      out_user  => ipv4eth_user
      );

  ipv4arbiter_user0 <= udpipv4_user & udpipv4_dest;
  ipv4arbiter_user1 <= icmpipv4_user & icmpipv4_dest;
  ipv4arbiter_inst : entity ds.arbiter generic map (
    n           => 3,
    width       => width,
    user        => 80 + 24,
    include_reg => true
    ) port map (
      clk                         => clk,
      rst                         => int_rst,
      in_valid(0)                 => udpipv4_valid,
      in_valid(1)                 => icmpipv4_valid,
      in_valid(2)                 => igmpipv4_valid,
      in_ready(0)                 => udpipv4_ready,
      in_ready(1)                 => icmpipv4_ready,
      in_ready(2)                 => igmpipv4_ready,
      in_data(0)                  => udpipv4_data,
      in_data(1)                  => icmpipv4_data,
      in_data(2)                  => igmpipv4_data,
      in_last(0)                  => udpipv4_last,
      in_last(1)                  => icmpipv4_last,
      in_last(2)                  => igmpipv4_last,
      in_keep(0)                  => udpipv4_keep,
      in_keep(1)                  => icmpipv4_keep,
      in_keep(2)                  => igmpipv4_keep,
      in_user(0)                  => ipv4arbiter_user0,
      in_user(1)                  => ipv4arbiter_user1,
      in_user(2)                  => igmpipv4_user & igmpipv4_dest,
      out_valid                   => ip_valid,
      out_ready                   => ip_ready,
      out_data                    => ip_data,
      out_last                    => ip_last,
      out_keep                    => ip_keep,
      out_user(79 downto 0)       => ip_dest,
      out_user(80 + 23 downto 80) => ip_user
      );


  net_udp_inst : entity dsnet.tx_udp generic map (
    width => width
    ) port map (
      clk       => clk,
      rst       => int_rst,
      in_ready  => udp_ready,
      in_valid  => udp_valid,
      in_data   => udp_data,
      in_keep   => udp_keep,
      in_last   => udp_last,
      in_dest   => udp_dest,
      in_id     => udp_id,
      out_ready => udpipv4_ready,
      out_valid => udpipv4_valid,
      out_data  => udpipv4_data,
      out_keep  => udpipv4_keep,
      out_last  => udpipv4_last,
      out_dest  => udpipv4_dest,
      out_user  => udpipv4_user
      );
  bl_udprr : block
    signal udp_tx_valid_r, udp_tx_ready_r, udp_tx_last_r : std_logic_vector(ntx downto 0);
    signal udp_tx_data_r                                 : std_logic_vector_array(0 to ntx)(dhcpudp_data'range);
    signal udp_tx_keep_r                                 : std_logic_vector_array(0 to ntx)(dhcpudp_keep'range);
    signal udp_tx_user_r                                 : std_logic_vector_array(0 to ntx)(dhcpudp_dest'length + 15 downto 0);
  -- signal udp_tx_id_r                                   : std_logic_vector_array(udp_tx_id'range)(dhcpudp_id'range);
  begin
    forntx : for i in 0 to ntx - 1 generate
      reg2_inst : entity ds.reg2 generic map (
        width => width,
        dest  => dhcpudp_dest'length
        ) port map (
          clk       => clk,
          rst       => int_rst,
          in_ready  => udp_tx_ready(i),
          in_valid  => udp_tx_valid(i),
          in_data   => udp_tx_data(i),
          in_last   => udp_tx_last(i),
          in_keep   => udp_tx_keep(i),
          in_dest   => udp_tx_dest(i),
          -- in_id     => udp_tx_id(i),
          out_ready => udp_tx_ready_r(i),
          out_valid => udp_tx_valid_r(i),
          out_data  => udp_tx_data_r(i),
          out_last  => udp_tx_last_r(i),
          out_keep  => udp_tx_keep_r(i),
          out_dest  => udp_tx_user_r(i)(dhcpudp_dest'range)
          -- out_id    => udp_tx_id_r(i)
          );
      udp_tx_user_r(i)(udp_tx_user_r(i)'left downto dhcpudp_dest'length) <= tx_ports(i);
    end generate;
    udp_tx_valid_r(ntx) <= dhcpudp_valid;
    dhcpudp_ready       <= udp_tx_ready_r(ntx);
    udp_tx_data_r(ntx)  <= dhcpudp_data;
    udp_tx_last_r(ntx)  <= dhcpudp_last;
    udp_tx_keep_r(ntx)  <= dhcpudp_keep;
    udp_tx_user_r(ntx)  <= dhcpudp_id & dhcpudp_dest;
    udparbiter_inst : entity ds.arbiter generic map (
      n           => ntx + 1,
      width       => width,
      user        => 96 + 16,
      include_reg => true
      ) port map (
        clk                             => clk,
        rst                             => int_rst,
        in_valid                        => udp_tx_valid_r,
        in_ready                        => udp_tx_ready_r,
        in_data                         => udp_tx_data_r,
        in_last                         => udp_tx_last_r,
        in_keep                         => udp_tx_keep_r,
        in_user                         => udp_tx_user_r,
        out_valid                       => udp_valid,
        out_ready                       => udp_ready,
        out_data                        => udp_data,
        out_last                        => udp_last,
        out_keep                        => udp_keep,
        out_user(95 downto 0)           => udp_dest,
        out_user(96 + 16 - 1 downto 96) => udp_id
        );
  end block;
end architecture;
