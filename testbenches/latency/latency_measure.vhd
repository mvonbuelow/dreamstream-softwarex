-------------------------------------------------------------------------------
-- latency_measure
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

entity latency_measure is
  generic (
    width: integer;
    nprepend: integer;
    prepend: std_logic_vector(nprepend - 1 downto 0);
    ncheck: integer;
    check_mask: std_logic_vector(ncheck - 1 downto 0);
    check_val: std_logic_vector(ncheck - 1 downto 0);
    packet_size: integer;
    freq: real;
    nsamples: integer;
    estimate: real
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

architecture latency_measure_arch of latency_measure is
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

  signal p_valid, p_last, p_err: std_logic;
  signal p_user: std_logic_vector(check_mask'length + 16 downto 0);
  signal p_idx: integer;
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
    in_valid => packet_valid,
    in_ready => packet_ready,

    out_valid => out_valid,
    out_ready => out_ready,
    out_data => out_data,
    out_last => out_last,
    out_keep => out_keep
  );
  parser_inst: entity ds.parser generic map (
    width => width,
    user => p_user'length - 1,
    check_mask => check_mask & x"f000"
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => in_valid,
    in_data => in_data,
    in_last => in_last,
    in_keep => in_keep,
    in_ready => in_ready,
    out_valid => p_valid,
    out_last => p_last,
    out_ready => '1',
    out_user => p_user,
    check_val => check_val & x"0000"
  );
  p_err <= p_user(p_user'left);
  p_idx <= to_integer(unsigned(p_user(15 downto 0)));

  bl_ctrl: block
    type state_s_t is (INITWAIT, SEND_WAIT, SEND);
    type state_r_t is (WAITPACKET, WAITEND);
    signal state_s: state_s_t := INITWAIT;
    signal state_r: state_r_t := WAITPACKET;
    signal timer, end_time, waittimer: integer := 0;

    signal start_time_array: integer_array(0 to 127);
    signal idx_r, n: integer := 0;
    signal s: real := 0.0;
  begin
    packet_valid <= '1' when state_s = SEND or state_s = SEND_WAIT else '0';
    proc_send: process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          state_s <= INITWAIT;
          timer <= 0;
          waittimer <= 0;
          idx <= 0;
        else
          waittimer <= waittimer + 1;
          timer <= timer + 1;
          case state_s is
            when INITWAIT =>
              if waittimer > 2000 * 8 / width + (idx mod 64) then
                state_s <= SEND_WAIT;
              end if;
            when SEND_WAIT =>
              if out_valid = '1' then
                start_time_array(idx) <= timer;
                state_s <= SEND;
              end if;
              if packet_valid = '1' and packet_ready = '1' then
                state_s <= INITWAIT;
                idx <= (idx + 1) mod 128;
                waittimer <= 0;
              end if;
            when SEND =>
              if packet_valid = '1' and packet_ready = '1' then
                state_s <= INITWAIT;
                idx <= (idx + 1) mod 128;
                waittimer <= 0;
              end if;
            end case;
        end if;
      end if;
    end process;
    proc_recv: process(clk)
      variable dt: real;
    begin
      if rising_edge(clk) then
        if rst = '1' then
          state_r <= WAITPACKET;
          n <= 0;
          s <= 0.0;
          idx_r <= 0;
        else
          case state_r is
            when WAITPACKET =>
              if in_valid = '1' then
                end_time <= timer;
                state_r <= WAITEND;
              end if;
            when WAITEND =>
              if p_valid = '1' and p_last = '1' then
                state_r <= WAITPACKET;
                if p_err = '0' then
                  report "Packet idx: " & to_string(p_idx) & " ridx: " & to_string(idx_r);
                  assert p_idx = idx_r report "Index incorrect" severity failure;
                  dt := real(end_time - start_time_array(idx_r)) * (1000.0 / freq);
                  report "Latency: " & to_string(dt) & " ns; Estimate: " & to_string(estimate);
                  assert abs (dt - estimate) <= estimate * 0.5 report "Latency is > %50 away from estimate." severity failure;
                  idx_r <= (idx_r + 1) mod 128;
                  if n = nsamples then
                    report "Average: " & to_string(s / real(n)) & " ns";
                    finished <= '1';
                  end if;
                  n <= n + 1;
                  s <= s + dt;
                end if;
              end if;
            end case;
        end if;
      end if;
    end process;
  end block;
end architecture;

