-------------------------------------------------------------------------------
-- cdc
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsbus
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Makes a simple high-latency CDC on the bus. Additionally
--              integrates a bus supervisor that finishes the transaction if
--              the reset goes high on the subordinate.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;

library dsbus;
use dsbus.types.all;

entity cdc is
  port (
    clk_mngr: in std_logic; -- TODO: think about what happens if the MNGR goes offline... I think we will reset everything in the current design if that happens, but its locally not sane
    clk_sub: in std_logic;
    rst_sub: in std_logic;

    mngr: view axi4l_mngr_v;
    sub: view axi4l_sub_v
  );
end entity;

architecture cdc_arch of cdc is
  signal tmp: std_logic_vector(mngr.rdata'length + 1 downto 0);
  signal intmngr: axi4l_t(
    awaddr(mngr.awaddr'range),
    wdata(mngr.wdata'range),
    araddr(mngr.araddr'range),
    rdata(mngr.rdata'range)
  );
  signal rst_sub_int: std_logic;
begin
  arst_sync_inst: entity ds.arst_sync port map (
    clk => clk_mngr,
    arst => rst_sub,
    rst => rst_sub_int
  );
  block_r: block
    type state_t is (WAIT_FOR_ADDR, WAIT_FOR_DATA);
    signal state: state_t := WAIT_FOR_ADDR;
    signal blocked: std_logic := '0';
  begin
    mngr.arready <= '1' when blocked = '1' else intmngr.arready;
    intmngr.arvalid <= mngr.arvalid;
    intmngr.araddr <= mngr.araddr;

    intmngr.rready <= mngr.rready;
    mngr.rvalid <= '1' when blocked = '1' else intmngr.rvalid;
    mngr.rdata <= intmngr.rdata;
    mngr.rresp <= "10" when blocked = '1' else intmngr.rresp;
    fsm: process(clk_mngr)
    begin
      if rising_edge(clk_mngr) then
        if rst_sub_int = '1' then
          blocked <= '1';
        elsif state = WAIT_FOR_ADDR and mngr.arvalid = '0' then
          blocked <= '0';
        end if;
        case state is
          when WAIT_FOR_ADDR =>
            if mngr.arvalid = '1' and mngr.arready = '1' then
              state <= WAIT_FOR_DATA;
            end if;
          when WAIT_FOR_DATA =>
            if mngr.rvalid = '1' and mngr.rready = '1' then
              state <= WAIT_FOR_ADDR;
            end if;
        end case;
      end if;
    end process;
  end block;

  block_w: block
    type state_t is (WAIT_FOR_ADDR_OR_DATA, WAIT_FOR_ADDR, WAIT_FOR_DATA, WAIT_FOR_RESP);
    signal state: state_t := WAIT_FOR_ADDR_OR_DATA;
    signal blocked: std_logic := '0';
  begin
    mngr.awready <= '1' when blocked = '1' else intmngr.awready;
    intmngr.awvalid <= mngr.awvalid;
    intmngr.awaddr <= mngr.awaddr;

    mngr.wready <= '1' when blocked = '1' else intmngr.wready;
    intmngr.wvalid <= mngr.wvalid;
    intmngr.wdata <= mngr.wdata;

    intmngr.bready <= mngr.bready;
    mngr.bvalid <= '1' when blocked = '1' else intmngr.bvalid;
    mngr.bresp <= "10" when blocked = '1' else intmngr.bresp;

    fsm: process(clk_mngr)
    begin
      if rising_edge(clk_mngr) then
        if rst_sub_int = '1' then
          blocked <= '1';
        elsif state = WAIT_FOR_ADDR_OR_DATA and mngr.awvalid = '0' and mngr.wvalid = '0' then
          blocked <= '0';
        end if;
        case state is
          when WAIT_FOR_ADDR_OR_DATA =>
            if mngr.awvalid = '1' and mngr.awready = '1' and mngr.wvalid = '1' and mngr.wready = '1' then
              state <= WAIT_FOR_RESP;
            elsif mngr.awvalid = '1' and mngr.awready = '1' then
              state <= WAIT_FOR_DATA;
            elsif mngr.wvalid = '1' and mngr.wready = '1' then
              state <= WAIT_FOR_ADDR;
            end if;
          when WAIT_FOR_DATA =>
            if mngr.awvalid = '1' and mngr.awready = '1' then
              state <= WAIT_FOR_RESP;
            end if;
          when WAIT_FOR_ADDR =>
            if mngr.wvalid = '1' and mngr.wready = '1' then
              state <= WAIT_FOR_RESP;
            end if;
          when WAIT_FOR_RESP =>
            if mngr.bvalid = '1' and mngr.bready = '1' then
              state <= WAIT_FOR_ADDR_OR_DATA;
            end if;
        end case;
      end if;
    end process;
  end block;

  sync_raddrinst: entity ds.resync generic map (
    width => intmngr.araddr'length
  ) port map (
    in_clk => clk_mngr,
    arst => rst_sub,
    in_ready => intmngr.arready,
    in_valid => intmngr.arvalid,
    in_data => intmngr.araddr,
    out_clk => clk_sub,
    out_ready => sub.arready,
    out_valid => sub.arvalid,
    out_data => sub.araddr
  );
  sync_rdatainst: entity ds.resync generic map (
    width => intmngr.rdata'length + 2
  ) port map (
    in_clk => clk_sub,
    arst => rst_sub,
    in_ready => sub.rready,
    in_valid => sub.rvalid,
    in_data => sub.rresp & sub.rdata,
    out_clk => clk_mngr,
    out_ready => intmngr.rready,
    out_valid => intmngr.rvalid,
    out_data => tmp
  );
  intmngr.rdata <= tmp(intmngr.rdata'range);
  intmngr.rresp <= tmp(33 downto 32);
  sync_waddrinst: entity ds.resync generic map (
    width => intmngr.awaddr'length
  ) port map (
    in_clk => clk_mngr,
    arst => rst_sub,
    in_ready => intmngr.awready,
    in_valid => intmngr.awvalid,
    in_data => intmngr.awaddr,
    out_clk => clk_sub,
    out_ready => sub.awready,
    out_valid => sub.awvalid,
    out_data => sub.awaddr
  );
  sync_wdatainst: entity ds.resync generic map (
    width => intmngr.wdata'length
  ) port map (
    in_clk => clk_mngr,
    arst => rst_sub,
    in_ready => intmngr.wready,
    in_valid => intmngr.wvalid,
    in_data => intmngr.wdata,
    out_clk => clk_sub,
    out_ready => sub.wready,
    out_valid => sub.wvalid,
    out_data => sub.wdata
  );
  sync_wrespinst: entity ds.resync generic map (
    width => 2
  ) port map (
    in_clk => clk_sub,
    arst => rst_sub,
    in_ready => sub.bready,
    in_valid => sub.bvalid,
    in_data => sub.bresp,
    out_clk => clk_mngr,
    out_ready => intmngr.bready,
    out_valid => intmngr.bvalid,
    out_data => intmngr.bresp
  );
end architecture;
