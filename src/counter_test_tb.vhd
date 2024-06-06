library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter_test_tb is
  -- no ports
end entity;

architecture beh of counter_test_tb is
  signal clk_s : std_logic;
  signal out_s : std_logic_vector(7 downto 0);
  component counter_test is port(
    clk: in std_logic;
    o:   out std_logic_vector(7 downto 0));
  end component;
begin
  duv: component counter_test port map(
    clk => clk_s,
    o   => out_s
  );

  clk_gen: process
  begin
    clk_s <= '0', '1' after 1 ns;
    wait for 2 ns;
  end process;

end architecture;
