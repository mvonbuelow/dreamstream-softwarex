-------------------------------------------------------------------------------
-- stream_fifo
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Injects an header to the start of a packet in an AXI stream.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;

entity stream_fifo is
  generic (
    width           : integer;
    depth           : integer;
    packet_mode     : boolean := false;
    drop_packet     : boolean := false;
    user            : integer;
    ignore_keep_msb : boolean := false;  -- saves one bit :)
    max_packets     : integer := depth
    );
  port (
    clk : in std_logic;
    rst : in std_logic := '0';

    in_valid : in  std_logic;
    in_data  : in  std_logic_vector(width - 1 downto 0);
    in_last  : in  std_logic;
    in_ready : out std_logic;
    in_keep  : in  std_logic_vector(width / 8 - 1 downto 0);
    in_user  : in  std_logic_vector(user - 1 downto 0) := (others => '0');
    in_drop  : in  std_logic                           := '0';

    out_valid : out std_logic;
    out_data  : out std_logic_vector(width - 1 downto 0);
    out_last  : out std_logic;
    out_ready : in  std_logic;
    out_keep  : out std_logic_vector(width / 8 - 1 downto 0);
    out_user  : out std_logic_vector(user - 1 downto 0)
    );
end;

architecture stream_fifo_arch of stream_fifo is
  signal usermerge_valid, usermerge_ready, usermerge_last : std_logic;
  signal usermerge_data                                   : std_logic_vector(width - 1 downto 0);
  signal usermerge_keep                                   : std_logic_vector(width / 8 - 1 downto 0);

  signal fifo_in_valid, fifo_in_ready, fifo_in_last, outfifo_valid, outfifo_ready, outfifo_last : std_logic;
  signal fifo_in_all, fifo_out_all                                                              : std_logic_vector(width + width / 8 - 1 downto 0) := (others => '1');  -- here is the missing keep bit ;)
  signal fifo_in_data, fifo_out_data, outfifo_data                                              : std_logic_vector(out_data'range);
  signal fifo_in_keep, fifo_out_keep, outfifo_keep                                              : std_logic_vector(out_keep'range);
  signal fifo_out_valid, fifo_out_ready, fifo_out_last                                          : std_logic;
  signal outfifo_user                                                                           : std_logic_vector(out_user'range);

  constant user_words : integer                                           := (user + width - 1) / width;
  signal out_user_pre : std_logic_vector(user_words * width - 1 downto 0);
  signal in_user_pad  : std_logic_vector(user_words * width - 1 downto 0) := (others => '0');

begin
  -- merge first user word into stream
  in_user_pad(in_user'range) <= in_user;
  composer_inst : entity ds.composer generic map (
    width => width,
    user  => in_user_pad'length
    ) port map (
      clk       => clk,
      rst       => rst,
      in_valid  => in_valid,
      in_data   => in_data,
      in_last   => in_last,
      in_ready  => in_ready,
      in_keep   => in_keep,
      in_user   => in_user_pad,
      out_valid => usermerge_valid,
      out_data  => usermerge_data(in_data'range),
      out_last  => usermerge_last,
      out_ready => usermerge_ready,
      out_keep  => usermerge_keep
      );

  fifo_in_valid   <= usermerge_valid;
  fifo_in_data    <= usermerge_data;
  fifo_in_last    <= usermerge_last;
  fifo_in_keep    <= usermerge_keep;
  usermerge_ready <= fifo_in_ready;

  fifo_in_all <= fifo_in_keep & fifo_in_data;

  fifo_inst : entity ds.fifo generic map (
    width       => width + width / 8 - ite_i(ignore_keep_msb, 1, 0),
    depth       => depth,
    use_last    => true,
    packet_mode => packet_mode,
    drop_packet => drop_packet,
    max_packets => max_packets
    ) port map (
      clk       => clk,
      rst       => rst,
      in_ready  => fifo_in_ready,
      in_valid  => fifo_in_valid,
      in_data   => fifo_in_all(fifo_in_all'left - ite_i(ignore_keep_msb, 1, 0) downto 0),
      in_last   => fifo_in_last,
      in_drop   => in_drop,
      out_ready => fifo_out_ready,
      out_valid => fifo_out_valid,
      out_data  => fifo_out_all(fifo_out_all'left - ite_i(ignore_keep_msb, 1, 0) downto 0),
      out_last  => fifo_out_last
      );
  fifo_out_data <= fifo_out_all(fifo_out_data'range);
  fifo_out_keep <= fifo_out_all(fifo_out_all'left downto fifo_out_data'length);

  parser_inst : entity ds.parser generic map (
    width => width,
    user  => out_user_pre'length
    ) port map (
      clk       => clk,
      rst       => rst,
      in_valid  => fifo_out_valid,
      in_data   => fifo_out_data,
      in_last   => fifo_out_last,
      in_keep   => fifo_out_keep,
      in_ready  => fifo_out_ready,
      out_valid => outfifo_valid,
      out_data  => outfifo_data,
      out_user  => out_user_pre,
      out_keep  => outfifo_keep,
      out_last  => outfifo_last,
      out_ready => outfifo_ready
      );
  outfifo_user <= out_user_pre(out_user'range);

  reg_inst : entity ds.reg generic map (
    width => width,
    user  => user
    ) port map (
      clk       => clk,
      rst       => rst,
      in_ready  => outfifo_ready,
      in_valid  => outfifo_valid,
      in_data   => outfifo_data,
      in_last   => outfifo_last,
      in_keep   => outfifo_keep,
      in_user   => outfifo_user,
      out_ready => out_ready,
      out_valid => out_valid,
      out_data  => out_data,
      out_last  => out_last,
      out_keep  => out_keep,
      out_user  => out_user
      );

end architecture;
