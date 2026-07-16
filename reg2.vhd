-------------------------------------------------------------------------------
-- reg2
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Double-register (ready signal also registered) implementing
--              the AXI-Stream handshake.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

entity reg2 is
  generic (
    width: natural;
    user: natural := 0;
    dest: natural := 0;
    id: natural := 0
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    in_ready: out std_logic;
    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_last: in std_logic := '0';
    in_keep: in std_logic_vector( (width + 7) / 8 - 1 downto 0) := (others => '1');
    in_user: in std_logic_vector(user - 1 downto 0) := (others => '0');
    in_dest: in std_logic_vector(dest - 1 downto 0) := (others => '0');
    in_id: in std_logic_vector(id - 1 downto 0) := (others => '0');

    out_ready: in std_logic;
    out_valid: out std_logic := '0';
    out_data: out std_logic_vector(width - 1 downto 0) := (others => '0');
    out_last: out std_logic := '0';
    out_keep: out std_logic_vector( (width + 7) / 8 - 1 downto 0) := (others => '1');
    out_user: out std_logic_vector(user - 1 downto 0) := (others => '0');
    out_dest: out std_logic_vector(dest - 1 downto 0) := (others => '0');
    out_id: out std_logic_vector(id - 1 downto 0) := (others => '0')
  );
end;


architecture reg2_arch of reg2 is
  signal reg1_data, reg2_data: std_logic_vector(in_data'range) := (others => '0');
  signal reg1_keep, reg2_keep: std_logic_vector(in_keep'range) := (others => '0');
  signal reg1_last, reg2_last: std_logic := '0';
  signal reg1_user, reg2_user: std_logic_vector(in_user'range) := (others => '0');
  signal reg1_dest, reg2_dest: std_logic_vector(in_dest'range) := (others => '0');
  signal reg1_id, reg2_id: std_logic_vector(in_id'range) := (others => '0');
  signal out_valid_i: std_logic;
  signal reg1_valid, reg2_valid: std_logic := '0';
begin
  out_valid <= out_valid_i;

  proc_reg: process(clk)
    variable reg2_data_var: std_logic_vector(in_data'range);
    variable reg2_keep_var: std_logic_vector(in_keep'range);
    variable reg2_last_var: std_logic;
    variable reg2_valid_var: std_logic;
    variable reg2_user_var: std_logic_vector(in_user'range);
    variable reg2_dest_var: std_logic_vector(in_dest'range);
    variable reg2_id_var: std_logic_vector(in_id'range);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        reg1_data <= (others => '0');
        reg2_data <= (others => '0');
        reg1_keep <= (others => '0');
        reg2_keep <= (others => '0');
        reg1_user <= (others => '0');
        reg2_user <= (others => '0');
        reg1_dest <= (others => '0');
        reg2_dest <= (others => '0');
        reg1_id <= (others => '0');
        reg2_id <= (others => '0');
        reg1_last <= '0';
        reg2_last <= '0';
        reg1_valid <= '0';
        reg2_valid <= '0';
      else
        reg2_data_var := reg2_data;
        reg2_keep_var := reg2_keep;
        reg2_last_var := reg2_last;
        reg2_valid_var := reg2_valid;
        reg2_user_var := reg2_user;
        reg2_dest_var := reg2_dest;
        reg2_id_var := reg2_id;
        if in_valid = '1' then
          if reg1_valid = '0' then
            reg1_data <= in_data;
            reg1_keep <= in_keep;
            reg1_last <= in_last;
            reg1_valid <= '1';
            reg1_user <= in_user;
            reg1_dest <= in_dest;
            reg1_id <= in_id;
          elsif reg2_valid = '0' then
            reg2_data_var := in_data;
            reg2_keep_var := in_keep;
            reg2_last_var := in_last;
            reg2_valid_var := '1';
            reg2_user_var := in_user;
            reg2_dest_var := in_dest;
            reg2_id_var := in_id;
          end if;
        end if;
        if out_ready = '1' and out_valid_i = '1' then
          if reg2_valid_var = '1' then
            reg2_valid_var := '0';
            reg1_data <= reg2_data_var;
            reg1_keep <= reg2_keep_var;
            reg1_last <= reg2_last_var;
            reg1_user <= reg2_user_var;
            reg1_dest <= reg2_dest_var;
            reg1_id <= reg2_id_var;
          else
            reg1_valid <= '0';
          end if;
        end if;
        reg2_data <= reg2_data_var;
        reg2_keep <= reg2_keep_var;
        reg2_last <= reg2_last_var;
        reg2_valid <= reg2_valid_var;
        reg2_user <= reg2_user_var;
        reg2_dest <= reg2_dest_var;
        reg2_id <= reg2_id_var;
      end if;
    end if;
  end process;
  out_data <= reg1_data;
  out_keep <= reg1_keep;
  out_last <= reg1_last;
  out_user <= reg1_user;
  out_dest <= reg1_dest;
  out_id <= reg1_id;
  in_ready <= not reg1_valid or not reg2_valid;
  out_valid_i <= reg1_valid;
end architecture;
