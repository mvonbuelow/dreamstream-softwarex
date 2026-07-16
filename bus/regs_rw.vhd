-------------------------------------------------------------------------------
-- regs_rw
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsbus
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This is a basic storage for a set of registers. It has
--              configuration that allows making it read-only (ro) or self-
--              clearing (shot). If you need arbitrary combinations of them,
--              just put a crossbar in front of it and do whatever you want.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;
library dsbus;
use dsbus.types.all;

entity regs_rw is
  generic (
    n: integer := 8;
    addr_off: integer := 0;
    addr_len: integer := 1;
    reg_defaults: std_logic_vector_array(0 to n - 1)(31 downto 0) := (others => (others => '0'));
    shot: boolean := false;
    ro: boolean := false
  );
  port (
    clk: in std_logic;
    rst: in std_logic;

    reg: view axi4l_mngr_v;

    rd_req, rd_ack: out std_logic_vector(n - 1 downto 0);
    rd_done: in std_logic_vector(n - 1 downto 0) := (others => '1');

    wr_req, wr_ack: out std_logic_vector(n - 1 downto 0) := (others => '0');
    wr_done: in std_logic_vector(n - 1 downto 0) := (others => '1');

    regs_out: out std_logic_vector_array(0 to n - 1)(31 downto 0) := reg_defaults;
    regs_in: in std_logic_vector_array(0 to n - 1)(31 downto 0) := (others => (others => '0'))
  );
end entity;

architecture regs_rw_arch of regs_rw is
  signal subs: axi4l_array_t(0 to n - 1)(
    awaddr(reg.awaddr'range),
    wdata(reg.wdata'range),
    araddr(reg.araddr'range),
    rdata(reg.rdata'range)
  ) := (others => axi4l_default(reg.araddr'length, reg.rdata'length));
begin
  crossbar_inst: entity dsbus.crossbar generic map (
    -- w        => n,
    addr_off => addr_off,
    addr_len => addr_len
  ) port map (
    clk => clk,
    rst => rst,
    mngr => reg,
    subs => subs
  );
  genrd: for i in 0 to n - 1 generate
    subs(i).rdata <= regs_in(i);
    subs(i).rvalid <= rd_done(i); -- all registers are always valid
    rd_ack(i) <= subs(i).rready;
    rd_req(i) <= subs(i).arvalid;
    subs(i).arready <= '1'; -- don't care about the address; handled by crossbar
    subs(i).rresp <= "00"; -- register accesses are always successfull unless addresses are okay

  end generate;

  ifrw: if not ro generate
    genwr: for i in 0 to n - 1 generate
      subs(i).awready <= '1';
      subs(i).wready <= '1';
      subs(i).bvalid <= wr_done(i);
      wr_ack(i) <= subs(i).bready;
      wr_req(i) <= subs(i).wvalid;
      subs(i).bresp <= "00";
    end generate;

    gen_write: for i in regs_out'range generate
      signal reg_next: std_logic_vector(31 downto 0);
      signal clear: boolean := false;
    begin
      reg_next <= subs(i).wdata when not (clear and shot) else (others => '0');
      regs_out(i) <= reg_next when rising_edge(clk) and (subs(i).wvalid = '1' or (clear and shot));

      clear <= (subs(i).wvalid = '1' and not clear) when rising_edge(clk) and (subs(i).wvalid = '1' or clear);
    end generate;
  else generate
    genwr: for i in 0 to n - 1 generate
      subs(i).awready <= '1';
      subs(i).wready <= '1';
      subs(i).bvalid <= '1';
      subs(i).bresp <= "11";
    end generate;
  end generate;
end architecture;
