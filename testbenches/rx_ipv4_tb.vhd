-- use this command to run tests:
-- ghdl -a --std=08 --work=axi ../types.vhd ../treemux.vhd ../keep_shifter.vhd ../net/rx_ipv4.vhd rx_ipv4_tb.vhd && ghdl -e --std=08 --work=axi rx_ipv4_tb && ghdl -r --std=08 --work=axi rx_ipv4_tb --wave=test.ghw

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library dsnet;

entity rx_ipv4_tb is
end;

architecture rx_ipv4_tb_arch of rx_ipv4_tb is
  signal clk, clk_en: std_logic := '1';

  constant w: integer := 8;
  constant dw: integer := w * 8;
  constant clkp: time := 10 ns;

  signal in_valid, in_ready, in_last, out_valid, out_ready, out_last: std_logic := '0';
  signal in_keep, out_keep: std_logic_vector(w - 1 downto 0);
  signal in_data, out_data: std_logic_vector(dw - 1 downto 0);
  signal cur_test, cur_test_out: integer;
  signal in_id: std_logic_vector(47 downto 0) := (others => '0');
  signal out_id: std_logic_vector(79 downto 0);
  signal out_dest: std_logic_vector(31 downto 0);
  signal out_user: std_logic_vector(0 downto 0);
  signal actual_out_user: std_logic_vector(7 downto 0);
begin
  clk <= not clk and clk_en after clkp / 2;

  net_rx_ipv4_inst: entity dsnet.rx_ipv4 generic map (
    nprotos => 1,
    protos => (0 => x"11")
  ) port map (
    clk => clk,
    in_ready => in_ready,
    in_valid => in_valid,
    in_data => in_data,
    in_keep => in_keep,
    in_last => in_last,
    out_ready => out_ready,
    out_valid => out_valid,
    out_data => out_data,
    out_keep => out_keep,
    out_last => out_last,
    out_id => out_id,
    out_dest => out_dest,
    out_user(7 downto 0) => actual_out_user,
    out_user(8 downto 8) => out_user,
    in_id => in_id
  );

  process
  begin
    wait for clkp * 2;
    wait until rising_edge(clk);

    -- test 1: short frame
    cur_test <= 1;
    in_data <= x"4510001700000000";
    in_keep <= x"ff";
    in_valid <= '1';
    in_id <= x"0a0a00111234";
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"401166920A0A0011";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"0A0A001012345600";
    in_keep <= "11111110";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 2: longer frame
    cur_test <= 2;
    in_data <= x"4510001900010000";
    in_keep <= x"ff";
    in_valid <= '1';
    in_id <= x"0a0a00111234";
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"4011668f0A0A0011";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"0A0A001012345678";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"9000000000000000";
    in_keep <= "10000000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 3: 16 byte frame
    cur_test <= 3;
    in_data <= x"4510002400030000";
    in_keep <= x"ff";
    in_valid <= '1';
    in_id <= x"0a0a00111234";
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"401166820A0A0011";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"0A0A001012345678";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"90abcdef11223344";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"5566778811223344";
    in_keep <= "11110000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 4: empty frame
    cur_test <= 4;
    in_data <= x"4510001400070000";
    in_keep <= x"ff";
    in_valid <= '1';
    in_id <= x"0a0a00111234";
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"4011668e0A0A0011";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"0A0A001012345678";
    in_keep <= "11110000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    wait for clkp * 40;
    clk_en <= '0';


    wait;
  end process;

  process
  begin

    wait for clkp * 2;
    wait until rising_edge(clk);
    wait for 1 ns; -- make sure we read after the process above..

    report "test 1" severity note;
    cur_test_out <= 1;
    wait for clkp * 3;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = "11100000" and out_data(63 downto 40) = x"123456" and out_last = '1' and out_id(31 downto 0) = x"0A0A0011" and out_dest = x"0A0A0010" and out_user = "0" report "invalid output 1.1 " & to_string(out_keep) & " " & to_hex_string(out_data) & " " & to_hex_string(out_id) & " " & to_hex_string(out_dest) & " " & to_hex_string(out_user);
    wait for clkp;
    assert out_valid = '0' report "output still valid";
    out_ready <= '0';


    report "test 2" severity note;
    cur_test_out <= 2;
    wait for clkp * 3;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = "11111000" and out_data(63 downto 24) = x"1234567890" and out_last = '1' and out_id(31 downto 0) = x"0A0A0011" and out_dest = x"0A0A0010" and out_user = "0" report "invalid output 2.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";
    out_ready <= '0';


    report "test 3" severity note;
    cur_test_out <= 3;
    wait for clkp * 3;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = "11111111" and out_data = x"1234567890abcdef" and out_last = '0' and out_id(31 downto 0) = x"0A0A0011" and out_dest = x"0A0A0010" and out_user = "0" report "invalid output 3.1 " & to_string(out_keep) & " " & to_hex_string(out_data) & " " & to_hex_string(out_id) & " " & to_hex_string(out_dest) & " " & to_hex_string(out_user);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"1122334455667788" and out_last = '1' and out_id(31 downto 0) = x"0A0A0011" and out_dest = x"0A0A0010" and out_user = "0" report "invalid output 3.1 " & to_string(out_keep) & " " & to_hex_string(out_data) & " " & to_hex_string(out_id) & " " & to_hex_string(out_dest) & " " & to_hex_string(out_user);
    wait for clkp;
    assert out_valid = '0' report "output still valid";
    out_ready <= '0';

    report "test 4" severity note;
    cur_test_out <= 1;
    wait for clkp * 3;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = "00000000" and out_last = '1' and out_id(31 downto 0) = x"0A0A0011" and out_dest = x"0A0A0010" and out_user = "0" report "invalid output 4.1 " & to_string(out_keep) & " " & to_hex_string(out_data) & " " & to_hex_string(out_id) & " " & to_hex_string(out_dest) & " " & to_hex_string(out_user);
    wait for clkp;
    assert out_valid = '0' report "output still valid";
    out_ready <= '0';

    wait;
  end process;
end architecture;
