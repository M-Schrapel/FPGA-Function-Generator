
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity dc_generator is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port (
		en			: in  	std_logic  := '0';
		q			: out   	std_logic_vector((integer(ceil(log2(real(PWM_STEPS-1)))))-1 downto 0)
    );
end dc_generator;

architecture rtl of dc_generator is

begin

dc_gen:
		process(en)
				begin						
					if en ='1' then
						q	<= (others => '1');	
					else
						q	<= (others => '0');		
					end if;
	end process dc_gen;

end architecture rtl;