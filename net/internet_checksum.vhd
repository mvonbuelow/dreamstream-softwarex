-------------------------------------------------------------------------------
-- internet_checksum
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Compute the internet checksum (RFC 1071) on a variable input
--              vector asynchronously.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;

entity internet_checksum is
  generic (
    width: integer;
    wrap: boolean := true
  );
  port (
    data: in unsigned(width - 1 downto 0);
    chksum: out unsigned(15 + ite_i(wrap, 0, 1) downto 0) := (others => '0')
  );
end;

architecture internet_checksum_arch of internet_checksum is
  function calc_offset(maxlvl: integer; curlvl: integer) return integer is
    variable curoff: integer := 0;
  begin
    for i in maxlvl downto curlvl loop
      curoff := curoff + 2 ** i;
    end loop;
    return curoff;
  end function;

  constant maxlvl: integer := integer(log2(real(width))) - 1;
  constant minlvl: integer := integer(log2(16.0));

  constant mincuroff: integer := calc_offset(maxlvl, minlvl);
  constant minprevoff: integer := calc_offset(maxlvl, minlvl + 1);
  signal a, b, c: unsigned(mincuroff + ite_i(wrap, 15, 1) downto 0) := (others => '0');

  -- this function translates 'U' to '0'. it has no effect to synthesis
  function sanitize(input: unsigned) return unsigned is
    variable result: unsigned(input'range);
  begin
    for i in input'range loop
      if input(i) = 'U' then
        result(i) := '0';
      else
        result(i) := input(i);
      end if;
    end loop;
    return result;
  end function;
begin
  assert width >= 16 severity failure;
  assert width mod 16 = 0 severity failure;

  if0: if width = 16 generate
    chksum(data'range) <= data;
  else generate
    a(width / 2 - 1 downto 0) <= sanitize(data(width / 2 - 1 downto 0));
    b(width / 2 - 1 downto 0) <= sanitize(data(width - 1 downto width / 2));
    gen0: for i in maxlvl downto minlvl + 1 generate
      constant curw: integer := 2 ** i;
      constant curoff: integer := calc_offset(maxlvl, i);
      constant prevoff: integer := calc_offset(maxlvl, i + 1);
    begin
      a(curoff + curw / 2 - 1 downto curoff) <= transport c(prevoff + curw / 2 - 1 downto prevoff) after 1 ps;
      b(curoff + curw / 2 - 1 downto curoff) <= transport c(prevoff + curw - 1 downto prevoff + curw / 2) after 1 ps;
    end generate;

    if1: if wrap generate
      a(mincuroff + 15 downto mincuroff) <= transport c(minprevoff + 15 downto minprevoff) after 1 ps;
      b(mincuroff + 15 downto mincuroff) <= (others => '0');
      chksum <= c(c'left downto c'left - 15);
    else generate
      chksum <= c(c'left downto c'left - 16);
    end generate;

    c <= a + b;
  end generate;
end architecture;
