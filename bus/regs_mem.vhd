-------------------------------------------------------------------------------
-- regs_mem
-------------------------------------------------------------------------------
-- Project:     dreamstream/dsbus
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: This is a RW reg with an additional internal address port.
--              Everything will be stored in a block ram, so you can allocate
--              512 registers or so without any trouble. If width is bigger
--              than the bus width, it will be serialized onto the bus address
--              space. MSBs get lower addresses than LSBs (big endian).
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;
use ds.types.all;
library dsbus;
use dsbus.types.all;

entity regs_mem is
  generic (
    n            : integer                                                := 8;
    width        : integer                                                := 32;
    addr_off     : integer                                                := 0;
    addr_len     : integer                                                := 1;
    reg_defaults : std_logic_vector_array(0 to n - 1)(width - 1 downto 0) := (others => (others => '1'))
    );
  port (
    clk : in std_logic;
    rst : in std_logic;

    reg : view axi4l_mngr_v;

    int_read_addr_valid : in  std_logic := '0';
    int_read_addr_data  : in  unsigned(integer(log2_ceil(n)) - 1 downto 0);
    int_read_data       : out std_logic_vector(width - 1 downto 0);

    int_write_addr_valid : in std_logic                                    := '0';
    int_write_addr_data  : in unsigned(integer(log2_ceil(n)) - 1 downto 0) := (others => '0');
    int_write_data       : in std_logic_vector(width - 1 downto 0)         := (others => '0')
    );
end entity;

architecture regs_mem_arch of regs_mem is
  constant nmems         : integer := (width + 31) / 32;
  constant base_addr_len : integer := log2_ceil(nmems);

  signal subs : axi4l_array_t(0 to nmems - 1)(
    awaddr(reg.awaddr'range),
    wdata(reg.wdata'range),
    araddr(reg.araddr'range),
    rdata(reg.rdata'range)
    ) := (others => axi4l_default(reg.araddr'length, reg.rdata'length));

  function select_slice (vin : std_logic_vector_array; i : integer) return std_logic_vector_array is
    variable vout : std_logic_vector_array(vin'range)(31 downto 0);
  begin
    for j in vin'range loop
      vout(j) := vin(j)(i * 32 + 31 downto i * 32);
    end loop;
    return vout;
  end function;
begin
  assert width mod 32 = 0 severity failure;
  ifone : if nmems <= 1 generate
    connect_inst : entity dsbus.connect port map (
      mngr => reg,
      sub  => subs(0)
      );
  else generate
    crossbar_inst : entity dsbus.crossbar generic map (
      addr_off => addr_off,
      addr_len => base_addr_len
      ) port map (
        clk => clk,
        rst => rst,

        mngr => reg,
        subs => subs
        );
  end generate;
  mult : for i in 0 to nmems - 1 generate
    constant j                                 : integer                                                     := nmems - 1 - i;
    type rstate_t is (IDLE, WAIT_REG, WAIT_FOR_DATA);
    signal rstate, rstate_next                 : rstate_t                                                    := IDLE;
    type wstate_t is (IDLE, WAIT_FOR_DATA, WAIT_FOR_RESP);
    signal wstate, wstate_next                 : wstate_t                                                    := IDLE;
    signal cur_read_addr, cur_read_addr_next   : std_logic_vector(subs(i).araddr'range)                      := (others => '0');
    signal cur_write_addr, cur_write_addr_next : std_logic_vector(subs(i).awaddr'range)                      := (others => '0');
    constant addr_w                            : integer                                                     := integer(log2_ceil(n));
    signal regs                                : std_logic_vector_array(0 to (2 ** addr_w) - 1)(31 downto 0) := select_slice(reg_defaults, j);
    signal int_raddr, mem_raddr                : unsigned(addr_w - 1 downto 0)                               := (others => '0');
    signal full_raddr                          : unsigned(addr_len - base_addr_len - 1 downto 0)             := (others => '0');
    signal int_waddr, mem_waddr                : unsigned(addr_w - 1 downto 0)                               := (others => '0');
    signal full_waddr                          : unsigned(addr_len - base_addr_len - 1 downto 0)             := (others => '0');
    signal err_raddr, err_waddr                : std_logic;

    signal mem_write_data, mem_read_data, mem_read_data_q : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_write_en                  : std_logic;

    attribute syn_ramstyle         : string;
    attribute syn_ramstyle of regs : signal is "block_ram";
  begin
    int_raddr  <= unsigned(cur_read_addr_next(int_raddr'length - 1 + addr_off + base_addr_len downto addr_off + base_addr_len));
    full_raddr <= unsigned(cur_read_addr_next(full_raddr'length - 1 + addr_off + base_addr_len downto addr_off + base_addr_len));
    int_waddr  <= unsigned(cur_write_addr_next(int_waddr'length - 1 + addr_off + base_addr_len downto addr_off + base_addr_len));
    full_waddr <= unsigned(cur_write_addr_next(full_waddr'length - 1 + addr_off + base_addr_len downto addr_off + base_addr_len));

    err_raddr <= '1' when full_raddr > n - 1 else '0';
    err_waddr <= '1' when full_waddr > n - 1 else '0';

    proc_mem : process(clk)
    begin
      if rising_edge(clk) then
        if mem_write_en = '1' then
          regs(to_integer(mem_waddr)) <= mem_write_data;
        end if;
        mem_read_data <= regs(to_integer(mem_raddr));
        mem_read_data_q <= mem_read_data;
      end if;
    end process;

    subs(i).rdata                            <= mem_read_data_q;
    int_read_data(j * 32 + 31 downto j * 32) <= mem_read_data;
    mem_raddr                                <= int_raddr when int_read_addr_valid = '0' else int_read_addr_data;

    mem_write_data <= subs(i).wdata when int_write_addr_valid = '0' else int_write_data(j * 32 + 31 downto 32 * j);
    mem_write_en   <= subs(i).wvalid or int_write_addr_valid;
    mem_waddr      <= int_waddr     when int_write_addr_valid = '0' else int_write_addr_data;

    subs(i).arready <= '0'  when rstate /= IDLE                                       else '1';
    subs(i).rvalid  <= '0'  when rstate /= WAIT_FOR_DATA or int_read_addr_valid = '1' else '1';
    subs(i).rresp   <= "00" when err_raddr = '0'                                      else "11";

    subs(i).awready <= '0'  when wstate /= IDLE                                        else '1';
    subs(i).wready  <= '0'  when wstate /= WAIT_FOR_DATA or int_write_addr_valid = '1' else '1';
    subs(i).bvalid  <= '0'  when wstate /= WAIT_FOR_RESP                               else '1';
    subs(i).bresp   <= "00" when err_waddr = '0'                                       else "11";

    rctrl_noreg_proc_sync : process(clk)
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
    rctrl_noreg_proc_comb : process(all)
    begin
      rstate_next        <= rstate;
      cur_read_addr_next <= cur_read_addr;
      case (rstate) is
        when IDLE =>
          if subs(i).arvalid = '1' then
            cur_read_addr_next <= subs(i).araddr;
            if subs(i).arready = '1' then
              rstate_next <= WAIT_REG;
            end if;
          end if;
        when WAIT_REG =>
          rstate_next <= WAIT_FOR_DATA;
        when WAIT_FOR_DATA =>
          if subs(i).rvalid = '1' and subs(i).rready = '1' then
            rstate_next <= IDLE;
          end if;
      end case;
    end process;
    wreg_proc_sync : process(clk)
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
    wreg_proc_comb : process(all)
    begin
      wstate_next         <= wstate;
      cur_write_addr_next <= cur_write_addr;
      case (wstate) is
        when IDLE =>
          if subs(i).awvalid = '1' then
            cur_write_addr_next <= subs(i).awaddr;
            if subs(i).awready = '1' then
              wstate_next <= WAIT_FOR_DATA;
            end if;
          end if;
        when WAIT_FOR_DATA =>
          if subs(i).wvalid = '1' and subs(i).wready = '1' then
            wstate_next <= WAIT_FOR_RESP;
          end if;
        when WAIT_FOR_RESP =>
          if subs(i).bvalid = '1' and subs(i).bready = '1' then
            wstate_next <= IDLE;
          end if;
      end case;
    end process;
  end generate;
end architecture;
