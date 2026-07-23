-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Two-phase handshaking CDC for resynchronizing a vector of correlated data from one clock
-- domain to another.
-- Features an AXI-Stream-like handshaking interface on both the ``input`` and ``result`` side.
--
-- .. figure:: resync_twophase_handshake_transparent.png
--
-- In many ways this entity is a superset of :ref:`resync.resync_twophase`, so see that
-- for some more insight.
-- But this one features ``ready``/``valid`` handshaking, which enables backpressure but increases
-- :ref:`resync.resync_twophase_handshake.resource_utilization` slightly.
--
-- .. note::
--   This entity has a scoped constraint file
--   `resync_twophase_handshake.tcl <https://github.com/hdl-modules/hdl-modules/blob/main/modules/resync/scoped_constraints/resync_twophase_handshake.tcl>`__
--   that must be used for proper operation.
--   See :ref:`here <scoped_constraints>` for instructions.
--
-- Note that unlike e.g. :ref:`resync.resync_level`, it is safe to drive the input of this entity
-- with LUTs as well as FFs.
--
--
-- Latency
-- _______
--
-- The latency from ``input`` to ``result`` is less than or equal to
--
--   period(in_clk) + 3 * period(out_clk),
--
--
-- Throughput
-- __________
--
-- The sampling period (inverse of throughput) of is roughly equal to
--
--   3 * period(in_clk) + 3 * period(out_clk).
--
-- If ``out_ready`` is stalling, new ``input`` can be sampled before the previous
-- ``result`` is sent out, which aids throughput in this scenario.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library ds;

entity resync is
  generic (
    width: positive
  );
  port (
    in_clk, arst: in std_ulogic;
    in_ready: out std_ulogic := '0';
    in_valid: in std_ulogic;
    in_data: in std_ulogic_vector(width - 1 downto 0);
    --# {{}}
    out_clk: in std_ulogic;
    out_ready: in std_ulogic;
    out_valid: out std_ulogic := '0';
    out_data: out std_ulogic_vector(width - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of resync is
  attribute dont_touch: string;
  attribute async_reg: string;

  signal in_data_sampled, out_data_int: std_ulogic_vector(in_data'range) := (others => '0');

  -- We apply constraints to these two signals, and they are crucial for the function of the CDC.
  -- Do not allow the tool to optimize these or move any logic.
  attribute dont_touch of in_data_sampled: signal is "true";
  attribute dont_touch of out_data_int: signal is "true";

  signal in_level_p1: std_ulogic := '0';
  signal out_level_m1, out_level, out_level_handshake: std_ulogic := '0';
  -- Different default value than the others, to trigger the first 'in_ready' event.
  signal in_level_m1, in_level, out_level_feedback: std_ulogic := '1';

  -- These two feed async_reg chains, and it is absolutely crucial that they are driven by FFs.
  -- So place attribute on them so that build tool does not optimize/modify anything.
  attribute dont_touch of in_level_p1: signal is "true";
  attribute dont_touch of out_level_feedback: signal is "true";

  -- Ensure FFs are not optimized/modified, and placed in the same slice to minimize MTBF.
  attribute async_reg of in_level_m1: signal is "true";
  attribute async_reg of in_level: signal is "true";
  attribute async_reg of out_level_m1: signal is "true";
  attribute async_reg of out_level: signal is "true";

  signal in_rst, out_rst: std_logic;
begin

  arst_sync_in_inst: entity ds.arst_sync port map (
    clk => in_clk,
    arst => arst,
    rst => in_rst
  );
  arst_sync_out_inst: entity ds.arst_sync port map (
    clk => out_clk,
    arst => arst,
    rst => out_rst
  );

  ------------------------------------------------------------------------------
  handle_input: process(in_clk)
  begin
    if rising_edge(in_clk) then
      if in_rst = '1' then
        in_level <= '1';
        in_level_m1 <= '1';
        in_level_p1 <= '0';
      else

        if in_ready then
          -- Sample regardless of 'valid' or not. Is handled below.
          in_data_sampled <= in_data;
        end if;

        if in_valid then
          -- If we have 'in_ready', this assignment will
          -- 1. lower 'in_ready'.
          -- 2. toggle the level to the 'result' side, indicating that a new data word is available.
          --
          -- If 'in_ready' is low, this assignment does nothing.
          in_level_p1 <= in_level;
        end if;

        -- CDC path into async_reg chain.
        in_level <= in_level_m1;
        in_level_m1 <= out_level_feedback;
      end if;
    end if;
  end process;

  in_ready <= in_level xor in_level_p1;


  ------------------------------------------------------------------------------
  handle_result: process(out_clk)
  begin
    if rising_edge(out_clk) then
      if out_rst = '1' then
        out_valid <= '0';
        out_level_feedback <= '1';
        out_level_m1 <= '0';
        out_level <= '0';
        out_level_handshake <= '0';
      else
        -- A new result level means that there is new data sampled on the 'input' side.
        -- Sample it and send it out, but NOT if we still have an older data word that has not
        -- been popped yet.
        -- This backpressure mechanism adds a FF and few LUTs but roughly doubles the throughput in
        -- some scenarios.
        if (out_level xor out_level_handshake) and not out_valid then
          out_valid <= '1';

          -- Parallel CDC path.
          out_data_int <= in_data_sampled;

          -- We have now sampled the data on the 'result' side, update the feedback level so
          -- the the 'input' side can sample a new value there.
          -- Regardless of whether the 'result' data word has been sent out or not.
          out_level_feedback <= not out_level_feedback;
        end if;

        if out_ready and out_valid then
          out_valid <= '0';

          -- Toggle the level so that valid is not raised again until we have new 'input' data.
          out_level_handshake <= not out_level_handshake;
        end if;

        -- CDC path into async_reg chain.
        out_level <= out_level_m1;
        out_level_m1 <= in_level_p1;
      end if;
    end if;
  end process;

  out_data <= out_data_int;

end architecture;
