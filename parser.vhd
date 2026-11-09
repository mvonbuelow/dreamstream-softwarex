-------------------------------------------------------------------------------
-- parser
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Extracts something from an axi stream.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;

entity parser is
  generic (
    width: integer;
    user: integer;
    check_mask: std_logic_vector(user - 1 downto 0) := (others => '0');
    absorb_on_error: boolean := false
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_last: in std_logic;
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_ready: out std_logic;

    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_last: out std_logic;
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_ready: in std_logic := '1';
    out_user: out std_logic_vector(ite_i(or check_mask = '1' and not absorb_on_error, 1, 0) + user - 1 downto 0);
    check_val: std_logic_vector(user - 1 downto 0) := (others => '0')
  );
end;

architecture parser_arch of parser is
  constant bytes_per_elm: integer := width / 8;

  constant offset: integer := (width - (user mod width)) mod width;
  constant offset_bytes: integer := offset / 8;
  constant num_words: integer := (user + width - 1) / width;
  constant last_word: integer := num_words - 1;

  constant idx_len: integer := log2_ceil(num_words + 1);
  signal idx: std_logic_vector(idx_len - 1 downto 0);

  signal shifter_in_keep: std_logic_vector(in_keep'range);
  signal shifter_in_valid, shifter_in_ready: std_logic;
  constant pad_keep: std_logic_vector(bytes_per_elm - offset_bytes - 1 downto 0) := (others => '0');

  signal parsing, cur_last_word, cur_err, cur_err_next, cur_err_reg: boolean := false;
  signal check_err: std_logic;

  signal cur_empty: boolean;

  signal out_user_pre: std_logic_vector(user - 1 downto 0) := (others => '0');
  signal out_valid_i, out_ready_i: std_logic;
begin
  assert user mod 8 = 0 severity failure;

  counter_inst: entity ds.counter generic map (
    user => idx_len,
    max => num_words
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => in_valid and in_ready,
    in_last => in_last,
    out_user => idx
  );

  cur_err <= (parsing and ((in_last = '1' and in_valid = '1' and in_keep(offset_bytes) /= '1') or (in_valid = '1' and in_last = '1' and not cur_last_word))) or cur_err_reg;
  cur_err_next <= false when (in_valid = '1' and in_ready = '1' and in_last = '1') or rst = '1' else cur_err;
  cur_err_reg <= cur_err_next when rising_edge(clk);

  cur_empty <= cur_last_word and in_last = '1' and (offset_bytes = 0 or in_keep(ite_i(offset_bytes = 0, 1, offset_bytes) - 1) = '0');

  proc_check: process(clk)
    variable my_idx: integer;
    variable my_slice, my_check_mask, my_check_val: std_logic_vector(7 downto 0);
    variable is_my_word, word_err: boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        out_user_pre <= (others => '0');
        check_err <= '0';
      else
        for i in 0 to num_words - 1 loop
          is_my_word := idx = std_logic_vector(to_unsigned(last_word - i, idx'length));
          word_err := false;
          for j in 0 to bytes_per_elm - 1 loop
            my_idx := i * bytes_per_elm + j - offset_bytes;
            if my_idx < 0 then
              next;
            end if;

            my_slice := in_data(j * 8 + 7 downto j * 8);
            my_check_mask := check_mask(my_idx * 8 + 7 downto my_idx * 8);
            my_check_val := check_val(my_idx * 8 + 7 downto my_idx * 8);
            if in_valid = '1' and is_my_word then
              out_user_pre(my_idx * 8 + 7 downto my_idx * 8) <= my_slice;
            end if;

            word_err := word_err or (in_valid = '1' and (my_slice and my_check_mask) /= my_check_val);
          end loop;
          if is_my_word then
            check_err <= '1' when word_err or check_err = '1' else '0';
          end if;
        end loop;
        if out_valid_i = '1' and out_last = '1' and out_ready_i = '1' then
          check_err <= '0';
        end if;
      end if;
    end if;
  end process;
  parsing <= unsigned(idx) /= num_words;
  cur_last_word <= unsigned(idx) = last_word;

  keep_shifter_inst: entity ds.keep_shifter generic map (
    width => width,
    shift => offset_bytes
  ) port map (
    clk => clk,
    in_data => in_data,
    in_keep => shifter_in_keep,
    in_valid => shifter_in_valid,
    in_last => in_last,
    in_ready => shifter_in_ready,
    out_data => out_data,
    out_valid => out_valid_i,
    out_ready => out_ready_i,
    out_last => out_last,
    out_keep => out_keep,
    fix_shift => true
  );
  ifshift: if offset_bytes /= 0 generate
    shifter_in_keep <= (others => '0') when cur_empty else pad_keep & in_keep(offset_bytes - 1 downto 0) when parsing else in_keep;
    shifter_in_valid <= '0' when parsing and not cur_last_word and not cur_err and not cur_empty else in_valid;
    in_ready <= '1' when (parsing and not cur_last_word) or cur_err else shifter_in_ready;
  else generate
    shifter_in_keep <= in_keep when not cur_empty else (others => '0');
    shifter_in_valid <= '0' when parsing and not cur_err and not cur_empty else in_valid;
    in_ready <= '1' when parsing or cur_err else shifter_in_ready;
  end generate;

  iferr: if (or check_mask) = '1' and not absorb_on_error generate
    out_user <= check_err & out_user_pre;
  else generate
    out_user <= out_user_pre;
  end generate;

  out_valid <= out_valid_i when not absorb_on_error else out_valid_i and not check_err;
  out_ready_i <= out_ready when not absorb_on_error else out_ready or check_err;
end architecture;
