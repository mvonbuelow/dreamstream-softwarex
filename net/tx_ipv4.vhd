-------------------------------------------------------------------------------
-- tx_ipv4
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: IPv4 packet constructor.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
library dsnet;

entity tx_ipv4 is
  generic (
    max_payload: integer := 1480; --  must be multiple of 8
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
    in_id: in std_logic_vector(31 downto 0);
    in_dest: in std_logic_vector(47 + 32 downto 0);
    in_user: in std_logic_vector(15 + 8 downto 0);

    out_ready: in std_logic;
    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_last: out std_logic;
    out_dest: out std_logic_vector(47 downto 0);
    out_user: out std_logic_vector(15 downto 0)
  );
end;

architecture net_tx_ipv4_arch of tx_ipv4 is
  signal h0chksum, ipchksum, chksum: std_logic_vector(15 downto 0);
  constant ethtype: std_logic_vector(15 downto 0) := x"0800";

  signal frag_ready, frag_valid, frag_last: std_logic;
  signal comp0_ready, comp0_valid, comp1_ready, comp1_valid, comp0_last, comp0r_ready, comp0r_valid, comp0r_last: std_logic;
  signal frag_data, comp0_data, comp0r_data: std_logic_vector(in_data'range);
  signal frag_keep, comp0_keep, comp0r_keep: std_logic_vector(in_keep'range);
  signal frag_dest: std_logic_vector(in_dest'range);
  signal comp0r_dest: std_logic_vector(out_dest'range);
  signal frag_id: std_logic_vector(in_id'range);
  signal frag_user: std_logic_vector(55 downto 0);
  signal comp0_user, comp0r_user: std_logic_vector(55 + 32 downto 0);

  constant header_vide: std_logic_vector(15 downto 0) := x"4" & x"5" & x"10";
  constant header_ttl: std_logic_vector(7 downto 0) := x"40";

  signal out_x_ready, out_x_valid, out_x_last, col_ready, col_valid, col_last: std_logic;
  signal out_x_data, col_data: std_logic_vector(out_data'range);
  signal out_x_keep, col_keep: std_logic_vector(out_keep'range);
  signal out_x_dest, col_dest: std_logic_vector(out_dest'range);
  signal out_x_user: std_logic_vector(out_user'range);
  signal col_user: std_logic_vector(48 + 15 downto 0);

  signal chksum_valid, chksum_ready: std_logic;
  signal chksum_data: std_logic_vector(15 downto 0);
begin
  net_tx_ipv4_fragment_inst: entity dsnet.tx_ipv4_fragment generic map (
    width => width,
    max_payload => max_payload,
    add_size => 20
  ) port map (
    clk => clk,
    rst => rst,
    in_ready => in_ready,
    in_valid => in_valid,
    in_data => in_data,
    in_keep => in_keep,
    in_last => in_last,
    in_dest => in_dest,
    in_id => in_id,
    in_user => in_user,
    out_ready => frag_ready,
    out_valid => frag_valid,
    out_data => frag_data,
    out_keep => frag_keep,
    out_last => frag_last,
    out_dest => frag_dest,
    out_id => frag_id,
    out_user => frag_user
  );

  -- intermediate step: code the last 64 bits (the part before the payload) to the stream to get rid of it (no need to waste further regs) and only encode an intermediate checksum for it to user data
  composer_inst: entity ds.composer generic map (
    width => width,
    user => 160
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => frag_valid,
    in_data => frag_data,
    in_last => frag_last,
    in_ready => frag_ready,
    in_keep => frag_keep,
    in_user(159 downto 128) => header_vide & frag_user(15 downto 0),
    in_user(127 downto 96) => frag_user(47 downto 16),
    in_user(95 downto 64) => header_ttl & frag_user(55 downto 48) & x"0000",
    in_user(63 downto 32) => frag_id,
    in_user(31 downto 0) => frag_dest(31 downto 0),
    out_valid => comp0_valid,
    out_data => comp0_data,
    out_last => comp0_last,
    out_ready => comp0_ready,
    out_keep => comp0_keep
  );

  net_stream_checksum_inst: entity dsnet.stream_checksum generic map (
    width => width,
    limit => 160
  ) port map (
    clk => clk,
    rst => rst,
    in_data => comp0_data,
    in_keep => comp0_keep,
    in_valid => comp0_valid and comp0_ready,
    in_last => comp0_last,
    out_data => chksum_data,
    out_valid => chksum_valid
  );
  net_stream_collect_inst: entity ds.collector generic map (
    width => width,
    user => 48,
    n => 1,
    meta_width => 16,
    max_offset => 32 * 8 * 8
  ) port map (
    clk => clk,
    rst => rst,
    in_data => comp0_data,
    in_keep => comp0_keep,
    in_valid => comp0_valid,
    in_last => comp0_last,
    in_ready => comp0_ready,
    in_user => frag_dest(79 downto 32),
    meta_valid(0) => chksum_valid,
    meta_data(0) => chksum_data,
    out_data => col_data,
    out_keep => col_keep,
    out_valid => col_valid,
    out_last => col_last,
    out_ready => col_ready,
    out_user => col_user
  );

  injector_inst: entity ds.injector generic map (
    w => width,
    user => 16,
    off => 80
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => col_valid,
    in_data => col_data,
    in_last => col_last,
    in_keep => col_keep,
    in_ready => col_ready,
    in_user => col_user(col_user'left downto col_user'left - 15),
    out_valid => out_x_valid,
    out_data => out_x_data,
    out_last => out_x_last,
    out_keep => out_x_keep,
    out_ready => out_x_ready
  );
  out_x_dest <= col_user(out_x_dest'range);
  out_x_user <= ethtype;
  reg_inst: entity ds.reg generic map (
    width => out_data'length,
    user => out_user'length,
    dest => out_dest'length
  ) port map (
    clk => clk,
    rst => rst,
    in_ready => out_x_ready,
    in_valid => out_x_valid,
    in_data => out_x_data,
    in_last => out_x_last,
    in_keep => out_x_keep,
    in_user => out_x_user,
    in_dest => out_x_dest,
    out_ready => out_ready,
    out_valid => out_valid,
    out_data => out_data,
    out_last => out_last,
    out_keep => out_keep,
    out_user => out_user,
    out_dest => out_dest
  );
end architecture;
