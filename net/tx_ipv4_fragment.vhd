-------------------------------------------------------------------------------
-- tx_ipv4_fragment
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This fragments the packets for further use in IPv4 packets.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

entity tx_ipv4_fragment is
  generic (
    width: integer := 64;
    max_payload: integer := 1480; -- must be multiple of 8
    add_size: integer := 0
  );
  port (
    clk, rst: in std_logic;

    in_ready: out std_logic;
    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_last: in std_logic;
    in_dest: in std_logic_vector(47 + 32 downto 0);
    in_id: in std_logic_vector(31 downto 0);
    in_user: in std_logic_vector(23 downto 0); -- 15:0 length 23:16 proto

    out_ready: in std_logic;
    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_last: out std_logic;
    out_dest: out std_logic_vector(47 + 32 downto 0);
    out_id: out std_logic_vector(31 downto 0);
    out_user: out std_logic_vector(55 downto 0) -- 15:0 fraglength 31:16 frag more+off 47:32 ident 55:48 proto
  );
end;

architecture net_tx_ipv4_fragment_arch of tx_ipv4_fragment is
  signal remaining_payload, cur_fragment_size: unsigned(15 downto 0) := (others => '0');
  signal fragmore: std_logic;

  signal frag_idx, frag_off: unsigned(15 downto 0) := (others => '0');
  signal frag_last: std_logic := '0';
  constant frag_max_idx: integer := max_payload - width / 8;
  signal fraginf: std_logic_vector(15 downto 0);
  signal ident: unsigned(15 downto 0) := (others => '0');

  signal out_x_ready, out_x_valid, out_x_last: std_logic;
  signal out_x_data: std_logic_vector(out_data'range);
  signal out_x_keep: std_logic_vector(out_keep'range);
  signal out_x_dest: std_logic_vector(out_dest'range);
  signal out_x_id: std_logic_vector(out_id'range);
  signal out_x_user: std_logic_vector(out_user'range);
begin
  proc_frag: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        frag_idx <= (others => '0');
        frag_off <= (others => '0');
        ident <= (others => '0');
      else
        if in_valid = '1' and in_ready = '1' then
          frag_idx <= frag_idx + width / 8;

          if frag_idx = frag_max_idx then
            frag_idx <= (others => '0');
            frag_off <= frag_off + frag_idx + width / 8;
          end if;
          if in_last = '1' then
            frag_off <= (others => '0');
            frag_idx <= (others => '0');
            ident <= ident + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
  frag_last <= '1' when frag_idx = frag_max_idx or in_last = '1' else '0';

  remaining_payload <= unsigned(in_user(15 downto 0)) - unsigned(frag_off);
  cur_fragment_size <= remaining_payload when remaining_payload <= max_payload else to_unsigned(max_payload, 16);
  fragmore <= '0' when remaining_payload <= max_payload else '1';
  fraginf <= "00" & fragmore & std_logic_vector(frag_off(15 downto 3));
  out_x_user <= in_user(23 downto 16) & std_logic_vector(ident) & fraginf & std_logic_vector(cur_fragment_size + add_size);

  out_x_data <= in_data;
  out_x_valid <= in_valid;
  out_x_dest <= in_dest;
  out_x_keep <= in_keep;
  out_x_last <= frag_last;
  in_ready <= out_x_ready;
  out_x_id <= in_id;

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
