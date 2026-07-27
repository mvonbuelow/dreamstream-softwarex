-------------------------------------------------------------------------------
-- rx_mac
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

entity rx_mac_aligner is
  generic (
    width: integer := 64
  );
  port (
    clk: in std_logic;
    rst: in std_logic := '0';

    xgmii_d: in std_logic_vector(width - 1 downto 0);
    xgmii_c: in std_logic_vector(width / 8 - 1 downto 0);


    out_valid: out std_logic;
    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_last: out std_logic;
    out_user: out std_logic_vector(32 downto 0);
  );
end;

architecture rx_mac_aligner_arch of rx_mac_aligner is
  constant sof: std_logic_vector(7 downto 0) := x"fb";
  constant eof: std_logic_vector(7 downto 0) := x"fd";

  type state_t is (IDLE, LANE0, LANE4, LANE0_S, LANE4_S);
  signal state: state_t := IDLE;
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
begin
  xgmii_d_s <= swap_chunks(xgmii_d, 8);
  xgmii_c_s <= swap_chunks(xgmii_c, 1);

  xgmii_d_r <= xgmii_d_s when rising_edge(clk);
  xgmii_c_r <= xgmii_c_s when rising_edge(clk);
  xgmii_d_rr <= xgmii_d_r when rising_edge(clk);
  xgmii_c_rr <= xgmii_c_r when rising_edge(clk);

  proc_align: process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= IDLE;
      else
        case state is
          when IDLE =>
            if xgmii_d_s(63 downto 56) = sof and xgmii_c_s(7) = '1' then
              state <= LANE0_S;
            elsif xgmii_d_s(31 downto 24) = sof and xgmii_c_s(3) = '1' then
              state <= LANE4_S;
            end if;
          when LANE0 | LANE4 | LANE0_S | LANE4_S =>
            state <= LANE0 when state = LANE0 or state = LANE0_S else LANE0;
            if out_last = '1' then
              state <= IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;
  proc_eof: process(all)
  begin
    out_user(32) <= '0';
    for i in 7 downto 0 loop
      if aligned_c_lookahead(i) = '1' then
        -- dbg <= aligned_d_lookahead(i * 8 + 7 downto i * 8);
        out_user(31 downto 0) <= swap_chunks(aligned_d_lookahead((i + 5) * 8 - 1 downto(i + 1) * 8), 8); -- FCS is not in network byte order
        if aligned_d_lookahead(i * 8 + 7 downto i * 8) /= eof then
          out_user(32) <= '1';
        end if;
        exit;
      end if;
    end loop;
  end process;

  aligned_d_lookahead <= xgmii_d_r(63 downto 0) & xgmii_d_s(63 downto 24) when state = LANE4 or state = LANE4_S else xgmii_d_rr(31 downto 0) & xgmii_d_r(63 downto 0) & xgmii_d_s(63 downto 56);
  aligned_c_lookahead <= xgmii_c_r(7 downto 0) & xgmii_c_s(7 downto 3) when state = LANE4 or state = LANE4_S else xgmii_c_rr(3 downto 0) & xgmii_c_r(7 downto 0) & xgmii_c_s(7 downto 7);

  first_byte_d <= aligned_d_lookahead(71 downto 64) when state = LANE0 or state = LANE4 else x"55";
  first_byte_k <= not aligned_c_lookahead(8) when state = LANE0 or state = LANE4 else '1';

  out_data <= first_byte_d & aligned_d_lookahead(63 downto 8);
  out_keep <= first_byte_k & not aligned_c_lookahead(7 downto 1);
  out_valid <= '1' when state = LANE0 or state = LANE4 or state = LANE0_S or state = LANE4_S else '0';
  out_last <= '1' when unsigned(aligned_c_lookahead(7 downto 0)) /= 0 else '0';
end architecture;
