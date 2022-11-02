library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity div_100 is
	port
	(
		clken		: in  std_logic ;
		clock		: in  std_logic ;
		numer		: in  std_logic_vector (17 downto 0);
		quotient	: out std_logic_vector (17 downto 0)
	);
end div_100;


architecture rtl of div_100 is

signal quotient_int 	: std_logic_vector(32 downto 0) := (others => '0');
signal numer_int 		: std_logic_vector(32 downto 0) := (others => '0');

begin

quotient			<= quotient_int(quotient'length-1 downto 0);
numer_int(numer'length-1 downto 0)	<= numer;

	ff:
		process(clken,numer_int,clock)
				begin	
					if rising_edge(clock) then
						if clken = '1' then
							--quotient_int	<= std_logic_vector(shift_right(shift_left(unsigned(numer_int),1) + shift_left(unsigned(numer_int),2) + shift_left(unsigned(numer_int),3) + shift_left(unsigned(numer_int),5) + shift_left(unsigned(numer_int),7) + shift_left(unsigned(numer_int),8) + shift_left(unsigned(numer_int),9) + shift_left(unsigned(numer_int),10) + shift_left(unsigned(numer_int),14) + shift_left(unsigned(numer_int),16),23)+1);
							
							quotient_int	<= std_logic_vector(shift_right(shift_right(
							unsigned(numer_int) +
							shift_left(unsigned(numer_int), 1) + 
							shift_left(unsigned(numer_int), 2) + 
							shift_left(unsigned(numer_int), 3) + 
							shift_left(unsigned(numer_int), 5) + 
							shift_left(unsigned(numer_int), 7) + 
							shift_left(unsigned(numer_int), 8) + 
							shift_left(unsigned(numer_int), 9) + 
							shift_left(unsigned(numer_int),10) + 
							shift_left(unsigned(numer_int),14) 
							,16) + unsigned(numer_int),7));
							--0100011110101111‬
						else
							quotient_int	<= (others => '0');
						end if;
					end if;
	end process ff; 

end rtl;