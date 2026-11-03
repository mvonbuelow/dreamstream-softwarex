-------------------------------------------------------------------------------
-- stream_checksum
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Compute the internet checksum (RFC 1071) progressively on an
--              input stream. Once in_valid and in_last is asserted the data
--              can be expected on the output two cycles later.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
library dsnet;
use ds.types.all;

entity stream_checksum is
  generic (
    width: integer;
    limit: integer := 0;
    mask_off, mask_len: integer := 0;
    ones_comp: boolean := true;
    split_at: integer := 128
  );
  port (
    clk, rst: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_valid: in std_logic;
    in_last: in std_logic;

    out_data: out std_logic_vector(15 downto 0);
    out_valid: out std_logic
  );
end;

architecture net_stream_checksum_arch of stream_checksum is
  signal in_bigkeep: std_logic_vector(in_data'range);
  signal in_valid_r, in_valid_rr: std_logic;
  signal cur_last_word, cur_last_word_r, cur_last_word_rr: std_logic := '0';
  signal in_data_r: std_logic_vector(in_data'range) := (others => '0');

  constant num_words: integer := (limit + width - 1) / width;
  constant remainder: integer := (width - (limit mod width)) mod width;
  constant remainder_bytes: integer := remainder / 8;

  constant remainder_keep: std_logic_vector(in_keep'range) := not std_logic_vector(to_unsigned(0, width / 8 - remainder_bytes)) & std_logic_vector(to_unsigned(0, remainder_bytes));
  signal mask: std_logic_vector(width - 1 downto 0);

  constant idx_len: integer := log2_ceil(num_words + 1);
  signal idx: std_logic_vector(idx_len - 1 downto 0);

  constant chksum_w_pre: integer := ite_i(width >= 16, width, 16);
  constant chksum_w: integer := ite_i(chksum_w_pre > split_at, split_at, chksum_w_pre);
  signal idx_odd: std_logic;
  constant nsplits: integer := (width + split_at - 1) / split_at;
  signal chksum_in: std_logic_vector(chksum_w * nsplits - 1 downto 0);
  signal in_data_chksum, in_data_chksum_r: unsigned(16 * nsplits - 1 downto 0) := (others => '0');
  signal cur_chksum, next_chksum: unsigned(15 downto 0) := (others => '0');

  signal ign: std_logic := '0';
begin
  proc_mask: process(all)
    variable a, b: integer;
    variable first_word, last_word: integer;
  begin
    -- xxxx|0000|XXXXX   -> 16,16 ==> [16,32], also [0,1]
    first_word := mask_off / width;
    last_word := (mask_off + mask_len) / width;
    for i in first_word to last_word loop
      if unsigned(idx) = i then
        a := mask_off mod width when i = first_word else 0;
        b := (mask_off + mask_len) mod width when i = last_word else width - 1;
        for j in a to b loop
          mask(j) <= '0' when j >= a and j <= b else '1';
        end loop;
      end if;
    end loop;
  end process;
  iflimit: if num_words /= 0 generate
    counter_inst: entity ds.counter generic map (
      user => idx_len,
      max => num_words
    ) port map (
      clk => clk,
      rst => rst,
      in_valid => in_valid,
      in_last => in_last,
      out_user => idx
    );
    cur_last_word <= '1' when unsigned(idx) = (limit + width - 1) / width - 1 else '0';
    proc_ign: process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          ign <= '0';
        elsif in_valid = '1' then
          if cur_last_word = '1' then
            ign <= '1';
          end if;
          if in_last = '1' then
            ign <= '0';
          end if;
        end if;
      end if;
    end process;
  else generate
    cur_last_word <= in_last;
  end generate;

  -- idx_odd <= idx(0);

  for0: for i in in_bigkeep'range generate
    in_bigkeep(i) <= in_keep(i / 8) when cur_last_word = '0' or limit = 0 else remainder_keep(i / 8);
  end generate;

  proc0: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        in_valid_r <= '0';
        cur_last_word_r <= '0';
      else
        in_data_r <= in_data and in_bigkeep;
        in_valid_r <= in_valid and not ign;
        cur_last_word_r <= in_valid and cur_last_word and not ign;
      end if;
    end if;
  end process;

  if0: if width >= 16 generate
    chksum_in <= in_data_r;
  else generate
    proc_idx_odd: process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          idx_odd <= '0';
        else
          if in_valid_r = '1' then
            idx_odd <= not idx_odd and not cur_last_word_r;
          end if;
        end if;
      end if;
    end process;
    chksum_in <= in_data_r & x"00" when idx_odd = '0' else x"00" & in_data_r;
  end generate;
  forsplits: for i in 0 to nsplits - 1 generate
    in_chksum_inst: entity dsnet.internet_checksum generic map (
      width => chksum_w
    ) port map (
      data => unsigned(chksum_in(chksum_w * (i + 1) - 1 downto chksum_w * i)),
      chksum => in_data_chksum(16 * (i + 1) - 1 downto 16 * i)
    );
  end generate;
  proc1: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        in_valid_rr <= '0';
        cur_last_word_rr <= '0';
      else
        in_data_chksum_r <= in_data_chksum;
        in_valid_rr <= in_valid_r;
        cur_last_word_rr <= cur_last_word_r;
      end if;
    end if;
  end process;

  bl_full_chksum: block
    constant full_w: integer := 16 + 16 * nsplits;
    constant ceiled_w: integer := 2 ** log2_ceil(full_w);
    signal in_pad: unsigned(ceiled_w - 1 downto 0) := (others => '0');
  begin
    in_pad(full_w - 1 downto 0) <= cur_chksum & in_data_chksum_r;
    full_chksum_inst: entity dsnet.internet_checksum generic map (
      width => ceiled_w
    ) port map (
      data => in_pad,
      chksum => next_chksum
    );
  end block;

  proc_chksum: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cur_chksum <= (others => '0');
      else
        if in_valid_rr = '1' then
          cur_chksum <= next_chksum when cur_last_word_rr = '0' else (others => '0');
        end if;
      end if;
    end if;
  end process;
  -- cur_chksum <= next_chksum when rising_edge(clk) and in_valid_rr = '1';
  -- cur_last_word_rrr <= cur_last_word_rr when rising_edge(clk);

  out_valid <= cur_last_word_rr;
  ifcomp: if ones_comp generate
    out_data <= not std_logic_vector(next_chksum);
  else generate
    out_data <= std_logic_vector(next_chksum);
  end generate;
end architecture;
