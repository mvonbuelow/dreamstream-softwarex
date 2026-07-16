-------------------------------------------------------------------------------
-- rx_ipv4
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: IPv4 packet parser.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;

entity rx_ipv4 is
  generic (
    width: integer := 64;
    nprotos: integer := 0;
    protos: std_logic_vector_array(0 to nprotos - 1)(7 downto 0)
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    in_ready: out std_logic;
    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_last: in std_logic;
    in_id: in std_logic_vector(47 downto 0);

    out_ready: in std_logic;
    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_last: out std_logic;
    out_id: out std_logic_vector(48 + 31 downto 0) := (others => '0');
    out_dest: out std_logic_vector(31 downto 0);
    out_user: out std_logic_vector(8 + log2_ceil(nprotos + 1) - 1 downto 0) := (others => '0')
  );
end;

architecture net_rx_ipv4_arch of rx_ipv4 is
  signal out_x_ready, out_x_valid, out_x_last: std_logic;
  signal out_x_data: std_logic_vector(out_data'range);
  signal out_x_keep: std_logic_vector(out_keep'range);
  signal out_x_dest: std_logic_vector(out_dest'range);
  signal out_x_id: std_logic_vector(out_id'range);
  signal out_x_user: std_logic_vector(out_user'range);
  signal out_x_user_pre: std_logic_vector(8 * 4 * 5 - 1 downto 0);
  signal err: std_logic;
  signal anno: std_logic_vector(log2_ceil(nprotos + 1) - 1 downto 0);
begin
  -- We drop packets that have IPv4 options. This makes the code easier to parse.
  -- RFC7126 says that we are more or less allowed to do this and we definately don't risk anything.
  -- https://datatracker.ietf.org/doc/rfc7126/

  parser_inst: entity ds.parser generic map (
    width => width,
    user => out_x_user_pre'length,
    check_mask => x"ff000000" & (x"0000" & "1011" & x"fff") & x"00000000" & x"00000000" & x"00000000",
    absorb_on_error => true
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => in_valid,
    in_data => in_data,
    in_last => in_last,
    in_keep => in_keep,
    in_ready => in_ready,
    out_valid => out_x_valid,
    out_data => out_x_data,
    out_last => out_x_last,
    out_keep => out_x_keep,
    out_ready => out_x_ready,
    out_user => out_x_user_pre,
    check_val => x"45000000" & x"00000000" & x"00000000" & x"00000000" & x"00000000"
  );

  proc_protos: process(all)
  begin
    anno <= (others => '1');
    for i in 0 to nprotos - 1 loop
      if out_x_user_pre(87 downto 80) = protos(i) then
        anno <= std_logic_vector(to_unsigned(i, anno'length));
        exit;
      end if;
    end loop;
  end process;
  out_x_user <= anno & out_x_user_pre(87 downto 80);
  out_x_dest <= out_x_user_pre(31 downto 0);
  out_x_id <= in_id & out_x_user_pre(63 downto 32);

  reg_inst: entity ds.reg generic map (
    width => out_data'length,
    user => out_user'length,
    dest => out_dest'length,
    id => out_id'length
  ) port map (
    clk => clk,
    rst => rst,
    in_ready => out_x_ready,
    in_valid => out_x_valid,
    in_data => out_x_data,
    in_last => out_x_last,
    in_keep => out_x_keep,
    in_user => out_x_user,
    in_dest => out_x_dest,
    in_id => out_x_id,
    out_ready => out_ready,
    out_valid => out_valid,
    out_data => out_data,
    out_last => out_last,
    out_keep => out_keep,
    out_user => out_user,
    out_dest => out_dest,
    out_id => out_id
  );
end architecture;
