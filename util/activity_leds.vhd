library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity activity_leds is
  generic (
    w           : integer  := 1;
    clk_freq_hz : positive := 125_000_000;  -- Hz
    led_freq_hz : positive := 30            -- Hz
    );
  port (
    CLK       : in  std_logic;
    RST       : in  std_logic;
    SIG_IN    : in  std_logic_vector(w - 1 downto 0);
    ACTIVE_IN : in  std_logic_vector(w - 1 downto 0) := (others => '1');
    LED_OUT   : out std_logic_vector(w - 1 downto 0)
    );
end activity_leds;

architecture RTL of activity_leds is

  constant C_DIVISOR : natural                          := clk_freq_hz / led_freq_hz;
  signal counter     : natural range 0 to C_DIVISOR - 1 := 0;
  signal slow_tick   : std_logic                        := '0';

  signal sig_r        : std_logic_vector(w - 1 downto 0);
  signal activity_led : std_logic_vector(w - 1 downto 0);  -- history status of low


-------------------------------------------------------------------------------
begin  -- BEGIN -- BEGIN -- BEGIN -- BEGIN -- BEGIN -- BEGIN --
-------------------------------------------------------------------------------

  p_CLK_DIV : process
  begin
    wait until rising_edge(CLK);
    if rst = '1' then
      counter   <= 0;
      slow_tick <= '0';
    elsif counter = C_DIVISOR-1 then
      counter   <= 0;
      slow_tick <= '1';
    else
      counter   <= counter + 1;
      slow_tick <= '0';
    end if;
  end process;


  g_ACTIVITY_LEDS : for i in 0 to w-1 generate
  begin
    p_ACTIVITY_LED : process(CLK)
    begin
      if rising_edge(CLK) then
        if SIG_IN(i) = '1' then
          sig_r(i) <= '1';
        end if;

        if slow_tick = '1' then
          activity_led(i) <= not activity_led(i) or not sig_r(i);
          sig_r(i)        <= '0';
        end if;
      end if;
    end process;
    LED_OUT(i) <= activity_led(i) and ACTIVE_IN(i);
  end generate;

end RTL;
