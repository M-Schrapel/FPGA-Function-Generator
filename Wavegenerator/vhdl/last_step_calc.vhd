library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity last_step_calc is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port (
		clock			: in  std_ulogic;
		enable		: in  std_ulogic;
		period		: in  std_logic_vector(19 downto 0);
		
		nperiods		: out std_logic_vector (16 downto 0);
		last_period	: out std_logic_vector (9 downto 0)
    );
end last_step_calc;

architecture rtl of last_step_calc is

--signal div_periods	: std_logic_vector(10 downto 0);
signal period_int		: std_logic_vector(19 downto 0);
signal result_int		: std_logic_vector(19 downto 0);
--signal remain_int		: std_logic_vector(10 downto 0);
signal remain_sig		: std_logic_vector(10 downto 0);
--
component step_div is
	PORT
	(
		clken		: in std_logic ;
		clock		: in std_logic ;
		denom		: in  std_logic_vector (10 downto 0);
		numer		: in  std_logic_vector (19 downto 0);
		quotient	: out std_logic_vector (19 downto 0);
		remain	: out std_logic_vector (10 downto 0)
	);
end component step_div;

component div_step is
	PORT
	(
		clken		: in std_logic ;
		clock		: in std_logic ;
		numer		: in  std_logic_vector (19 downto 0);
		quotient	: out std_logic_vector (19 downto 0);
		remain	: out std_logic_vector (10 downto 0)
	);
end component div_step;

begin
--div_periods		<= std_logic_vector(to_unsigned(PWM_STEPS*1,div_periods'length));	
--	div_steps: step_div 
--		port map(
--			clken		=> enable,
--			clock		=> clock,
--			denom 	=> std_logic_vector(to_unsigned(PWM_STEPS*1,11)),
--			numer		=> period_int,
--			quotient	=> result_int,
--			remain	=> remain_sig
--		 );	
		 
	div_steps: div_step 
		port map(
			clken		=> enable,
			clock		=> clock,
			numer		=> period_int,
			quotient	=> result_int,
			remain	=> remain_sig
		 );	

	en:
		process(enable,result_int,remain_sig,period)
				begin	
					if enable = '1' then
						nperiods			<= result_int(nperiods'length-1 downto 0);	
						last_period		<= remain_sig(last_period'length-1 downto 0);
						period_int		<= period;	
					else
						nperiods			<= (others => '0');
						last_period		<= (others => '0');
						period_int		<= (others => '1');	
					end if;
	end process en;	


end architecture rtl;