library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity div_mapping_1024 is
	port
	(
		clken		: in  std_logic ;
		clock		: in  std_logic ;
		numer		: in  std_logic_vector (26 downto 0);
		quotient	: out std_logic_vector (25 downto 0)
	);
end div_mapping_1024;


architecture rtl of div_mapping_1024 is

signal res_mul_tmp	: std_logic_vector (49 downto 0):= (others => '0'); -- *102300
signal numer_tmp		: std_logic_vector (49 downto 0):= (others => '0'); -- *102300
signal quotient_int	: std_logic_vector (49 downto 0):= (others => '0');
signal quotient_tmp	: std_logic_vector (49 downto 0):= (others => '0');

begin
	quotient_int		<= std_logic_vector(shift_right(unsigned(res_mul_tmp),16));
	numer_tmp(numer'length-1 downto 0)	<= numer;
	numer_tmp(numer_tmp'length-1 downto numer'length) <= (others => '0');
	quotient_tmp		<= std_logic_vector(shift_right(unsigned(quotient_int),20));
	quotient		<= quotient_tmp(quotient'length-1 downto 0);
	
	ff:
		process(clken,numer_tmp,clock)
				begin	
					if rising_edge(clock) then
						if clken = '1' then
							res_mul_tmp	<= std_logic_vector(unsigned(numer_tmp) + shift_left(unsigned(numer_tmp),14) + shift_left(unsigned(numer_tmp),17) + shift_left(unsigned(numer_tmp),19));
--						else
--							res_mul_tmp	<= (others => '0');
						end if;
					end if;
	end process ff; 

end rtl;