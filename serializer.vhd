-------------------------------------------------------------------------------
-- serializer
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Serializes multiple words from a bigger stream to a smaller
--              stream.
--
-- WARNING:     This entity has not been used anywhere yet. It needs to be
--              tested (or 'tried out').
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;

entity serializer is
  generic (
    width: integer := 64;
    out_width: integer := 8;
    keep_width: integer := 8;
    user: integer := 1
  );
  port (
    clk: in std_logic;
    rst: in std_logic;

    in_valid: in std_logic;
    in_ready: out std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / keep_width - 1 downto 0) := (others => '1');
    in_last: in std_logic := '1';
    in_user: in std_logic_vector(user - 1 downto 0) := (others => '0');
    out_valid: out std_logic;
    out_ready: in std_logic;
    out_data: out std_logic_vector(out_width - 1 downto 0);
    out_keep: out std_logic_vector(out_width / keep_width - 1 downto 0);
    out_last: out std_logic;
    out_user: out std_logic_vector(user - 1 downto 0)
  );
end entity;

architecture serializer_arch of serializer is
  constant parts: integer := width / out_width;
  signal in_data_i: std_logic_vector_array(0 to parts - 1)(out_width - 1 downto 0);
  signal in_keep_i: std_logic_vector_array(0 to parts - 1)(out_width / keep_width - 1 downto 0);
  signal ser_data: std_logic_vector(out_data'range);
  signal sel, sel_next: unsigned(integer(ceil(log2(real(parts)))) - 1 downto 0) := (others => '0');
  signal ser_valid, ser_ready, ser_last: std_logic;
  signal ser_keep: std_logic_vector(out_width / keep_width - 1 downto 0);
  signal in_keep_valid: std_logic_vector(parts - 1 downto 0);
  signal last_bit: std_logic_vector(parts - 1 downto 0) := (others => '1');
  signal ser_last_bit: std_logic;
begin
  if0: if width = out_width generate
    out_data <= in_data;
    out_valid <= in_valid;
    in_ready <= out_ready;
    out_keep <= in_keep;
    out_last <= in_last;
    out_user <= in_user;
  else generate
    axi_reg_inst: entity ds.reg generic map (
      width => out_width,
      user => user,
      keep_width => keep_width
    ) port map (
      clk => clk,
      rst => rst,
      in_data => ser_data,
      in_valid => ser_valid,
      in_ready => ser_ready,
      in_keep => ser_keep,
      in_last => ser_last,
      in_user => in_user,
      out_data => out_data,
      out_valid => out_valid,
      out_ready => out_ready,
      out_keep => out_keep,
      out_last => out_last,
      out_user => out_user
    );

    treemux_inst: entity ds.treemux generic map (
      n => parts,
      width => out_width,
      keep_width => keep_width
    ) port map (
      in_data => in_data_i,
      in_valid => in_keep_valid,
      in_keep => in_keep_i,
      in_last => last_bit,

      out_data => ser_data,
      out_valid => ser_valid,
      out_keep => ser_keep,
      out_last => ser_last_bit,
      sel => sel
    );

    for0: for i in 0 to parts - 1 generate
      signal in_keep_set: std_logic;
    begin
      in_keep_set <= or in_keep(out_width / keep_width * (i + 1) - 1 downto out_width / keep_width * i) when i /= parts - 1 else '1'; -- don't elimiate the complete packet
      in_data_i(parts - 1 - i) <= in_data((i + 1) * out_width - 1 downto i * out_width);
      in_keep_i(parts - 1 - i) <= in_keep((i + 1) * out_width / keep_width - 1 downto i * out_width / keep_width);
      in_keep_valid(parts - 1 - i) <= in_keep_set and in_valid;
      if0: if i /= 0 generate
        last_bit(parts - 1 - i) <= not (or in_keep(out_width / keep_width * i - 1 downto out_width / keep_width * (i - 1)));
      end generate;
    end generate;

    ser_last <= ser_last_bit and in_last;

    in_ready <= '1' when ser_ready = '1' and in_valid = '1' and ser_last_bit = '1' else '0';

    sel <= sel_next when rising_edge(clk) and ser_valid = '1' and ser_ready = '1';
    sel_next <= (others => '0') when rst = '1' or ser_last_bit = '1' else sel + 1;
  end generate;
end architecture;
