-----------------------------------------------------------
-- 	Human-Computer Interaction Group
-- 	Leibniz University Hannover
-----------------------------------------------------------
-- project:			Waveganerator
--	file :			counter.vhdl
--	authors :		Maximilian Schrapel	
--	last update :	08/2018
--	description :	General purpose Counter
--						When enabled, the counter does what it does
-----------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity counter is
	generic (
		MAX_VALUE	: integer := 512  -- Number of Steps
	);
	port (
		clock 		: in  	std_ulogic;
		reset			: in 		std_ulogic;
		
		set_count	: in 		std_ulogic;
		count_new	: in   	std_ulogic_vector((integer(ceil(log2(real(MAX_VALUE*1)))))-1 downto 0);

		enable		: in   	std_ulogic;
		count			: out   	std_ulogic_vector((integer(ceil(log2(real(MAX_VALUE*1)))))-1 downto 0)
    );
end counter;

architecture rtl of counter is

signal count_sig		: std_ulogic_vector((integer(ceil(log2(real(MAX_VALUE*1)))))-1 downto 0) := (others => '0');
signal count_nxt		: std_ulogic_vector((integer(ceil(log2(real(MAX_VALUE*1)))))-1 downto 0) := (others => '0');


begin
count <= count_sig;

	ff:
		process(reset,clock)
				begin	
					if reset = '1' then
						count_sig	<= (others => '0');						
					elsif rising_edge(clock) then
						count_sig	<= count_nxt;
					end if;
	end process ff;	

	ctr:
		process(enable,count_sig,set_count,count_new)
				begin		
					if enable = '1' then
						count_nxt <= std_ulogic_vector( unsigned(count_sig) + 1 );
						-- ! only uncomment if you dont use full steps ! 
--					elsif unsigned(count_sig) = to_unsigned(MAX_VALUE-1,count_sig'length) then
--						count_nxt <= (others => '0');	
					else
						if set_count = '1' then
							count_nxt <= count_new;
						else
							count_nxt <= count_sig;
						end if;
					end if;	
	end process ctr;	
	
end architecture rtl;
