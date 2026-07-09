-------------------------------------------------------------------------------
-- crossbar
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsbus
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: An AXI4L crossbar. Currently, only one manager is supported.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;
library dsbus;
use dsbus.types.all;

entity crossbar is
  generic (
    addr_off : integer := 0;
    addr_len : integer := 0
    );
  port (
    clk : in std_logic;
    rst : in std_logic;


    mngr : view axi4l_mngr_v;
    subs : view (axi4l_sub_v) of axi4l_array_t
    );
end entity;

architecture crossbar_arch of crossbar is
  constant w : integer := subs'length;
  signal intmngr : axi4l_t(
    awaddr(mngr.awaddr'range),
    wdata(mngr.wdata'range),
    araddr(mngr.araddr'range),
    rdata(mngr.rdata'range)
    );

  constant addr_len_int : integer := ite_i(addr_len = 0, log2_ceil(w), addr_len);
begin
  reg_inst : entity dsbus.reg port map (
    clk  => clk,
    rst  => rst,
    mngr => mngr,
    sub  => intmngr
    );
  bl_read : block
    signal cur_read_addr, cur_read_addr_next                   : std_logic_vector(mngr.araddr'range)   := (others => '0');
    type state_t is (IDLE, WAIT_FOR_ADDRESS, WAIT_FOR_DATA);
    signal rstate, rstate_next                                 : state_t                               := IDLE;
    constant treemux_addr_w                                    : integer                               := log2_ceil(w);
    signal int_raddr                                           : unsigned(treemux_addr_w - 1 downto 0) := (others => '0');
    signal full_raddr                                          : unsigned(addr_len_int - 1 downto 0)   := (others => '0');
    signal resp_read_mux                                       : std_logic_vector_array(0 to w - 1)(35 downto 0);
    signal err_raddr                                           : std_logic;
    signal intmngr_read_valid_mux, intmngr_read_addr_ready_mux : std_logic;
    signal intmngr_read_resp_data_mux                          : std_logic_vector(1 downto 0);
  begin
    int_raddr  <= unsigned(cur_read_addr(int_raddr'length - 1 + addr_off downto addr_off));
    full_raddr <= unsigned(cur_read_addr(full_raddr'length - 1 + addr_off downto addr_off));

    genr : for i in 0 to w - 1 generate
      subs(i).arvalid <= '1' when rstate = WAIT_FOR_ADDRESS and err_raddr = '0' and (treemux_addr_w = 0 or int_raddr = i)   else '0';
      subs(i).rready  <= '1' when rstate = WAIT_FOR_DATA and intmngr.rready = '1' and (treemux_addr_w = 0 or int_raddr = i) else '0';

      resp_read_mux(i) <= subs(i).rresp & subs(i).arready & subs(i).rvalid & subs(i).rdata;
      subs(i).araddr   <= cur_read_addr;
    end generate;

    err_raddr <= '1' when full_raddr > w - 1 else '0';

    treemuxr_inst : entity ds.treemux generic map (
      n     => w,
      width => 36
      ) port map (
        in_data                => resp_read_mux,
        out_data(31 downto 0)  => intmngr.rdata,
        out_data(32)           => intmngr_read_valid_mux,
        out_data(33)           => intmngr_read_addr_ready_mux,
        out_data(35 downto 34) => intmngr_read_resp_data_mux,
        sel                    => int_raddr
        );
    intmngr.arready <= '0'                        when rstate /= IDLE          else '1';
    intmngr.rvalid  <= '0'                        when rstate /= WAIT_FOR_DATA else intmngr_read_valid_mux when err_raddr = '0' else '1';
    intmngr.rresp   <= intmngr_read_resp_data_mux when err_raddr = '0'         else "11";

    intmngr_proc_sync : process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          rstate        <= IDLE;
          cur_read_addr <= (others => '0');
        else
          rstate        <= rstate_next;
          cur_read_addr <= cur_read_addr_next;
        end if;
      end if;
    end process;
    intmngr_proc_comb : process(all)
    begin
      rstate_next        <= rstate;
      cur_read_addr_next <= cur_read_addr;
      case (rstate) is
        when IDLE =>
          if intmngr.arvalid = '1' then
            cur_read_addr_next <= intmngr.araddr;
            rstate_next        <= WAIT_FOR_ADDRESS;
          end if;
        when WAIT_FOR_ADDRESS =>
          if intmngr_read_addr_ready_mux = '1' or err_raddr = '1' then
            rstate_next <= WAIT_FOR_DATA;
          end if;
        when WAIT_FOR_DATA =>
          if intmngr.rvalid = '1' and intmngr.rready = '1' then
            rstate_next <= IDLE;
          end if;
      end case;
    end process;
  end block;
  bl_write : block
    signal cur_write_addr, cur_write_addr_next                                                 : std_logic_vector(mngr.awaddr'range)   := (others => '0');
    type state_t is (IDLE, WAIT_FOR_ADDRESS_OR_DATA, WAIT_FOR_ADDRESS, WAIT_FOR_DATA, WAIT_FOR_RESP);
    signal wstate, wstate_next                                                                 : state_t                               := IDLE;
    constant treemux_addr_w                                                                    : integer                               := log2_ceil(w);
    signal int_waddr                                                                           : unsigned(treemux_addr_w - 1 downto 0) := (others => '0');
    signal full_waddr                                                                          : unsigned(addr_len_int - 1 downto 0)   := (others => '0');
    signal resp_write_mux                                                                      : std_logic_vector_array(0 to w - 1)(1 downto 0);
    signal err_waddr                                                                           : std_logic;
    signal intmngr_write_ready_mux, intmngr_write_addr_ready_mux, intmngr_write_resp_valid_mux : std_logic;
    signal intmngr_write_resp_data_mux                                                         : std_logic_vector(1 downto 0);

    signal resp_write_resp_data  : std_logic_vector_array(0 to w - 1)(1 downto 0);
    signal resp_write_resp_valid : std_logic_vector(w - 1 downto 0);
  begin

    int_waddr  <= unsigned(cur_write_addr(int_waddr'length - 1 + addr_off downto addr_off)) when treemux_addr_w /= 0 else (others => '0');
    full_waddr <= unsigned(cur_write_addr(full_waddr'length - 1 + addr_off downto addr_off));

    genr : for i in 0 to w - 1 generate
      subs(i).awvalid <= '1' when (wstate = WAIT_FOR_ADDRESS_OR_DATA or wstate = WAIT_FOR_ADDRESS) and err_waddr = '0' and (treemux_addr_w = 0 or int_waddr = i)                       else '0';
      subs(i).wvalid  <= '1' when (wstate = WAIT_FOR_ADDRESS_OR_DATA or wstate = WAIT_FOR_DATA) and err_waddr = '0' and intmngr.wvalid = '1' and (treemux_addr_w = 0 or int_waddr = i) else '0';
      subs(i).bready  <= '1' when wstate = WAIT_FOR_RESP and intmngr.bready = '1' and (treemux_addr_w = 0 or int_waddr = i)                                                            else '0';

      resp_write_mux(i) <= subs(i).awready & subs(i).wready;

      subs(i).wdata            <= intmngr.wdata;
      subs(i).awaddr           <= cur_write_addr;
      resp_write_resp_data(i)  <= subs(i).bresp;
      resp_write_resp_valid(i) <= subs(i).bvalid;
    end generate;

    err_waddr <= '1' when full_waddr > w - 1 else '0';

    treemuxw_inst : entity ds.treemux generic map (
      n     => w,
      width => 2
      ) port map (
        in_data     => resp_write_mux,
        out_data(0) => intmngr_write_ready_mux,
        out_data(1) => intmngr_write_addr_ready_mux,
        sel         => int_waddr
        );
    intmngr.awready <= '0' when wstate /= IDLE                                                 else '1';
    intmngr.wready  <= '0' when wstate /= WAIT_FOR_DATA and wstate /= WAIT_FOR_ADDRESS_OR_DATA else intmngr_write_ready_mux when err_waddr = '0' else '1';
    treemuxb_inst : entity ds.treemux generic map (
      n     => w,
      width => 2
      ) port map (
        in_data   => resp_write_resp_data,
        in_valid  => resp_write_resp_valid,
        out_data  => intmngr_write_resp_data_mux,
        out_valid => intmngr_write_resp_valid_mux,
        sel       => int_waddr
        );
    intmngr.bvalid <= '0'                         when wstate /= WAIT_FOR_RESP else intmngr_write_resp_valid_mux when err_waddr = '0' else '1';
    intmngr.bresp  <= intmngr_write_resp_data_mux when err_waddr = '0'         else "11";

    intmngr_proc_sync : process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          wstate         <= IDLE;
          cur_write_addr <= (others => '0');
        else
          wstate         <= wstate_next;
          cur_write_addr <= cur_write_addr_next;
        end if;
      end if;
    end process;
    intmngr_proc_comb : process(all)
    begin
      wstate_next         <= wstate;
      cur_write_addr_next <= cur_write_addr;
      case (wstate) is
        when IDLE =>
          if intmngr.awvalid = '1' then
            cur_write_addr_next <= intmngr.awaddr;
            wstate_next         <= WAIT_FOR_ADDRESS_OR_DATA;
          end if;
        when WAIT_FOR_ADDRESS_OR_DATA =>
          if intmngr_write_addr_ready_mux = '1' and intmngr.wvalid = '1' and intmngr.wready = '1' then
            wstate_next <= WAIT_FOR_RESP;
          elsif intmngr_write_addr_ready_mux = '1' or err_waddr = '1' then
            wstate_next <= WAIT_FOR_DATA;
          elsif intmngr.wvalid = '1' and intmngr.wready = '1' then
            wstate_next <= WAIT_FOR_RESP;
          end if;
        when WAIT_FOR_ADDRESS =>
          if intmngr_write_addr_ready_mux = '1' or err_waddr = '1' then
            wstate_next <= WAIT_FOR_DATA;
          end if;
        when WAIT_FOR_DATA =>
          if intmngr.wvalid = '1' and intmngr.wready = '1' then
            wstate_next <= WAIT_FOR_RESP;
          end if;
        when WAIT_FOR_RESP =>
          if intmngr.bvalid = '1' and intmngr.bready = '1' then
            wstate_next <= IDLE;
          end if;
      end case;
    end process;
  end block;
end architecture;
