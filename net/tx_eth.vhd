-------------------------------------------------------------------------------
-- tx_eth
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Ethernet frame constructor.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

entity tx_eth is
  generic (
    width: integer := 64
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    in_ready: out std_logic;
    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_last: in std_logic;
    in_dest: in std_logic_vector(47 downto 0);
    in_id: in std_logic_vector(47 downto 0);
    in_user: in std_logic_vector(15 downto 0); -- ethtype

    out_ready: in std_logic;
    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_last: out std_logic
  );
end;

architecture net_tx_eth_arch of tx_eth is
  signal out_x_ready, out_x_valid, out_x_last: std_logic;
  signal out_x_data: std_logic_vector(out_data'range);
  signal out_x_keep: std_logic_vector(out_keep'range);
begin
  composer_inst: entity ds.composer generic map (
    width => width,
    user => 48 * 2 + 16
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => in_valid,
    in_data => in_data,
    in_last => in_last,
    in_ready => in_ready,
    in_keep => in_keep,
    in_user => in_dest & in_id & in_user,
    out_valid => out_x_valid,
    out_data => out_x_data,
    out_last => out_x_last,
    out_ready => out_x_ready,
    out_keep => out_x_keep
  );
  reg_inst: entity ds.reg2 generic map (
    width => out_data'length
  ) port map (
    clk => clk,
    rst => rst,
    in_ready => out_x_ready,
    in_valid => out_x_valid,
    in_data => out_x_data,
    in_last => out_x_last,
    in_keep => out_x_keep,
    out_ready => out_ready,
    out_valid => out_valid,
    out_data => out_data,
    out_last => out_last,
    out_keep => out_keep
  );
end architecture;
