-------------------------------------------------------------------------------
-- collector
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This module delays the data stream until all packet metadata is
--              collected, then transmits the packet with stable sideband
--              information attached for the entire packet.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;

entity collector is
  generic (
    width               : integer;
    user                : integer;
    n                   : integer := 1;
    meta_width          : integer;
    max_offset          : integer;  -- number of bits to buffer. it must be at least the number of bytes that the last "meta_valid" is away from the beginning (MTU + x in most cases).
    overflow_protection : boolean := false
    );
  port (
    clk, rst : in  std_logic;
    in_data  : in  std_logic_vector(width - 1 downto 0);
    in_keep  : in  std_logic_vector(width / 8 - 1 downto 0);
    in_valid : in  std_logic;
    in_last  : in  std_logic;
    in_ready : out std_logic;
    in_user  : in  std_logic_vector(user - 1 downto 0);

    meta_valid : in std_logic_vector(n - 1 downto 0);
    meta_data  : in std_logic_vector_array(0 to n - 1)(meta_width - 1 downto 0);

    out_data  : out std_logic_vector(width - 1 downto 0);
    out_keep  : out std_logic_vector(width / 8 - 1 downto 0) := (others => '1');
    out_valid : out std_logic;
    out_last  : out std_logic;
    out_ready : in  std_logic;
    out_user  : out std_logic_vector(user + n * meta_width - 1 downto 0)
    );
end;

architecture net_collector_arch of collector is
  signal fifo_ready, fifo_valid : std_logic;
  signal fifo_data              : std_logic_vector(in_data'range);

  signal in_first               : std_logic := '1';
  signal all_meta_latches_ready : std_logic;

  signal fifo_in_valid, fifo_in_ready : std_logic;

  signal meta_latch_valid_arr, latch_in_valid_arr      : std_logic_vector(n downto 0);
  signal latch_in_data                                 : std_logic_vector(out_user'range);
  signal latch_in_ready, latch_in_ready_x, latch_valid : std_logic;
  signal meta_ready_arr                                : std_logic_vector(n - 1 downto 0);
  signal user_ready                                    : std_logic;

  signal fifo_drop, latch_drop, ignore : std_logic := '0';
begin
  -- accept new data when all meta_latches are ready to accept data
  all_meta_latches_ready <= and meta_ready_arr and user_ready;
  fifo_in_valid          <= in_valid and all_meta_latches_ready;
  in_ready               <= fifo_in_ready and all_meta_latches_ready;
  proc_user : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        in_first <= '1';
      else
        if in_valid = '1' and in_ready = '1' then
          in_first <= in_last;
        end if;
      end if;
    end if;
  end process;

-- this block resolves a deadlock caused by a packet that is too big. we just delete it.
  blk_deadlock : if overflow_protection and false generate
    type state_t is (IDLE, DEADLOCK, CLEAN_META);
    signal state : state_t := IDLE;
  begin
    proc_deadlock : process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          state <= IDLE;
        else
          case state is
            when IDLE =>
              if fifo_in_ready = '0' and fifo_in_valid = '1' and out_valid = '0' and false then
                state <= DEADLOCK;
              end if;
            when DEADLOCK =>
              -- fifo_in_ready should be asserted now...
              if fifo_in_valid = '1' and in_last = '1' then
                state <= CLEAN_META;
              end if;
            when CLEAN_META =>
              if latch_valid = '1' then
                state <= IDLE;
              end if;
          end case;
        end if;
      end if;
    end process;
    fifo_drop  <= '1' when state = DEADLOCK   else '0';
    latch_drop <= '1' when state = CLEAN_META else '0';
    ignore     <= '1' when state /= IDLE      else '0';
  end generate;
  fifo_inst : entity ds.fifo generic map (
    width           => in_data'length,
    depth           => max_offset / width,
    use_last        => true,
    use_keep        => true,
    ignore_keep_msb => true,
    outreg          => true
    ) port map (
      clk       => clk,
      rst       => rst,
      in_ready  => fifo_in_ready,
      in_valid  => fifo_in_valid,
      in_data   => in_data,
      in_keep   => in_keep,
      in_last   => in_last,
      in_drop   => fifo_drop,
      out_ready => fifo_ready,
      out_valid => fifo_valid,
      out_data  => out_data,
      out_keep  => out_keep,
      out_last  => out_last
      );

  -- the collector architecture consists of the following three-phase setup: metadata goes into a meta_latch, then into
  -- a collector and finally into the output_latch. this architecture makes sure that one packet can be processed onto the
  -- input while the output stream is still in process. this makes it possible to archive full throughput.
  -- 
  -- # meta_latch
  -- metadata is pulsed in here. each metadata stream of them has a separate meta_latch. this latch keeps the data until
  -- the collectors are ready to take them over.
  --
  -- # collector
  -- each external input also has a collector that read from the meta_latch. the collector keeps the data until every other
  -- has the data and the output_latch is ready.
  -- 
  -- # output_latch
  -- the sideband data must stay active during the stream. the packet latch is written once the collector has data
  -- and released on tlast. This means that the latch is busy during transfer of a packet on the output!
  for0 : for i in 0 to n - 1 generate
    signal meta_latch_valid, meta_latch_ready : std_logic;
    signal meta_latch_data                    : std_logic_vector(meta_width - 1 downto 0);
  begin
    meta_latch_inst : entity ds.reg generic map (
      width => meta_width
      ) port map (
        clk       => clk,
        rst       => rst,
        in_ready  => meta_ready_arr(i),
        in_valid  => meta_valid(i),
        in_data   => meta_data(i),
        out_ready => meta_latch_ready,
        out_valid => meta_latch_valid,
        out_data  => meta_latch_data
        );
    meta_latch_valid_arr(i) <= meta_latch_valid;
    collector_inst : entity ds.reg generic map (
      width => meta_width
      ) port map (
        clk       => clk,
        rst       => rst,
        in_valid  => meta_latch_valid,
        in_ready  => meta_latch_ready,
        in_data   => meta_latch_data,
        out_valid => latch_in_valid_arr(i),
        out_ready => latch_in_ready,
        out_data  => latch_in_data(user + (i + 1) * meta_width - 1 downto user + i * meta_width)
        );
  end generate;
  bl_user : block
    signal meta_latch_valid, meta_latch_ready : std_logic;
    signal meta_latch_data                    : std_logic_vector(user - 1 downto 0);
  begin
    meta_latch_inst : entity ds.reg generic map (
      width => user
      ) port map (
        clk       => clk,
        rst       => rst,
        in_ready  => user_ready,
        in_data   => in_user,
        in_valid  => in_first and in_valid and in_ready,
        out_ready => meta_latch_ready,
        out_valid => meta_latch_valid,
        out_data  => meta_latch_data
        );
    meta_latch_valid_arr(n) <= meta_latch_valid;
    collector_inst : entity ds.reg generic map (
      width => user
      ) port map (
        clk       => clk,
        rst       => rst,
        in_valid  => meta_latch_valid,
        in_ready  => meta_latch_ready,
        in_data   => meta_latch_data,
        out_valid => latch_in_valid_arr(n),
        out_ready => latch_in_ready,
        out_data  => latch_in_data(user - 1 downto 0)
        );
  end block;
  latch_in_ready <= latch_in_ready_x and and latch_in_valid_arr;
  output_latch_inst : entity ds.reg2 generic map (
    width => user + meta_width * n
    ) port map (
      clk       => clk,
      rst       => rst,
      in_valid  => and latch_in_valid_arr,
      in_ready  => latch_in_ready_x,
      in_data   => latch_in_data,
      out_valid => latch_valid,
      out_ready => (out_ready and out_valid and out_last) or latch_drop,
      out_data  => out_user
      );
  out_valid  <= fifo_valid and latch_valid and not ignore;
  fifo_ready <= latch_valid and out_ready and not ignore;
end architecture;

