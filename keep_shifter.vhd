-------------------------------------------------------------------------------
-- keep_shifter
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: TODO
--
-- TODO: check if user is valid until last
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;

entity keep_shifter is
  generic (
    width: integer := 64;
    user: integer := 0;
    shift: integer := 0
  );
  port (
    clk: in std_logic;

    in_data: in std_logic_vector(width - 1 downto 0);
    in_user: in std_logic_vector(user - 1 downto 0) := (others => '0');
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
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

architecture keep_shifter_arch of keep_shifter is
  signal shift_data: std_logic_vector(shift * 8 - 1 downto 0) := (others => '0');
  signal shift_keep: std_logic_vector(shift - 1 downto 0) := (others => '0');
  signal cur_keep: std_logic_vector(width / 8 - shift - 1 downto 0) := (others => '0');
  signal shift_last: std_logic := '0';
  signal shift_valid: std_logic := '0';
begin
  gen0: if shift = 0 generate
    out_data <= in_data;
    out_user <= in_user;
    out_valid <= in_valid;
    in_ready <= out_ready;
    out_last <= in_last;
    out_keep <= in_keep;
  else generate
    proc: process(clk)
    begin
      if rising_edge(clk) then
        if in_valid = '1' and in_ready = '1' then
          shift_data <= in_data(shift_data'range);
          shift_keep <= in_keep(shift_keep'range);
          shift_last <= in_last;
          shift_valid <= '1';
        end if;
        if out_valid = '1' and out_ready = '1' and out_last = '1' then
          shift_valid <= '0';
          shift_last <= '0';
          shift_keep <= (others => '0');
        end if;
      end if;
    end process;

    -- shift_valid <= not (out_last and out_valid) when rising_edge(clk) and in_valid = '1' and in_ready = '1';

    out_data <= shift_data & in_data(in_data'left downto shift_data'length);
    cur_keep <= in_keep(in_keep'left downto shift_keep'length) when in_valid = '1' and (shift_valid = '0' or shift_last = '0') else (others => '0');
    out_keep <= shift_keep & cur_keep;
    out_last <= shift_last when (in_keep(shift - 1) = '1' and in_valid = '1') or in_valid = '0' else in_last;
    out_user <= in_user; -- I think this is safe as we wait 1 cycle if we have last in the register

    out_valid <= ((in_valid or shift_last) and shift_valid) or (in_valid and in_keep(in_keep'left)) or (in_valid and in_last and in_keep(in_keep'left));
    in_ready <= (not shift_valid and not in_keep(in_keep'left) and (in_keep(0) or in_last) and not shift_last) or -- in_keep(in_keep'left)='0', but in_keep(0) or in_last, happens when we fix a shift; input "00001111", e.g.
      (out_ready and not shift_last); -- shift_last means that we have a remainder from the last word and don't accept a new word in the current cycle.

  end generate;
end architecture;
