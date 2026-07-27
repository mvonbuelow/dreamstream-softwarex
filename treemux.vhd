-------------------------------------------------------------------------------
-- treemux
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Using this module, you can dynamically switch between
--              multiple input streams. It forces the synthesis to use a tree-
--              of multiplexers for that, hence the name.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;

entity treemux is
  generic (
    width: integer;
    n: integer;
    user: integer := 1;
    keep_width: integer := 8
  );
  port (
    in_data: in std_logic_vector_array(0 to n - 1)(width - 1 downto 0) := (others => (others => '0'));
    in_keep: in std_logic_vector_array(0 to n - 1)((width + keep_width - 1) / keep_width - 1 downto 0) := (others => (others => '0'));
    in_valid: in std_logic_vector(n - 1 downto 0) := (others => '1');
    in_last: in std_logic_vector(n - 1 downto 0) := (others => '0');
    in_user: in std_logic_vector_array(0 to n - 1)(user - 1 downto 0) := (others => (others => '0'));

    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector((width + keep_width - 1) / keep_width - 1 downto 0);
    out_valid: out std_logic;
    out_last: out std_logic;
    out_user: out std_logic_vector(user - 1 downto 0);

    sel: in unsigned(integer(ceil(log2(real(n)))) - 1 downto 0)
  );
end entity;


architecture treemux_arch of treemux is
  constant nh: integer := (n + 1) / 2;
  signal tmp_data: std_logic_vector_array(0 to nh - 1)(width - 1 downto 0);
  signal tmp_keep: std_logic_vector_array(0 to nh - 1)(out_keep'range);
  signal tmp_valid, tmp_last: std_logic_vector(nh - 1 downto 0);
  signal tmp_user: std_logic_vector_array(0 to nh - 1)(user - 1 downto 0);
begin
  if2: if n /= 0 generate
    for0: for i in 0 to n / 2 - 1 generate
      tmp_data(i) <= in_data(i * 2) when sel(0) = '0' else in_data(i * 2 + 1);
      tmp_keep(i) <= in_keep(i * 2) when sel(0) = '0' else in_keep(i * 2 + 1);
      tmp_valid(i) <= in_valid(i * 2) when sel(0) = '0' else in_valid(i * 2 + 1);
      tmp_last(i) <= in_last(i * 2) when sel(0) = '0' else in_last(i * 2 + 1);
      tmp_user(i) <= in_user(i * 2) when sel(0) = '0' else in_user(i * 2 + 1);
    end generate;
    if1: if n mod 2 = 1 generate
      tmp_data(nh - 1) <= in_data(n - 1);
      tmp_keep(nh - 1) <= in_keep(n - 1);
      tmp_valid(nh - 1) <= in_valid(n - 1);
      tmp_last(nh - 1) <= in_last(n - 1);
      tmp_user(nh - 1) <= in_user(n - 1);
    end generate;

    if0: if n = 2 or n = 1 generate
      out_data <= tmp_data(0);
      out_keep <= tmp_keep(0);
      out_valid <= tmp_valid(0);
      out_last <= tmp_last(0);
      out_user <= tmp_user(0);
    else generate
      treemux_inst: entity ds.treemux generic map (
        n => nh,
        width => width,
        user => user,
        keep_width => keep_width
      ) port map (
        in_data => tmp_data,
        in_keep => tmp_keep,
        in_valid => tmp_valid,
        in_last => tmp_last,
        in_user => tmp_user,
        out_data => out_data,
        out_keep => out_keep,
        out_valid => out_valid,
        out_last => out_last,
        out_user => out_user,
        sel => sel(sel'left downto 1)
      );
    end generate;
  end generate;
end architecture;
