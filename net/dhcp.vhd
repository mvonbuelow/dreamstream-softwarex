-------------------------------------------------------------------------------
-- dhcp
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: DHCP protocol.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

entity dhcp is
  generic (
    width: integer := 64;
    my_name: string := "DREAMSTREAM";
    vendor_bytes: integer := 8
  );
  port (
    clk: in std_logic;
    rst: in std_logic;

    in_ready: out std_logic;
    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_last: in std_logic;
    in_id: in std_logic_vector(95 downto 0);

    out_ready: in std_logic;
    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_last: out std_logic;
    out_id: out std_logic_vector(15 downto 0);
    out_dest: out std_logic_vector(95 downto 0);
    out_user: out std_logic_vector(15 downto 0);

    my_id_mac: in std_logic_vector(47 downto 0);
    my_id_vendor: in std_logic_vector(vendor_bytes * 8 - 1 downto 0) := (others => '0');
    my_id_ip: out std_logic_vector(31 downto 0) := (others => '0');
    my_subnetmask: out std_logic_vector(31 downto 0) := (others => '0');
    done: out std_logic;
    have_ip: in std_logic
  );
end;

architecture net_dhcp_arch of dhcp is
  signal out_x_ready, out_x_valid, out_x_last: std_logic;
  signal out_x_data: std_logic_vector(out_data'range);
  signal out_x_keep: std_logic_vector(out_keep'range);
  signal out_x_dest: std_logic_vector(out_dest'range);
  signal out_x_id: std_logic_vector(out_id'range);
  signal out_x_user: std_logic_vector(out_user'range);

  type state_t is (BOOTING, D, O, R, A, FIN);
  signal state, state_next: state_t := D;
  signal dhcp_type: std_logic_vector(7 downto 0);
  signal id: std_logic_vector(in_id'range) := x"ffffffffffffffffffff0043";
  signal timeout: unsigned(27 downto 0) := (others => '0');
  signal xid: std_logic_vector(31 downto 0);

  signal parser_user: std_logic_vector((11 * 4 + 192 + 4) * 8 - 1 downto 0);
  signal composer_user: std_logic_vector(parser_user'length + (21 + my_name'length + 2 + vendor_bytes) * 8 - 1 downto 0);
  signal composer_valid, composer_ready: std_logic;
  signal si_or_pad: std_logic_vector(47 downto 0);

  signal parser_valid, parser_ready, parser_last: std_logic;
  signal parser_data: std_logic_vector(in_data'range);
  signal parser_keep: std_logic_vector(in_keep'range);
  signal ser_valid, ser_ready, ser_last: std_logic;
  signal ser_data: std_logic_vector(7 downto 0);
  signal ser_user: std_logic_vector(31 + in_id'length downto 0);
  signal expected_type: std_logic_vector(7 downto 0);

  signal tlv_valid, tlv_ready: std_logic;
  signal tlv_data: std_logic_vector(63 downto 0);
  signal tlv_user: std_logic_vector(in_id'length downto 0);

  signal txnctr: unsigned(15 downto 0) := (others => '0'); -- I don't make it too big... it's only for XID randomness

  function string_to_slv(s: string) return std_logic_vector is
    variable result: std_logic_vector(s'length * 8 - 1 downto 0);
    variable idx: integer := result'left;
  begin
    for i in s'range loop
      result(idx downto idx - 7) :=
        std_logic_vector(to_unsigned(character'pos(s(i)), 8));
      idx := idx - 8;
    end loop;
    return result;
  end function;
  signal in_valid_i, in_ready_i: std_logic;
begin
  absorber_inst: entity ds.absorber port map (
    clk => clk,
    rst => rst,
    in_valid => in_valid,
    in_ready => in_ready,
    in_last => in_last,
    in_absorb => done,
    out_valid => in_valid_i,
    out_ready => in_ready_i
  );
  done <= '1' when state = FIN else '0';
  fsm_main: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= D;
        txnctr <= (others => '0');
      else
        case state is
          when BOOTING =>
            id <= x"ffffffffffffffffffff0043";
            timeout <= timeout + 1;
            if timeout(10) = '1' and have_ip = '0' then
              timeout <= (others => '0');
              state_next <= D;
              txnctr <= txnctr + 1;
            end if;
          when D | R =>
            if out_x_valid = '1' and out_x_last = '1' and out_x_ready = '1' then
              if have_ip = '1' then
                state <= BOOTING;
              else
                state <= O when state = D else A;
              end if;
            end if;
          when O | A =>
            if tlv_valid = '1' then
              my_id_ip <= tlv_data(63 downto 32);
              my_subnetmask <= tlv_data(31 downto 0);
              id <= tlv_user(id'range);
              if tlv_user(tlv_user'left) = '0' then
                state <= R when state = O else FIN;
              end if;
            end if;
            timeout <= timeout + 1;
            if timeout(timeout'left) = '1' then
              timeout <= (others => '0');
              state <= D;
              id <= x"ffffffffffffffffffff0043";
            end if;
          when FIN =>
        end case;
      end if;
    end if;
  end process;
  tlv_ready <= '1' when state = O or state = A else '0';
  composer_valid <= '1' when state = D or state = R else '0';
  dhcp_type <= x"01" when state = D else x"03";

  si_or_pad <= x"3604" & id(47 downto 16) when state /= D else x"000000000000";
  composer_user <=
    x"01010600" & -- op, htype, hlen, hops
    xid &
    x"00000000" & -- secs, flags
    my_id_ip & -- ciaddr
    x"00000000" & -- yiaddr
    id(47 downto 16) & -- siaddr
    x"00000000" & -- giaddr
    my_id_mac & x"0000" & x"00000000" & x"00000000" & -- chaddr
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" &
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" &
    x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" &
    x"63825363" & -- magic cookie
    x"3501" & dhcp_type & x"3d0701" & my_id_mac & x"0c" & std_logic_vector(to_unsigned(my_name'length, 8)) & string_to_slv(my_name) & x"2b" & std_logic_vector(to_unsigned(vendor_bytes, 8)) & my_id_vendor & si_or_pad & x"ff";

  xid <= (my_id_mac(47 downto 32) xor my_id_mac(31 downto 16) xor std_logic_vector(txnctr)) & (my_id_mac(15 downto 0) xor std_logic_vector(txnctr)); -- TODO
  composer_inst: entity ds.composer generic map (
    width => width,
    user => composer_user'length
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => composer_valid,
    in_ready => composer_ready,
    in_user => composer_user,
    out_valid => out_x_valid,
    out_data => out_x_data,
    out_last => out_x_last,
    out_ready => out_x_ready,
    out_keep => out_x_keep
  );

  expected_type <= x"02" when state = O else x"05";
  parser_inst: entity ds.parser generic map (
    width => width,
    user => parser_user'length,
    check_mask =>
      x"ffffff00" & -- op, htype, hlen, hops
      x"ffffffff" & -- xid
      x"00000000" & -- secs, flags
      x"00000000" & -- ciaddr
      x"00000000" & -- yiaddr
      x"00000000" & -- siaddr
      x"00000000" & -- giaddr
      x"00000000" & x"00000000" & x"00000000" & x"00000000" & -- chaddr
      x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" &
      x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" &
      x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" &
      x"ffffffff", -- & -- magic cookie
    absorb_on_error => true
      -- x"ffffff"
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => in_valid_i,
    in_data => in_data,
    in_last => in_last,
    in_keep => in_keep,
    in_ready => in_ready_i,
    out_valid => parser_valid,
    out_data => parser_data,
    out_last => parser_last,
    out_keep => parser_keep,
    out_ready => parser_ready,
    out_user => parser_user,
    check_val =>
      x"02010600" & -- op, htype, hlen, hops
      xid &
      x"00000000" & -- secs, flags
      x"00000000" & -- ciaddr
      x"00000000" & -- yiaddr
      x"00000000" & -- siaddr
      x"00000000" & -- giaddr
      x"00000000" & x"00000000" & x"00000000" & x"00000000" & -- chaddr
      x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" &
      x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" &
      x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" &
      x"63825363" -- & -- magic cookie
      -- x"3501" & expected_type
  );
  serializer_inst: entity ds.serializer generic map (
    -- now it gets slow... we must parse TVL on byte level... what a mess...
    width => width,
    out_width => 8,
    user => 32 + in_id'length
  ) port map (
    clk => clk,
    rst => rst,
    in_valid => parser_valid,
    in_ready => parser_ready,
    in_data => parser_data,
    in_keep => parser_keep,
    in_last => parser_last,
    in_user => in_id & parser_user((48 + 7) * 32 + 31 downto(48 + 7) * 32),
    out_valid => ser_valid,
    out_ready => ser_ready,
    out_data => ser_data,
    out_last => ser_last,
    out_user => ser_user
  );

  bl_options: block
    type state_t is (T, L, V, FIN, ERR, IGN, FIN_IGN);
    signal state: state_t := T;
    signal is_type, is_mask, found_type, found_mask: boolean := false;
    signal len, idx: unsigned(7 downto 0);
  begin
    tlv_valid <= '1' when state = FIN or state = ERR else '0';
    tlv_user(tlv_user'left) <= '1' when state = ERR else '0';
    with state select ser_ready <=
      '1' when T | L | V | FIN_IGN | IGN,
      '0' when others;
    fsm: process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          state <= T;
          is_type <= false;
          is_mask <= false;
          found_type <= false;
          found_mask <= false;
        else
          case state is
            when T =>
              if ser_valid = '1' then
                tlv_user(tlv_user'left - 1 downto 0) <= ser_user(ser_user'left downto 32);
                tlv_data(63 downto 32) <= ser_user(31 downto 0);
                if ser_data = x"ff" then
                  if found_type and found_mask then
                    state <= FIN when ser_last = '1' else FIN_IGN;
                  else
                    state <= ERR when ser_last = '1' else IGN;
                  end if;
                elsif ser_last = '1' then
                  state <= ERR;
                elsif ser_data /= x"00" then
                  is_type <= ser_data = x"35";
                  is_mask <= ser_data = x"01";
                  state <= L;
                end if;
              end if;
            when L =>
              found_type <= found_type or is_type;
              found_mask <= found_mask or is_mask;
              if ser_valid = '1' then
                if ser_last = '1' then
                  state <= ERR;
                else
                  if (is_type and ser_data /= x"01") or (is_mask and ser_data /= x"04") then
                    state <= IGN;
                  else
                    state <= V;
                  end if;
                  len <= unsigned(ser_data) - 1;
                  idx <= (others => '0');
                end if;
              end if;
            when V =>
              if ser_valid = '1' then
                idx <= idx + 1;
                if ser_last = '1' then
                  state <= ERR;
                else
                  if idx = len then
                    state <= T;
                  end if;
                  if is_type then
                    if ser_data /= expected_type then
                      state <= IGN;
                    end if;
                  end if;
                  if is_mask then
                    for i in 3 downto 0 loop
                      if i = idx then
                        tlv_data((3 - i) * 8 + 7 downto(3 - i) * 8) <= ser_data;
                      end if;
                    end loop;
                  end if;
                end if;
              end if;
            when IGN | FIN_IGN =>
              if ser_valid = '1' and ser_last = '1' then
                state <= ERR when state = IGN else FIN;
              end if;
            when ERR | FIN =>
              if tlv_ready = '1' then
                state <= T;
              end if;
          end case;
        end if;
      end if;
    end process;
  end block;

  out_x_user <= x"0103" when state = D else x"0109";
  out_x_id <= x"0044";
  out_x_dest <= id;
  reg_inst: entity ds.reg generic map (
    width => out_data'length,
    user => out_user'length,
    dest => out_dest'length,
    id => out_id'length
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
    in_id => out_x_id,
    out_ready => out_ready,
    out_valid => out_valid,
    out_data => out_data,
    out_last => out_last,
    out_keep => out_keep,
    out_user => out_user,
    out_dest => out_dest,
    out_id => out_id
  );
end architecture;
