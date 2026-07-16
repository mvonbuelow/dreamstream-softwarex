-------------------------------------------------------------------------------
-- connect
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsbus
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This is boring. Just connects two AXI4L streams because its
--              not trivial with the records.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library dsbus;
use dsbus.types.all;

entity connect is
  port (
    mngr: view axi4l_mngr_v;
    sub: view axi4l_sub_v
  );
end entity;

architecture connect_arch of connect is
begin
  mngr.rvalid <= sub.rvalid;
  mngr.rdata <= sub.rdata;
  mngr.rresp <= sub.rresp;
  sub.rready <= mngr.rready;

  sub.arvalid <= mngr.arvalid;
  sub.araddr <= mngr.araddr;
  mngr.arready <= sub.arready;

  sub.wvalid <= mngr.wvalid;
  sub.wdata <= mngr.wdata;
  mngr.wready <= sub.wready;

  sub.awvalid <= mngr.awvalid;
  sub.awaddr <= mngr.awaddr;
  mngr.awready <= sub.awready;

  mngr.bvalid <= sub.bvalid;
  mngr.bresp <= sub.bresp;
  sub.bready <= mngr.bready;
end architecture;
