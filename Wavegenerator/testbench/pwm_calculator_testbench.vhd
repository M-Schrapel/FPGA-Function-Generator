library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pwm_calculator_testbench is
	generic (
		PWM_STEPS		: integer := 512;  -- Number of Steps
		CLOCK_MHZ		: integer := 350;   -- Clock signal in MHZ
		AMPLIFY			: integer := 50;  -- Number of Steps
		PERIOD_VAL		: integer := 683594;
		PERIOD_ON_VAL	: integer := 511
	);
--	port(
--		clock_in 			: in  std_ulogic;
--		reset_in				: in 	std_ulogic
--	);
end pwm_calculator_testbench;

architecture rtl of pwm_calculator_testbench is

signal clock				: std_ulogic := '0';
signal reset				: std_ulogic := '0';

signal data_request		: std_ulogic := '0';
signal period_in			: std_logic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0)  := (others => '0');
signal period_on_in		: std_logic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0)  := (others => '0');
signal amp					: std_ulogic_vector(7 downto 0) := (others => '0');
		
signal data_avail			: std_ulogic := '0';
signal period_on			: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0) := (others => '0');
signal n_periods			: std_ulogic_vector(16 downto 0) := (others => '0');
signal last_period		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0) := (others => '0');
signal last_period_on	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0) := (others => '0');

signal count_sig		: std_ulogic_vector((integer(ceil(log2(real(3*1)))))-1 downto 0) := (others => '0');
signal count_nxt		: std_ulogic_vector((integer(ceil(log2(real(3*1)))))-1 downto 0) := (others => '0');

component pwm_calculator is
	generic (
		PWM_STEPS	: integer := 512;  -- Number of Steps
		CLOCK_MHZ	: integer := 50   -- Clock signal in MHZ
	);
	port (
		clock 			: in  std_ulogic;
		reset				: in 	std_ulogic;
	
		data_request	: in  std_ulogic;
		period_in		: in  std_logic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0);
		period_on_in	: in  std_logic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		amp				: in  std_ulogic_vector(7 downto 0);
		
		data_avail		: out std_ulogic;
		period_on		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods		: out std_ulogic_vector(16 downto 0);
		last_period		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on	: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0)
    );
	end component pwm_calculator;

begin
--clock	<= clock_in;
--reset <= reset_in;
period_in		<= std_logic_vector(to_unsigned(PERIOD_VAL*1,period_in'length));
period_on_in	<= std_logic_vector(to_unsigned(PERIOD_ON_VAL*1,period_on_in'length));
amp				<= std_ulogic_vector(to_unsigned(AMPLIFY*1,amp'length));

	gen_reset : process
	begin
		reset <= '1';
		wait for 40 ns;
		reset <= '0';
		wait;
	end process gen_reset;
	
	gen_clock : process
	begin
    clock <= '1';
    wait for 10 ns;
    clock <= '0';
    wait for 10 ns;
	end process gen_clock;
	
	pwm_calc: pwm_calculator 
		generic map(
			PWM_STEPS 	=> PWM_STEPS,
			CLOCK_MHZ	=>	CLOCK_MHZ
		)
		port map(
			clock				=> clock,
			reset				=> reset,
			
			data_request 	=> data_request,
			period_in		=> period_in,
			period_on_in	=> period_on_in,
			amp				=> amp,
			
			data_avail		=> data_avail,
			period_on		=> period_on,
			n_periods		=> n_periods,
			last_period		=> last_period,
			last_period_on	=> last_period_on
		 );	 
		 
	ff:
		process(reset,clock)
				begin	
					if reset = '1' then
						count_sig	<= (others => '0');						
					elsif rising_edge(clock) then
						count_sig	<= count_nxt;
					end if;
	end process ff;
		 
	gen_com : process(reset,data_avail,count_sig)
	begin
	 if reset = '0' then
		 if data_avail = '0' then
			if unsigned(count_sig) = 0 then
				data_request	<= '1';
				count_nxt		<= (others => '0');		
			else
				data_request	<= '0';
				count_nxt		<= (others => '0');		
			end if;
		 else
			if unsigned(count_sig) > 0 then
				data_request	<= '0';
				count_nxt		<= (others => '0');
			else
				data_request	<= '1';
				count_nxt <= std_ulogic_vector( unsigned(count_sig) + 1 );
			end if;
		 end if;
	 else
		data_request	<= '0';
		count_nxt		<= (others => '0');	
	 end if;
	end process gen_com;
	
end rtl;