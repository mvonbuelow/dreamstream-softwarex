library ieee;
use ieee.std_logic_1164.all;

entity async_reg is
  generic (
    width: integer := 1
  );
  port (
    in_clk, out_clk: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    out_data: out std_logic_vector(width - 1 downto 0)
  );
end entity;

architecture async_reg_arch of async_reg is
  signal data_r, data_rr: std_logic_vector(in_data'range);
begin
  data_r <= in_data when rising_edge(in_clk);
  data_rr <= data_r when rising_edge(out_clk);
  out_data <= data_rr when rising_edge(out_clk);
end architecture;
