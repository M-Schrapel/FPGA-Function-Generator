library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.log2;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity rom_reader_testbench is
	generic (
		PWM_STEPS	: integer := 1024;  -- Number of Steps
		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 255;	 -- Amplitude Divider (100 steps + gain)
		MAX_FREQ		: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 5	 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
		--CALC_TICKS	: integer := 5		 -- internal number of clocks until result is valid
	);
end rom_reader_testbench;

architecture rtl of rom_reader_testbench is

signal clock  				: std_ulogic :=  '0';
signal reset  				: std_ulogic :=  '0';

signal data_request  	: std_ulogic :=  '0';
signal data_request_nxt : std_ulogic :=  '0';

signal function_sel		: std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS))))-1 downto 0) := (others => '0');
signal function_sel_nxt	: std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS))))-1 downto 0) := (others => '0');


signal frequency			: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0) := (others => '0');
signal frequency_nxt		: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0) := (others => '0');

signal step					: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal step_nxt			: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');

signal factor				: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
signal factor_nxt			: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
			
signal data_avail			: std_ulogic :=  '0';
signal period_on			: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0) := (others => '0');
signal n_periods			: std_ulogic_vector(16 downto 0);
signal last_period		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal last_period_on	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		
signal write_custom		: std_ulogic :=  '0';
signal address				: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal pwm_value			: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');


component rom_reader is
	generic (
		PWM_STEPS	: integer := 512;  -- Number of Steps
		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 256;	 -- Amplitude Divider (100 steps + gain)
		MAX_FREQ		: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 5	 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
		--CALC_TICKS	: integer := 5		 -- internal number of clocks until result is valid
	);
	port(
		clock				: in  std_ulogic := '0';
		reset				: in  std_ulogic := '0';
		
		data_request	: in  std_ulogic := '0';
		function_sel	: in  std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS))))-1 downto 0) := (others => '0');
		frequency		: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
		step				: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		factor			: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
		
		data_avail		: out std_ulogic;
		period_on		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods		: out std_ulogic_vector(16 downto 0);
		last_period		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on	: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		
		
		write_custom	: in  std_ulogic := '0';
		address			: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		pwm_value		: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0')
	);
end component rom_reader;

begin

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

	rom_reader_inst : rom_reader
		generic map(
			PWM_STEPS	=> PWM_STEPS,
			CLOCK_MHZ	=> CLOCK_MHZ,
			AMP_STEPS	=> AMP_STEPS,
			MAX_FREQ		=> MAX_FREQ,
			NUM_FUNCS	=> NUM_FUNCS
			--CALC_TICKS	=> CALC_TICKS
		)
		port map(
			clock				=> clock,
			reset				=> reset,
			
			data_request	=> data_request,
			function_sel	=> function_sel,
			frequency		=> frequency,
			step				=> step,
			factor			=> factor,
			
			data_avail		=> data_avail,
			period_on		=> period_on,
			n_periods		=> n_periods,
			last_period		=> last_period,
			last_period_on	=> last_period_on,
			
			write_custom	=> write_custom,
			address			=> address,
			pwm_value		=> pwm_value
		 );

	ff:
		process(reset,clock)
				begin	
					if reset = '1' then
						function_sel	<= (others => '0');	
						frequency		<= (others => '0');	
						step				<= (others => '0');	
						data_request	<= '0';
						factor			<= std_ulogic_vector( to_unsigned(100,factor'length) + 0 );
					elsif rising_edge(clock) then
						function_sel	<= function_sel_nxt;
						frequency		<= frequency_nxt;
						step				<= step_nxt;
						data_request	<= data_request_nxt;
						--factor			<= factor_nxt;
						factor			<= std_ulogic_vector( to_unsigned(100,factor'length) + 0 );
					end if;
	end process ff;	
		 
	ctr:
		process(data_avail,function_sel,step,factor,frequency)
				begin		
					if data_avail = '0' then
						data_request_nxt 		<= '1';
						function_sel_nxt	<= function_sel;
						step_nxt	<= step;
						factor_nxt	<= factor;
						frequency_nxt	<= frequency;
					else
						data_request_nxt 		<= '0';
--						function_sel_nxt	<= std_ulogic_vector( unsigned(function_sel) + 1 );
						if unsigned(function_sel) < 4 then
							if data_request 	= '0' then
								function_sel_nxt	<= std_ulogic_vector( unsigned(function_sel) + 1 );
							else
								function_sel_nxt	<= function_sel;	
							end if;
						else
							function_sel_nxt	<= (others => '0');	
						end if;	
						step_nxt	<= std_ulogic_vector( unsigned(step) + 1 );
						factor_nxt	<= std_ulogic_vector( unsigned(factor) + 0 );
						--frequency_nxt	<= std_ulogic_vector( unsigned(frequency) + 1 );
						frequency_nxt	<= std_ulogic_vector( to_unsigned(1,frequency_nxt'length) );
					end if;	
	end process ctr;	
	
end rtl;