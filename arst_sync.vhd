library ieee;
use ieee.std_logic_1164.all;

entity arst_sync is
  port (
    clk: in std_logic;
    arst: in std_logic;
    rst: out std_logic := '1'
  );
end entity;

architecture arst_sync_arch of arst_sync is
  signal rst_ff1: std_logic := '1';
begin
  process(clk, arst)
  begin
    if arst = '1' then
      rst_ff1 <= '1';
      rst <= '1';
    elsif rising_edge(clk) then
      rst_ff1 <= '0';
      rst <= rst_ff1;
    end if;
  end process;
end;
