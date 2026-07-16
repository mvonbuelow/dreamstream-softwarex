-------------------------------------------------------------------------------
-- tx_udp
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: UDP datagram constructor.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

library dsnet;

entity tx_udp is
  generic (
    width: integer := 64
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    in_ready: out std_logic;
    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_last: in std_logic;
    in_id: in std_logic_vector(15 downto 0);
    in_dest: in std_logic_vector(48 + 32 + 16 - 1 downto 0);

    out_ready: in std_logic;
    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_last: out std_logic;
    out_dest: out std_logic_vector(47 + 32 downto 0);
    out_user: out std_logic_vector(15 + 8 downto 0)
  );
end;

architecture net_tx_udp_arch of tx_udp is
  signal size_data, chksum_data: std_logic_vector(15 downto 0);
  signal size_valid, size_ready, chksum_valid: std_logic;
  signal out_x_user_pre2: std_logic_vector(16 * 1 - 1 downto 0);
  signal out_x_user_pre: std_logic_vector(out_dest'length + out_x_user_pre2'length - 1 downto 0);

  signal udp_ready, udp_valid, udp1_ready, udp1_valid, udp_last: std_logic;
  signal udp_data: std_logic_vector(out_data'range);
  signal udp_keep: std_logic_vector(out_keep'range);
  signal udp_dest: std_logic_vector(out_dest'range);

  signal out_x_ready, out_x_valid, out_x_last: std_logic;
  signal out_x_data: std_logic_vector(out_data'range);
  signal out_x_keep: std_logic_vector(out_keep'range);

  constant depth: integer := 2048 * 8;
begin
  composer_inst: entity ds.composer generic map (
    width => width,
    user => 64
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => in_valid,
    in_data => in_data,
    in_last => in_last,
    in_ready => in_ready,
    in_keep => in_keep,
    in_user => in_id & in_dest(15 downto 0) & x"0000" & x"0000",
    out_valid => udp_valid,
    out_data => udp_data,
    out_last => udp_last,
    out_ready => udp_ready,
    out_keep => udp_keep
  );

  udp_dest <= in_dest(in_dest'left downto 16);

  net_stream_size_inst: entity dsnet.stream_size generic map (
    width => width
  ) port map (
    clk => clk,
    rst => rst,
    in_data => udp_data,
    in_keep => udp_keep,
    in_valid => udp_valid and udp_ready,
    in_last => udp_last,
    out_data => size_data,
    out_valid => size_valid
  );
  net_stream_checksum_inst: entity dsnet.stream_checksum generic map (
    width => width
  ) port map (
    clk => clk,
    rst => rst,
    in_data => udp_data,
    in_keep => udp_keep,
    in_valid => udp_valid and udp_ready,
    in_last => udp_last,
    out_data => chksum_data,
    out_valid => chksum_valid
  );

  net_stream_collect_inst: entity ds.collector generic map (
    width => width,
    user => out_dest'length,
    n => 1,
    meta_width => 16,
    max_offset => depth,
    overflow_protection => true
  ) port map (
    clk => clk,
    rst => rst,
    in_data => udp_data,
    in_keep => udp_keep,
    in_valid => udp_valid,
    in_last => udp_last,
    in_ready => udp_ready,
    in_user => udp_dest,
    -- meta_valid(0) => chksum_valid,
    meta_valid(0) => size_valid,
    -- meta_data(0)  => chksum_data,
    meta_data(0) => size_data,
    out_data => out_x_data,
    out_keep => out_x_keep,
    out_valid => out_x_valid,
    out_last => out_x_last,
    out_ready => out_x_ready,
    out_user => out_x_user_pre
  );


  injector_inst: entity ds.injector generic map (
    w => width,
    user => 32,
    off => 32
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => out_x_valid,
    in_data => out_x_data,
    in_last => out_x_last,
    in_keep => out_x_keep,
    in_ready => out_x_ready,
    in_user => out_x_user_pre2 & x"0000",
    out_valid => out_valid,
    out_data => out_data,
    out_last => out_last,
    out_keep => out_keep,
    out_ready => out_ready
  );

  -- out_id          <= out_x_user_pre(out_id'range);
  out_dest <= out_x_user_pre(out_dest'range);
  out_x_user_pre2 <= out_x_user_pre(out_x_user_pre'left downto out_dest'length);
  out_user <= x"11" & out_x_user_pre2;
end architecture;
