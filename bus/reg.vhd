-------------------------------------------------------------------------------
-- reg
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsbus
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This is just a register you can put onto a AXI4L stream in
--              order to relax timing. It's just using the AXIS registers on
--              the internal AXI4L streams.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;

library dsbus;
use dsbus.types.all;

entity reg is
  port (
    clk, rst : in std_logic;

    mngr : view axi4l_mngr_v;
    sub  : view axi4l_sub_v
    );
end entity;

architecture reg_arch of reg is
begin
  reg0_inst : entity ds.reg2 generic map (
    width => mngr.rdata'length,
    user  => 2
    ) port map (
      clk       => clk,
      rst       => rst,
      in_ready  => sub.rready,
      in_valid  => sub.rvalid,
      in_data   => sub.rdata,
      in_user   => sub.rresp,
      out_ready => mngr.rready,
      out_valid => mngr.rvalid,
      out_data  => mngr.rdata,
      out_user  => mngr.rresp
      );
  reg1_inst : entity ds.reg2 generic map (
    width => mngr.araddr'length
    ) port map (
      clk       => clk,
      rst       => rst,
      in_ready  => mngr.arready,
      in_valid  => mngr.arvalid,
      in_data   => mngr.araddr,
      out_ready => sub.arready,
      out_valid => sub.arvalid,
      out_data  => sub.araddr
      );
  reg2_inst : entity ds.reg2 generic map (
    width => mngr.wdata'length
    ) port map (
      clk       => clk,
      rst       => rst,
      in_ready  => mngr.wready,
      in_valid  => mngr.wvalid,
      in_data   => mngr.wdata,
      out_ready => sub.wready,
      out_valid => sub.wvalid,
      out_data  => sub.wdata
      );
  reg3_inst : entity ds.reg2 generic map (
    width => mngr.awaddr'length
    ) port map (
      clk       => clk,
      rst       => rst,
      in_ready  => mngr.awready,
      in_valid  => mngr.awvalid,
      in_data   => mngr.awaddr,
      out_ready => sub.awready,
      out_valid => sub.awvalid,
      out_data  => sub.awaddr
      );
  reg4_inst : entity ds.reg2 generic map (
    width => 2
    ) port map (
      clk       => clk,
      rst       => rst,
      in_ready  => sub.bready,
      in_valid  => sub.bvalid,
      in_data   => sub.bresp,
      out_ready => mngr.bready,
      out_valid => mngr.bvalid,
      out_data  => mngr.bresp
      );
end architecture;
