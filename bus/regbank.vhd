-------------------------------------------------------------------------------
-- regbank
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsbus
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This is just a convenience module that integrates a RW and RO
--              register field and a crossbar for interconnection.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;
library dsbus;
use dsbus.types.all;

entity regbank is
  generic (
    nwregs        : integer                                              := 8;
    nrregs        : integer                                              := 8;
    addr_off      : integer                                              := 0;
    addr_len      : integer                                              := 1;
    wreg_addr_bit : integer                                              := 10;  -- if this bit is '1', rw-regs are selected instead of ro-regs
    wreg_defaults : std_logic_vector_array(0 to nwregs - 1)(31 downto 0) := (others => (others => '1'))
    );
  port (
    clk : in std_logic;
    rst : in std_logic;

    reg : view axi4l_mngr_v;

    wregs : out std_logic_vector_array(0 to nwregs - 1)(31 downto 0);
    rregs : in  std_logic_vector_array(0 to nrregs - 1)(31 downto 0)
    );
end entity;

architecture regbank_arch of regbank is
  signal subs : axi4l_array_t(0 to 1)(
    awaddr(reg.awaddr'range),
    wdata(reg.wdata'range),
    araddr(reg.araddr'range),
    rdata(reg.rdata'range)
    ) := (others => axi4l_default(reg.araddr'length, reg.rdata'length));
begin
  crossbar_inst : entity dsbus.crossbar generic map (
    addr_off => wreg_addr_bit,
    addr_len => 2
    ) port map (
      clk  => clk,
      rst  => rst,
      mngr => reg,
      subs => subs
      );
  regs_ro_inst : entity dsbus.regs_rw generic map (
    n        => nrregs,
    addr_off => addr_off,
    addr_len => addr_len,
    ro       => true
    ) port map (
      clk     => clk,
      rst     => rst,
      reg     => subs(0),
      regs_in => rregs
      );
  regs_rw_inst : entity dsbus.regs_rw generic map (
    n            => nwregs,
    addr_off     => addr_off,
    addr_len     => addr_len,
    reg_defaults => wreg_defaults
    ) port map (
      clk      => clk,
      rst      => rst,
      reg      => subs(1),
      regs_in  => wregs,
      regs_out => wregs
      );
end architecture;
