-------------------------------------------------------------------------------
-- fifo
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This is just a wrapper for all kinds of fifos.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;

entity fifo is
  generic (
    width                 : natural;
    depth                 : natural;
    async                 : boolean := false;
    almost_full_threshold : natural := 0;
    use_last              : boolean := false;
    packet_mode           : boolean := false;
    drop_packet           : boolean := false;
    drop_absorb           : boolean := true;  -- if packet is dropped, assume the packet continues until last flag is set. the fifo will absorb that remaining data.
    max_packets           : integer := depth;  -- every value is fine; the fifo will de-assert in-ready when we cannot count more packets
    outreg                : boolean := false;
    use_keep              : boolean := false;
    ignore_keep_msb       : boolean := true   -- saves one bit :)
    );
  port (
    clk, in_clk, out_clk : in std_logic := 'U';
    rst, in_rst, out_rst : in std_logic := 'U';

    in_ready : out std_logic;
    in_valid : in  std_logic;
    in_data  : in  std_logic_vector(width - 1 downto 0);
    in_last  : in  std_logic                                := '0';
    in_drop  : in  std_logic                                := '0';
    in_keep  : in  std_logic_vector(width / 8 - 1 downto 0) := (others => '1');

    out_ready : in  std_logic;
    out_valid : out std_logic;
    out_data  : out std_logic_vector(width - 1 downto 0);
    out_last  : out std_logic;
    out_keep  : out std_logic_vector(width / 8 - 1 downto 0);

    almost_full : out std_logic
    );
end;


architecture fifo_arch of fifo is
  signal in_valid_i, in_ready_i : std_logic;

  signal in_drop_gated, do_absorption : std_logic;

  signal in_clk_i, out_clk_i, in_rst_i, out_rst_i : std_logic;

  signal in_data_packed, out_data_packed : std_logic_vector(width + ite_i(use_keep, width / 8 - ite_i(ignore_keep_msb, 1, 0), 0) - 1 downto 0);

  signal out_valid_i, out_ready_i, out_last_i : std_logic;
  signal out_data_i                           : std_logic_vector(out_data'range);
  signal out_keep_i                           : std_logic_vector(out_keep'range);
begin
  in_clk_i  <= in_clk  when async else clk;
  out_clk_i <= out_clk when async else clk;
  in_rst_i  <= in_rst  when async else rst;
  out_rst_i <= out_rst when async else rst;

  ifkeep : if use_keep generate
    in_data_packed <= in_keep(in_keep'left - ite_i(ignore_keep_msb, 1, 0) downto 0) & in_data;
  else generate
    in_data_packed <= in_data;
  end generate;

  in_drop_gated <= in_drop       when use_last and packet_mode else '0';  -- synthesizer-only logic; no actual gates
  do_absorption <= in_drop_gated when drop_absorb              else '0';
  absorber_inst : entity ds.absorber port map (  -- will be optimized away if we take care of in_absorb
    clk       => in_clk_i,
    rst       => in_rst_i,
    in_valid  => in_valid,
    in_ready  => in_ready,
    in_last   => in_last,
    in_absorb => do_absorption,
    out_valid => in_valid_i,
    out_ready => in_ready_i
    );
  ifsync : if not async generate
    sync_fifo_inst : entity ds.sync_fifo
      generic map (
        width                 => in_data_packed'length,
        depth                 => depth,
        almost_full_threshold => almost_full_threshold,
        use_last              => use_last,
        packet_mode           => packet_mode,
        drop_packet           => drop_packet,
        drop_absorb           => drop_absorb,
        max_packets           => max_packets
        )
      port map (
        clk         => in_clk_i,
        rst         => in_rst_i,
        in_ready    => in_ready_i,
        in_valid    => in_valid_i,
        in_data     => in_data_packed,
        in_last     => in_last,
        in_drop     => in_drop,
        out_ready   => out_ready_i,
        out_valid   => out_valid_i,
        out_data    => out_data_packed,
        out_last    => out_last_i,
        almost_full => almost_full
        );
  else generate
    async_fifo_inst : entity ds.async_fifo
      generic map (
        width              => in_data_packed'length,
        depth              => depth,
        enable_last        => use_last,
        enable_packet_mode => packet_mode,
        enable_drop        => drop_packet
        )
      port map (
        in_clk    => in_clk_i,
        in_rst    => in_rst_i,
        out_clk   => out_clk_i,
        out_rst   => out_rst_i,
        in_ready  => in_ready_i,
        in_valid  => in_valid_i,
        in_data   => in_data_packed,
        in_last   => in_last,
        in_drop   => in_drop,
        out_ready => out_ready_i,
        out_valid => out_valid_i,
        out_data  => out_data_packed,
        out_last  => out_last_i
        );
  end generate;

  out_data_i                                                          <= out_data_packed(out_data_i'range);
  out_keep_i(out_keep_i'left - ite_i(ignore_keep_msb, 1, 0) downto 0) <= out_data_packed(out_data_packed'left downto out_data_i'length);

  ifoutreg : if outreg generate
    reg_inst : entity ds.reg
      generic map (
        width => width
        )
      port map (
        clk       => out_clk_i,
        rst       => out_rst_i,
        in_valid  => out_valid_i,
        in_ready  => out_ready_i,
        in_data   => out_data_i,
        in_last   => out_last_i,
        in_keep   => out_keep_i,
        out_valid => out_valid,
        out_ready => out_ready,
        out_data  => out_data,
        out_last  => out_last,
        out_keep  => out_keep
        );
  else generate
    out_valid   <= out_valid_i;
    out_ready_i <= out_ready;
    out_data    <= out_data_i;
    out_last    <= out_last_i;
    out_keep    <= out_keep_i;
  end generate;
end architecture;

