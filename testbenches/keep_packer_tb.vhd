-- use this command to run tests:
-- ghdl -a --std=08 --work=axi ../types.vhd ../treemux.vhd ../keep_packer.vhd keep_packer_tb.vhd && ghdl -e --std=08 --work=axi keep_packer_tb && ghdl -r --std=08 --work=axi keep_packer_tb --wave=test.ghw

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

entity keep_packer_tb is
end;

architecture keep_packer_tb_arch of keep_packer_tb is
  signal clk, clk_en: std_logic := '1';

  constant w: integer := 8;
  constant dw: integer := w * 8;
  constant clkp: time := 10 ns;

  signal in_valid, in_ready, in_last, out_valid, out_ready, out_last: std_logic := '0';
  signal in_keep, out_keep: std_logic_vector(w - 1 downto 0);
  signal in_data, out_data: std_logic_vector(dw - 1 downto 0);
  signal cur_test, cur_test_out: integer;
begin
  clk <= not clk and clk_en after clkp / 2;

  keep_packer_inst: entity ds.keep_packer generic map (width => w * 8) port map (
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
    out_keep => out_keep
  );

  process
  begin
    wait for clkp * 2;
    wait until rising_edge(clk);

    -- test 1: last = 1 when keep = 0
    cur_test <= 1;
    in_data <= x"1234567890abcdef";
    in_keep <= "11110000";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"1122334455667788";
    in_keep <= "11111111";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"aaaabbbb00000000";
    in_keep <= "11110000";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_keep <= "00000000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 2: last = 1 when keep = 0
    cur_test <= 2;
    in_data <= x"1234567890abcdef";
    in_keep <= "11110000";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"1122334455667788";
    in_keep <= "11111111";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"aaaabbbb00000000";
    in_keep <= "11110000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 3: mixed keep
    cur_test <= 3;
    in_data <= x"1122334400000000";
    in_keep <= "11110000"; -- "11223344"
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"5500000000000000";
    in_keep <= "10000000"; -- "55"

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"6600000000000000";
    in_keep <= "10000000"; -- "66"
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"7788990000000000";
    in_keep <= "11100000"; -- "778899"
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 4: something normal
    cur_test <= 4;
    in_data <= x"1122334455667788";
    in_keep <= "11111111";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"99aa000000000000";
    in_keep <= "11000000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 5: byte wise
    cur_test <= 5;
    in_data <= x"1122334455667788";
    in_keep <= "10000000";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"22aa000000000000";
    in_keep <= "10000000";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"33aa000000000000";
    in_keep <= "10000000";
    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;


    in_valid <= '0';
    wait for clkp * 4;

    wait for clkp;
    in_valid <= '1';
    in_data <= x"44aa000000000000";
    in_keep <= "10000000";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"55aa000000000000";
    in_keep <= "10000000";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"66aa000000000000";
    in_keep <= "10000000";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"77aa000000000000";
    in_keep <= "10000000";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"88aa000000000000";
    in_keep <= "10000000";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"99aa000000000000";
    in_keep <= "10000000";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 4;

    wait for clkp;
    in_valid <= '1';
    in_keep <= (others => '0');
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 8;

    -- test 6: out_ready bug
    cur_test <= 6;
    in_data <= x"1122334455667788";
    in_keep <= "11000000";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"3344556677881122";
    in_keep <= "11111111";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"3344556677881122";
    in_keep <= "11111111";


    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"3344556677880000";
    in_keep <= "11111100";
    in_last <= '1';
    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;

    in_valid <= '0';
    in_last <= '0';
    wait for clkp;

    in_valid <= '1';
    in_last <= '0';
    in_keep <= (others => '1');
    in_data <= (others => '0');
    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_last <= '1';
    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;

    in_valid <= '0';

    wait for clkp * 3;

    -- test 7: in_ready bug when there is no gap between two packets
    cur_test <= 7;
    in_data <= x"1122334455667788";
    in_keep <= "11000000";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"3344556677881122";
    in_keep <= "11111111";
    in_last <= '1'; -- a short 10 byte packet; in_valid stays high

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"1122334455667788";
    in_keep <= "11000000";
    -- in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"3344556677881122";
    in_keep <= "11111111";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0'; -- let's go

    wait for clkp * 7;

    -- test 8: in_ready bug when there is no gap between two packets: 2 full packets
    cur_test <= 8;
    in_data <= x"1122334455667788";
    in_keep <= x"ff";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"3344556677881122";
    in_keep <= "11111111";
    in_last <= '1'; -- a short 10 byte packet; in_valid stays high

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"1122334455667788";
    in_keep <= x"ff";
    -- in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"3344556677881122";
    in_keep <= "11111111";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0'; -- let's go

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
    assert out_keep = x"ff" and out_data = x"1234567811223344" and out_last = '0' report "invalid output 1.1";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = x"ff" and out_data = x"55667788aaaabbbb" and out_last = '1' report "invalid output 1.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
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
    assert out_keep = x"ff" and out_data = x"1234567811223344" and out_last = '0' report "invalid output 2.1";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = x"ff" and out_data = x"55667788aaaabbbb" and out_last = '1' report "invalid output 2.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";
    out_ready <= '0';

    report "test 3" severity note;
    cur_test_out <= 3;
    wait for clkp * 2;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"1122334455667788" and out_last = '0' report "invalid output 3.1: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "10000000" and out_data(63 downto 56) = x"99" and out_last = '1' report "invalid output 3.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";
    out_ready <= '0';

    report "test 4" severity note;
    cur_test_out <= 4;
    wait for clkp * 2;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"1122334455667788" and out_last = '0' report "invalid output 4.1: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11000000" and out_data(63 downto 48) = x"99aa" and out_last = '1' report "invalid output 4.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";
    out_ready <= '0';

    report "test 5" severity note;
    cur_test_out <= 5;
    wait for clkp * 2;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"1122334455667788" and out_last = '0' report "invalid output 5.1: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    wait for clkp * 10;
    out_ready <= '1';
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "10000000" and out_data(63 downto 56) = x"99" and out_last = '1' report "invalid output 5.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";
    out_ready <= '0';

    report "test 6" severity note;
    cur_test_out <= 6;
    wait for clkp * 2;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"1122334455667788" and out_last = '0' report "invalid output 6.1: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    wait for clkp * 7;
    out_ready <= '1';
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"1122334455667788" and out_last = '0' report "invalid output 6.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    wait for clkp * 7;
    out_ready <= '1';
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"1122334455667788" and out_last = '1' report "invalid output 6.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;

    assert out_valid = '0' report "output still valid";
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0000000000000000" and out_last = '0' report "invalid output 6.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0000000000000000" and out_last = '0' report "invalid output 6.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0000000000000000" and out_last = '0' report "invalid output 6.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0000000000000000" and out_last = '0' report "invalid output 6.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0000000000000000" and out_last = '0' report "invalid output 6.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11111111" and out_data = x"0000000000000000" and out_last = '1' report "invalid output 6.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';

    assert out_valid = '0' report "output still valid";

    report "test 7" severity note;
    cur_test_out <= 7;
    wait for clkp * 2;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"1122334455667788" and out_last = '0' report "invalid output 7.1: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    wait for clkp * 7;
    out_ready <= '1';
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11000000" and out_data(63 downto 48) = x"1122" and out_last = '1' report "invalid output 7.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"1122334455667788" and out_last = '0' report "invalid output 7.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    wait for clkp * 7;
    out_ready <= '1';
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "11000000" and out_data(63 downto 48) = x"1122" and out_last = '1' report "invalid output 7.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    assert out_valid = '0' report "output still valid";


    report "test 8" severity note;
    cur_test_out <= 8;
    wait for clkp * 2;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"1122334455667788" and out_last = '0' report "invalid output 8.1: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    wait for clkp * 7;
    out_ready <= '1';
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = x"ff" and out_data = x"3344556677881122" and out_last = '1' report "invalid output 8.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"1122334455667788" and out_last = '0' report "invalid output 8.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    wait for clkp * 7;
    out_ready <= '1';
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = x"ff" and out_data = x"3344556677881122" and out_last = '1' report "invalid output 8.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    assert out_valid = '0' report "output still valid";



    wait;
  end process;
end architecture;
