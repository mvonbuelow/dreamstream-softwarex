-- use this command to run tests:
-- ghdl -a --std=08 --work=axi ../types.vhd ../treemux.vhd ../keep_shifter.vhd keep_shifter_tb.vhd && ghdl -e --std=08 --work=axi keep_shifter_tb && ghdl -r --std=08 --work=axi keep_shifter_tb --wave=test.ghw

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

entity keep_shifter_tb is
end;

architecture keep_shifter_tb_arch of keep_shifter_tb is
  signal clk, clk_en: std_logic := '1';

  constant w: integer := 8;
  constant dw: integer := w * 8;
  constant clkp: time := 10 ns;

  signal in_valid, in_ready, in_last, out_valid, out_ready, out_last: std_logic := '0';
  signal in_keep, out_keep: std_logic_vector(w - 1 downto 0);
  signal in_data, out_data: std_logic_vector(dw - 1 downto 0);
  signal cur_test, cur_test_out: integer;
  signal fix_shift: boolean := true;
begin
  clk <= not clk and clk_en after clkp / 2;

  keep_shifter_inst: entity ds.keep_shifter generic map (width => w * 8, shift => 2) port map (
    clk => clk,
    in_data => in_data,
    in_keep => in_keep,
    in_valid => in_valid,
    in_last => in_last,
    in_ready => in_ready,
    out_data => out_data,
    out_valid => out_valid,
    out_ready => out_ready,
    out_last => out_last,
    out_keep => out_keep,
    fix_shift => fix_shift
  );

  fix_shift <= in_keep(in_keep'left) = '0';

  process
  begin
    wait for clkp * 2;
    wait until rising_edge(clk);

    -- test 1
    cur_test <= 1;
    in_data <= x"1234567890ab0123";
    in_keep <= "00000011"; -- WOW :o
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11110000";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 2
    cur_test <= 2;
    in_data <= x"1234567890ab0123";
    in_keep <= "00000011"; -- WOW :o
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111110";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 3
    cur_test <= 3;
    in_data <= x"1234567890ab0123";
    in_keep <= x"ff";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111110";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 4: two continuous packets
    cur_test <= 4;
    in_data <= x"1234567890ab0123";
    in_keep <= "00000011"; -- WOW :o
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111110";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"1234567890ab0123";
    in_keep <= "00000011"; -- WOW :o
    -- in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111110";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 5: two continuous packets AND wait between with out_ready
    cur_test <= 5;
    in_data <= x"1234567890ab0123";
    in_keep <= "00000011"; -- WOW :o
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111110";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"1234567890ab0123";
    in_keep <= "00000011"; -- WOW :o
    -- in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111110";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 6: two continuous FULL packets
    cur_test <= 5;
    in_data <= x"1234567890ab0123";
    in_keep <= "00000011"; -- WOW :o
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111100";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"1234567890ab0123";
    in_keep <= "00000011"; -- WOW :o
    -- in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111100";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 7: two continuous packets
    cur_test <= 7;
    in_data <= x"1234567890ab0123";
    in_keep <= x"ff";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"1234567890abcdef";
    in_keep <= x"ff";
    -- in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 8: two continuous FULL packets
    cur_test <= 8;
    in_data <= x"1234567890ab0123";
    in_keep <= x"ff";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111100";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"aabbccddeeffabcd";
    in_keep <= x"ff";
    -- in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"456789abcdef0123";
    in_keep <= "11111111";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    in_data <= x"456789abcdef0123";
    in_keep <= "11111100";
    wait for clkp;

    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 9: empty
    cur_test <= 9;
    in_data <= x"1234567890ab0123";
    in_keep <= "00000000";
    in_valid <= '1';
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
    assert out_keep = x"ff" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 1.1";
    wait for clkp;
    out_ready <= '0';
    wait for clkp * 10;
    out_ready <= '1';
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111100" and out_data(63 downto 16) = x"0123456789ab" and out_last = '1' report "invalid output 1.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 2" severity note;
    cur_test_out <= 2;
    wait for clkp * 1;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 2.1";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data(63 downto 16) = x"0123456789ab" and out_last = '0' report "invalid output 2.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "10000000" and out_data(63 downto 56) = x"01" and out_last = '1' report "invalid output 2.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 3" severity note;
    cur_test_out <= 3;
    wait for clkp * 1;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = "00111111" and out_data(47 downto 0) = x"1234567890ab" and out_last = '0' report "invalid output 3.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 3.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 3.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "10000000" and out_data(63 downto 56) = x"01" and out_last = '1' report "invalid output 3.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 4" severity note;
    cur_test_out <= 4;
    wait for clkp * 1;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 4.1";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data(63 downto 16) = x"0123456789ab" and out_last = '0' report "invalid output 4.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "10000000" and out_data(63 downto 56) = x"01" and out_last = '1' report "invalid output 4.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = x"ff" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 4.4";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data(63 downto 16) = x"0123456789ab" and out_last = '0' report "invalid output 4.5: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "10000000" and out_data(63 downto 56) = x"01" and out_last = '1' report "invalid output 4.6: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 5" severity note;
    cur_test_out <= 5;
    wait for clkp * 1;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 5.1";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data(63 downto 16) = x"0123456789ab" and out_last = '0' report "invalid output 5.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "10000000" and out_data(63 downto 56) = x"01" and out_last = '1' report "invalid output 5.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    wait for clkp * 3;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 5.4";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data(63 downto 16) = x"0123456789ab" and out_last = '0' report "invalid output 5.5: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "10000000" and out_data(63 downto 56) = x"01" and out_last = '1' report "invalid output 5.6: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 6" severity note;
    cur_test_out <= 6;
    wait for clkp * 1;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 6.1";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data(63 downto 16) = x"0123456789ab" and out_last = '1' report "invalid output 6.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = x"ff" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 6.4";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data(63 downto 16) = x"0123456789ab" and out_last = '1' report "invalid output 6.5: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 7" severity note;
    cur_test_out <= 7;
    wait for clkp * 1;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = "00111111" and out_data(47 downto 0) = x"1234567890ab" and out_last = '0' report "invalid output 7.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 7.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 7.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11000000" and out_data(63 downto 56) = x"01" and out_last = '1' report "invalid output 7.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "00111111" and out_data(47 downto 0) = x"1234567890ab" and out_last = '0' report "invalid output 7.5 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"cdef456789abcdef" and out_last = '0' report "invalid output 7.6: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 7.7: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11000000" and out_data(63 downto 56) = x"01" and out_last = '1' report "invalid output 7.8: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 8" severity note;
    cur_test_out <= 8;
    wait for clkp * 1;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = "00111111" and out_data(47 downto 0) = x"1234567890ab" and out_last = '0' report "invalid output 8.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0123456789abcdef" and out_last = '0' report "invalid output 8.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0123456789abcdef" and out_last = '1' report "invalid output 8.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "00111111" and out_data(47 downto 0) = x"aabbccddeeff" and out_last = '0' report "invalid output 8.5 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"abcd456789abcdef" and out_last = '0' report "invalid output 8.6: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0123456789abcdef" and out_last = '1' report "invalid output 8.7: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 9" severity note;
    cur_test_out <= 9;
    wait for clkp * 3;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"00" and out_last = '1' report "invalid output 9.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    wait;
  end process;
end architecture;
