
-------------------------------------------------------------------------------
-- pod
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Ping of death.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;
library dsnet;

entity pod is
  generic (
    width: integer := 64;
    magic: std_logic_vector(63 downto 0) := x"ECC1701D" & x"abad1dea";
    magic_unicast: std_logic_vector(63 downto 0) := x"ECC1701D" & x"CAFE1500"
  );
  port (
    clk, rst: in std_logic;

    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0) := (others => '1');
    in_last: in std_logic;
    src_mac: in std_logic_vector(47 downto 0);

    reboot: out std_logic := '0'
  );
end;

architecture pod_arch of pod is
  signal reboot_unicast, reboot_broadcast, reboot_old: std_logic;
begin
  bl_unicast: block
    constant check_mask: std_logic_vector(63 downto 0) := (others => '1');
    signal pod_user: std_logic_vector( (6 + 6 + 2) * 8 + 5 * 32 + 64 + magic'length + 48 downto 0);
    signal pod_valid: std_logic;
  begin
    parser_inst: entity ds.parser generic map (
      width => width,
      user => pod_user'length - 1,
      check_mask => x"010000000000000000000000ffff" & (x"ff000000" & (x"0000" & "1011" & x"fff") & x"00ff0000" & x"00000000" & x"00000000") & x"ffff000000000000" & check_mask & x"ffffffffffff"
    ) port map (
      clk => clk,
      rst => rst,
      in_valid => in_valid,
      in_data => in_data,
      in_last => in_last,
      in_keep => in_keep,
      out_valid => pod_valid,
      out_ready => '1',
      out_user => pod_user,
      check_val => (x"010000000000" & x"000000000000" & x"0800") & (x"45000000" & x"00000000" & x"00010000" & x"00000000" & x"00000000") & (x"0800000000000000") & magic_unicast & src_mac
    );
    reboot_unicast <= pod_valid and not pod_user(pod_user'left) when rising_edge(clk);
  end block;
  bl_broadcast: block
    constant check_mask: std_logic_vector(63 downto 0) := (others => '1');
    signal pod_user: std_logic_vector( (6 + 6 + 2) * 8 + 5 * 32 + 64 + magic'length downto 0);
    signal pod_valid: std_logic;
  begin
    parser_inst: entity ds.parser generic map (
      width => width,
      user => pod_user'length - 1,
      check_mask => x"010000000000000000000000ffff" & (x"ff000000" & (x"0000" & "1011" & x"fff") & x"00ff0000" & x"00000000" & x"00000000") & x"ffff000000000000" & check_mask
    ) port map (
      clk => clk,
      rst => rst,
      in_valid => in_valid,
      in_data => in_data,
      in_last => in_last,
      in_keep => in_keep,
      out_valid => pod_valid,
      out_ready => '1',
      out_user => pod_user,
      check_val => (x"010000000000" & x"000000000000" & x"0800") & (x"45000000" & x"00000000" & x"00010000" & x"00000000" & x"00000000") & (x"0800000000000000") & magic
    );
    reboot_broadcast <= pod_valid and not pod_user(pod_user'left) when rising_edge(clk);
  end block;
  bl_old: block
    constant check_mask: std_logic_vector(63 downto 0) := (others => '1');
    signal pod_user: std_logic_vector( (6 + 6 + 2) * 8 + 5 * 32 + 64 + magic'length downto 0);
    signal pod_valid: std_logic;
  begin
    parser_inst: entity ds.parser generic map (
      width => width,
      user => pod_user'length - 1,
      check_mask => x"ffffffffffff000000000000ffff" & (x"ff000000" & (x"0000" & "1011" & x"fff") & x"00ff0000" & x"00000000" & x"00000000") & x"ffff000000000000" & check_mask
    ) port map (
      clk => clk,
      rst => rst,
      in_valid => in_valid,
      in_data => in_data,
      in_last => in_last,
      in_keep => in_keep,
      out_valid => pod_valid,
      out_ready => '1',
      out_user => pod_user,
      check_val => (src_mac & x"000000000000" & x"0800") & (x"45000000" & x"00000000" & x"00010000" & x"00000000" & x"00000000") & (x"0800000000000000") & magic
    );
    reboot_old <= pod_valid and not pod_user(pod_user'left) when rising_edge(clk);
  end block;
  reboot <= reboot_unicast or reboot_broadcast or reboot_old;
end architecture;
