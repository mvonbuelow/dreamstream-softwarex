-------------------------------------------------------------------------------
-- eof2last
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

library ds;

entity eof2last is
  generic (
    w    : integer;
    user : integer := 1
    );
  port (
    clk : in std_logic;
    rst : in std_logic := '0';

    in_ready : out std_logic;
    in_valid : in  std_logic;
    in_eof   : in  std_logic;
    in_data  : in  std_logic_vector(w - 1 downto 0);
    in_user  : in  std_logic_vector(user - 1 downto 0) := (others => '0');

    out_ready : in  std_logic;
    out_valid : out std_logic;
    out_last  : out std_logic;
    out_data  : out std_logic_vector(w - 1 downto 0)    := (others => '0');
    out_user  : out std_logic_vector(user - 1 downto 0) := (others => '0');
    out_empty : out std_logic
    );
end;


architecture eof2last_arch of eof2last is
  signal outreg_full : std_logic := '0';
begin
  proc_out : process(clk)               -- TODO: write tests for this
  begin
    if rising_edge(clk) then
      if in_ready = '1' then
        out_data    <= in_data;
        out_user    <= in_user;
        outreg_full <= in_valid;
      end if;
      if rst = '1' then
        outreg_full <= '0';
      end if;
    end if;
  end process;
  in_ready  <= (not outreg_full and not in_eof) or out_ready;
  out_valid <= (outreg_full and (in_valid or in_eof)) or in_eof;
  out_last  <= in_eof;
  out_empty <= not outreg_full;
end architecture;
