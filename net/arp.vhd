-------------------------------------------------------------------------------
-- arp
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: ARP protocol.
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

entity arp is
  generic (
    width: integer := 64
  );
  port (
    clk: in std_logic;
    rst: in std_logic;

    in_ready: out std_logic;
    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_last: in std_logic;
    in_id: in std_logic_vector(47 downto 0);

    out_ready: in std_logic;
    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_last: out std_logic;
    out_dest: out std_logic_vector(47 downto 0);
    out_user: out std_logic_vector(15 downto 0);

    my_id: in std_logic_vector(79 downto 0)
  );
end;



architecture net_arp_arch of arp is
  signal out_x_ready, out_x_valid, out_x_last: std_logic;
  signal out_x_data: std_logic_vector(out_data'range);
  signal out_x_keep: std_logic_vector(out_keep'range);
  signal out_x_dest: std_logic_vector(out_dest'range);
  signal out_x_user: std_logic_vector(out_user'range);

  signal parsed_valid, parsed_last, parsed_ready, composer_valid, composer_ready: std_logic;
  signal parsed_user: std_logic_vector(7 * 32 - 1 downto 0);
  signal composer_user: std_logic_vector(parsed_user'length - 1 downto 0);

  type state_t is (REQ, RES);
  signal state: state_t := REQ;
  signal dest: std_logic_vector(79 downto 0);
begin
  parser_inst: entity ds.parser generic map (
    width => width,
    user => composer_user'length,
    check_mask => x"ffffffff" & x"ffffffff" & x"00000000" & x"00000000" & x"00000000" & x"00000000" & x"ffffffff",
    absorb_on_error => true
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => in_valid,
    in_data => in_data,
    in_last => in_last,
    in_keep => in_keep,
    in_ready => in_ready,
    out_valid => parsed_valid,
    out_ready => parsed_ready,
    out_user => parsed_user,
    out_last => parsed_last,
    check_val => x"00010800" & x"06040001" & x"00000000" & x"00000000" & x"00000000" & x"00000000" & my_id(31 downto 0)
  );

  parsed_ready <= '1' when state = REQ else '0';
  proc_fsm: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= REQ;
      else
        case state is
          when REQ =>
            if parsed_valid = '1' and parsed_last = '1' then
              state <= RES;
              dest <= parsed_user(159 downto 80);
            end if;
          when RES =>
            if composer_ready = '1' then
              state <= REQ;
            end if;
          end case;
      end if;
    end if;
  end process;
  composer_valid <= '1' when state = RES else '0';

  composer_user <= x"00010800" & x"06040002" & my_id & dest;
  composer_inst: entity ds.composer generic map (
    width => width,
    user => composer_user'length + 144
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => composer_valid,
    in_ready => composer_ready,
    in_user => composer_user & x"00000000_00000000_00000000_00000000_0000",
    out_valid => out_x_valid,
    out_data => out_x_data,
    out_last => out_x_last,
    out_ready => out_x_ready,
    out_keep => out_x_keep
  );
  out_x_dest <= dest(dest'left downto dest'left - 47);
  out_x_user <= x"0806";

  reg_inst: entity ds.reg generic map (
    width => out_data'length,
    user => out_user'length,
    dest => out_dest'length
  ) port map (
    clk => clk,
    rst => rst,
    in_ready => out_x_ready,
    in_valid => out_x_valid,
    in_data => out_x_data,
    in_last => out_x_last,
    in_keep => out_x_keep,
    in_user => out_x_user,
    in_dest => out_x_dest,
    out_ready => out_ready,
    out_valid => out_valid,
    out_data => out_data,
    out_last => out_last,
    out_keep => out_keep,
    out_user => out_user,
    out_dest => out_dest
  );
end architecture;
