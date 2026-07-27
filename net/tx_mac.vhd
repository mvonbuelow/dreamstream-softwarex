-------------------------------------------------------------------------------
-- tx_mac
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Ethernet frame constructor.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;

entity tx_mac_aligner is
  generic (
    width: integer := 64
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    xgmii_d: out std_logic_vector(width - 1 downto 0);
    xgmii_c: out std_logic_vector(width / 8 - 1 downto 0);


    in_valid: in std_logic;
    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_last: in std_logic;
    in_ready: out std_logic
  );
end;

architecture tx_mac_aligner_arch of tx_mac_aligner is
  constant sof: std_logic_vector(7 downto 0) := x"fb";
  constant eof: std_logic_vector(7 downto 0) := x"fd";
  constant ic: std_logic_vector(7 downto 0) := x"07";
  constant half_idle: std_logic_vector(31 downto 0) := ic & ic & ic & ic;
  constant full_idle: std_logic_vector(63 downto 0) := half_idle & half_idle;

  type state_t is (IDLE_L0, IDLE_L4, LANE0, LANE4, FORCE_IDLE);
  signal state, state_next: state_t := IDLE_L0;
  signal xgmii_d_s, xgmii_d_r, xgmii_d_rr: std_logic_vector(63 downto 0);
  signal xgmii_c_s, xgmii_c_r, xgmii_c_rr: std_logic_vector(7 downto 0);
  signal aligned_d_lookahead: std_logic_vector(103 downto 0);
  signal aligned_c_lookahead: std_logic_vector(12 downto 0); -- this is one bit lookahead to set tlast early enough + 4 bytes FCS from past
  signal first_byte_d: std_logic_vector(7 downto 0);
  signal first_byte_k: std_logic;

  function swap_chunks(
    data: std_logic_vector;
    width: positive
  ) return std_logic_vector is
    variable normalized, result: std_logic_vector(data'length - 1 downto 0);
    constant total_bits: natural := data'length;
    constant num_chunks: natural := total_bits / width;
  begin
    normalized := data;
    for i in 0 to num_chunks - 1 loop
      result((i + 1) * width - 1 downto i * width) := normalized((num_chunks - i) * width - 1 downto(num_chunks - i - 1) * width);
    end loop;
    return result;
  end function;
  signal dbg: std_logic_vector(7 downto 0);

  -- signal dic : unsigned(1 downto 0);
  signal dic, dic_next: integer range 0 to 3;
  signal ipg, ipg_next: integer range 1 to 3; -- number of 32 bit words to send idle

  signal in_data_r: std_logic_vector(31 downto 0);
  signal in_keep_r: std_logic_vector(3 downto 0);
  signal in_valid_r, in_last_r: std_logic := '0';
  signal in_data_shifted, in_data_shifted_mask, in_data_shifted_eof: std_logic_vector(63 downto 0);
  signal in_keep_shifted: std_logic_vector(7 downto 0);
  signal in_valid_shifted, in_last_shifted: std_logic;
begin
  in_data_r <= in_data(31 downto 0) when rising_edge(clk);
  in_keep_r <= in_keep(3 downto 0) when rising_edge(clk);
  in_last_r <= in_last when rising_edge(clk);
  in_valid_r <= in_valid when rising_edge(clk);

  mask: for i in in_keep'range generate
    signal i_is_last: boolean;
  begin
    in_data_shifted_mask(i * 8 + 7 downto i * 8) <= (others => in_keep_shifted(i));

    iffirst: if i = 7 generate
      i_is_last <= in_keep_shifted(i) = '0';
    else generate
      i_is_last <= in_keep_shifted(i) = '0' and in_keep_shifted(i + 1) = '1';
    end generate;
    in_data_shifted_eof(i * 8 + 7 downto i * 8) <= eof when in_valid_shifted = '1' and in_last_shifted = '1' and i_is_last else ic;
  end generate;

  with state select in_ready <=
    '1' when IDLE_L0 | IDLE_L4 | LANE0 | LANE4,
    '0' when others;
  proc_align: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= IDLE_L0;
        dic <= 0;
      else
        state <= state_next;
        dic <= dic_next;
        ipg <= ipg_next;
      end if;
    end if;

  end process;

  proc_comb: process(all)
    variable keepmod, iw, nextdic: integer;
  begin
    xgmii_d_s <= full_idle;
    xgmii_c_s <= x"ff";
    state_next <= state;
    dic_next <= dic;
    ipg_next <= ipg;
    case state is
      when IDLE_L0 =>
        if in_valid = '1' then
          state_next <= LANE0;
          xgmii_d_s <= sof & in_data(55 downto 0);
          xgmii_c_s <= "10000000";
        end if;
      when IDLE_L4 =>
        if in_valid = '1' then
          state_next <= LANE4;
          xgmii_d_s <= ic & ic & ic & ic & sof & in_data(55 downto 32);
          xgmii_c_s <= "11111000";
        else
          state_next <= IDLE_L0;
        end if;
      when LANE0 | LANE4 =>
        if in_valid_shifted = '1' and in_last_shifted = '1' then
          -- the DIC table (IW is for number of full Idle Words (32 bit) following the partial idle word)
          -- DIC old > | 0              | 1              | 2              | 3              |
          -- Mod v     | IPG | IW | DIC | IPG | IW | DIC | IPG | IW | DIC | IPG | IW | DIC |
          -- ----------+-----+----+-----+-----+----+-----+-----+----+-----+-----+----+-----+
          -- 0         |  12 |  2 |   0 |  12 |  2 |   1 | 12  |  2 |   2 | 12  |  2 |   3 |
          -- 1         |  11 |  1 |   1 |  11 |  1 |   2 | 11  |  1 |   3 | 15  |  2 |   0 |
          -- 2         |  10 |  1 |   2 |  10 |  1 |   3 | 14  |  2 |   0 | 14  |  2 |   1 |
          -- 3         |   9 |  1 |   3 |  13 |  2 |   0 | 13  |  2 |   1 | 13  |  2 |   2 |
          --
          -- 4         |     |  3 |     |     |  2 |     |     |  3 |     |     |  3 |     |
          -- 5         |     |  2 |     |     |  2 |     |     |  2 |     |     |  3 |     |
          -- 6         |     |  2 |     |     |  2 |     |     |  3 |     |     |  3 |     |
          -- 7         |     |  2 |     |     |  3 |     |     |  3 |     |     |  3 |     |
          nextdic := 0;
          for i in 7 downto 0 loop
            keepmod := (7 - i) mod 4;
            if in_keep_shifted(i) = '0' then
              -- 7 - i is the modulus
              nextdic := (keepmod + dic) mod 4;
              iw := 3 when keepmod = 0 or dic = 3 or (dic = 1 and keepmod = 3) or (dic = 2 and keepmod /= 1) else 2;
              if 7 - i < 4 then
                iw := iw - 1; -- 4 bytes in current 64 bit beat free
              end if;
              exit;
            end if;
          end loop;
          dic_next <= nextdic;

          state_next <= FORCE_IDLE when iw /= 1 else IDLE_L4;
          ipg_next <= iw;
        end if;
        xgmii_d_s <= (in_data_shifted and in_data_shifted_mask) or (in_data_shifted_eof and not in_data_shifted_mask);
        xgmii_c_s <= not in_keep_shifted;
        -- M0: TIII IIII     | IIII SDDD   IFG=12 (NEVER +4)
        -- M1: DTII IIII     | IIII SDDD   IFG=11 (or +4 = 15, if dic  = 3)
        -- M2: DDTI IIII     | IIII SDDD   IFG=10 (or +4 = 14, if dic >= 2)
        -- M3: DDDT IIII     | IIII SDDD   IFG=9  (or +4 = 13, if dic >= 1)
        -- M0: DDDD TIII     | IIII IIII   | S..  IFG=12..
        --
        -- rule: if packet ends in second half, we MUST send a whole word of /I/ (FORCE_IDLE)
        --         --> then, the DIC decision is made in FORCE_IDLE
        --       if we are in the first half, it depends on DIC val (see rule above)
        --
        -- if we force an /I/, we can conintue the next packet on lane0, if we do not force
        -- an /I/, we transmit in lane 4 if there is a packet available. otherwise, we switch
        -- to lane 0 after one cycle.
        -- 
      when FORCE_IDLE =>
        state_next <= IDLE_L0 when iw = 2 else IDLE_L4;
    end case;
  end process;

  in_data_shifted <= in_data when state = LANE0 else in_data_r & in_data(63 downto 32);
  in_keep_shifted <= in_keep when state = LANE0 else in_keep_r & in_keep(7 downto 4);
  in_last_shifted <= in_last when state = LANE0 else in_last_r when in_keep(7) = '1' else in_last;
  in_valid_shifted <= in_valid when state = LANE0 else in_valid_r or in_valid when in_keep(7) = '1' else in_valid;
end architecture;
