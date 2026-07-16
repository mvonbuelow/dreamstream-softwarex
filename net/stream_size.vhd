-------------------------------------------------------------------------------
-- stream_checksum
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Just keeps track of the number of bytes. Once in_valid and
--              in_last is asserted the data can be expected directly on the
--              output stream.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;

entity stream_size is
  generic (
    width: integer
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

architecture net_stream_size_arch of stream_size is
  signal in_keep_popcnt: integer range 0 to width / 8;
  constant size_bits: integer := out_data'length;
  constant max_size: integer := 2 ** size_bits - 1;
  signal size: std_logic_vector(out_data'range);
begin
  popcnt_proc: process(all)
  begin
    in_keep_popcnt <= width / 8;
    for i in width / 8 - 1 downto 0 loop
      if in_keep(i) = '0' then
        in_keep_popcnt <= width / 8 - 1 - i;
        exit;
      end if;
    end loop;
  end process;
  counter_inst: entity ds.counter generic map (
    user => size_bits,
    max => max_size,
    lookahead => true
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => in_valid,
    in_last => in_last,
    in_user => std_logic_vector(to_unsigned(in_keep_popcnt, size_bits)),
    out_user => size
  );
  out_data <= size; -- when rising_edge(clk);
  out_valid <= in_valid and in_last; -- when rising_edge(clk);
end architecture;

