-------------------------------------------------------------------------------
-- resizer
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Packs multiple words from a smaller stream to a bigger stream.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;

entity resizer is
  generic (
    width     : integer := 32;
    out_width : integer := 64;
    user      : integer := 1
    );
  port (
    clk : in std_logic;
    rst : in std_logic := '0';

    in_data  : in  std_logic_vector(width - 1 downto 0);
    in_keep  : in  std_logic_vector(width / 8 - 1 downto 0) := (others => '1');
    in_valid : in  std_logic;  -- WARNING: we assume that the input keeps stable until we signaled in_ready!
    in_ready : out std_logic;
    in_last  : in  std_logic;
    in_user  : in  std_logic_vector(user - 1 downto 0)      := (others => '0');

    out_data  : out std_logic_vector(out_width - 1 downto 0);
    out_keep  : out std_logic_vector(out_width / 8 - 1 downto 0);
    out_valid : out std_logic;
    out_ready : in  std_logic;
    out_last  : out std_logic;
    out_user  : out std_logic_vector(user - 1 downto 0)
    );
end entity;

architecture resizer_arch of resizer is
begin
  if0 : if out_width < width generate
    serializer_inst : entity ds.serializer generic map (
      width     => width,
      out_width => out_width,
      user      => user
      ) port map (
        clk       => clk,
        rst       => rst,
        in_valid  => in_valid,
        in_ready  => in_ready,
        in_data   => in_data,
        in_keep   => in_keep,
        in_last   => in_last,
        in_user   => in_user,
        out_valid => out_valid,
        out_ready => out_ready,
        out_data  => out_data,
        out_keep  => out_keep,
        out_last  => out_last,
        out_user  => out_user
        );
  else generate
    packer_inst : entity ds.packer generic map (
      width      => width,
      out_width  => out_width,
      user       => user,
      scale_user => false
      ) port map (
        clk       => clk,
        rst       => rst,
        in_valid  => in_valid,
        in_ready  => in_ready,
        in_data   => in_data,
        in_keep   => in_keep,
        in_last   => in_last,
        in_user   => in_user,
        out_valid => out_valid,
        out_ready => out_ready,
        out_data  => out_data,
        out_keep  => out_keep,
        out_last  => out_last,
        out_user  => out_user
        );
  end generate;
end;
