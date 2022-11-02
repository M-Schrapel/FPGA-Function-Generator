library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity gain_unit is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port (
		clock			: in  std_ulogic;
		enable		: in  std_ulogic;
		amp			: in  std_ulogic_vector(7 downto 0);
		period_on	: in  std_logic_vector(9 downto 0);
		period_in	: in  std_logic_vector(9 downto 0);
		data_avail	: out std_logic;
		period		: out std_logic_vector(9 downto 0)
    );
end gain_unit;

architecture rtl of gain_unit is

signal mul_res			: std_logic_vector(24 downto 0):= (others => '0');
signal amp_int			: std_logic_vector(7 downto 0):= (others => '0');
signal period_on_int	: std_logic_vector(16 downto 0):= (others => '0');
signal result_int		: std_logic_vector(16 downto 0):= (others => '0');

signal period_on_tmp : std_logic_vector(16 downto 0):= (others => '0');

signal count_int				: std_logic_vector(2 downto 0) := (others => '0');
signal count_nxt				: std_logic_vector(2 downto 0) := (others => '0');


signal enable_div		: std_logic := '0';
signal result_fin		: std_logic_vector (16 downto 0);

component amp_mul is
	port
	(
		clken		: in  std_logic ;
		clock		: in  std_logic ;
		dataa		: in  std_logic_vector (16 downto 0);
		datab		: in  std_logic_vector (7 downto 0);
		result	: out std_logic_vector (24 downto 0)
	);
end component amp_mul;


component amp_div is
	port
	(
		clken		: in  std_logic ;
		clock		: in  std_logic ;
		denom		: in  std_logic_vector (7 downto 0);
		numer		: in  std_logic_vector (16 downto 0);
		quotient	: out std_logic_vector (16 downto 0);
		remain	: out std_logic_vector (7 downto 0)
	);
end component amp_div;

component div_100 is
	port
	(
		clken		: in  std_logic ;
		clock		: in  std_logic ;
		--denom		: in  std_logic_vector (7 downto 0);
		numer		: in  std_logic_vector (16 downto 0);
		quotient	: out std_logic_vector (16 downto 0)
		--remain	: out std_logic_vector (7 downto 0)
	);
end component div_100;

begin
	period_on_tmp(period_on'length-1 downto 0)	<= period_on;

	gain_pwm: amp_mul 
		port map(
			clken		=> enable,
			clock		=> clock,
			dataa 	=> period_on_int,
			datab		=> amp_int,
			result	=> mul_res
		 );	
		 
--	gain_div: amp_div 
--		port map(
--			clken		=> enable_div,
--			clock		=> clock,
--			denom 	=> std_logic_vector (to_unsigned(100,amp_int'length)),
--			numer		=> result_int,
--			quotient	=> result_fin,
--			remain	=> open -- not in use
--		 );	
--		 
	gain_div: div_100 
		port map(
			clken		=> enable_div,
			clock		=> clock,
			numer		=> result_int,
			quotient	=> result_fin
		 );	
		 
	ff:
		process(clock)
				begin	
					if rising_edge(clock) then
						count_int	<= count_nxt;
					end if;
	end process ff; 

	en:
		process(enable,mul_res,period_on_tmp,amp,count_int,result_fin,period_on,period_in)
				begin	
					if enable = '1' then
						result_int		<= mul_res(result_int'length-1 downto 0);
						period_on_int	<= period_on_tmp;
						amp_int			<= std_logic_vector(unsigned(amp));
						if unsigned(count_int) < 2 then
							count_nxt		<= std_logic_vector(unsigned(count_int) + 1); 
							enable_div		<= '0';
							data_avail		<= '0';
							period			<= (others => '0');
						else
							enable_div		<= '1';
							if unsigned(count_int) < 3 then
								count_nxt		<= count_int;
								data_avail		<= '1';
--								if unsigned(result_fin) <= unsigned(period_in) then
--									if unsigned(amp) >= 100 then
--										if unsigned(result_fin(period'length-1 downto 0)) < unsigned(period_on) then
--											period	<= (others => '1');
--										else
--											period	<= result_fin(period'length-1 downto 0);
--										end if;
--									else
--										if unsigned(result_fin(period'length-1 downto 0)) > unsigned(period_on) then
--											period	<= (others => '0');
--										else
--											period	<= result_fin(period'length-1 downto 0);
--										end if;
--									end if;
									period	<= result_fin(period'length-1 downto 0);
--								else	
--									period	<= period_in;
--								end if;
							else
								count_nxt		<= std_logic_vector(unsigned(count_int) + 1); 
								data_avail		<= '0';
								period			<= (others => '0');
							end if;
						end if;
					else
						enable_div		<= '0';
						data_avail		<= '0';
						count_nxt		<= (others => '0');	
						result_int		<= (others => '0');
						period_on_int	<= (others => '0');
						amp_int			<= (others => '0');
						period			<= (others => '0');
					end if;
	end process en;	
end architecture rtl;