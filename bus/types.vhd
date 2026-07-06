-------------------------------------------------------------------------------
-- types
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsbus
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: The AXI4L records.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package types is
  type axi4l_t is record
    awaddr  : std_logic_vector;
    awvalid : std_logic;
    awready : std_logic;

    wdata  : std_logic_vector;
    wvalid : std_logic;
    wready : std_logic;

    bresp  : std_logic_vector(1 downto 0);
    bvalid : std_logic;
    bready : std_logic;

    araddr  : std_logic_vector;
    arvalid : std_logic;
    arready : std_logic;

    rdata  : std_logic_vector;
    rvalid : std_logic;
    rready : std_logic;
    rresp  : std_logic_vector(1 downto 0);
  end record;

  view axi4l_mngr_v of axi4l_t is
    awaddr : in;
  awvalid : in;
  awready : out;

  wdata  : in;
  wvalid : in;
  wready : out;

  bresp  : out;
  bvalid : out;
  bready : in;

  araddr  : in;
  arvalid : in;
  arready : out;

  rdata  : out;
  rvalid : out;
  rready : in;
  rresp  : out;
end view axi4l_mngr_v;
view axi4l_sub_v of axi4l_t is
  awaddr : out;
awvalid : out;
awready : in;

wdata  : out;
wvalid : out;
wready : in;

bresp  : in;
bvalid : in;
bready : out;

araddr  : out;
arvalid : out;
arready : in;

rdata  : in;
rvalid : in;
rready : out;
rresp  : in;
end view axi4l_sub_v;

type axi4l_array_t is array (natural range <>) of axi4l_t;

subtype axi4l_a16_d32_t is axi4l_t (
  awaddr(15 downto 0),
  wdata(31 downto 0),
  araddr(15 downto 0),
  rdata(31 downto 0)
  );
subtype axi4l_a32_d32_t is axi4l_t (
  awaddr(31 downto 0),
  wdata(31 downto 0),
  araddr(31 downto 0),
  rdata(31 downto 0)
  );
function axi4l_default(addr_size : natural; data_size : natural) return axi4l_t;
end package;

package body types is
  function axi4l_default(addr_size : natural; data_size : natural) return axi4l_t is
  begin
    return (
      awaddr  => (addr_size - 1 downto 0 => '0'),
      awvalid => '0',
      awready => '1',
      wdata   => (data_size - 1 downto 0 => '0'),
      wvalid  => '0',
      wready  => '1',
      bresp   => "11",
      bvalid  => '1',
      bready  => '0',
      araddr  => (addr_size - 1 downto 0 => '0'),
      arvalid => '0',
      arready => '1',
      rdata   => (data_size - 1 downto 0 => '0'),
      rvalid  => '1',
      rready  => '0',
      rresp   => "11"
      );
  end function;
end package body;

