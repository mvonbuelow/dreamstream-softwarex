-------------------------------------------------------------------------------
-- types
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: TODO
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package types is
  type std_logic_vector_array is array (integer range <>) of std_logic_vector;
  type unsigned_array is array (integer range <>) of unsigned;
  type boolean_array is array (integer range <>) of boolean;
  type integer_array is array (integer range <>) of integer;

  function log2_ceil(value : integer) return integer;
  function ite_s(b         : boolean; x, y : string) return string;
  function ite_u(b         : boolean; x, y : unsigned) return unsigned;
  function ite_i(b         : boolean; x, y : integer) return integer;
  function ite_l(b         : boolean; x, y : std_logic) return std_logic;
  function ite_slv(b       : boolean; x, y : std_logic_vector) return std_logic_vector;
  function u2hex(uin       : unsigned) return string;
end package;

package body types is
  function log2_ceil(value : integer) return integer is
  begin
    return integer(ceil(log2(real(ite_i(value = 0, 1, value)))));
  end function;
  function ite_s(b : boolean; x, y : string) return string is
  begin
    if (b) then
      return x;
    else
      return y;
    end if;
  end function;
  function ite_u(b : boolean; x, y : unsigned) return unsigned is
  begin
    if (b) then
      return x;
    else
      return y;
    end if;
  end function;
  function ite_i(b : boolean; x, y : integer) return integer is
  begin
    if (b) then
      return x;
    else
      return y;
    end if;
  end function;
  function ite_l(b : boolean; x, y : std_logic) return std_logic is
  begin
    if (b) then
      return x;
    else
      return y;
    end if;
  end function;
  function ite_slv(b : boolean; x, y : std_logic_vector) return std_logic_vector is
  begin
    if (b) then
      return x;
    else
      return y;
    end if;
  end function;
  function u2hex(uin : unsigned) return string is
    variable res  : string((uin'length + 3) / 4 downto 1);
    constant chex : string := "0123456789ABCDEF";
  begin
    for i in res'reverse_range loop
      res(i) := chex(to_integer(shift_right(uin, (i - 1) * 4) mod 16) + 1);
    end loop;
    return "0x" & res;
  end function;
end package body;
