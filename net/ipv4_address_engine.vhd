-------------------------------------------------------------------------------
-- ipv4_address_engine
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsnet
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This entity handles the addresses under which the module
--              is accessible. In practice, this is the
--              * device IP,
--              * the broadcast address from the device subnet,
--              * the limited broadcast address (255.255.255.255), and
--              * all registered multicast addresses (stored in block RAM).
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;
library dsnet;
library dsbus;
use dsbus.types.all;

entity ipv4_address_engine is
  generic (
    width: integer := 64;
    user: integer := 8;
    clk_freq: real := 156.25;
    igmp_refresh: time := 10 sec
  );
  port (
    clk: in std_logic;
    rst: in std_logic;

    in_data: in std_logic_vector(width - 1 downto 0);
    in_keep: in std_logic_vector(width / 8 - 1 downto 0);
    in_dest: in std_logic_vector(31 downto 0); -- the ip address to be checked
    in_id: in std_logic_vector(79 downto 0);
    in_user: in std_logic_vector(user - 1 downto 0);
    in_valid: in std_logic;
    in_ready: out std_logic;
    in_last: in std_logic;

    out_data: out std_logic_vector(width - 1 downto 0);
    out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    out_dest: out std_logic_vector(31 downto 0); -- the ip address to be checked
    out_id: out std_logic_vector(79 downto 0);
    out_user: out std_logic_vector(user downto 0);
    out_valid: out std_logic;
    out_ready: in std_logic;
    out_last: out std_logic;

    mc_out_data: out std_logic_vector(width - 1 downto 0);
    mc_out_keep: out std_logic_vector(width / 8 - 1 downto 0);
    mc_out_dest: out std_logic_vector(79 downto 0);
    mc_out_user: out std_logic_vector(23 downto 0);
    mc_out_valid: out std_logic;
    mc_out_ready: in std_logic;
    mc_out_last: out std_logic;

    my_address, my_subnetmask: in std_logic_vector(31 downto 0);
    my_valid: in std_logic;
    reg: view axi4l_mngr_v
  );
end entity;

architecture net_ipv4_address_engine_arch of ipv4_address_engine is
  constant regbits: integer := 10;
  constant nregs: integer := 2 ** regbits;
  signal ip, ip_x: std_logic_vector(31 downto 0) := (others => '0');
  signal filter_ip_valid_x, igmp_ip_valid_x: std_logic := '0';
  signal filter_ip_valid, igmp_ip_valid: std_logic := '0';
  signal ip_req, filter_ip_req, igmp_ip_req_valid, igmp_ip_req_ready: std_logic;
  signal ip_idx, filter_ip_idx, igmp_ip_idx: unsigned(regbits - 1 downto 0) := (others => '0');
begin
  regs_ip_inst: entity dsbus.regs_mem generic map (
    n => nregs,
    width => 32,
    addr_off => 0,
    addr_len => regbits,
    reg_defaults => (0 => x"EF0a141e", others => (others => '0'))
  ) port map (
    clk => clk,
    rst => rst,
    reg => reg,
    int_read_addr_data => ip_idx,
    int_read_addr_valid => ip_req,
    int_read_data => ip_x
  );

  ip_idx <= filter_ip_idx when filter_ip_req = '1' else igmp_ip_idx;
  ip_req <= filter_ip_req or igmp_ip_req_valid;

  ip <= ip_x when rising_edge(clk);
  filter_ip_valid_x <= filter_ip_req when rising_edge(clk);
  igmp_ip_req_ready <= not filter_ip_req;
  igmp_ip_valid_x <= igmp_ip_req_valid and igmp_ip_req_ready when rising_edge(clk); -- filter has prio; we can take long time to send igmp reports
  filter_ip_valid <= filter_ip_valid_x when rising_edge(clk);
  igmp_ip_valid <= igmp_ip_valid_x when rising_edge(clk);

  bl_igmp: block
    type state_t is (REQ, RESP, SEND, TIMEOUT);
    signal state: state_t := REQ;
    constant ticks_ms: integer := integer(clk_freq * 1000.0);
    signal clk_en_sec: std_logic := '0';
    --signal timectr_ms             : integer range 0 to ticks_ms - 1 := 0;
    signal timectr_ms: unsigned( (log2_ceil(ticks_ms + 1) - 1) downto 0) := (others => '0');
    constant ticks: integer := integer(igmp_refresh / 1 ms);
    --signal timeoutctr              : integer range 0 to ticks - 1;
    signal timeoutctr: unsigned( (log2_ceil(ticks + 1) - 1) downto 0) := (others => '0');
    signal ip_eof: std_logic;
    signal checksum, checksum_next: unsigned(15 downto 0);
    constant igmp_magic: std_logic_vector(15 downto 0) := x"1600";
    signal grprec_ready, send_igmp: std_logic;
    signal igmp_rst: std_logic;
  begin
    igmp_rst <= rst or not my_valid;
    proc_time_sec: process(clk)
    begin
      if rising_edge(clk) then
        clk_en_sec <= '0';
        if igmp_rst = '1' then
          timectr_ms <= (others => '0');
        else
          if timectr_ms = ticks_ms then
            timectr_ms <= (others => '0');
            clk_en_sec <= '1';
          else
            timectr_ms <= timectr_ms + 1;
          end if;
        end if;
      end if;
    end process;
    ip_eof <= '1' when ip = x"00000000" else '0';
    igmp_ip_req_valid <= '1' when state = REQ else '0';
    net_ip_chksum_inst: entity dsnet.internet_checksum generic map (
      width => 64
    ) port map (
      data => unsigned(igmp_magic) & x"0000" & unsigned(ip),
      chksum => checksum_next
    );

    send_igmp <= '1' when state = SEND else '0';
    composer_inst: entity ds.composer generic map (
      width => width,
      user => 64
    ) port map (
      clk => clk,
      rst => igmp_rst,
      in_valid => send_igmp,
      in_ready => grprec_ready,
      in_user => igmp_magic & std_logic_vector(not checksum) & ip,
      out_valid => mc_out_valid,
      out_data => mc_out_data,
      out_last => mc_out_last,
      out_ready => mc_out_ready,
      out_keep => mc_out_keep
    );
    mc_out_dest <= x"01005e" & '0' & ip(22 downto 0) & ip;
    mc_out_user(23 downto 16) <= x"02";
    mc_out_user(15 downto 0) <= x"0008";
    proc_fsm: process(clk)
    begin
      if rising_edge(clk) then
        if igmp_rst = '1' then
          state <= REQ;
          igmp_ip_idx <= (others => '0');
          checksum <= unsigned(igmp_magic);
        else
          case state is
            when REQ =>
              if igmp_ip_req_ready = '1' then
                state <= RESP;
              end if;
            when RESP =>
              if igmp_ip_valid = '1' then
                if ip_eof then
                  state <= TIMEOUT;
                  igmp_ip_idx <= (others => '0');
                  timeoutctr <= (others => '0');
                else
                  state <= SEND;
                end if;
                checksum <= checksum_next;
              end if;
            when SEND =>
              if grprec_ready = '1' then
                state <= REQ;
                igmp_ip_idx <= igmp_ip_idx + 1;
              end if;
            when TIMEOUT =>
              if clk_en_sec = '1' then
                if timeoutctr = ticks - 1 then
                  state <= REQ;
                else
                  timeoutctr <= timeoutctr + 1;
                end if;
              end if;
            end case;
        end if;
      end if;
    end process;
  end block;

  bl_filter: block
    type state_t is (IDLE, CHECK_BC, ACCEPT, CHECK_MC, REJ);
    signal state: state_t := IDLE;
    signal full_bc: std_logic_vector(my_address'range) := (others => '1');
  begin
    filter_ip_req <= '1' when state = CHECK_MC else '0';

    proc_fsm: process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          state <= IDLE;
          filter_ip_idx <= (others => '0');
        else
          case state is
            when IDLE => -- use in_dest here, because in_dest_r is not available yet
              if in_valid = '1' then
                if in_dest = my_address then
                  state <= ACCEPT;
                elsif in_dest(31 downto 28) = "1110" then
                  state <= CHECK_MC;
                  filter_ip_idx <= (others => '0');
                else
                  state <= CHECK_BC;
                end if;
              end if;
            when CHECK_BC =>
              if in_valid = '1' then
                if in_dest = full_bc then
                  state <= ACCEPT;
                elsif (in_dest and my_subnetmask) = (my_address and my_subnetmask) and (in_dest and not my_subnetmask) = (full_bc and not my_subnetmask) then
                  state <= ACCEPT;
                  -- elsif in_dest_r = x"e0000001" then  -- Multicast "all hosts" (224.0.0.1)
                  --   state <= ACCEPT;
                else
                  state <= REJ;
                end if;
              end if;
            when CHECK_MC =>
              filter_ip_idx <= filter_ip_idx + 1;
              if filter_ip_valid = '1' then
                if ip = x"00000000" then
                  state <= REJ;
                elsif ip = in_dest then
                  state <= ACCEPT;
                end if;
              end if;
            when ACCEPT | REJ => -- TODO: when ACCEPT | REJ | CHECK_MC strange NVC error
              if out_valid = '1' and out_ready = '1' and out_last = '1' then
                state <= IDLE;
              end if;
            end case;
        end if;
      end if;
    end process;
    out_valid <= '1' when in_valid = '1' and (state = ACCEPT or state = REJ) else '0';
    in_ready <= '1' when out_ready = '1' and (state = ACCEPT or state = REJ) else '0';
    out_data <= in_data;
    out_keep <= in_keep;
    out_last <= in_last;
    out_dest <= in_dest;
    out_id <= in_id;
    out_user(out_user'left - 1 downto 0) <= in_user;
    out_user(out_user'left) <= '1' when state = REJ else '0';
  end block;
end architecture;
