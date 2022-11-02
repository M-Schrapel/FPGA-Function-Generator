
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity rect_generator is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port (
		address		: in  	std_logic_vector (9 downto 0) := (others => '0');
		clken			: in  	std_logic  := '0';
		q				: out   	std_logic_vector((integer(ceil(log2(real(PWM_STEPS*1)))))-1 downto 0)
    );
end rect_generator;

architecture rtl of rect_generator is

begin

rect_gen:
		process(clken,address)
				begin						
					if clken ='1' then
						if unsigned(address) >= shift_left(to_unsigned(PWM_STEPS,address'length),1) then
							q	<= (others => '0');
						else
							q	<= (others => '1');	
						end if;
					else
						q		<= (others => '0');		
					end if;
	end process rect_gen;

end rtl;