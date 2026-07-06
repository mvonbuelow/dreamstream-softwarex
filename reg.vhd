-------------------------------------------------------------------------------
-- axi_reg
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Sigle-register (ready signal NOT registered) implementing
--              the AXI-Stream handshake.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

entity reg is
  generic (
    width      : natural;
    user       : natural := 0;
    dest       : natural := 0;
    id         : natural := 0;
    keep_width : natural := 8
    );
  port (
    clk : in std_logic;
    rst : in std_logic := '0';

    in_ready : out std_logic;
    in_valid : in  std_logic;
    in_data  : in  std_logic_vector(width - 1 downto 0);
    in_last  : in  std_logic                                                            := '0';
    in_keep  : in  std_logic_vector((width + keep_width - 1) / keep_width - 1 downto 0) := (others => '1');
    in_user  : in  std_logic_vector(user - 1 downto 0)                                  := (others => '0');
    in_dest  : in  std_logic_vector(dest - 1 downto 0)                                  := (others => '0');
    in_id    : in  std_logic_vector(id - 1 downto 0)                                    := (others => '0');

    out_ready : in  std_logic;
    out_valid : out std_logic                                                            := '0';
    out_data  : out std_logic_vector(width - 1 downto 0)                                 := (others => '0');
    out_last  : out std_logic                                                            := '0';
    out_keep  : out std_logic_vector((width + keep_width - 1) / keep_width - 1 downto 0) := (others => '1');
    out_user  : out std_logic_vector(user - 1 downto 0)                                  := (others => '0');
    out_dest  : out std_logic_vector(dest - 1 downto 0)                                  := (others => '0');
    out_id    : out std_logic_vector(id - 1 downto 0)                                    := (others => '0')
    );
end;

architecture reg_arch of reg is
begin
  proc_reg: process(clk) begin
    if rising_edge(clk) then
      if rst = '1' then
        out_valid <= '0';
      elsif in_ready = '1' then
        out_valid <= in_valid;
      end if;
      if in_ready = '1' then
        out_data <= in_data;
        out_last <= in_last;
        out_keep <= in_keep;
        out_user <= in_user;
        out_dest <= in_dest;
        out_id   <= in_id;
      end if;
    end if;
  end process;
  in_ready <= out_ready or not out_valid;
end architecture;
