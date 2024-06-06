library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter_test is
  port(clk:   in std_logic;
       o:     out std_logic_vector(7 downto 0));
end entity;

architecture beh of counter_test is
  signal counter : std_logic_vector(31 downto 0);
begin
  process(clk) is
  begin
    if(rising_edge(clk)) then
      counter <= std_logic_vector(to_unsigned(to_integer(unsigned(counter)) + 2, 32));
      o <= counter(31 downto 24);
    end if;
  end process;
end architecture;
