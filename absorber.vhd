-------------------------------------------------------------------------------
-- absorber
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: When in_absorb is asserted, it ignores the rest of the frame
--              until last flag is asserted.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;

entity absorber is
  port (
    clk, rst : in std_logic;

    in_valid  : in  std_logic;
    in_ready  : out std_logic;
    in_last   : in  std_logic;
    in_absorb : in  std_logic;

    out_valid : out std_logic;
    out_ready : in  std_logic
    );
end;

architecture absorber_arch of absorber is
  signal absorb : std_logic := '0';
begin
  in_ready  <= out_ready or absorb;
  out_valid <= in_valid and not absorb;

  proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        absorb <= '0';
      else
        if in_absorb = '1' then
          absorb <= '1';
        end if;
        if in_valid = '1' and in_ready = '1' and in_last = '1' then
          absorb <= '0';
        end if;
      end if;
    end if;
  end process;
end architecture;

