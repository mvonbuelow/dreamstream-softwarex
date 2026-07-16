-------------------------------------------------------------------------------
-- counter
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Counts where we are in the packet.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;

entity counter is
  generic (
    user: integer := 8;
    max: integer := 0;
    lookahead: boolean := false -- when set to true, we see the next value on out_user
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    in_valid, in_ready: in std_logic := '1';
    in_last: in std_logic;
    in_user: in std_logic_vector(user - 1 downto 0) := std_logic_vector(to_unsigned(1, user)); -- inc

    out_user: out std_logic_vector(user - 1 downto 0)
  );
end;

architecture counter_arch of counter is
  signal idx, idx_next: unsigned(user - 1 downto 0) := (others => '0');
  constant idxfull: unsigned(user - 1 downto 0) := ite_u(max = 0, to_unsigned(0, user) - 1, to_unsigned(max, user));
begin
  idx_next <= (others => '0') when in_valid = '1' and in_ready = '1' and in_last = '1' else
    idxfull when idx = idxfull else
    idx + unsigned(in_user);
  proc_idx: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        idx <= (others => '0');
      elsif in_valid = '1' and in_ready = '1' then
        idx <= idx_next;
      end if;
    end if;
  end process;
  -- idx <= idx_next when rising_edge(clk) and ((in_valid = '1' and in_ready = '1') or rst = '1');

  out_user <= std_logic_vector(idx) when in_valid = '0' or not lookahead else std_logic_vector(idx + unsigned(in_user));
end architecture;
