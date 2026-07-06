-- use this command to run tests:
-- ghdl -a --std=08 --work=axi ../types.vhd ../treemux.vhd ../keep_shifter.vhd ../net/tx_ipv4.vhd tx_ipv4_tb.vhd && ghdl -e --std=08 --work=axi tx_ipv4_tb && ghdl -r --std=08 --work=axi tx_ipv4_tb --wave=test.ghw
-- nvc --std=2019 --work=ds:/tmp/ds -a ../types.vhd ../reg.vhd ../treemux.vhd ../keep_shifter.vhd ../counter.vhd ../parser.vhd ../composer.vhd ../fifo.vhd ../injector.vhd && nvc --std=2019 --work=dsnet:/tmp/dsnet -L/tmp -a ../net/internet_checksum.vhd ../net/tx_ipv4_fragment.vhd ../net/tx_ipv4.vhd tx_ipv4_tb.vhd && nvc --std=2019 --work=dsnet:/tmp/dsnet -L/tmp -e tx_ipv4_tb && nvc --std=2019 --work=dsnet:/tmp/dsnet -L/tmp -r tx_ipv4_tb --wave=test.ghw

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.stop;

library dsnet;

entity tx_ipv4_tb is
end;

architecture tx_ipv4_tb_arch of tx_ipv4_tb is
  signal clk, clk_en : std_logic := '1';

  constant w    : integer := 8;
  constant dw   : integer := w * 8;
  constant clkp : time    := 10 ns;

  signal in_valid, in_ready, in_last, out_valid, out_ready, out_last : std_logic                          := '0';
  signal in_keep, out_keep                                           : std_logic_vector(w - 1 downto 0);
  signal in_data, out_data                                           : std_logic_vector(dw - 1 downto 0);
  signal cur_test, cur_test_out                                      : integer;
  signal in_id                                                       : std_logic_vector(31 downto 0)      := (others => '0');
  signal in_dest                                                     : std_logic_vector(48 + 31 downto 0) := (others => '0');
  signal in_user                                                     : std_logic_vector(23 downto 0)      := (others => '0');
  signal out_dest                                                    : std_logic_vector(47 downto 0);
  signal out_user                                                    : std_logic_vector(15 downto 0);
begin
  clk <= not clk and clk_en after clkp / 2;

  net_tx_ipv4_inst : entity dsnet.tx_ipv4 generic map (max_payload => 16) port map (
    clk                                                              => clk,
    in_ready                                                         => in_ready,
    in_valid                                                         => in_valid,
    in_data                                                          => in_data,
    in_keep                                                          => in_keep,
    in_last                                                          => in_last,
    out_ready                                                        => out_ready,
    out_valid                                                        => out_valid,
    out_data                                                         => out_data,
    out_keep                                                         => out_keep,
    out_last                                                         => out_last,
    out_dest                                                         => out_dest,
    out_user                                                         => out_user,
    in_id                                                            => in_id,
    in_dest                                                          => in_dest,
    in_user                                                          => in_user
    );

  process
  begin
    wait for clkp * 2;
    wait until rising_edge(clk);

    -- test 1: short frame
    cur_test                   <= 1;
    in_data                    <= x"1234567890abcdef";
    in_keep                    <= "11100000";
    in_valid                   <= '1';
    in_user(15 downto 0)       <= x"0003";
    in_user(23 downto 16)      <= x"11";
    in_id(31 downto 0)         <= x"0a0a0011";
    in_dest(31 downto 0)       <= x"0a0a0010";
    in_dest(31 + 48 downto 32) <= (others => '0');
    in_last                    <= '1';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 2: a bit longer frame
    cur_test                   <= 2;
    in_data                    <= x"1234567890abcdef";
    in_keep                    <= "11111000";
    in_valid                   <= '1';
    in_user(15 downto 0)       <= x"0005";
    in_user(23 downto 16)      <= x"11";
    in_id(31 downto 0)         <= x"0a0a0011";
    in_dest(31 downto 0)       <= x"0a0a0010";
    in_dest(31 + 48 downto 32) <= (others => '0');
    in_last                    <= '1';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 3: 13 byte frame
    cur_test                   <= 3;
    in_data                    <= x"1234567890abcdef";
    in_keep                    <= "11111111";
    in_valid                   <= '1';
    in_user(15 downto 0)       <= x"000d";
    in_user(23 downto 16)      <= x"11";
    in_id(31 downto 0)         <= x"0a0a0011";
    in_dest(31 downto 0)       <= x"0a0a0010";
    in_dest(31 + 48 downto 32) <= (others => '0');
    in_last                    <= '0';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_data <= x"1122334455667788";
    in_keep <= "11111000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 4: 16 byte frame --> no fragmentation yet
    cur_test                   <= 4;
    in_data                    <= x"1234567890abcdef";
    in_keep                    <= "11111111";
    in_valid                   <= '1';
    in_user(15 downto 0)       <= x"0010";
    in_user(23 downto 16)      <= x"11";
    in_id(31 downto 0)         <= x"0a0a0011";
    in_dest(31 downto 0)       <= x"0a0a0010";
    in_dest(31 + 48 downto 32) <= (others => '0');
    in_last                    <= '0';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_data <= x"1122334455667788";
    in_keep <= "11111111";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_valid <= '0';
    wait for clkp * 3;

    -- test 5: 17 byte frame --> fragmentation
    cur_test                   <= 5;
    in_data                    <= x"1234567890abcdef";
    in_keep                    <= "11111111";
    in_valid                   <= '1';
    in_user(15 downto 0)       <= x"0011";
    in_user(23 downto 16)      <= x"11";
    in_id(31 downto 0)         <= x"0a0a0011";
    in_dest(31 downto 0)       <= x"0a0a0010";
    in_dest(31 + 48 downto 32) <= (others => '0');
    in_last                    <= '0';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_data <= x"1122334455667788";
    in_keep <= "11111111";

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_data <= x"aabbccddeeff0011";
    in_keep <= "10000000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_valid <= '0';
    wait for clkp * 3;

    wait for clkp * 10;
    -- test 6: burst of 2 18 byte fragments
    cur_test                   <= 6;
    in_data                    <= x"1234567890abcdef";
    in_keep                    <= "11111111";
    in_valid                   <= '1';
    in_user(15 downto 0)       <= x"0012";
    in_user(23 downto 16)      <= x"11";
    in_id(31 downto 0)         <= x"0a0a0011";
    in_dest(31 downto 0)       <= x"0a0a0010";
    in_dest(31 + 48 downto 32) <= (others => '0');
    in_last                    <= '0';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_data <= x"1122334455667788";
    in_keep <= "11111111";

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_data <= x"aabbccddeeff0011";
    in_keep <= "11000000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;

    in_data                    <= x"fedcba0987654321";
    in_keep                    <= "11111111";
    -- in_valid <= '1';
    in_user(15 downto 0)       <= x"0012";
    in_user(23 downto 16)      <= x"11";
    in_id(31 downto 0)         <= x"0a0a0011";
    in_dest(31 downto 0)       <= x"0a0a0010";
    in_dest(31 + 48 downto 32) <= (others => '0');
    in_last                    <= '0';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_data <= x"8877665544332211";
    in_keep <= "11111111";

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_data <= x"bbaa1100aabbccdd";
    in_keep <= "11000000";
    in_last <= '1';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_valid <= '0';
    wait for clkp * 3;


    wait for clkp * 10;


    -- test 7: empty frame
    cur_test                   <= 7;
    in_data                    <= x"1234567890abcdef";
    in_keep                    <= "00000000";
    in_valid                   <= '1';
    in_user(15 downto 0)       <= x"0000";
    in_user(23 downto 16)      <= x"11";
    in_id(31 downto 0)         <= x"0a0a0011";
    in_dest(31 downto 0)       <= x"0a0a0010";
    in_dest(31 + 48 downto 32) <= (others => '0');
    in_last                    <= '1';

    wait for clkp;
    while in_ready = '0' loop wait for clkp; end loop;
    in_valid <= '0';
    wait for clkp * 3;

    wait;
  end process;

  process
  begin

    wait for clkp * 2;
    wait until rising_edge(clk);
    wait for 1 ns;  -- make sure we read after the process above..

    report "test 1" severity note;
    cur_test_out <= 1;
    wait for clkp * 3;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready    <= '1';
    assert out_keep = x"ff" and out_data = x"4510001700000000" and out_last = '0' report "invalid output 1.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"401166920A0A0011" and out_last = '0' report "invalid output 1.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11111110" and out_data(63 downto 8) = x"0A0A0010123456" and out_last = '1' report "invalid output 1.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    -- assert out_valid = '0' report "1output still valid";
    out_ready    <= '0';


    report "test 2" severity note;
    cur_test_out <= 2;
    wait for clkp * 3;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready    <= '1';
    assert out_keep = x"ff" and out_data = x"4510001900010000" and out_last = '0' report "invalid output 2.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"4011668f0A0A0011" and out_last = '0' report "invalid output 2.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11111111" and out_data = x"0A0A001012345678" and out_last = '0' report "invalid output 2.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "10000000" and out_data(63 downto 56) = x"90" and out_last = '1' report "invalid output 2.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    -- assert out_valid = '0' report "2output still valid";
    out_ready    <= '0';


    report "test 3" severity note;
    cur_test_out <= 3;
    wait for clkp * 3;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready    <= '1';
    assert out_keep = x"ff" and out_data = x"4510002100020000" and out_last = '0' report "invalid output 3.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"401166860A0A0011" and out_last = '0' report "invalid output 3.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11111111" and out_data = x"0A0A001012345678" and out_last = '0' report "invalid output 3.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"90abcdef11223344" and out_last = '0' report "invalid output 3.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "10000000" and out_data(63 downto 56) = x"55" and out_last = '1' report "invalid output 3.5: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';

    report "test 4" severity note;
    cur_test_out <= 4;
    wait for clkp * 3;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready    <= '1';
    assert out_keep = x"ff" and out_data = x"4510002400030000" and out_last = '0' report "invalid output 4.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"401166820A0A0011" and out_last = '0' report "invalid output 4.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11111111" and out_data = x"0A0A001012345678" and out_last = '0' report "invalid output 4.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"90abcdef11223344" and out_last = '0' report "invalid output 4.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11110000" and out_data(63 downto 32) = x"55667788" and out_last = '1' report "invalid output 4.5: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';



    report "test 5" severity note;
    cur_test_out <= 5;
    wait for clkp * 3;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready    <= '1';
    assert out_keep = x"ff" and out_data = x"4510002400042000" and out_last = '0' report "invalid output 5.0.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"401146810A0A0011" and out_last = '0' report "invalid output 5.0.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11111111" and out_data = x"0A0A001012345678" and out_last = '0' report "invalid output 5.0.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"90abcdef11223344" and out_last = '0' report "invalid output 5.0.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11110000" and out_data(63 downto 32) = x"55667788" and out_last = '1' report "invalid output 5.0.5: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';

    -- frag 2
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"4510001500040002" and out_last = '0' report "invalid output 5.1.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"4011668e0A0A0011" and out_last = '0' report "invalid output 5.1.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11111000" and out_data(63 downto 24) = x"0A0A0010aa" and out_last = '1' report "invalid output 5.1.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';



    report "test 6" severity note;
    cur_test_out <= 6;
    wait for clkp * 3;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready    <= '1';
    assert out_keep = x"ff" and out_data = x"4510002400052000" and out_last = '0' report "invalid output 6.0.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"401146800A0A0011" and out_last = '0' report "invalid output 6.0.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11111111" and out_data = x"0A0A001012345678" and out_last = '0' report "invalid output 6.0.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"90abcdef11223344" and out_last = '0' report "invalid output 6.0.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11110000" and out_data(63 downto 32) = x"55667788" and out_last = '1' report "invalid output 6.0.5: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';

    -- frag 2
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"4510001600050002" and out_last = '0' report "invalid output 6.1.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"4011668c0A0A0011" and out_last = '0' report "invalid output 6.1.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11111100" and out_data(63 downto 16) = x"0A0A0010aabb" and out_last = '1' report "invalid output 6.1.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';

    -- next frame
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"4510002400062000" and out_last = '0' report "invalid output 6.2.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"4011467f0A0A0011" and out_last = '0' report "invalid output 6.2.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11111111" and out_data = x"0A0A0010fedcba09" and out_last = '0' report "invalid output 6.2.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"8765432188776655" and out_last = '0' report "invalid output 6.2.4: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11110000" and out_data(63 downto 32) = x"44332211" and out_last = '1' report "invalid output 6.2.5: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    out_ready <= '0';

    -- next frame frag 2
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready <= '1';
    assert out_keep = x"ff" and out_data = x"4510001600060002" and out_last = '0' report "invalid output 6.3.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"4011668b0A0A0011" and out_last = '0' report "invalid output 6.3.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11111100" and out_data(63 downto 16) = x"0A0A0010bbaa" and out_last = '1' report "invalid output 6.3.3: " & to_string(out_keep) & " " & to_hex_string(out_data);

    wait for clkp;
    -- assert out_valid = '0' report "6output still valid";
    out_ready <= '0';

    report "test 7" severity note;
    cur_test_out <= 7;
    wait for clkp * 3;
    while out_valid = '0' loop wait for clkp; end loop;
    out_ready    <= '1';
    assert out_keep = x"ff" and out_data = x"4510001400070000" and out_last = '0' report "invalid output 1.1 " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = x"ff" and out_data = x"4011668e0A0A0011" and out_last = '0' report "invalid output 1.2: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    while out_valid = '0' loop wait for clkp; end loop;
    assert out_keep = "11110000" and out_data(63 downto 32) = x"0A0A0010" and out_last = '1' report "invalid output 1.3: " & to_string(out_keep) & " " & to_hex_string(out_data);
    wait for clkp;
    -- assert out_valid = '0' report "7output still valid";
    out_ready    <= '0';

    wait for clkp * 10;
    stop;
    wait;
  end process;
end architecture;
