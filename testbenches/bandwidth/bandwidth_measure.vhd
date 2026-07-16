-------------------------------------------------------------------------------
-- bandwidth_measure
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: A helper to measure latencies of an AXIS module.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
library dsnet;
library dsbus;

use ds.types.all;
use dsbus.types.all;

entity bandwidth_measure is
  generic (
    width: integer;
    nprepend: integer;
    prepend: std_logic_vector(nprepend - 1 downto 0);
    packet_size: integer;
    freq: real;
    estimate: real;
    direction_in: boolean
  );
  port (
    clk, rst: in std_logic;

    out_valid: out std_logic;
    out_ready: in std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_last: out std_logic;

    in_valid: in std_logic;
    in_ready: out std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_last: in std_logic;

    finished: out std_logic := '0'
  );
end;

architecture bandwidth_measure_arch of bandwidth_measure is
  signal mngr: axi4l_t(
    awaddr(31 downto 0),
    wdata(31 downto 0),
    araddr(31 downto 0),
    rdata(31 downto 0)
  ) := axi4l_default(32, 32);

  constant total_packet_size: integer := packet_size + nprepend / 8;

  signal idx: integer := 0;
  signal packet_data: std_logic_vector(2048 * 8 - 1 downto 0) := (others => '0');
  constant packet_keep_ones: std_logic_vector(total_packet_size - 1 downto 0) := (others => '1');
  constant packet_keep_zeros: std_logic_vector(packet_data'length / 8 - total_packet_size - 1 downto 0) := (others => '0');
  signal packet_keep: std_logic_vector(2047 downto 0) := packet_keep_ones & packet_keep_zeros;

  signal packet_ready, packet_valid: std_logic;
  signal word_valid: std_logic;

  function popcnt(v: std_logic_vector) return natural is
    variable cnt: integer := 0;
  begin
    for i in v'range loop
      if v(i) = '1' then
        cnt := cnt + 1;
      end if;
    end loop;
    return cnt;
  end function;
  signal pc: integer;
begin
  packet_data(packet_data'left downto packet_data'left - 15 - prepend'length) <= prepend & std_logic_vector(to_unsigned(idx, 16));

  traffic_gen_inst: entity ds.resizer generic map (
    width => packet_data'length,
    out_width => width
  ) port map (
    clk => clk,
    rst => rst,

    in_data => packet_data,
    in_keep => packet_keep,
    in_last => '1',
    in_valid => '1',

    out_valid => out_valid,
    out_ready => out_ready,
    out_data => out_data,
    out_last => out_last,
    out_keep => out_keep
  );
  in_ready <= '1';

  word_valid <= in_valid and in_ready when direction_in else out_valid and out_ready;
  pc <= popcnt(in_keep) when direction_in else popcnt(out_keep);

  bl_ctrl: block
    type state_r_t is (TIMEOUT, MEASURE);
    signal state_r: state_r_t := TIMEOUT;
    signal timer, start_time, waittimer: integer := 0;

    signal nvalid: integer := 0;
  begin
    proc_recv: process(clk)
      variable dt: real;
    begin
      if rising_edge(clk) then
        if rst = '1' then
          state_r <= TIMEOUT;
          waittimer <= 0;
          timer <= 0;
          nvalid <= 0;
        else
          timer <= timer + 1;
          case state_r is
            when TIMEOUT =>
              waittimer <= waittimer + 1;
              if waittimer = 5000 then
                state_r <= MEASURE;
                start_time <= timer;
              end if;
            when MEASURE =>
              if word_valid = '1' then
                nvalid <= nvalid + pc;
              end if;
              dt := real(timer - start_time);
              if dt >= 50000.0 then
                report "Bandwidth: " & to_string(real(nvalid * 8) / (dt * 1000.0 / freq)); -- bits per ns == Mb/s
                finished <= '1';
              end if;
            end case;
        end if;
      end if;
    end process;
  end block;
end architecture;

