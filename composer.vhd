-------------------------------------------------------------------------------
-- composer
-------------------------------------------------------------------------------
-- Project:     dreamstream
--
-- Company:     GSI Helmholtz Centre for Heavy Ion Research
-- Author:      M. von Buelow <m.vonbuelow@gsi.de>
--
-- Description: Prepends an header to the start of a packet in an AXI stream.
--
-- WARNING:     Do not put any latency in here. The user can wire user data
--              outside this entity.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ds;
use ds.types.all;

entity composer is
  generic (
    width : integer;
    user  : integer := 8
    );
  port (
    clk : in std_logic;
    rst : in std_logic := '0';

    in_valid : in  std_logic;
    in_data  : in  std_logic_vector(width - 1 downto 0)     := (others => '0');
    in_last  : in  std_logic                                := '1';
    in_ready : out std_logic;
    in_keep  : in  std_logic_vector(width / 8 - 1 downto 0) := (others => '0');
    in_user  : in  std_logic_vector(user - 1 downto 0);

    out_valid : out std_logic;
    out_data  : out std_logic_vector(width - 1 downto 0);
    out_last  : out std_logic;
    out_ready : in  std_logic;
    out_keep  : out std_logic_vector(width / 8 - 1 downto 0)
    );
end;

architecture composer_arch of composer is
  constant bytes_per_elm   : integer := width / 8;
  constant num_words       : integer := (user + width - 1) / width;
  constant shift           : integer := (user mod width);
  constant shift_bytes     : integer := shift / 8;
  constant offset          : integer := (width - shift) mod width;
  constant offset_bytes    : integer := offset / 8;
  signal idx               : std_logic_vector(log2_ceil(num_words + 1) downto 0);
  constant idx_actual_bits : integer := log2_ceil(num_words);

  signal in_user_pad       : std_logic_vector(num_words * width - 1 downto 0)               := (others => '0');
  signal in_user_sliced    : std_logic_vector_array(0 to num_words - 1)(width - 1 downto 0) := (others => (others => '0'));
  signal in_user_cur_slice : std_logic_vector(width - 1 downto 0);

  signal composing, cur_last_word : boolean;

  constant rem_keep : std_logic_vector(shift_bytes - 1 downto 0) := (others => '1');

  signal shifted_data                       : std_logic_vector(in_data'range);
  signal shifted_keep                       : std_logic_vector(in_keep'range);
  signal shifted_valid, shifted_last        : std_logic;
  signal shifter_in_valid, shifter_in_ready : std_logic;

  type state_t is (COMP, PASSTH);
  signal state : state_t := COMP;
begin
  assert user mod 8 = 0 severity failure;

  proc_fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= COMP;
      else
        case state is
          when COMP =>
            if cur_last_word and out_valid = '1' and out_ready = '1' and out_last = '0' then
              state <= PASSTH;
            end if;
          when PASSTH =>
            if out_valid = '1' and out_ready = '1' and out_last = '1' then
              state <= COMP;
            end if;
        end case;
      end if;
    end if;
  end process;
  counter_inst : entity ds.counter generic map (
    user => idx'length,
    max  => num_words - 1
    ) port map (
      clk      => clk,
      rst      => rst,
      in_valid => out_valid and out_ready,
      in_last  => out_last,
      out_user => idx
      );
  composing     <= state = COMP;
  cur_last_word <= idx = std_logic_vector(to_unsigned(num_words - 1, idx'length));

  in_user_pad(in_user'range) <= in_user;
  elmfor : for i in 0 to num_words - 1 generate
    bytefor : for j in 0 to bytes_per_elm - 1 generate
      constant my_idx : integer := i * bytes_per_elm + j - offset_bytes;
    begin
      if0 : if my_idx >= 0 generate
        in_user_sliced(in_user_sliced'length - 1 - i)(j * 8 + 7 downto j * 8) <= in_user(my_idx * 8 + 7 downto my_idx * 8);
      end generate;
    end generate;
  end generate;

  treemux_inst : entity ds.treemux generic map (
    n     => num_words,
    width => width
    ) port map (
      in_data  => in_user_sliced,
      out_data => in_user_cur_slice,
      sel      => unsigned(idx(idx_actual_bits - 1 downto 0))
      );

  keep_shifter_inst : entity ds.keep_shifter generic map (
    width => width,
    shift => shift_bytes
    ) port map (
      clk       => clk,
      in_data   => in_data,
      in_keep   => in_keep,
      in_valid  => shifter_in_valid,
      in_last   => in_last,
      in_ready  => shifter_in_ready,
      out_data  => shifted_data,
      out_valid => shifted_valid,
      out_ready => out_ready,
      out_last  => shifted_last,
      out_keep  => shifted_keep
      );

  ifshift : if shift_bytes /= 0 generate
    shifter_in_valid <= '0'               when composing and not cur_last_word else in_valid;
    in_ready         <= '0'               when composing and not cur_last_word else shifter_in_ready;
    out_valid        <= in_valid          when composing and not cur_last_word else shifted_valid;
    out_last         <= '0'               when composing and not cur_last_word else shifted_last;
    out_keep         <= (others => '1')   when composing and not cur_last_word else rem_keep & shifted_keep(offset_bytes - 1 downto 0) when composing and cur_last_word else shifted_keep;
    out_data         <= in_user_cur_slice when composing and not cur_last_word else in_user_cur_slice(in_user_cur_slice'left downto offset) & shifted_data(offset - 1 downto 0) when composing and cur_last_word else shifted_data;
  else generate
    shifter_in_valid <= '0' when composing else in_valid;
    in_ready         <= '0' when composing and not cur_last_word else
                shifter_in_ready when composing and cur_last_word and in_valid = '1' and in_keep(in_keep'left) = '0' else
                '0'              when composing else
                shifter_in_ready;
    out_valid <= in_valid when composing else shifted_valid;
    out_last  <= '0'      when composing and not cur_last_word else
                '1' when composing and cur_last_word and in_valid = '1' and in_keep(in_keep'left) = '0' else
                '0' when composing else
                shifted_last;
    out_keep <= (others => '1')   when composing else shifted_keep;
    out_data <= in_user_cur_slice when composing else shifted_data;
  end generate;
end architecture;
