library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity div_step is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port
	(
		clken		: in std_logic ;
		clock		: in std_logic ;
		numer		: in  std_logic_vector (19 downto 0);
		quotient	: out std_logic_vector (19 downto 0);
		remain	: out std_logic_vector (10 downto 0)
	);
end div_step;

architecture rtl of div_step is
signal quotient_int : std_logic_vector (quotient'length-1 downto 0);
signal remain_int : std_logic_vector (quotient'length-1 downto 0);
begin
	quotient	<= quotient_int;
	remain	<= remain_int(remain'length-1 downto 0);
	ff:
		process(clken,numer,clock)
				begin	
					if rising_edge(clock) then
						if clken = '1' then
							quotient_int	<= std_logic_vector(shift_right(unsigned(numer),1+integer(ceil(log2(real(PWM_STEPS*1))))));
						else
							quotient_int	<= (others => '0');
						end if;
					end if;
	end process ff; 

	ff2:
		process(quotient_int,numer,clken)	
			begin
				if clken = '1' then
					remain_int	<= std_logic_vector(unsigned(numer)-shift_left(unsigned(quotient_int),1+integer(ceil(log2(real(PWM_STEPS*1))))));
				else
					remain_int	<= (others => '0');
				end if;
	end process ff2; 
	
end rtl;