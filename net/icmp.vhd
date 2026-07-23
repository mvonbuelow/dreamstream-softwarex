-------------------------------------------------------------------------------
-- icmp
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: ICMP protocol.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
library dsnet;

entity icmp is
  generic (
    width: integer := 64
  );
  port (
    clk, rst: in std_logic;

    in_ready: out std_logic;
    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_last: in std_logic;
    in_id: in std_logic_vector(79 downto 0);
    -- in_user : in std_logic_vector(15 downto 0);

    out_ready: in std_logic;
    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_last: out std_logic;
    out_dest: out std_logic_vector(79 downto 0);
    out_user: out std_logic_vector(23 downto 0);

    my_id: in std_logic_vector(79 downto 0)
  );
end;


architecture net_icmp_arch of icmp is
  signal parsed_data, reg_data: std_logic_vector(in_data'range);
  signal parsed_keep, reg_keep: std_logic_vector(in_keep'range);
  signal parsed_valid, parsed_ready, parsed1_valid, parsed1_ready, parsed2_valid, parsed2_ready, parsed_last, reg_valid, reg_ready, reg_last: std_logic;
  signal parsed_user: std_logic_vector(31 downto 0);
  signal reg_user: std_logic_vector(31 + in_id'length downto 0);
  signal chksum_valid, chksum_ready, size_valid, size_ready, have_chksum, have_size: std_logic := '0';
  signal chksum_data, size_data, chksum, size: std_logic_vector(15 downto 0) := (others => '0');

  signal comp_valid, comp_ready: std_logic;

  signal dest: std_logic_vector(in_id'range) := (others => '0');

  signal out_x_ready, out_x_valid, out_x_last: std_logic;
  signal out_x_data: std_logic_vector(out_data'range);
  signal out_x_keep: std_logic_vector(out_keep'range);
  signal out_x_dest: std_logic_vector(out_dest'range);
  signal out_x_user: std_logic_vector(out_user'range);

  signal parsed_drop, clear_meta: std_logic;
begin
  parser_inst: entity ds.parser generic map (
    width => width,
    user => 32,
    check_mask => x"ffff0000",
    absorb_on_error => true
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => in_valid,
    in_data => in_data,
    in_last => in_last,
    in_keep => in_keep,
    in_ready => in_ready,
    out_valid => parsed_valid,
    out_data => parsed_data,
    out_last => parsed_last,
    out_keep => parsed_keep,
    out_ready => parsed_ready,
    out_user => parsed_user,
    check_val => x"08000000"
  );
  chksum_inst: entity dsnet.stream_checksum generic map (
    width => width
  ) port map (
    clk => clk,
    rst => rst,
    in_data => parsed_data,
    in_keep => parsed_keep,
    in_valid => parsed_valid and parsed_ready,
    in_last => parsed_last,
    out_data => chksum_data,
    out_valid => chksum_valid
  );
  size_inst: entity dsnet.stream_size generic map (
    width => width
  ) port map (
    clk => clk,
    rst => rst,
    in_data => parsed_data,
    in_keep => parsed_keep,
    in_valid => parsed_valid and parsed_ready,
    in_last => parsed_last,
    out_data => size_data,
    out_valid => size_valid
  );

  net_stream_collect_inst: entity ds.collector generic map (
    width => width,
    user => in_id'length,
    n => 2,
    meta_width => 16,
    max_offset => 2048 * 8
  ) port map (
    clk => clk,
    rst => rst,
    in_data => parsed_data,
    in_keep => parsed_keep,
    in_valid => parsed_valid,
    in_last => parsed_last,
    in_ready => parsed_ready,
    in_user => in_id,
    meta_valid(0) => chksum_valid,
    meta_valid(1) => size_valid,
    meta_data(0) => chksum_data,
    meta_data(1) => size_data,
    out_data => reg_data,
    out_keep => reg_keep,
    out_valid => reg_valid,
    out_last => reg_last,
    out_ready => reg_ready,
    out_user => reg_user
  );


  dest <= reg_user(in_id'range);
  chksum <= reg_user(in_id'length + 15 downto in_id'length);
  size <= reg_user(in_id'length + 31 downto in_id'length + 16);

  composer_inst: entity ds.composer generic map (
    width => width,
    user => 32
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => reg_valid,
    in_data => reg_data,
    in_last => reg_last,
    in_ready => reg_ready,
    in_keep => reg_keep,
    in_user => x"0000" & chksum,
    out_valid => out_x_valid,
    out_data => out_x_data,
    out_last => out_x_last,
    out_ready => out_x_ready,
    out_keep => out_x_keep
  );
  out_x_user <= x"01" & std_logic_vector(unsigned(size) + 4);
  out_x_dest <= dest;
  reg2_inst: entity ds.reg generic map (
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
