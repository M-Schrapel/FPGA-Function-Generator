
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity rect_generator is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port (
		address		: in  	std_logic_vector((integer(ceil(log2(real(PWM_STEPS-1)))))-1 downto 0);
		clken			: in  	std_logic  := '0';
		clock			: in  	std_logic  := '0';
		q				: out   	std_logic_vector((integer(ceil(log2(real(PWM_STEPS-1)))))-1 downto 0)
    );
end rect_generator;

architecture rtl of rect_generator is

signal q_int	: std_logic_vector((integer(ceil(log2(real(PWM_STEPS*1)))))-1 downto 0) := (others => '0');
signal q_nxt	: std_logic_vector((integer(ceil(log2(real(PWM_STEPS*1)))))-1 downto 0) := (others => '0');

begin
q	<= q_int;
	ff:
		process(clock,q_nxt)
				begin	
					if rising_edge(clock) then
						q_int	<= q_nxt;
					end if;
	end process ff;	

rect_gen:
		process(clken,address,q_int)
				begin						
					if clken ='1' then
						if unsigned(address) >= unsigned(shift_right(to_unsigned((PWM_STEPS-1)*1,address'length),1)) then
							q_nxt	<= (others => '0');
						else
							q_nxt	<= (others => '1');	
						end if;
					else
						q_nxt		<= q_int;		
					end if;
	end process rect_gen;

end architecture rtl;