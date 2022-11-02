library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity mapping_unit is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port (
		clock			: in  std_ulogic;
		enable		: in  std_ulogic;
		last_period	: in  std_logic_vector(9 downto 0);
		period_on	: in  std_logic_vector(9 downto 0);
		
		data_avail	: out  std_ulogic;
		result		: out std_logic_vector(9 downto 0)
    );
end mapping_unit;

architecture rtl of mapping_unit is

signal enable_div			: std_logic := '0';
--signal step_mul			: std_logic_vector(16 downto 0):= (others => '0');
signal last_period_int	: std_logic_vector(9 downto 0):= (others => '0');
signal period_on_int		: std_logic_vector(9 downto 0):= (others => '0');
signal mul_res				: std_logic_vector(19 downto 0):= (others => '0');
signal mul_res_sig		: std_logic_vector(26 downto 0):= (others => '0');
signal mul_res_100		: std_logic_vector(26 downto 0):= (others => '0');
signal result_int			: std_logic_vector (25 downto 0);

-- internal  clock counter 
signal count_int				: std_logic_vector(2 downto 0) := (others => '0');
signal count_nxt				: std_logic_vector(2 downto 0) := (others => '0');


component mul_period is
	PORT
	(
		clken		: in  std_logic ;
		clock		: in  std_logic ;
		dataa		: in  std_logic_vector (9 downto 0);
		datab		: in  std_logic_vector (9 downto 0);
		result	: out std_logic_vector (19 downto 0)
	);
end component mul_period;

component period_mul is
	PORT
	(
		clken		: in  std_logic ;
		clock		: in  std_logic ;
		dataa		: in  std_logic_vector (9 downto 0);
		datab		: in  std_logic_vector (9 downto 0);
		result	: out std_logic_vector (19 downto 0)
	);
end component period_mul;


component mapping_div is
	PORT
	(
		clken		: in  std_logic ;
		clock		: in  std_logic ;
		denom		: in  std_logic_vector (16 downto 0);
		numer		: in  std_logic_vector (25 downto 0);
		quotient	: out std_logic_vector (25 downto 0);
		remain	: out std_logic_vector (16 downto 0)
	);
end component mapping_div;

component div_mapping_1024 is
	port
	(
		clken		: in  std_logic ;
		clock		: in  std_logic ;
		numer		: in  std_logic_vector (26 downto 0);
		quotient	: out std_logic_vector (25 downto 0)
	);
end component div_mapping_1024;

begin
	
mul_res_sig(mul_res'length-1 downto 0)	<= mul_res;
mul_res_100	<= std_logic_vector((shift_left(unsigned(mul_res_sig), 6) + shift_left(unsigned(mul_res_sig), 5) + shift_left(unsigned(mul_res_sig), 2)));		
-- CRITICAL!!!
--step_mul		<= std_logic_vector(shift_left(to_unsigned(PWM_STEPS-1,step_mul'length), 6) + shift_left(to_unsigned(PWM_STEPS-1,step_mul'length), 5) + shift_left(to_unsigned(PWM_STEPS-1,step_mul'length), 2));	
	mul_unit: mul_period 
		port map(
			clken		=> enable,
			clock		=> clock,
			dataa 	=> period_on_int,
			datab		=> last_period_int,
			result	=> mul_res
		 );	
--		 
--	mul_unit: period_mul 
--		port map(
--			clken		=> enable,
--			clock		=> clock,
--			dataa 	=> period_on_int,
--			datab		=> last_period_int,
--			result	=> mul_res
--		 );	
--		 
--	div_map: mapping_div 
--		port map(
--			clken		=> enable_div,
--			clock		=> clock,
--			denom 	=> std_logic_vector(shift_left(to_unsigned(PWM_STEPS-1,17), 6) + shift_left(to_unsigned(PWM_STEPS-1,17), 5) + shift_left(to_unsigned(PWM_STEPS-1,17), 2))	,
--			numer		=> mul_res_100,
--			quotient	=> result_int,
--			remain	=> open -- not in use
--		 );	
		 

	div_map: div_mapping_1024 
		port map(
			clken		=> enable_div,
			clock		=> clock,
			numer		=> mul_res_100,
			quotient	=> result_int
		 );	
		 
	ff:
		process(clock)
				begin	
					if rising_edge(clock) then
						count_int	<= count_nxt;
					end if;
	end process ff;
		 
	en:
		process(enable,period_on,result_int,last_period,count_int)
				begin	
					if enable = '1' then
						if unsigned(period_on) > 0 then
							result			<= result_int(result'length-1 downto 0);		
						else
							result			<= (others => '0');
						end if;
						--period_on_int		<= std_logic_vector(shift_left(unsigned(period_on), 6) + shift_left(unsigned(period_on), 5) + shift_left(unsigned(period_on), 2)); 
						period_on_int		<= period_on;
						last_period_int	<= std_logic_vector(unsigned(last_period));
						if unsigned(count_int) < 3 then
							count_nxt		<= std_logic_vector(unsigned(count_int) + 1); 
							enable_div		<= '0';
							data_avail		<= '0';
						elsif unsigned(count_int) < 4 then
							count_nxt		<= std_logic_vector(unsigned(count_int) + 1); 
							data_avail		<= '0';
							enable_div		<= '1';
						else
							enable_div		<= '1';
							count_nxt		<= count_int;
							data_avail		<= '1';
						end if;
					else
						enable_div			<= '0';
						data_avail			<= '0';
						count_nxt			<= (others => '0');	
						result				<= (others => '0');	
						period_on_int		<= (others => '0');	
						last_period_int	<= (others => '0');	
					end if;
	end process en;	

end rtl;
