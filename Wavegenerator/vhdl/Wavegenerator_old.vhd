library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.function_pkg.all;

entity Wavegenerator_old is
	generic (
      BAUD_RATE   : integer := 115200; -- baud rate value
      PARITY_BIT  : string  := "none"; -- type of parity: "none", "even", "odd", "mark", "space"
		NUM_PORTS	: integer := 1;  	 -- Number of Ports
		PWM_STEPS	: integer := 1024;  -- Number of Steps
		CLOCK_MHZ	: integer := 350;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 255;	 -- Amplitude Divider (100 steps)
		MAX_FREQ		: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 5	 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
		--CALC_TICKS	: integer := 5		 -- internal number of clocks until result is valid
	);
	port(
		clock		: in	std_ulogic;
		reset		: in	std_ulogic;
      uart_rxd	: in  std_ulogic;
		uart_txd	: out std_ulogic;
		wave		: out	std_ulogic_vector(NUM_PORTS-1 downto 0)
	);
end Wavegenerator_old;

architecture rtl of Wavegenerator_old is

--u1 : for i in 0 to NUM_PORTS-1 generate
--signal mult_request_wave_unit_i : std_logic ;
--begin
--end generate u1;

signal clock_int			: std_ulogic := '0';
signal reset_int			: std_ulogic := '0';
signal n_reset_int		: std_ulogic := '0';

signal clock_50			: std_ulogic := '0';
signal clock_100			: std_ulogic := '0';
signal clock_350			: std_ulogic := '0';

-- if data is loaded from ROM this signal is high
signal data_back			: std_ulogic_vector(max(NUM_PORTS-1,1) downto 0) := (others => '0');
-- multiplier for unit
signal mul_back			: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
-- number of clocks per pwm period for chosen frequency
signal period_back		: std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0'); -- Minimum update rate at 1Hz
-- number of high clocks per pwm period for chosen frequency 
signal period_on_back	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0) := (others => '0'); -- Minimum update rate at 1Hz
-- frequency for unit
signal frequency_back	: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0) := (others => '0');
-- function for unit
signal function_back		: std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0) := (others => '0');
	
-- enable reguest of a single port
signal req_enable			: std_ulogic_vector(max(NUM_PORTS-1,1) downto 0) := (others => '0');

-- if a ports requests data is signal is high
signal data_request		: std_ulogic_vector(max(NUM_PORTS-1,1) downto 0) := (others => '0');
-- stored multiplier data of each unit after enabled 
signal mul_request		: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
-- requested pwm step of each unit after enabled 
signal pwm_step_next		: std_ulogic_vector(max(integer(ceil(log2(real(PWM_STEPS*1))))-1,1) downto 0) := (others => '0');
signal pwm_step_out		: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');

-- requested frequency of each unit after enabled 
signal freq_request		: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0) := (others => '0');
-- requested function of each unit after enabled 
signal function_request	: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0) := (others => '0');
-- number of full periods
signal n_periods			: std_ulogic_vector(16 downto 0) := (others => '0');
-- length of last period
signal last_period		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0) := (others => '0');
-- length of HIGH signal for last period
signal last_period_on	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0) := (others => '0');

-- if enabled data will be written to custom ROM
signal write_custom_rom	: std_ulogic :=  '0';
-- address of data for custom ROM
signal address_rom		: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
-- value of data for custom ROM
signal pwm_value_rom		: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');

-- Communication signals for UART
signal ext_request						: std_ulogic := '0';
signal type_request						: std_ulogic_vector(integer(ceil(log2(real((5)))))-1 downto 0);
signal wave_unit_select					: std_ulogic_vector(max(integer(ceil(log2(real((NUM_PORTS*1))))),1) downto 0)  := (others => '0');
signal function_select					: std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS))))-1 downto 0) := (others => '0');
signal frequency_select					: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
signal mult_select						: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0)  := (others => '0');
signal phase_reference_select			: std_ulogic_vector(max(integer(ceil(log2(real(NUM_PORTS*1)))),1) downto 0)  := (others => '0');
signal phase_value_select				: std_ulogic_vector(8 downto 0)  := (others => '0');
signal data_back_com						: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal ack_ext								: std_ulogic := '0';
signal write_custom_request			: std_ulogic := '0';
signal address_request					: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal pwm_value_request				: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');

-- ROM communication
signal data_request_rom					: std_ulogic := '0';
signal function_request_rom			: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0) := (others => '0');
signal frequency_request_rom			: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
signal step_request_rom					: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal mult_request_rom					: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
		
signal data_avail_response_rom		: std_ulogic;
signal period_on_response_rom			: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal n_periods_response_rom			: std_ulogic_vector(16 downto 0);
signal last_period_response_rom		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal last_period_on_response_rom	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);

	component pll is
	port (
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0				: OUT STD_LOGIC ;
		c1				: OUT STD_LOGIC ;
		c2				: OUT STD_LOGIC ;
		locked		: OUT STD_LOGIC 
    );
	end component pll;
	
component rom_reader is
	generic (
		PWM_STEPS	: integer := 512;  -- Number of Steps
		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 255;	 -- Amplitude Divider (100 steps + gain)
		MAX_FREQ		: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 5	 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
		--CALC_TICKS	: integer := 5		 -- internal number of clocks until result is valid
	);
	port(
		clock				: in  std_ulogic := '0';
		reset				: in  std_ulogic := '0';
		
		data_request	: in  std_ulogic := '0';
		function_sel	: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS)))),1)-1 downto 0) := (others => '0');
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
	
component wave_updatelogic is
	generic (
		NUM_PORTS	: integer := 1;  	 -- Number of Ports
		PWM_STEPS	: integer := 512;  -- Number of Steps
		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 255;	 -- Amplitude Divider (100 steps + gain)
		MAX_FREQ		: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 5	 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
	);
	port(
		clock									: in  std_ulogic := '0';
		reset									: in  std_ulogic := '0';
		-- waveunit communication
		enable_request_wave				: out std_ulogic_vector(max(NUM_PORTS-1,1) downto 0);
		-- incoming request
		data_request_wave					: in  std_ulogic_vector(max(NUM_PORTS-1,1) downto 0);
		mult_request_wave					: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		pwm_step_request_wave			: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		freq_request_wave					: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_request_wave			: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0);
		-- response 
		data_avail_response_wave		: out std_ulogic_vector(max(NUM_PORTS-1,1) downto 0);
		mult_response_wave				: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		period_on_response_wave			: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods_response_wave			: out std_ulogic_vector(16 downto 0);
		last_period_response_wave		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on_response_wave	: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		freq_response_wave				: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_response_wave			: out std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0);
		pwm_step_response_wave			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
	
		-- rom reader communication
		
		-- requesting data
		data_request_rom					: out std_ulogic := '0';
		function_request_rom				: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0) := (others => '0');
		frequency_request_rom			: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
		step_request_rom					: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		mult_request_rom					: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
		-- response of rom
		data_avail_response_rom			: in  std_ulogic;
		period_on_response_rom			: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods_response_rom			: in  std_ulogic_vector(16 downto 0);
		last_period_response_rom		: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on_response_rom	: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		-- write data to custom rom
		write_custom_request_rom		: out std_ulogic := '0';
		address_request_rom				: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		pwm_value_request_rom			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		
		--communication with external data
		ext_request							: in  std_ulogic := '0';
		type_request						: in	std_ulogic_vector(integer(ceil(log2(real((5)))))-1 downto 0);
		-- 0: function select
		-- 1: frequency select
		-- 2: multiplier select
		-- 3: phase select
		-- 4: request data
		
		wave_unit_select					: in  std_ulogic_vector(max(integer(ceil(log2(real((NUM_PORTS*1))))),1) downto 0)  := (others => '0');
		function_select					: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0)  := (others => '0');
		frequency_select					: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
		mult_select							: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0)  := (others => '0');
		phasereference_select			: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_PORTS*1)))),1) downto 0)  := (others => '0');
		phase_value_select				: in  std_ulogic_vector(8 downto 0)  := (others => '0');
		data_back							: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		write_custom_request				: in  std_ulogic := '0';
		address_request					: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		pwm_value_request					: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		ack_ext								: out std_ulogic := '0'
	);
end component wave_updatelogic;
	
component waveunit is
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
		function_in		: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0);
		pwm_step_in		: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		
		req_enable		: in  std_ulogic;
		data_request	: out std_ulogic;
		multiplier_chain	: in std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		multiplier_out	: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		pwm_step_chain			: in std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		pwm_step			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		freq_chain			: in std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		freq_out			: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_chain	: in std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0);
		function_out	: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0);
		
--		ack				: out	std_ulogic;
		wave				: out std_ulogic
    );
	end component waveunit;

begin

--  g_test: for i in 1 to NUM_PORTS generate
--    signal mul_request_wave_unit_i : std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
--  begin
--		mul_request <= mul_request or mul_request_wave_unit_i;
--  end generate g_test;
  


	-- internal reset when pll is not locked
	reset_int <= not(n_reset_int);
	
	-- internal clock signal

	clk_50_gen: if CLOCK_MHZ = 50 generate
		clock_int <= clock_50;
	end generate clk_50_gen;
	
	clk_100_gen: if CLOCK_MHZ = 100 generate
		clock_int <= clock_50;
	end generate clk_100_gen;
	
	clk_350_gen: if CLOCK_MHZ = 350 generate
		clock_int <= clock_350;
	end generate clk_350_gen;
	
	
	-- pll for internal clock
	pll_inst : pll
		port map(
			areset		=> reset,
			inclk0		=> clock,
			c0				=> clock_50,
			c1				=> clock_100,
			c2				=> clock_350,
			locked		=> n_reset_int
		);

-- generating unit instances
	waver_gen : for i in 1 to NUM_PORTS generate
		--signal mul_request_wave_unit_i : std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
		--signal mul_request_temp_i : std_ulogic_vector
		
		type mult_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		type pwm_step_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		type freq_request_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		type func_request_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS))))-1 downto 0);
		
		signal mul_request_wave_unit	: mult_array;
		signal pwm_step_out_unit		: pwm_step_array;
		signal freq_request_unit		: freq_request_array;
		signal function_request_unit		: func_request_array;
		--variable SumSin : signed(3 downto 0);
		
		begin
		first: if i=1 generate
		waver : waveunit -- counter for every pwm step	waver : waveunit -- counter for every pwm step
		generic map(
			PWM_STEPS 	=> PWM_STEPS,
			CLOCK_MHZ 	=> CLOCK_MHZ,
			AMP_STEPS 	=> AMP_STEPS,
			MAX_FREQ 	=> MAX_FREQ
		)
		port map(
			clock 			=> clock_int,
			reset				=> reset_int,
			
			data_avail		=> data_back(i-1),
			multiplier_in	=> mul_back,

			period_on_in	=> period_on_back,
			n_periods		=> n_periods,
			last_period		=> last_period,
			last_period_on	=> last_period_on,
			function_in		=> function_back,
			freq_in			=> frequency_back,
			pwm_step_in		=> pwm_step_next,		
			
			req_enable		=> req_enable(i-1),
			data_request	=> data_request(i-1),
			multiplier_chain	=>	 (others=> '0'),
			multiplier_out	=> mul_request_wave_unit(i-1),
			pwm_step_chain	=>	 (others=> '0'),
			pwm_step			=> pwm_step_out_unit(i-1),
			freq_chain	=>	 (others=> '0'),
			freq_out			=> freq_request_unit(i-1),		
			function_chain	=>	 (others=> '0'),	
			function_out	=> function_request_unit(i-1),	
--			ack				=> ack,
			wave				=> wave(i-1)		
		 );
		 end generate first;
		other: if i>1 generate
		waver : waveunit -- counter for every pwm step	waver : waveunit -- counter for every pwm step
		generic map(
			PWM_STEPS 	=> PWM_STEPS,
			CLOCK_MHZ 	=> CLOCK_MHZ,
			AMP_STEPS 	=> AMP_STEPS,
			MAX_FREQ 	=> MAX_FREQ
		)
		port map(
			clock 			=> clock_int,
			reset				=> reset_int,
			
			data_avail		=> data_back(i-1),
			multiplier_in	=> mul_back,

			period_on_in	=> period_on_back,
			n_periods		=> n_periods,
			last_period		=> last_period,
			last_period_on	=> last_period_on,
			function_in		=> function_back,
			freq_in			=> frequency_back,
			pwm_step_in		=> pwm_step_next,		
			
			req_enable		=> req_enable(i-1),
			data_request	=> data_request(i-1),
			multiplier_chain	=>	 mul_request_wave_unit(i-2),
			multiplier_out	=> mul_request_wave_unit(i-1),
			pwm_step_chain	=>	 pwm_step_out_unit(i-2),
			pwm_step			=> pwm_step_out_unit(i-1),
			freq_chain		=>	freq_request_unit(i-2),
			freq_out			=> freq_request_unit(i-1),		
			function_chain	=>	function_request_unit(i-2),
			function_out	=> function_request_unit(i-1),	
--			ack				=> ack,
			wave				=> wave(i-1)		
		 );
		 end generate other;
		--t: if i = NUM_PORTS generate
		mul_gen: if i=NUM_PORTS generate
		mul_request			<=	std_ulogic_vector(unsigned(mul_request_wave_unit(i-1)));
		pwm_step_out		<=	std_ulogic_vector(unsigned(pwm_step_out_unit(i-1)));
		function_request	<=	std_ulogic_vector(unsigned(function_request_unit(i-1)));
		freq_request		<=	std_ulogic_vector(unsigned(freq_request_unit(i-1)));
		end generate mul_gen;
		--end generate ;
		--		 freq_request
--		 pwm_step_out
--		 function_request
		--mul_request_temp_i <= mul_request or mul_request_wave_unit_i;
		--mul_request		  <= mul_request_temp;
	end generate waver_gen;
	
wave_handler : wave_updatelogic
	generic map(
		NUM_PORTS	=> NUM_PORTS,
		PWM_STEPS	=> PWM_STEPS,
		CLOCK_MHZ	=> CLOCK_MHZ,
		AMP_STEPS	=> AMP_STEPS,
		MAX_FREQ		=> MAX_FREQ,
		NUM_FUNCS	=> NUM_FUNCS
	)
	port map(
		clock									=> clock_int,
		reset									=> reset_int,
		-- waveunit communication
		enable_request_wave				=> req_enable,
		-- incoming request
		data_request_wave					=> data_request,
		mult_request_wave					=> mul_request,
		pwm_step_request_wave			=> pwm_step_out,
		freq_request_wave					=> freq_request,
		function_request_wave			=> function_request,
		-- response 
		data_avail_response_wave		=> data_back,
		mult_response_wave				=> mul_back,
		period_on_response_wave			=> period_on_back,
		n_periods_response_wave			=> n_periods,
		last_period_response_wave		=> last_period,
		last_period_on_response_wave	=> last_period_on,
		freq_response_wave				=> frequency_back,
		function_response_wave			=> function_back,
		pwm_step_response_wave			=> pwm_step_next,
	
		-- rom reader communication
		
		-- requesting data
		data_request_rom					=> data_request_rom,
		function_request_rom				=> function_request_rom,
		frequency_request_rom			=> frequency_request_rom,
		step_request_rom					=> step_request_rom,
		mult_request_rom					=> mult_request_rom,
		-- response of rom
		data_avail_response_rom			=> data_avail_response_rom,
		period_on_response_rom			=> period_on_response_rom,
		n_periods_response_rom			=> n_periods_response_rom,
		last_period_response_rom		=> last_period_response_rom,
		last_period_on_response_rom	=> last_period_on_response_rom,
		-- write data to custom rom
		write_custom_request_rom		=> write_custom_rom,
		address_request_rom				=> address_rom,
		pwm_value_request_rom			=> pwm_value_rom,
		
		--communication with external data
		ext_request							=> ext_request,
		type_request						=> type_request,
		wave_unit_select					=> wave_unit_select,
		function_select					=> function_select,
		frequency_select					=> frequency_select,
		mult_select							=> mult_select,
		phasereference_select			=> phase_reference_select,
		phase_value_select				=> phase_value_select,
		data_back							=> data_back_com,
		write_custom_request				=> write_custom_request,
		address_request					=> address_request,
		pwm_value_request					=> pwm_value_request,
		ack_ext								=> ack_ext
	);

	
	
	
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
			clock				=> clock_int,
			reset				=> reset_int,
			
			data_request	=> data_request_rom,
			function_sel	=> function_request_rom,
			frequency		=> frequency_request_rom,
			step				=> step_request_rom,
			factor			=> mult_request_rom,
			
			data_avail		=> data_avail_response_rom,
			period_on		=> period_on_response_rom,
			n_periods		=> n_periods_response_rom,
			last_period		=> last_period_response_rom,
			last_period_on	=> last_period_on_response_rom,
			
			write_custom	=> write_custom_rom,
			address			=> address_rom,
			pwm_value		=> pwm_value_rom
		 );
	
end rtl;