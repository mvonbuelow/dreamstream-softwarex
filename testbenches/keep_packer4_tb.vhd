-- use this command to run tests:
-- ghdl -a --std=08 --work=axi ../types.vhd ../treemux.vhd ../keep_packer.vhd keep_packer4_tb.vhd && ghdl -e --std=08 --work=axi keep_packer4_tb && ghdl -r --std=08 --work=axi keep_packer4_tb --wave=test.ghw

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

entity keep_packer4_tb is
end;

architecture keep_packer4_tb_arch of keep_packer4_tb is
  signal clk, clk_en: std_logic := '1';

  constant w: integer := 4;
  constant dw: integer := w * 8;
  constant clkp: time := 10 ns;

  signal in_valid, in_ready, in_last, out_valid, out_ready, out_last: std_logic := '0';
  signal in_keep, out_keep: std_logic_vector(w - 1 downto 0);
  signal in_data, out_data: std_logic_vector(dw - 1 downto 0);
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
    in_data <= x"12345678";
    in_keep <= "1100";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"11223344";
    in_keep <= "1111";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"aaaa0000";
    in_keep <= "1100";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_keep <= "0000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 2: last = 1 when keep = 0
    in_data <= x"12345678";
    in_keep <= "1100";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"11223344";
    in_keep <= "1111";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"aaaa0000";
    in_keep <= "1100";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 3: mixed keep
    in_data <= x"11220000";
    in_keep <= "1100"; -- "1122"
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"33000000";
    in_keep <= "1000"; -- "33"

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"44556600";
    in_keep <= "1110"; -- "445566"
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 4: something normal
    in_data <= x"11223344";
    in_keep <= "1111";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"55660000";
    in_keep <= "1100";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 5: byte wise
    in_data <= x"11223344";
    in_keep <= "1000";
    in_valid <= '1';
    in_last <= '0';

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"22aa0000";
    in_keep <= "1000";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"33aa0000";
    in_keep <= "1000";
    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;


    in_valid <= '0';
    wait for clkp * 4;

    wait for clkp;
    in_valid <= '1';
    in_data <= x"44aa0000";
    in_keep <= "1000";

    wait for clkp;
    while in_ready = '0' loop
      wait for clkp;
    end loop;
    in_data <= x"55aa0000";
    in_keep <= "1000";

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
    wait for clkp * 3;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"f" and out_data = x"12341122" and out_last = '0' report "invalid output 1.1";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = x"f" and out_data = x"3344aaaa" and out_last = '1' report "invalid output 1.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 2" severity note;
    wait for clkp * 3;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"f" and out_data = x"12341122" and out_last = '0' report "invalid output 2.1";
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = x"f" and out_data = x"3344aaaa" and out_last = '1' report "invalid output 2.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 3" severity note;
    wait for clkp * 2;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"f" and out_data = x"11223344" and out_last = '0' report "invalid output 3.1: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "1100" and out_data(31 downto 16) = x"5566" and out_last = '1' report "invalid output 3.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 4" severity note;
    wait for clkp * 2;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"f" and out_data = x"11223344" and out_last = '0' report "invalid output 4.1: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "1100" and out_data(31 downto 16) = x"5566" and out_last = '1' report "invalid output 4.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";

    report "test 5" severity note;
    wait for clkp * 2;
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    out_ready <= '1';
    assert out_keep = x"f" and out_data = x"11223344" and out_last = '0' report "invalid output 5.1: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';
    wait for clkp * 10;
    out_ready <= '1';
    while out_valid = '0' loop
      wait for clkp;
    end loop;
    assert out_keep = "1000" and out_data(31 downto 24) = x"55" and out_last = '1' report "invalid output 5.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    assert out_valid = '0' report "output still valid";
    wait;
  end process;
end architecture;
