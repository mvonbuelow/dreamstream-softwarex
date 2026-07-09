-------------------------------------------------------------------------------
-- sync_fifo
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: TODO
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;

entity sync_fifo is
  generic (
    width                 : integer;
    depth                 : integer;
    almost_full_threshold : integer := 0;
    use_last              : boolean := false;
    packet_mode           : boolean := false;
    drop_packet           : boolean := false;
    max_packets           : integer := depth  -- every value is fine; the fifo will de-assert in-ready when we cannot count more packets
    );
  port (
    clk : in std_logic;
    rst : in std_logic := '0';

    in_ready : out std_logic;
    in_valid : in  std_logic;
    in_data  : in  std_logic_vector(width - 1 downto 0);
    in_last  : in  std_logic := '0';
    in_drop  : in  std_logic := '0';

    out_ready : in  std_logic;
    out_valid : out std_logic;
    out_data  : out std_logic_vector(width - 1 downto 0);
    out_last  : out std_logic;

    almost_full : out std_logic;
    cnt         : out integer range 0 to depth - 1
    );
end;


architecture sync_fifo_arch of sync_fifo is
  signal fifo_in_data, fifo_out_data : std_logic_vector(width + ite_i(use_last, 1, 0) - 1 downto 0);
  signal ram                         : std_logic_vector_array(0 to depth - 1)(fifo_in_data'range);
  signal head, packet_start, head_r  : unsigned(log2_ceil(depth - 1) - 1 downto 0)       := (others => '0');
  signal next_packet_idx             : unsigned(head'range)                              := (others => '0');
  signal tail, next_tail             : unsigned(head'range)                              := (others => '0');
  signal tailp1                      : unsigned(head'range)                              := to_unsigned(1, head'length);
  signal count                       : unsigned(head'range)                              := (others => '0');
  signal count_lasts                 : unsigned(log2_ceil(max_packets + 1) - 1 downto 0) := (others => '0');
  signal packet_last                 : std_logic;
begin
  cnt <= to_integer(count);

  packet_last <= in_last and in_valid and in_ready and not in_drop;

  proc_idx : process(clk)
    variable tail_inc, head_inc : boolean;
    variable inc                : unsigned(head'range);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        tail         <= (others => '0');
        tailp1       <= to_unsigned(1, tailp1'length);
        head         <= (others => '0');
        packet_start <= (others => '0');
        count        <= (others => '0');
        head_r       <= (others => '0');
      else
        head_r   <= head;
        head_inc := in_ready = '1' and in_valid = '1';
        tail_inc := out_ready = '1' and out_valid = '1';

        tail <= next_tail;
        if tail_inc then
          tailp1 <= tail + 2;  -- use this for next_tail, s.t. no adder is required for the reading address
        end if;
        if head_inc or in_drop = '1' then
          head <= packet_start when drop_packet and use_last and in_drop = '1' else head + 1;
        end if;
        if packet_last = '1' and drop_packet and use_last then
          packet_start <= head + 1;
        end if;
        if drop_packet and use_last then
          if tail_inc and in_drop = '1' then
            count <= packet_start - (tail + 1);
          elsif in_drop = '1' then
            count <= packet_start - tail;
          elsif tail_inc and head_inc then
          -- counter does not change
          elsif tail_inc then
            count <= head - (tail + 1);
          elsif head_inc then
            count <= head + 1 - tail;
          end if;
        else
          inc := to_unsigned(1, head'length) when head_inc and not tail_inc else
                                               (others => '1') when not head_inc and tail_inc else
                                                                 (others => '0');
          count <= count + inc;
        end if;
      end if;
    end if;
  end process;

  next_tail <= tailp1 when out_ready = '1' and out_valid = '1' else tail;

  iflast : if use_last generate
    fifo_in_data <= in_last & in_data;
    out_data     <= fifo_out_data(out_data'range);
    out_last     <= fifo_out_data(out_data'length);
    ifpack : if packet_mode generate
      proc_lasts : process(clk)
      begin
        if rising_edge(clk) then
          if rst = '1' then
            count_lasts <= (others => '0');
          elsif packet_last = '1' and out_valid = '1' and out_ready = '1' and out_last = '1' then
          elsif packet_last = '1' then
            count_lasts <= count_lasts + 1;
          elsif out_valid = '1' and out_ready = '1' and out_last = '1' then
            count_lasts <= count_lasts - 1;
          end if;
        end if;
      end process;
    end generate;
  else generate
    fifo_in_data <= in_data;
    out_data     <= fifo_out_data;
  end generate;
  proc_ram : process(clk)
  begin
    if rising_edge(clk) then
      ram(to_integer(head)) <= fifo_in_data;
      fifo_out_data         <= ram(to_integer(next_tail));
    end if;
  end process;

  in_ready    <= '1' when count < depth - 1 and count_lasts /= max_packets else '0';
  almost_full <= '1' when count >= almost_full_threshold                   else '0';

  out_valid <= '0' when
               (or (std_logic_vector(head_r) xor std_logic_vector(tail))) = '0' or
               (packet_mode and count_lasts = 0) else '1';
end architecture;

