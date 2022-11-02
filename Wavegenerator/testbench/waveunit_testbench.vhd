library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity waveunit_testbench is
	generic (
		PWM_STEPS	: integer := 20;  -- Number of Steps
		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 100;	 -- Amplitude Divider (100 steps)
		MAX_FREQ		: integer := 300;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 5;	 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
		NPERIODS		: integer := 5;
		LPERIOD		: integer := 5;
		LPERIODON	: integer := 4;
		AMPLIFIER	: integer := 100;
		PERIODON		: integer := 10;
		FREQUENCY	: integer := 250;
		FUNCTIONSEL	: integer := 0;
		REQ_DELAY	: integer := 3	
	);
end entity waveunit_testbench;

architecture rtl of waveunit_testbench is

signal clock				: std_ulogic := '0';
signal reset				: std_ulogic := '0';

signal data_back			: std_ulogic := '0';
signal mul_back			: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
signal period_back		: std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0'); -- Minimum update rate at 1Hz
signal period_on_back	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal frequency_back	: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0) := (others => '0');
		
signal req_enable			: std_ulogic := '0';

signal req_cnt				: std_ulogic_vector(integer(ceil(log2(real(REQ_DELAY*1))))-1 downto 0) := (others => '0');
signal req_cnt_nxt		: std_ulogic_vector(integer(ceil(log2(real(REQ_DELAY*1))))-1 downto 0) := (others => '0');

signal data_request		: std_ulogic := '0';
signal mul_request		: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
signal pwm_step_next		: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal freq_request		: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0) := (others => '0');

signal wave					: std_ulogic := '0';
--signal ack					: std_ulogic := '0';

signal n_periods			: std_ulogic_vector(16 downto 0) := (others => '0');
signal last_period		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0) := (others => '0');
signal last_period_on	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0) := (others => '0');
		
signal function_request	: std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS))))-1 downto 0) := (others => '0');
signal function_back		: std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0) := (others => '0');

		
--signal count_sig			: std_ulogic_vector(3 downto 0);
--signal count_sig_nxt		: std_ulogic_vector(3 downto 0);

	component waveunit is
--	generic (
--		PWM_STEPS	: integer := 512;  -- Number of Steps
--		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
--		AMP_STEPS	: integer := 100;	 -- Amplitude Divider (100 steps)
--		MAX_FREQ		: integer := 511;	 -- Maximum Frequency of Output in Hz
--		NUM_FUNCS	: integer := 5		 -- Number of functions ( 0=Sine, 1=tiagle, 2=sawtooth, 3= rectangle)
--		);
--	port (
--		clock 			: in  std_ulogic;
--		reset				: in  std_ulogic;
--
--		data_avail		: in  std_ulogic;
--		multiplier_in	: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
--		period_on_in	: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
--		n_periods		: in  std_ulogic_vector(16 downto 0);
--		last_period		: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
--		last_period_on	: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
--		freq_in			: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
--		function_in		: in  std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0);
--		pwm_step_in		: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
--		
--		req_enable		: in  std_ulogic;
--		data_request	: out std_ulogic;
--		multiplier_out	: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
--		pwm_step			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
--		freq_out			: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
--		function_out	: out std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0);
--		
----		ack				: out	std_ulogic;
--		wave				: out std_ulogic
	generic (
		PWM_STEPS	: integer := 512;  -- Number of Steps
		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 100;	 -- Amplitude Divider (100 steps)
		MAX_FREQ		: integer := 511;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 5		 -- Number of functions ( 0=Sine, 1=tiagle, 2=sawtooth, 3= rectangle)
		);
	port (
		clock 			: in  std_ulogic;
		reset				: in  std_ulogic;

		data_avail		: in  std_ulogic;
		multiplier_in	: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		period_on_in	: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods		: in  std_ulogic_vector(16 downto 0);
		last_period		: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on	: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		freq_in			: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_in		: in  std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0);
		pwm_step_in		: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		
		req_enable		: in  std_ulogic;
		data_request	: out std_ulogic;
		multiplier_chain	: in std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		multiplier_out	: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		pwm_step_chain			: in std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		pwm_step			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		freq_chain			: in std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		freq_out			: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_chain	: in std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS))))-1 downto 0);
		function_out	: out std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS))))-1 downto 0);
		
--		ack				: out	std_ulogic;
		wave				: out std_ulogic
    );

	end component waveunit;

begin

n_periods		<= std_ulogic_vector(to_unsigned(NPERIODS,n_periods'length));
last_period		<= std_ulogic_vector(to_unsigned(LPERIOD,last_period'length));
last_period_on	<= std_ulogic_vector(to_unsigned(LPERIODON,last_period_on'length));
--function_back	<= std_ulogic_vector(to_unsigned(0,function_back'length));

	waver : waveunit -- counter for every pwm step
		generic map(
			PWM_STEPS 	=> PWM_STEPS,
			CLOCK_MHZ 	=> CLOCK_MHZ,
			AMP_STEPS 	=> AMP_STEPS,
			MAX_FREQ 	=> MAX_FREQ,
			NUM_FUNCS	=> NUM_FUNCS
		)
		port map(
			clock 			=> clock,
			reset				=> reset,
			
			data_avail		=> data_back,
			multiplier_in	=> mul_back,

			period_on_in	=> period_on_back,
			n_periods		=> n_periods,
			last_period		=> last_period,
			last_period_on	=> last_period_on,
			function_in		=> function_back,
			freq_in			=> frequency_back,
			pwm_step_in		=> pwm_step_next,		
			
			req_enable		=> req_enable,
			data_request	=> data_request,
			multiplier_chain	=> (others => '0'),
			multiplier_out	=> mul_request,
			pwm_step_chain	=> (others => '0'),
			pwm_step			=> pwm_step_next,
			freq_chain		=> (others => '0'),
			freq_out			=> freq_request,	
			function_chain	=> (others => '0'),
			function_out	=> function_request,	
			
--			ack				=> ack,
			wave				=> wave		
		 );

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
	
	ff:
		process(reset,clock)
				begin	
					if reset = '1' then
						req_cnt	<= (others => '0');						
					elsif rising_edge(clock) then
						req_cnt	<= req_cnt_nxt;
					end if;
	end process ff;	
	
	
	get_data : process(data_request,clock)
	begin
		if data_request = '1' then
			--if ack = '0' then
				req_enable		<= '1';
				data_back		<= '1';
				mul_back			<= std_ulogic_vector(to_unsigned(AMPLIFIER,mul_back'length));			
				period_on_back	<= std_ulogic_vector(to_unsigned(PERIODON,period_on_back'length));	
				frequency_back	<= std_ulogic_vector(to_unsigned(FREQUENCY,frequency_back'length));	
				function_back	<= std_ulogic_vector(to_unsigned(FUNCTIONSEL,function_back'length));
				
			
			
			--end if;
		else
			req_enable		<= '0';
			data_back		<= '0';
			mul_back			<= (others => '0');
--			period_back		<= (others => '0');
			period_on_back	<= (others => '0');
			frequency_back	<= (others => '0');
			function_back	<= (others => '0');
			
		end if;
	end process get_data;

end architecture rtl;