-------------------------------------------------------------------------------
-- fifo
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This is just a wrapper for all kinds of fifos. Supports async
--              and sync fifos. Allows to integrate the tuser path into the
--              tdata path. Implements tlast and tkeep. Includes ptional
--              outreg.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;

entity fifo is
  generic (
    width: integer;
    depth: integer;
    async: boolean := false;
    outreg: boolean := false;
    almost_full_threshold: integer := 0;

  -- tkeep handling
    use_keep: boolean := false;
    ignore_keep_msb: boolean := true; -- saves one bit :)

  -- tuser handling
    integrate_user: boolean := false;
    user: integer := 0;

  -- packet mode
    use_last: boolean := false;
    packet_mode: boolean := false;
    drop_packet: boolean := false;
    drop_absorb: boolean := true; -- if packet is dropped, assume the packet continues until last flag is set. the fifo will absorb that remaining data.
    max_packets: integer := depth -- every value is fine; the fifo will de-assert in-ready when we cannot count more packets
  );
  port (
    clk, in_clk, out_clk: in std_logic := 'U';
    rst, in_rst, out_rst: in std_logic := 'U';

    in_ready: out std_logic;
    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_last: in std_logic := '0';
    in_keep: in std_logic_vector( (width + 7) / 8 - 1 downto 0) := (others => '1');
    in_user: in std_logic_vector(user - 1 downto 0) := (others => '0');
    in_drop: in std_logic := '0';

    out_ready: in std_logic;
    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_last: out std_logic;
    out_keep: out std_logic_vector( (width + 7) / 8 - 1 downto 0);
    out_user: out std_logic_vector(user - 1 downto 0);

    almost_full: out std_logic
  );
end;

architecture fifo_arch of fifo is
  signal in_valid_c, in_ready_c, in_last_c, in_valid_a, in_ready_a: std_logic;
  signal in_data_c: std_logic_vector(in_data'range);
  signal in_keep_c: std_logic_vector(in_keep'range);

  signal in_drop_gated, do_absorption: std_logic;

  signal in_clk_i, out_clk_i, in_rst_i, out_rst_i: std_logic;

  signal in_data_keep_packed: std_logic_vector(width + ite_i(use_keep, width / 8 - ite_i(ignore_keep_msb, 1, 0), 0) - 1 downto 0);
  signal in_data_packed, out_data_packed: std_logic_vector(in_data_keep_packed'length + ite_i(integrate_user, 0, user) - 1 downto 0);

  signal out_valid_i, out_ready_i, out_last_i, out_valid_p, out_ready_p, out_last_p: std_logic;
  signal out_data_i, out_data_p: std_logic_vector(out_data'range);
  signal out_keep_i, out_keep_p: std_logic_vector(out_keep'range) := (others => '1');
  signal out_user_i, out_user_p: std_logic_vector(out_user'range);
  constant user_words: integer := (user + width - 1) / width;
  signal in_user_pad, out_user_p_pad: std_logic_vector(user_words * width - 1 downto 0) := (others => '0');
begin
  -- handle individual clock inputs for sync/async
  in_clk_i <= in_clk when async else clk;
  out_clk_i <= out_clk when async else clk;
  in_rst_i <= in_rst when async else rst;
  out_rst_i <= out_rst when async else rst;

  -- serialize tuser into tdata
  ifint: if user /= 0 and integrate_user generate
    in_user_pad(in_user'range) <= in_user;
    composer_inst: entity ds.composer
      generic map (
        width => width,
        user => in_user_pad'length
      )
      port map (
        clk => in_clk_i,
        rst => in_rst_i,
        in_valid => in_valid,
        in_data => in_data,
        in_last => in_last,
        in_ready => in_ready,
        in_keep => in_keep,
        in_user => in_user_pad,
        out_valid => in_valid_c,
        out_data => in_data_c(in_data'range),
        out_last => in_last_c,
        out_ready => in_ready_c,
        out_keep => in_keep_c
      );
  else generate
    in_valid_c <= in_valid;
    in_ready <= in_ready_c;
    in_last_c <= in_last;
    in_data_c <= in_data;
    in_keep_c <= in_keep;
  end generate;

  -- pack tkeep into tdata
  ifkeep: if use_keep generate
    in_data_keep_packed <= in_keep_c(in_keep'left - ite_i(ignore_keep_msb, 1, 0) downto 0) & in_data_c;
  else generate
    in_data_keep_packed <= in_data_c;
  end generate;

  -- pack tuser into tdata
  ifint2: if integrate_user generate
    in_data_packed <= in_data_keep_packed;
  else generate
    in_data_packed <= in_user & in_data_keep_packed;
  end generate;

  -- drop-absorption logic
  in_drop_gated <= in_drop when use_last and packet_mode else '0'; -- synthesizer-only logic; no actual gates
  do_absorption <= in_drop_gated when drop_absorb else '0';
  absorber_inst: entity ds.absorber
    port map (-- will be optimized away if we take care of in_absorb
      clk => in_clk_i,
      rst => in_rst_i,
      in_valid => in_valid_c,
      in_ready => in_ready_c,
      in_last => in_last_c,
      in_absorb => do_absorption,
      out_valid => in_valid_a,
      out_ready => in_ready_a
    );

  -- the actual fifos
  ifsync: if not async generate
    sync_fifo_inst: entity ds.sync_fifo
      generic map (
        width => in_data_packed'length,
        depth => depth,
        almost_full_threshold => almost_full_threshold,
        use_last => use_last,
        packet_mode => packet_mode,
        drop_packet => drop_packet,
        max_packets => max_packets
      )
      port map (
        clk => in_clk_i,
        rst => in_rst_i,
        in_ready => in_ready_a,
        in_valid => in_valid_a,
        in_data => in_data_packed,
        in_last => in_last_c,
        in_drop => in_drop,
        out_ready => out_ready_i,
        out_valid => out_valid_i,
        out_data => out_data_packed,
        out_last => out_last_i,
        almost_full => almost_full
      );
  else generate
    proc_check: process
    begin
      assert max_packets = depth report "Async fifo does not support max_packets." severity failure;
      assert almost_full_threshold = 0 report "Async fifo does not support almost_full_threshold." severity failure;
      wait;
    end process;
    async_fifo_inst: entity ds.async_fifo
      generic map (
        width => in_data_packed'length,
        depth => depth,
        enable_last => use_last,
        enable_packet_mode => packet_mode,
        enable_drop => drop_packet
      )
      port map (
        in_clk => in_clk_i,
        in_rst => in_rst_i,
        out_clk => out_clk_i,
        out_rst => out_rst_i,
        in_ready => in_ready_a,
        in_valid => in_valid_a,
        in_data => in_data_packed,
        in_last => in_last_c,
        in_drop => in_drop,
        out_ready => out_ready_i,
        out_valid => out_valid_i,
        out_data => out_data_packed,
        out_last => out_last_i
      );
  end generate;

  -- extract tdata and tkeep from packed vector
  out_data_i <= out_data_packed(out_data_i'range);
  ifkeep2: if use_keep generate
    out_keep_i(out_keep_i'left - ite_i(ignore_keep_msb, 1, 0) downto 0) <= out_data_packed(out_data_i'length + out_keep_i'length - ite_i(ignore_keep_msb, 1, 0) - 1 downto out_data_i'length);
  end generate;

  -- extract serialized tuser, otherwise extract tuser from packed vector
  ifint3: if user /= 0 and integrate_user generate
    parser_inst: entity ds.parser
      generic map (
        width => width,
        user => out_user_p_pad'length
      )
      port map (
        clk => out_clk_i,
        rst => out_rst_i,
        in_valid => out_valid_i,
        in_data => out_data_i,
        in_last => out_last_i,
        in_keep => out_keep_i,
        in_ready => out_ready_i,
        out_valid => out_valid_p,
        out_data => out_data_p,
        out_user => out_user_p_pad,
        out_keep => out_keep_p,
        out_last => out_last_p,
        out_ready => out_ready_p
      );
    out_user_p <= out_user_p_pad(out_user'range);
  else generate
    out_user_i <= out_data_packed(out_data_packed'left downto out_data_packed'left - user + 1);
    out_valid_p <= out_valid_i;
    out_ready_i <= out_ready_p;
    out_last_p <= out_last_i;
    out_data_p <= out_data_i;
    out_keep_p <= out_keep_i;
    out_user_p <= out_user_i;
  end generate;

  -- the outreg
  ifoutreg: if outreg generate
    reg_inst: entity ds.reg
      generic map (
        width => width,
        user => user
      )
      port map (
        clk => out_clk_i,
        rst => out_rst_i,
        in_valid => out_valid_p,
        in_ready => out_ready_p,
        in_data => out_data_p,
        in_last => out_last_p,
        in_keep => out_keep_p,
        in_user => out_user_p,
        out_valid => out_valid,
        out_ready => out_ready,
        out_data => out_data,
        out_last => out_last,
        out_keep => out_keep,
        out_user => out_user
      );
  else generate
    out_valid <= out_valid_p;
    out_ready_p <= out_ready;
    out_data <= out_data_p;
    out_last <= out_last_p;
    out_keep <= out_keep_p;
    out_user <= out_user_p;
  end generate;
end architecture;

