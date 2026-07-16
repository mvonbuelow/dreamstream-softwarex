-------------------------------------------------------------------------------
-- injector
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Injects something into an axi stream.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;

entity injector is
  generic (
    w: integer;
    user: integer;
    off: integer
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    in_valid: in std_logic;
    in_data: in std_logic_vector(w - 1 downto 0);
    in_last: in std_logic;
    in_keep: in std_logic_vector(w / 8 - 1 downto 0);
    in_ready: out std_logic;
    in_user: in std_logic_vector(user - 1 downto 0);

    out_valid: out std_logic;
    out_data: out std_logic_vector(w - 1 downto 0);
    out_last: out std_logic;
    out_keep: out std_logic_vector(w / 8 - 1 downto 0);
    out_ready: in std_logic
  );
end;

architecture injector_arch of injector is
  constant off_word: integer := off / w;
  constant end_word: integer := (off + user - 1) / w;

  constant num_words: integer := end_word + 1;

  constant idx_len: integer := log2_ceil(num_words + 1);
  signal idx: std_logic_vector(idx_len - 1 downto 0);
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

  proc_mux: process(all)
    variable off_in_word, end_in_word, user_off: integer;
  begin
    out_data <= in_data;
    for i in off_word to end_word loop
      if i = unsigned(idx) then
        off_in_word := ite_i(i = off_word, off mod w, 0);
        end_in_word := ite_i(i = end_word, (off + user - 1) mod w, w - 1);
        -- report integer'image(off_in_word) & " " & integer'image(end_in_word) severity note;

        for j in w - 1 downto 0 loop
          user_off := user - 1 - (i * w + j - off);
          out_data(w - 1 - j) <= in_user(user_off) when j >= off_in_word and j <= end_in_word else in_data(w - 1 - j);
        end loop;
        exit;
      end if;
    end loop;
  end process;
  out_valid <= in_valid;
  in_ready <= out_ready;
  out_last <= in_last;
  out_keep <= in_keep;
end architecture;
