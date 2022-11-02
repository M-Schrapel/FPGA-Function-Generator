library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.function_pkg.all;

entity wave_unit_rom_testbench is
	generic (
		NUM_PORTS		: integer := 5;  	 -- Number of Ports
		PWM_STEPS		: integer := 512;  -- Number of Steps
		CLOCK_MHZ		: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS		: integer := 255;	 -- Amplitude Divider (100 steps + gain)
		MAX_FREQ			: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS		: integer := 5;	 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
		-- Internal Test signal values
		-- from wave unit
		MUL_WAVE			: integer := 100;
		PWM_WAVE			: integer := 511;
		FREQ_WAVE		: integer := 2;
		FUNC_WAVE		: integer := 3;
		PHASE				: integer := 180;
		UNIT_SELECT		: integer := 0;
		-- from rom reader
		PERIODON_ROM	: integer := 100;
		NPERIODS_ROM	: integer := 511;
		LPERIOD_ROM		: integer := 1;
		LPERIODON_ROM	: integer := 230;
		REQ_DELAY		: integer := 48828	
		);
end wave_unit_rom_testbench;

architecture rtl of wave_unit_rom_testbench is

signal clock								: std_ulogic := '0';
signal reset								: std_ulogic := '0';
		-- waveunit communication
signal enable_request_wave				: std_ulogic_vector(max(NUM_PORTS-1,1) downto 0);
		-- incoming request
signal data_request_wave				: std_ulogic_vector(max(NUM_PORTS-1,1) downto 0) := (others => '0');
signal mult_request_wave				: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
signal pwm_step_request_wave			: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
signal freq_request_wave				: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
signal function_request_wave			: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0);
		-- response 
signal data_avail_response_wave		: std_ulogic_vector(max(NUM_PORTS-1,1) downto 0);
signal mult_response_wave				: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
signal period_on_response_wave		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal n_periods_response_wave		: std_ulogic_vector(16 downto 0);
signal last_period_response_wave		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal last_period_on_response_wave	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal freq_response_wave				: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
signal function_response_wave			: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0);
signal pwm_step_response_wave			: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
	
		-- rom reader communication
		
		-- requesting data
signal data_request_rom					: std_ulogic := '0';
signal function_request_rom			: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0) := (others => '0');
signal frequency_request_rom			: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
signal step_request_rom					: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal mult_request_rom					: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
		-- response of rom
signal data_avail_response_rom		: std_ulogic;
signal period_on_response_rom			: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal n_periods_response_rom			: std_ulogic_vector(16 downto 0);
signal last_period_response_rom		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal last_period_on_response_rom	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		-- write data to custom rom
signal write_custom_request_rom		: std_ulogic := '0';
signal address_request_rom				: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal pwm_value_request_rom			: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		
		--communication with external data
signal ext_request						: std_ulogic := '0';
signal type_request						: std_ulogic_vector(integer(ceil(log2(real((5)))))-1 downto 0) := (others => '0');
		-- 0: function select
		-- 1: frequency select
		-- 2: multiplier select
		-- 3: phase select
		-- 4: request data
		
signal wave_unit_select					: std_ulogic_vector(max(integer(ceil(log2(real((NUM_PORTS*1))))),1) downto 0)  := (others => '0');
signal function_select					: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0) := (others => '0');
signal frequency_select					: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
signal mult_select						: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0)  := (others => '0');
signal phasereference_select			: std_ulogic_vector(max(integer(ceil(log2(real(NUM_PORTS*1)))),1) downto 0)  := (others => '0');
signal phase_value_select				: std_ulogic_vector(8 downto 0)  := (others => '0');
signal data_back							: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal write_custom_request			: std_ulogic := '0';
signal address_request					: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal pwm_value_request				: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal ack_ext								: std_ulogic := '0';
	
signal wave									: std_ulogic_vector(NUM_PORTS-1 downto 0);
	
signal req_cnt								: std_ulogic_vector(integer(ceil(log2(real(REQ_DELAY*1))))-1 downto 0) := (others => '0');
signal req_cnt_nxt						: std_ulogic_vector(integer(ceil(log2(real(REQ_DELAY*1))))-1 downto 0) := (others => '0');
signal req_wcnt							: std_ulogic_vector(integer(ceil(log2(real(REQ_DELAY*1))))+1 downto 0) := (others => '0');
signal req_wcnt_nxt						: std_ulogic_vector(integer(ceil(log2(real(REQ_DELAY*1))))+1 downto 0) := (others => '0');
	
		type mult_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		type pwm_step_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		type freq_request_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		type func_request_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS))))-1 downto 0);
		
		signal mul_request_wave_unit	: mult_array;
		signal pwm_step_out_unit		: pwm_step_array;
		signal freq_request_unit		: freq_request_array;
		signal function_request_unit		: func_request_array;
	
	
	
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
			
			write_custom	=> write_custom_request_rom,
			address			=> address_request_rom,
			pwm_value		=> pwm_value_request_rom
		 );

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
		clock									=> clock,
		reset									=> reset,
		-- waveunit communication
		enable_request_wave				=> enable_request_wave,
		-- incoming request
		data_request_wave					=> data_request_wave,
		mult_request_wave					=> mult_request_wave,
		pwm_step_request_wave			=> pwm_step_request_wave,
		freq_request_wave					=> freq_request_wave,
		function_request_wave			=> function_request_wave,
		-- response 
		data_avail_response_wave		=> data_avail_response_wave,
		mult_response_wave				=> mult_response_wave,
		period_on_response_wave			=> period_on_response_wave,
		n_periods_response_wave			=> n_periods_response_wave,
		last_period_response_wave		=> last_period_response_wave,
		last_period_on_response_wave	=> last_period_on_response_wave,
		freq_response_wave				=> freq_response_wave,
		function_response_wave			=> function_response_wave,
		pwm_step_response_wave			=> pwm_step_response_wave,
	
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
		write_custom_request_rom		=> write_custom_request_rom,
		address_request_rom				=> address_request_rom,
		pwm_value_request_rom			=> pwm_value_request_rom,
		
		--communication with external data
		ext_request							=> ext_request,
		type_request						=> type_request,
		wave_unit_select					=> wave_unit_select,
		function_select					=> function_select,
		frequency_select					=> frequency_select,
		mult_select							=> mult_select,
		phasereference_select			=> phasereference_select,
		phase_value_select				=> phase_value_select,
		data_back							=> data_back,
		write_custom_request				=> write_custom_request,
		address_request					=> address_request,
		pwm_value_request					=> pwm_value_request,
		ack_ext								=> ack_ext
	);
	
	
	gen_ext:
		process(req_cnt,req_wcnt,ack_ext)
				begin	
					if unsigned(req_cnt) = to_unsigned(REQ_DELAY+4,req_cnt'length) then
						ext_request		<= '1';
						type_request	<= req_wcnt(type_request'length-1 downto 0);
						if unsigned(req_wcnt(type_request'length-1 downto 0)) > 3 then
							req_cnt_nxt		<= (others => '0');	--std_ulogic_vector(unsigned(req_cnt)+1);
						else
							if ack_ext = '0' then
								req_cnt_nxt		<= std_ulogic_vector(unsigned(req_cnt)+0);
							else
								req_cnt_nxt		<= (others => '0');	--std_ulogic_vector(unsigned(req_cnt)+1);
							end if;
						end if;
						
						phasereference_select	<= (others => '0');	
						phase_value_select		<= std_ulogic_vector(to_unsigned(PHASE*1,phase_value_select'length));
						mult_select			<= std_ulogic_vector(to_unsigned(MUL_WAVE*1,mult_select'length));
						frequency_select	<= std_ulogic_vector(to_unsigned(FREQ_WAVE*1,frequency_select'length));
						function_select	<= std_ulogic_vector(to_unsigned(FUNC_WAVE*1,function_select'length));
--						wave_unit_select	<= req_wcnt(wave_unit_select'length-1 downto 0);
						wave_unit_select	<= std_ulogic_vector(to_unsigned(UNIT_SELECT*1,wave_unit_select'length));
						req_wcnt_nxt		<= req_wcnt;
					else
						ext_request		<= '0';
						type_request	<= (others => '0');	
						req_wcnt_nxt	<= std_ulogic_vector(unsigned(req_wcnt)+1);
						req_cnt_nxt			<= std_ulogic_vector(unsigned(req_cnt)+1);
						phasereference_select	<= (others => '0');	
						phase_value_select		<= (others => '0');
						mult_select			<= (others => '0');
						frequency_select	<= (others => '0');
						function_select	<= (others => '0');
						wave_unit_select	<= (others => '0');
						
					end if;
	end process gen_ext;
	
--	REQUEST TYPES
--	3 = phase
--	2 = multiplier
--	1 = frequency
--	0 = function

	-- generating unit instances
	waver_gen : for i in 1 to NUM_PORTS generate
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
			clock 			=> clock,
			reset				=> reset,
			
			data_avail		=> data_avail_response_wave(i-1),
			multiplier_in	=> mult_response_wave,

			period_on_in	=> period_on_response_wave,
			n_periods		=> n_periods_response_wave,
			last_period		=> last_period_response_wave,
			last_period_on	=> last_period_on_response_wave,
			function_in		=> function_response_wave,
			freq_in			=> freq_response_wave,
			pwm_step_in		=> pwm_step_response_wave,		
			
			req_enable		=> enable_request_wave(i-1),
			data_request	=> data_request_wave(i-1),
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
			clock 			=> clock,
			reset				=> reset,
			
			data_avail		=> data_avail_response_wave(i-1),
			multiplier_in	=> mult_response_wave,

			period_on_in	=> period_on_response_wave,
			n_periods		=> n_periods_response_wave,
			last_period		=> last_period_response_wave,
			last_period_on	=> last_period_on_response_wave,
			function_in		=> function_response_wave,
			freq_in			=> freq_response_wave,
			pwm_step_in		=> pwm_step_response_wave,		
			
			req_enable		=> enable_request_wave(i-1),
			data_request	=> data_request_wave(i-1),
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
		mult_request_wave			<=	std_ulogic_vector(unsigned(mul_request_wave_unit(i-1)));
		pwm_step_request_wave	<=	std_ulogic_vector(unsigned(pwm_step_out_unit(i-1)));
		function_request_wave	<=	std_ulogic_vector(unsigned(function_request_unit(i-1)));
		freq_request_wave			<=	std_ulogic_vector(unsigned(freq_request_unit(i-1)));
		end generate mul_gen;
	end generate waver_gen;
	
	
	
	
	ff:
		process(reset,clock)
				begin	
					if reset = '1' then
						req_cnt	<= (others => '0');		
						req_wcnt	<= (others => '0');				
					elsif rising_edge(clock) then
						req_cnt	<= req_cnt_nxt;
						req_wcnt	<= req_wcnt_nxt;
					end if;
	end process ff;
	
--	get_data_rom : process(data_request_rom,req_cnt)
--		begin
--			if data_request_rom = '1' then
--				if unsigned(req_cnt) = to_unsigned(REQ_DELAY-1,req_cnt'length) then
--					req_cnt_nxt							<= req_cnt;
--					data_avail_response_rom 		<= '1';
--					period_on_response_rom			<= std_ulogic_vector(to_unsigned(PERIODON_ROM,period_on_response_rom'length));	
--					n_periods_response_rom			<= std_ulogic_vector(to_unsigned(NPERIODS_ROM,n_periods_response_rom'length));	
--					last_period_response_rom		<= std_ulogic_vector(to_unsigned(LPERIOD_ROM,last_period_response_rom'length));	
--					last_period_on_response_rom	<= std_ulogic_vector(to_unsigned(LPERIODON_ROM,last_period_on_response_rom'length));	
--				else
--					req_cnt_nxt							<= std_ulogic_vector(unsigned(req_cnt)+1);
--					data_avail_response_rom 		<= '0';
--					period_on_response_rom			<= (others => '0');
--					n_periods_response_rom			<= (others => '0');	
--					last_period_response_rom		<= (others => '0');
--					last_period_on_response_rom	<= (others => '0');
--				end if;
--			else
--				data_avail_response_rom 			<= '0';
--				req_cnt_nxt								<= (others => '0');
--				period_on_response_rom				<= (others => '0');
--				n_periods_response_rom				<= (others => '0');
--				last_period_response_rom			<= (others => '0');
--				last_period_on_response_rom		<= (others => '0');
--			end if;
--		end process get_data_rom;
		
--	get_data_wave : process(enable_request_wave,req_wcnt)
--		begin	
--			if enable_request_wave(0) = '1' then 
--				if unsigned(req_wcnt) >= to_unsigned(REQ_DELAY-1,req_wcnt'length) then
--					data_request_wave(0) 	<= '1';
--					mult_request_wave			<= std_ulogic_vector(to_unsigned(MUL_WAVE,mult_request_wave'length));	
--					pwm_step_request_wave	<= std_ulogic_vector(to_unsigned(PWM_WAVE,pwm_step_request_wave'length));	
--					freq_request_wave			<= std_ulogic_vector(to_unsigned(FREQ_WAVE,freq_request_wave'length));	
--					function_request_wave	<= std_ulogic_vector(to_unsigned(FUNC_WAVE,function_request_wave'length));
--					if data_avail_response_wave(0) = '1' then
--						req_wcnt_nxt			<= (others => '0');
--					else
--						req_wcnt_nxt			<= std_ulogic_vector(unsigned(req_wcnt)+1);
--					end if;
--				else
--					data_request_wave(0) 	<= '0';
--					req_wcnt_nxt				<= std_ulogic_vector(unsigned(req_wcnt)+1);
--					mult_request_wave			<= (others => '0');
--					pwm_step_request_wave	<= (others => '0');
--					freq_request_wave			<= (others => '0');
--					function_request_wave	<= (others => '0');
--				end if;
--			else	
--				if unsigned(req_wcnt) >= to_unsigned(REQ_DELAY-1,req_wcnt'length) then
--					data_request_wave(0) 	<= '1';
--				else
--					data_request_wave(0) 	<= '0';
--				end if;
--				req_wcnt_nxt				<= std_ulogic_vector(unsigned(req_wcnt)+1);
--				mult_request_wave			<= (others => '0');
--				pwm_step_request_wave	<= (others => '0');
--				freq_request_wave			<= (others => '0');
--				function_request_wave	<= (others => '0');
--			end if;
--		end process get_data_wave;
		
		
--	get_data_wave : process(enable_request_wave,req_wcnt)
--		begin
--			if enable_request_wave(0) = '1' then
--				if unsigned(req_wcnt) = to_unsigned(REQ_DELAY-1,req_wcnt'length) then-- or unsigned(req_wcnt) = to_unsigned(0,req_wcnt'length) then
--					
--					if data_avail_response_wave(0) = '0' then
--						req_wcnt_nxt			<= req_wcnt;
--						data_request_wave(0) <= '1';
--					else
--						req_wcnt_nxt			<= (others => '0');
--						data_request_wave(0) <= '0';
--					end if;
--				else
--					data_request_wave(0) <= '1';
--					req_wcnt_nxt		<= std_ulogic_vector(unsigned(req_wcnt)+1);
--					--req_wcnt_nxt			<= (others => '0');
--				end if;
--				mult_request_wave			<= std_ulogic_vector(to_unsigned(MUL_WAVE,mult_request_wave'length));	
--				pwm_step_request_wave	<= std_ulogic_vector(to_unsigned(PWM_WAVE,pwm_step_request_wave'length));	
--				freq_request_wave			<= std_ulogic_vector(to_unsigned(FREQ_WAVE,freq_request_wave'length));	
--				function_request_wave	<= std_ulogic_vector(to_unsigned(FUNC_WAVE,function_request_wave'length));
--			else
--				mult_request_wave			<= (others => '0');
--				pwm_step_request_wave	<= (others => '0');
--				freq_request_wave			<= (others => '0');
--				function_request_wave	<= (others => '0');
--				if unsigned(req_wcnt) = to_unsigned(REQ_DELAY-1,req_wcnt'length) or unsigned(req_wcnt) = to_unsigned(0,req_wcnt'length) then
--					data_request_wave(0) <= '1';
--					req_wcnt_nxt			<= std_ulogic_vector(unsigned(req_wcnt)+0);	
--				else
--					data_request_wave(0) <= '0';
--					req_wcnt_nxt			<= std_ulogic_vector(unsigned(req_wcnt)+1);
--				end if;
--			end if;
--		end process get_data_wave;
		
		
	
end rtl;