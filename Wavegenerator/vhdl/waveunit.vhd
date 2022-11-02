library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.function_pkg.all;

entity waveunit is
	generic (
		PWM_STEPS	: integer := 1024;  -- Number of Steps
		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 100;	 -- Amplitude Divider (100 steps)
		MAX_FREQ		: integer := 511;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 255		 -- Number of functions ( 0=Sine, 1=tiagle, 2=sawtooth, 3= rectangle)
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
		
		req_enable			: in  std_ulogic;
		data_request		: out std_ulogic;
		multiplier_chain	: in std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		multiplier_out		: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		pwm_step_chain		: in std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		pwm_step				: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		freq_chain			: in std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		freq_out				: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_chain		: in std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0);
		function_out		: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0);
		
		
		-- For faster asynchronous changes
		async_data_chain			: in  std_ulogic_vector(max(max(integer(ceil(log2(real(AMP_STEPS*1)))),integer(ceil(log2(real(MAX_FREQ*1))))),integer(ceil(log2(real(NUM_FUNCS)))))-1 downto 0);
		async_data_out				: out std_ulogic_vector(max(max(integer(ceil(log2(real(AMP_STEPS*1)))),integer(ceil(log2(real(MAX_FREQ*1))))),integer(ceil(log2(real(NUM_FUNCS)))))-1 downto 0);
		async_req_enable			: in  std_ulogic;
		async_req_type_chain		: in  std_ulogic_vector(1 downto 0);
		async_req_type				: out std_ulogic_vector(1 downto 0);
		async_ack_chain			: in  std_ulogic;	
		async_ack					: out std_ulogic;	
		
--		ack				: out	std_ulogic;
		wave				: out std_ulogic
    );
end waveunit;

architecture rtl of waveunit is

signal mul_sig						: std_ulogic_vector(multiplier_out'length-1 downto 0) := (others => '0');
signal mul_sig_nxt				: std_ulogic_vector(multiplier_out'length-1 downto 0) := (others => '0');

signal freq_sig					: std_ulogic_vector(freq_out'length-1 downto 0) := (others => '0');
signal freq_sig_nxt				: std_ulogic_vector(freq_out'length-1 downto 0) := (others => '0');

signal function_sig				: std_ulogic_vector(function_out'length-1 downto 0) := (others => '0');
signal function_sig_nxt			: std_ulogic_vector(function_out'length-1 downto 0) := (others => '0');

signal step_trigger				: std_ulogic := '0';
signal data_request_int			: std_ulogic := '0';
signal step_count					: std_ulogic_vector(pwm_step'length-1 downto 0) := (others => '0');
signal step_count_nxt			: std_ulogic_vector(pwm_step'length-1 downto 0) := (others => '0');

-- asynchronous ack
signal async_ack_int				: std_ulogic := '0';
signal async_ack_nxt				: std_ulogic := '0';

--signal pwm_step			 : std_ulogic_vector((integer(ceil(log2(real(PWM_STEPS*1)))))-1 downto 0);

component pwm_generator is
	generic (
		PWM_STEPS		: integer := 512;  -- Number of Steps
		CLOCK_MHZ		: integer := 50;   -- Clock signal in MHZ
		MAX_FREQ			: integer := 512	 -- Maximum Frequency of Output in Hz
	);
	port (
		clock 			: in  std_ulogic;
		reset				: in 	std_ulogic;
		
		data_valid		: in  std_ulogic;
		period_on		: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods		: in  std_ulogic_vector(16 downto 0);
		last_period		: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on	: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		
		data_request	: out std_ulogic;
		step_trigger	: out std_ulogic;
		wave				: out std_ulogic
		
    );
end component pwm_generator;
	
begin

data_request	<= data_request_int;
async_req_type <=	async_req_type_chain;

	pwm : pwm_generator
		generic map(
		PWM_STEPS			=> PWM_STEPS,
		CLOCK_MHZ			=> CLOCK_MHZ,
		MAX_FREQ				=>	MAX_FREQ
		)
		port map(
			clock 			=> clock,
			reset				=> reset,
			
			data_valid		=> data_avail,
			period_on		=> period_on_in,
			n_periods		=> n_periods,
			last_period		=> last_period,
			last_period_on	=> last_period_on,
		
			data_request	=> data_request_int,
			step_trigger	=> step_trigger,
			wave				=> wave
		 );	
		 
	ff:
		process(reset, clock)
			begin	
				if reset = '1' then
					-- units will be enabled when powered up
					mul_sig			<= std_ulogic_vector(to_unsigned(100,mul_sig'length));
					-- units will be enabled when powered up
--					mul_sig			<= (others => '0');
					--freq_sig			<= (others => '0');
					freq_sig			<= std_ulogic_vector(to_unsigned(0,freq_sig'length));
					--freq_sig			<= '10010110‬';
					--freq_sig			<= (others => '1');
					function_sig	<= (others => '0');
					--function_sig	<= std_ulogic_vector(to_unsigned(3,function_sig'length));
					--1=triagle, 2=sawtooth, 3=rectangle, 4=custom
					async_ack_int	<= '0';
					step_count		<= (others => '0');
				elsif rising_edge(clock) then
					mul_sig			<= mul_sig_nxt;
					freq_sig			<= freq_sig_nxt;
					function_sig	<= function_sig_nxt;
					step_count		<= step_count_nxt;
					async_ack_int	<= async_ack_nxt;
				end if;
	end process ff;	
	
	step_calc:
		process(step_trigger,step_count,data_avail,pwm_step_in)
			begin	
				if step_trigger = '1' then
					if	to_unsigned(PWM_STEPS-1,step_count'length) = unsigned(step_count) then
						step_count_nxt	<= (others => '0');
					else
						step_count_nxt	<= std_ulogic_vector(unsigned(step_count)+1);
					end if;
				else
					if data_avail = '1' then
						step_count_nxt	<= pwm_step_in;
					else
						step_count_nxt	<= step_count;
					end if;
				end if;
	end process step_calc;	
	
	communication:
		process(multiplier_chain,pwm_step_chain,function_chain,freq_chain,mul_sig,step_count,freq_sig,function_sig,req_enable,data_request_int,data_avail,multiplier_in,freq_in,function_in,pwm_step_in,
				  async_data_chain,async_req_enable,async_req_type_chain,async_ack_int,async_ack_chain)
			begin	
				if req_enable = '1' and data_request_int = '1' then
					multiplier_out	<= mul_sig ;--or multiplier_chain; -- Sinals are dont care if unit is enabled
					pwm_step			<= step_count;-- or pwm_step_chain;
					freq_out			<= freq_sig;-- or freq_chain;
					function_out	<= function_sig;-- or function_chain;
				else
					multiplier_out	<= multiplier_chain;
					pwm_step			<= pwm_step_chain;
					freq_out			<= freq_chain;
					function_out	<= function_chain;
				end if;
				async_ack_nxt		<= '0';
				if req_enable = '1' and data_request_int = '1' and data_avail = '1' then
					mul_sig_nxt				<= multiplier_in;
					freq_sig_nxt			<= freq_in;
					function_sig_nxt		<= function_in;
					async_data_out			<= async_data_chain;
					async_ack				<= async_ack_chain;
				elsif async_req_enable = '1' and req_enable = '0' then -- Fast change
					if unsigned(async_req_type_chain) = 0 then-- Function
						function_sig_nxt		<= async_data_chain(function_sig_nxt'length-1 downto 0);
						async_data_out			<= (others => '0');
						mul_sig_nxt				<= mul_sig;
						freq_sig_nxt			<= freq_sig;
					elsif unsigned(async_req_type_chain) = 1 then-- Frequency
						freq_sig_nxt			<= async_data_chain(freq_sig_nxt'length-1 downto 0);
						async_data_out			<= (others => '0');
						mul_sig_nxt				<= mul_sig;
						function_sig_nxt		<= function_sig;
					else -- Amplification
						mul_sig_nxt				<= async_data_chain(mul_sig_nxt'length-1 downto 0);
						async_data_out			<= (others => '0');
						freq_sig_nxt			<= freq_sig;
						function_sig_nxt		<= function_sig;
					end if;
					async_ack_nxt			<= '1';
					async_ack				<= async_ack_int;
				else
					mul_sig_nxt				<= mul_sig;
					freq_sig_nxt			<= freq_sig;
					function_sig_nxt		<= function_sig;
					async_data_out			<= async_data_chain;
					async_ack				<= async_ack_chain;
				end if;
				
	end process communication;
	
	
end rtl;