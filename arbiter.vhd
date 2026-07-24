-------------------------------------------------------------------------------
-- arbiter
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This is a AXIS arbiter. It uses round-robin strategy to
--              multiplex streams.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;

entity arbiter is
  generic (
    width: integer;
    n: integer;
    user: integer := 1;
    include_reg: boolean := false
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    in_data: in std_logic_vector_array(0 to n - 1)(width - 1 downto 0);
    in_keep: in std_logic_vector_array(0 to n - 1)(width / 8 - 1 downto 0) := (others => (others => '0'));
    in_valid: in std_logic_vector(n - 1 downto 0) := (others => '1');
    in_ready: out std_logic_vector(n - 1 downto 0);
    in_last: in std_logic_vector(n - 1 downto 0) := (others => '0');
    in_user: in std_logic_vector_array(0 to n - 1)(user - 1 downto 0) := (others => (others => '0'));

    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_valid: out std_logic;
    out_ready: in std_logic;
    out_last: out std_logic;
    out_user: out std_logic_vector(user - 1 downto 0)
  );
end entity;


architecture arbiter_arch of arbiter is
  signal out_x_ready, out_x_valid, out_x_last: std_logic;
  signal out_x_data: std_logic_vector(out_data'range);
  signal out_x_keep: std_logic_vector(out_keep'range);
  signal out_x_user: std_logic_vector(out_user'range);
  signal sel, sel_next: unsigned(integer(ceil(log2(real(n)))) - 1 downto 0) := (others => '0');
  type state_t is (IDLE, FWD);
  signal state: state_t := IDLE;
  signal out_x_valid_next: std_logic;
begin
  treemux_inst: entity ds.treemux generic map (
    n => n,
    width => width,
    user => user
  ) port map (
    in_data => in_data,
    in_keep => in_keep,
    in_valid => in_valid,
    in_last => in_last,
    in_user => in_user,
    out_data => out_x_data,
    out_keep => out_x_keep,
    out_valid => out_x_valid,
    out_last => out_x_last,
    out_user => out_x_user,
    sel => sel
  );
  treemux_next_inst: entity ds.treemux generic map (
    n => n,
    width => width,
    user => user
  ) port map (
    in_valid => in_valid,
    out_valid => out_x_valid_next,
    sel => sel_next
  );

  readygen: for i in 0 to n - 1 generate
    in_ready(i) <= '1' when out_x_ready = '1' and sel = i else '0';
  end generate;

  rr_proc: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= IDLE;
        sel <= (others => '0');
      else
        case state is
          when IDLE =>
            if out_x_valid = '0' or (out_x_ready = '1' and out_x_last = '1') then -- try next channel if cur channel not valid; if cur channel valid and last (one byte in packet) also increment here
              sel <= sel_next;
            else
              state <= FWD;
            end if;
          when FWD =>
            if out_x_valid = '1' and out_x_last = '1' and out_x_ready = '1' then
              state <= IDLE;
              if n /= 2 or out_x_valid_next /= '0' then
                sel <= sel_next;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;
  sel_next <= sel + 1 when sel /= n - 1 else (others => '0');
  if0: if include_reg generate
    reg_inst: entity ds.reg generic map (
      width => out_data'length,
      user => out_user'length
    ) port map (
      clk => clk,
      rst => rst,
      in_ready => out_x_ready,
      in_valid => out_x_valid,
      in_data => out_x_data,
      in_last => out_x_last,
      in_keep => out_x_keep,
      in_user => out_x_user,
      out_ready => out_ready,
      out_valid => out_valid,
      out_data => out_data,
      out_last => out_last,
      out_keep => out_keep,
      out_user => out_user
    );
  else generate
    out_x_ready <= out_ready;
    out_valid <= out_x_valid;
    out_data <= out_x_data;
    out_last <= out_x_last;
    out_keep <= out_x_keep;
    out_user <= out_x_user;
  end generate;
end architecture;
