-------------------------------------------------------------------------------
-- packer
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

entity packer is
  generic (
    width: integer := 32;
    out_width: integer := 64;
    user: integer := 1;
    scale_user: boolean := true
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0) := (others => '1');
    in_valid: in std_logic; -- WARNING: we assume that the input keeps stable until we signaled in_ready!
    in_ready: out std_logic;
    in_last: in std_logic;
    in_user: in std_logic_vector(user - 1 downto 0) := (others => '0');

    out_data: out std_logic_vector(out_width - 1 downto 0);
    out_keep: out std_logic_vector(out_width / width * (width / 8) - 1 downto 0);
    out_valid: out std_logic;
    out_ready: in std_logic;
    out_last: out std_logic;
    out_user: out std_logic_vector(ite_i(scale_user, out_width / width * user, user) - 1 downto 0)
  );
end entity;

architecture packer_arch of packer is
  signal reg_data: std_logic_vector(in_data'range) := (others => '0');
  signal reg_keep: std_logic_vector(in_keep'range) := (others => '0');
  signal reg_last: std_logic := '0';
  signal reg_user: std_logic_vector(in_user'range) := (others => '0');
  type state_t is (S0, S1, S2);
  signal state: state_t := S0;
  constant nokeep: std_logic_vector(in_keep'range) := (others => '0');
  signal tmp_valid, tmp_ready, tmp_last: std_logic;
  signal tmp_data: std_logic_vector(width * 2 - 1 downto 0);
  signal tmp_keep: std_logic_vector(width / 4 - 1 downto 0);
  signal tmp_user: std_logic_vector(ite_i(scale_user, user * 2, user) - 1 downto 0);
begin
  -- I just implemented a two-to-one packer and do it recursively
  if0: if width = out_width generate
    out_data <= in_data;
    out_keep <= in_keep;
    out_last <= in_last;
    out_valid <= in_valid;
    out_user <= in_user;
    in_ready <= out_ready;
    elsif width * 2 /= out_width generate
      packer_inst: entity ds.packer generic map (
        width => width,
        out_width => width * 2,
        user => user,
        scale_user => scale_user
      ) port map (
        clk => clk,
        rst => rst,
        in_data => in_data,
        in_keep => in_keep,
        in_valid => in_valid,
        in_ready => in_ready,
        in_last => in_last,
        in_user => in_user,
        out_data => tmp_data,
        out_keep => tmp_keep,
        out_valid => tmp_valid,
        out_ready => tmp_ready,
        out_last => tmp_last,
        out_user => tmp_user
      );
    packer_inst2: entity ds.packer generic map (
      width => width * 2,
      out_width => out_width,
      user => ite_i(scale_user, user * 2, user),
      scale_user => scale_user
    ) port map (
      clk => clk,
      rst => rst,
      in_data => tmp_data,
      in_keep => tmp_keep,
      in_valid => tmp_valid,
      in_ready => tmp_ready,
      in_last => tmp_last,
      in_user => tmp_user,
      out_data => out_data,
      out_keep => out_keep,
      out_valid => out_valid,
      out_ready => out_ready,
      out_last => out_last,
      out_user => out_user
    );
  else generate
    proc: process(clk)
    begin
      if rising_edge(clk) then
        if state = S0 then
          if in_valid = '1' then
            reg_data <= in_data;
            reg_keep <= in_keep;
            reg_last <= in_last;
            reg_user <= in_user;
            if in_last = '0' then
              state <= S1;
            else
              state <= S2;
            end if;
          end if;
        elsif state = S1 then
          if in_valid = '1' and out_ready = '1' then
            state <= S0;
          end if;
        else
          if out_ready = '1' then
            state <= S0;
          end if;
        end if;

        if rst = '1' then
          state <= S0;
        end if;
      end if;
    end process;
    in_ready <= '1' when state = S0 or (state = S1 and out_ready = '1') else '0';
    out_valid <= '1' when (state = S1 and in_valid = '1') or (state = S2) else '0';
    out_data <= reg_data & in_data;
    out_keep <= reg_keep & in_keep when state /= S2 else reg_keep & nokeep;
    out_last <= reg_last or in_last;
    ifscale: if scale_user generate
      out_user <= reg_user & in_user;
    else generate
      out_user <= in_user;
    end generate;
  end generate;
end;
