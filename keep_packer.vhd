-------------------------------------------------------------------------------
-- keep_packer
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This module receives a stream of partially filled tkeeps,
--              however always starting from the first (MSB) byte and con-
--              catenates them into a bubble-free stream together.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;

entity keep_packer is
  generic (
    width: integer := 64;
    user: integer := 0
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    in_data: in std_logic_vector(width - 1 downto 0);
    in_user: in std_logic_vector(user - 1 downto 0) := (others => '0');
    in_keep: in std_logic_vector(width / 8 - 1 downto 0); -- WARNING: No bubbles allowed. '1' start from MSB
    in_valid: in std_logic;
    in_last: in std_logic;
    in_ready: out std_logic;

    out_data: out std_logic_vector(width - 1 downto 0) := (others => '0');
    out_user: out std_logic_vector(user - 1 downto 0);
    out_valid: out std_logic := '0';
    out_ready: in std_logic;
    out_last: out std_logic := '0';
    out_keep: out std_logic_vector(width / 8 - 1 downto 0) := (others => '0')
  );
end;

architecture keep_packer_arch of keep_packer is
  constant w: integer := width / 8;
  constant dw: integer := width;
  signal last: std_logic := '0';
  signal data: std_logic_vector(dw - 1 downto 0) := (others => '0');
  signal keep: std_logic_vector(w - 1 downto 0) := (others => '0');

  signal dataarr: std_logic_vector_array(0 to w - 1)(7 downto 0);
  signal shift: unsigned(log2_ceil(w) - 1 downto 0) := (others => '0');
  signal cnt: unsigned(shift'length downto 0) := (others => '0');

  signal shift_data, mux_data: std_logic_vector(dw - 1 downto 0);
  signal shift_keep, mux_keep, rem_keep, valid_mask: std_logic_vector(w - 1 downto 0);
  signal fully_processed: std_logic := '1';
begin
  ifbyte: if width = 8 generate
    out_data <= in_data;
    out_user <= in_user;
    out_keep <= in_keep;
    out_valid <= in_valid;
    out_last <= in_last;
    in_ready <= out_ready;
  else generate
    process(clk) -- only for simulation
    begin
      if rising_edge(clk) then
        if in_valid = '1' and rst = '0' then
          for i in w - 1 to 0 loop
            if in_keep(i) = '0' then
              assert or in_keep(i downto 0) = '0' report "invalid in_keep = " & to_string(in_keep);
              exit;
            end if;
          end loop;
        end if;
      end if;
    end process;

    valid_mask <= (others => in_valid and not last);
    gentreemux: for i in 0 to w - 1 generate
      signal in_keep_masked: std_logic_vector(in_keep'range);
    begin
      dataarr(i) <= in_data(i * 8 + 7 downto i * 8);
      in_keep_masked <= in_keep and valid_mask;
      treemux_inst: entity ds.treemux generic map (
        n => w,
        width => 8
      ) port map (
        in_data => dataarr(i to dataarr'right) & dataarr(0 to i - 1),
        in_valid => in_keep_masked(i - 1 downto 0) & in_keep_masked(in_keep_masked'left downto i), -- by shiftig here the static part, we get it for free. using sel = shift + i is less efficient
        out_data => shift_data(i * 8 + 7 downto i * 8),
        out_valid => shift_keep(i),
        sel => unsigned(shift)
          -- sel => unsigned(i + shift)
      );

      mux_data(i * 8 + 7 downto i * 8) <= data(i * 8 + 7 downto i * 8) when keep(i) = '1' else shift_data(i * 8 + 7 downto i * 8);
    end generate;

    cnt_proc: process(all)
    begin
      cnt <= to_unsigned(w, cnt'length);
      for i in 0 to w - 1 loop
        if in_keep(w - 1 - i) = '0' then
          cnt <= to_unsigned(i, cnt'length);
          exit;
        end if;
      end loop;
    end process;

    -- out_valid <= '1' when (and mux_keep = '1' and or rem_keep = '1') or (out_last = '1' and or mux_keep = '1') else '0'; -- this is less efficient but the same as the following when no bubbles in one word.
    out_valid <= '1' when
      (mux_keep(0) = '1' and rem_keep(w - 1) = '1') or -- when the current keep (register + input) is full AND at least one byte remains. the remaining byte indicates that the current word is definately not the last one; in other cases we have to wait for last
      (out_last = '1' and mux_keep(w - 1) = '1') else '0'; -- when this is the last word and at least one byte is in the current keep

    in_ready <= fully_processed;

    out_user <= in_user; -- TODO: this must be registered, unfortunately

    mux_keep <= keep or shift_keep; -- "00001111" or  "11111111"
    rem_keep <= keep and shift_keep; -- "00001111" and "11111111"
    out_data <= mux_data;
    out_keep <= mux_keep;
    out_last <= '1' when last = '1' or (in_last = '1' and in_valid = '1' and rem_keep(w - 1) = '0') else '0';

    process(clk)
    begin
      if rising_edge(clk) then
        if in_valid = '1' and in_ready = '1' then
          keep <= mux_keep;
          data <= mux_data;
          last <= in_last;
          shift <= shift + cnt(shift'range);
        end if;
        if out_valid = '1' and out_ready = '1' then
          -- shift <= (others => '0');
          keep <= rem_keep;
          if out_last = '1' then
            keep <= (others => '0');
            last <= '0';
            shift <= (others => '0');
          end if;
          data <= shift_data;
        end if;

        if rst = '1' then
          keep <= (others => '0');
          last <= '0';
          shift <= (others => '0');
        end if;
      end if;
    end process;
    fully_processed <= '1' when (rem_keep(w - 1) = '0' and last = '0') or -- we have enough space in our internal register; eat up! last means that we have a remainder from the last word and don't accept a new word in the current cycle
      (out_ready = '1' and out_valid = '1' and last = '0') else '0'; -- don't care about our internal space; the drain is open

    -- free_space <= to_unsigned(w, free_space'length) - shift;
  end generate;
end architecture;
