-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Synchronize a counter value between two domains using Gray-coded values.
-- Converts the binary input counter word to Gray code, resynchronizes it to the
-- output clock domain with an ``async_reg`` chain, and converts it back to a binary number.
--
-- .. figure:: resync_counter_transparent.png
--
-- Note that unlike e.g. :ref:`axi.resync_cnt`, it is safe to drive the input of this entity
-- with LUTs as well as FFs.
--
-- .. note::
--       This entity has a scoped constraint file
--       `resync_counter.tcl <https://github.com/hdl-modules/hdl-modules/blob/main/modules/resync/scoped_constraints/resync_counter.tcl>`__
--       that must be used for proper operation.
--       See :ref:`here <scoped_constraints>` for instructions.
--
-- .. warning::
--       This entity assumes that the input counter value only increments and decrements in steps
--       of one.
--       Erroneous values can appear on the output if this is not followed.
--
-- See the
-- `constraint file <https://github.com/hdl-modules/hdl-modules/blob/main/modules/resync/scoped_constraints/resync_counter.tcl>`__
-- and
-- `this article <https://www.linkedin.com/pulse/reliable-cdc-constraints-2-counters-fifos-lukas-vik-ist5c>`__
-- for information about timing constraints and how this CDC topology is made reliable.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ds;

entity resync_counter is
  generic (
    width                         : positive;
    -- Initial value for the output that will be set for a few cycles before the first input
    -- value has propagated.
    default_value                 : unsigned(width - 1 downto 0) := (others => '0');
    -- Optional pipeline step on the output after Gray conversion
    -- This CDC topology fails if the input counter jumps by more than one each clock cycle.
    -- Optionally disable the assertion that this never happens.
    assert_false_on_counter_jumps : boolean                      := true
    );
  port (
    clk_in, rst_in   : in  std_logic;
    counter_in       : in  unsigned(default_value'range);
    --# {{}}
    clk_out, rst_out : in  std_logic;
    counter_out      : out unsigned(default_value'range) := default_value
    );
end entity;

architecture a of resync_counter is
  function to_gray(value : unsigned) return std_logic_vector is
    variable value_slv, result : std_logic_vector(value'range) := (others => '0');
  begin
    value_slv := std_logic_vector(value);
    result    := value_slv xor "0" & value_slv(value_slv'high downto 1);
    return result;
  end function;

  function from_gray(code : std_logic_vector) return unsigned is
    variable result : unsigned(code'range) := (others => '0');
  begin
    result(code'high) := code(code'high);
    for bit_num in code'high - 1 downto 0 loop
      result(bit_num) := result(bit_num + 1) xor code(bit_num);
    end loop;

    return result;
  end function;

  subtype binary_integer_t is integer range 0 to 1;
  function to_int(value : std_logic) return binary_integer_t is
  begin
    if value = '1' then
      return 1;
    end if;
    return 0;
  end function;
  function count_ones(data : std_logic_vector) return natural is
    variable result : natural range 0 to data'length := 0;
  begin
    for bit_idx in data'range loop
      result := result + to_int(data(bit_idx));
    end loop;
    return result;
  end function;


  function hamming_distance(data1, data2 : std_logic_vector) return natural is
    constant xor_value : std_logic_vector(data1'range)   := data1 xor data2;
    constant result    : natural range 0 to data1'length := count_ones(xor_value);
  begin
    assert data1'length = data2'length report "Arguments must be of equal length" severity failure;
    return result;
  end function;

  signal counter_in_gray, counter_in_gray_p1, counter_out_gray : std_logic_vector(
    counter_in'range
    ) := to_gray(default_value);

  -- These feed async_reg chains, and it is absolutely crucial that they are driven by FFs.
  -- So place attribute on them so that build tool does not optimize/modify anything.
  attribute dont_touch                    : string;
  attribute dont_touch of counter_in_gray : signal is "true";

  -- Ensure FFs are not optimized/modified, and placed in the same slice to minimize MTBF.
  attribute async_reg                       : string;
  attribute async_reg of counter_in_gray_p1 : signal is "true";
  attribute async_reg of counter_out_gray   : signal is "true";



begin

  ------------------------------------------------------------------------------
  clk_in_process : process
  begin
    wait until rising_edge(clk_in);

    if assert_false_on_counter_jumps then
      assert hamming_distance(to_gray(counter_in), counter_in_gray) <= 1
                                                                       report "Counter jumped by more than one";
    end if;

    if rst_in = '1' then
      counter_in_gray <= to_gray(default_value);
    else
      counter_in_gray <= to_gray(counter_in);
    end if;
  end process;


  ------------------------------------------------------------------------------
  clk_out_process : process
  begin
    wait until rising_edge(clk_out);

    if rst_out = '1' then
      counter_out_gray   <= to_gray(default_value);
      counter_in_gray_p1 <= to_gray(default_value);
    else
      counter_out_gray   <= counter_in_gray_p1;
      counter_in_gray_p1 <= counter_in_gray;
    end if;
  end process;


  ------------------------------------------------------------------------------

  counter_out <= from_gray(counter_out_gray);


end architecture;


-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Asynchronous (two clocks) First In First Out (FIFO) data buffering stage with AXI-Stream-like
-- handshaking interface.
-- Supports ``last``, packet mode and ``in_drop`` just like the
-- :ref:`synchronous FIFO <fifo.fifo>`.
-- The implementation is quite optimized with very low resource utilization when extra features
-- are not enabled.
--
-- .. figure:: asynchronous_fifo_circuit.png
--
-- For more CDC solutions, please see :ref:`module_resync`.
--
-- .. note::
--       This entity has a scoped constraint file
--       `asynchronous_fifo.tcl <https://github.com/hdl-modules/hdl-modules/blob/main/modules/fifo/scoped_constraints/asynchronous_fifo.tcl>`__
--       that must be used for proper operation.
--       See :ref:`here <scoped_constraints>` for instructions.
--       This entity also instantiates :ref:`axi.resync_counter` which has a further constraint file
--       that must be used.
--
-- .. warning::
--       In case ``enable_output_register`` is set, the implementation does not keep track of
--       the exact level on the write side. When there is no word in the output register,
--       e.g when the FIFO is empty, the ``in_cnt`` reported will be one higher than the
--       real level.
--
-- See the
-- `constraint file <https://github.com/hdl-modules/hdl-modules/blob/main/modules/fifo/scoped_constraints/asynchronous_fifo.tcl>`__
-- and
-- `this article <https://www.linkedin.com/pulse/reliable-cdc-constraints-5-asynchronous-fifo-lukas-vik-snlgf>`__
-- for information about timing constraints and how this CDC topology is made reliable.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;


entity async_fifo is
  generic (
    width              : positive;
    depth              : positive;
    enable_last        : boolean := false;
    enable_packet_mode : boolean := false;
    enable_drop        : boolean := false
    );
  port (
    in_clk   : in  std_logic;
    in_rst   : in  std_logic                := '0';
    in_ready : out std_logic                := '1';
    in_valid : in  std_logic;
    in_last  : in  std_logic                := '0';
    in_data  : in  std_logic_vector(width - 1 downto 0);
    in_cnt   : out natural range 0 to depth := 0;
    in_drop  : in  std_logic                := '0';


    out_clk   : in  std_logic;
    out_rst   : in  std_logic                            := '0';
    out_ready : in  std_logic;
    out_valid : out std_logic                            := '0';
    out_last  : out std_logic                            := '0';
    out_data  : out std_logic_vector(width - 1 downto 0) := (others => '0');
    out_cnt   : out natural range 0 to depth             := 0
    );
end entity;

architecture async_fifo_arch of async_fifo is

  constant memory_depth : positive := depth;

  subtype fifo_addr_t is unsigned(log2_ceil(2 * memory_depth - 1) - 1 downto 0);
  signal out_addr_next, in_addr : fifo_addr_t := (others => '0');

  subtype bram_addr_range is natural range log2_ceil(memory_depth - 1) - 1 downto 0;

  signal out_valid_pre     : std_logic   := '0';
  signal num_lasts_written : fifo_addr_t := (others => '0');
begin

  in_block : block
    signal in_addr_next, in_addr_next_if_not_drop, in_addr_start_of_packet : fifo_addr_t := (others => '0');
    signal out_addr_resync                                                 : fifo_addr_t := (others => '0');
  begin
    in_status : process
    begin
      wait until rising_edge(in_clk);

      if in_rst = '1' then
        in_ready                <= '1';
        in_addr                 <= (others => '0');
        in_cnt                  <= 0;
        num_lasts_written       <= (others => '0');
        in_addr_start_of_packet <= (others => '0');
      else

        if enable_drop then
          num_lasts_written <= num_lasts_written + ite_i((in_ready and in_valid and in_last and not in_drop) = '1', 1, 0);
        else
          num_lasts_written <= num_lasts_written + ite_i((in_ready and in_valid and in_last) = '1', 1, 0);
        end if;

        in_ready <= ite_l(out_addr_resync(bram_addr_range) /= in_addr_next_if_not_drop(bram_addr_range) or (out_addr_resync(out_addr_resync'high) = in_addr_next_if_not_drop(in_addr_next'high)), '1', '0');

        if enable_drop then
          if (not in_drop) and in_ready and in_valid and in_last then
            in_addr_start_of_packet <= in_addr_next;
          end if;
        end if;

        in_addr <= in_addr_next;
        in_cnt  <= (to_integer(in_addr_next - out_addr_resync) mod (2 * memory_depth));
      end if;
    end process;

    in_addr_next_if_not_drop <= in_addr + ite_i((in_ready and in_valid) = '1', 1, 0);
    in_addr_next             <= in_addr_start_of_packet when enable_drop and in_drop = '1' else in_addr_next_if_not_drop;


    resync_out_addr : entity ds.resync_counter
      generic map (
        width => out_addr_next'length
        )
      port map (
        clk_in      => out_clk,
        rst_in      => out_rst,
        counter_in  => out_addr_next,
        clk_out     => in_clk,
        rst_out     => in_rst,
        counter_out => out_addr_resync
        );

  end block;


  out_block : block
    signal in_addr_resync, out_addr                                    : fifo_addr_t := (others => '0');
    signal num_lasts_read, num_lasts_written_resync, num_lasts_in_fifo : fifo_addr_t := (others => '0');
  begin
    out_status : process
      variable out_cnt_next       : natural range 0 to depth := 0;
      variable num_lasts_out_next : fifo_addr_t              := (others => '0');
    begin
      wait until rising_edge(out_clk);

      if out_rst = '1' then
        out_addr       <= (others => '0');
        out_cnt        <= 0;
        num_lasts_read <= (others => '0');
        out_valid_pre  <= '0';
      else
        out_addr <= out_addr_next;
        if not enable_packet_mode then
          out_cnt_next := to_integer(in_addr_resync - out_addr_next) mod (2 * memory_depth);

          out_cnt <= out_cnt_next;
        end if;

        if enable_packet_mode then
          num_lasts_out_next := num_lasts_read + ite_i((out_ready and out_valid and out_last) = '1', 1, 0);
          out_valid_pre      <= ite_l(num_lasts_out_next /= num_lasts_written_resync, '1', '0');

          num_lasts_read <= num_lasts_out_next;
        else
          out_valid_pre <= ite_l(out_cnt_next /= 0, '1', '0');
        end if;
      end if;
    end process;

    out_addr_next <= out_addr + ite_i((out_ready and out_valid) = '1', 1, 0);

    out_valid <= out_valid_pre;


    resync_in_addr : if not enable_packet_mode generate

      resync_counter_inst : entity ds.resync_counter
        generic map (
          width => in_addr'length
          )
        port map (
          clk_in      => in_clk,
          rst_in      => in_rst,
          counter_in  => in_addr,
          clk_out     => out_clk,
          rst_out     => out_rst,
          counter_out => in_addr_resync
          );

    end generate;

    resync_num_lasts_written : if enable_packet_mode generate
      resync_counter_inst : entity ds.resync_counter
        generic map (
          width => num_lasts_written'length
          )
        port map (
          clk_in      => in_clk,
          rst_in      => in_rst,
          counter_in  => num_lasts_written,
          clk_out     => out_clk,
          rst_out     => out_rst,
          counter_out => num_lasts_written_resync
          );
    end generate;
  end block;


  memory : block
    constant memory_word_width : positive := width + ite_i(enable_last, 1, 0);
    subtype word_t is std_logic_vector(memory_word_width - 1 downto 0);
    type mem_t is array (natural range <>) of word_t;

    signal mem : mem_t(0 to memory_depth - 1) := (others => (others => '0'));

    signal memory_out_data, memory_in_data : word_t := (others => '0');
  begin

    out_data                      <= memory_out_data(out_data'range);
    memory_in_data(in_data'range) <= in_data;

    assign_data : if enable_last generate
      out_last                            <= memory_out_data(memory_out_data'high);
      memory_in_data(memory_in_data'high) <= in_last;
    end generate;


    in_memory : process
    begin
      wait until rising_edge(in_clk);

      if in_ready and in_valid then
        mem(to_integer(in_addr(bram_addr_range))) <= memory_in_data;
      end if;
    end process;

    out_memory : process
    begin
      wait until rising_edge(out_clk);

      memory_out_data <= mem(to_integer(out_addr_next(bram_addr_range)));
    end process;

  end block;
end architecture;
