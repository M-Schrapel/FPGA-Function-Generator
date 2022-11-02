library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity waveunit_old2 is
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
		
--		---------
--		
--		data_request	: in  std_ulogic := '0';
--		function_sel	: in  std_ulogic_vector(NUM_FUNCS-1 downto 0) := (others => '0');
--		frequency		: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
--		step				: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
--		factor			: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
--		
--		data_avail		: out std_ulogic;
--		period_on		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
--		n_periods		: out std_ulogic_vector(16 downto 0);
--		last_period		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
--		last_period_on	: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
--		---------
		
		period_on_in	: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods		: in  std_ulogic_vector(16 downto 0);
		last_period		: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on	: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		freq_in			: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_in		: in  std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0);
		pwm_step_in		: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		
		req_enable		: in  std_ulogic;
		data_req			: out std_ulogic;
		multiplier_out	: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		pwm_step			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		freq_out			: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_out	: out std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0);
		
		ack				: out	std_ulogic;
		wave				: out std_ulogic
    );
end waveunit_old2;

architecture rtl of waveunit_old2 is

signal mul_sig						: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
signal mul_sig_nxt				: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');

signal period_sig					: std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');
--signal period_sig_nxt			: std_ulogic_vector(period_on_in'length-1 downto 0) := (others => '0');

signal period_on_sig				: std_ulogic_vector(period_on_in'length-1 downto 0) := (others => '0');
signal period_on_sig_nxt		: std_ulogic_vector(period_on_in'length-1 downto 0) := (others => '0');

signal freq_sig					: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0) := (others => '0');
signal freq_sig_nxt				: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0) := (others => '0');

signal function_sig				: std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0) := (others => '0');
signal function_sig_nxt			: std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0) := (others => '0');


signal n_periods_sig				: std_ulogic_vector(16 downto 0);
signal n_periods_sig_nxt		: std_ulogic_vector(16 downto 0);

signal last_period_sig			: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal last_period_sig_nxt		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);

signal last_period_on_sig		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal last_period_on_sig_nxt	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);

signal n_periods_cnt				: std_ulogic_vector(16 downto 0);
signal n_periods_cnt_nxt		: std_ulogic_vector(16 downto 0);


signal ack_int						: std_ulogic := '0';
--signal ack_int_sig			: std_ulogic := '0';
--signal ack_int_sig_nxt		: std_ulogic := '0';

signal ack_wcntr					: std_ulogic := '0';
signal ack_wcntr_sig				: std_ulogic := '0';
signal ack_wcntr_sig_nxt		: std_ulogic := '0';


signal data_req_int				: std_ulogic := '0';

signal ack_wave					: std_ulogic := '0';
-- ACK when data is written

-- Address of pwm step
signal addr_pwmrom				: std_ulogic_vector((integer(ceil(log2(real(PWM_STEPS*1)))))-1 downto 0) := (others => '0');
-- Number of clock ticks per period from ROM
signal next_pwm_period  		: std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');
-- Number of positive clock ticks per period from ROM
signal next_pwm_step  			: std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');

signal period_sig_int			: std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');
signal period_sig_int_nxt		: std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');
signal period_on_int				: std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');
signal period_on_int_nxt		: std_ulogic_vector(period_on_int'length-1 downto 0) := (others => '0');

signal next_pwmstep		 : std_ulogic := '0';

signal set_count			 : std_ulogic := '0';


--signal pwm_step			 : std_ulogic_vector((integer(ceil(log2(real(PWM_STEPS*1)))))-1 downto 0);

	component counter is
	generic (
		MAX_VALUE	: integer := 512  -- Number of Steps
	);
	port (
		clock 		: in  	std_ulogic;
		reset			: in 		std_ulogic;
		
		set_count	: in 		std_ulogic;
		count_new	: in   	std_ulogic_vector((integer(ceil(log2(real(MAX_VALUE*1)))))-1 downto 0);

		enable		: in   	std_ulogic;
		count			: out   	std_ulogic_vector((integer(ceil(log2(real(PWM_STEPS*1)))))-1 downto 0)
    );
	end component counter;

	component wavecounter is
	generic (
		PWM_STEPS	: integer := 512;  -- Number of Steps
		CLOCK_MHZ	: integer := 50   -- Clock signal in MHZ
	);
	port (
		clock 		: in  std_ulogic;
		reset			: in 	std_ulogic;

		period		: in  std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0); -- Minimum update rate at 1Hz
		period_on	: in  std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0); -- Minimum update rate at 1Hz

		ack			: out std_ulogic;
		pwm_step		: out std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000/PWM_STEPS)/PWM_STEPS)))))-1 downto 0);
		wave			: out std_ulogic
    );
	end component wavecounter;
	
begin

	period_sig	<= std_ulogic_vector(to_unsigned(PWM_STEPS-1,period_sig'length));

	ack			<= ack_int;
	data_req		<= data_req_int;
	
	pwmstepcnt : counter -- counter for every pwm step
		generic map(
			MAX_VALUE 	=> PWM_STEPS
		)
		port map(
			clock 		=> clock,
			reset			=> reset,
			
			set_count	=> set_count,
			count_new	=> pwm_step_in,

			enable		=> next_pwmstep,
			count			=> addr_pwmrom
		 );	
	
	pwm_gen : wavecounter -- pwm generator
		generic map(
			PWM_STEPS 	=> PWM_STEPS,
			CLOCK_MHZ	=> CLOCK_MHZ
		)
		port map(
			clock 		=> clock,
			reset			=> reset,
			period		=> period_sig_int,
			period_on	=> period_on_int,
			ack			=>	ack_wave,
			pwm_step		=> open,
			wave			=>	wave
		 );	

	ff:
		process(reset, clock)
			begin	
				if reset = '1' then
					mul_sig					<= (others => '0');	
					period_on_sig			<= (others => '0');	
					freq_sig					<= (others => '0');	
					function_sig			<= (others => '0');	
					n_periods_sig			<= (others => '0');
					last_period_sig		<= (others => '0');
					last_period_on_sig	<= (others => '0');
					n_periods_cnt			<= (others => '0');
					period_sig_int			<= (others => '0');
					period_on_int			<= (others => '0');
--					ack_int_sig				<= '0';
					ack_wcntr_sig			<= '0';
				elsif rising_edge(clock) then
					mul_sig					<= mul_sig_nxt;
					period_on_sig			<= period_on_sig_nxt;
					n_periods_sig			<= n_periods_sig_nxt;
					last_period_sig		<= last_period_sig_nxt;
					last_period_on_sig	<= last_period_on_sig_nxt;
					freq_sig					<= freq_sig_nxt;
					function_sig			<= function_sig_nxt;
					n_periods_cnt			<= n_periods_cnt_nxt;
					period_sig_int			<= period_sig_int_nxt;
					period_on_int			<= period_on_int_nxt;
--					ack_int_sig				<= ack_int_sig_nxt;
					ack_wcntr_sig			<=	ack_wcntr_sig_nxt;
				end if;
	end process ff;	
	
	data_ff:
		process(multiplier_in, n_periods, last_period, last_period_on, function_in, period_on_in, mul_sig, freq_in, data_avail, ack_wcntr_sig, ack_wcntr,clock,freq_sig,period_sig,period_on_sig,function_sig)	
			begin
				if data_avail = '1' then
					mul_sig_nxt 				<= multiplier_in;
					period_on_sig_nxt			<= period_on_in;
					freq_sig_nxt 				<= freq_in;
					function_sig_nxt			<= function_in;
					n_periods_sig_nxt			<= n_periods;
					last_period_sig_nxt		<= last_period;
					last_period_on_sig_nxt	<= last_period_on;
					set_count					<= '1';
					ack_int						<= '1';
					data_req_int				<= '0';
					ack_wcntr_sig_nxt			<= ack_wcntr_sig;
				else
					set_count					<= '0';
					mul_sig_nxt 				<= mul_sig;
					period_on_sig_nxt			<= period_on_sig;
					n_periods_sig_nxt			<= n_periods_sig;
					last_period_sig_nxt		<= last_period_sig;
					last_period_on_sig_nxt	<= last_period_on_sig;
					freq_sig_nxt 				<= freq_sig;
					function_sig_nxt			<= function_sig;
					ack_int						<= '0';		
					if ack_wcntr_sig = '1' then
						data_req_int			<= '1';
						ack_wcntr_sig_nxt		<= ack_wcntr_sig;
					else
						if ack_wcntr = '1' then
							ack_wcntr_sig_nxt	<= '1';
							data_req_int		<= '1';
						else
							ack_wcntr_sig_nxt	<= '0';
							data_req_int		<= '0';
						end if;
					end if;
				end if;
	end process data_ff;	
	
	req_out:
		process(data_req_int,req_enable,freq_sig,mul_sig,function_sig,addr_pwmrom)	
			begin
				if data_req_int = '1' and req_enable = '1' then
					multiplier_out	<= mul_sig;
					pwm_step			<= std_ulogic_vector( unsigned(addr_pwmrom) + 1 );
					freq_out			<= freq_sig;
					function_out	<= function_sig;
				else
					multiplier_out	<= (others => '0');
					pwm_step			<= (others => '0');
					freq_out			<= (others => '0');
					function_out	<= (others => '0');
				end if;
	end process req_out;	

	period_former:
		process(ack_wave,n_periods_cnt,n_periods_sig,period_sig,period_on_sig,last_period_sig,last_period_on_sig,period_sig_int,period_on_int)
			begin
				if ack_wave = '1' then
					n_periods_cnt_nxt	<= std_ulogic_vector(unsigned(n_periods_cnt) + 1);
					ack_wcntr	<= '0';
					if unsigned(n_periods_cnt) < unsigned(n_periods_sig) then
						period_sig_int_nxt	<=  period_sig;
						period_on_int_nxt		<=  period_on_sig;
					else
						ack_wcntr	<= '1';
						if unsigned(last_period_sig)	> 0 then
							period_sig_int_nxt	<=  last_period_sig;
							period_on_int_nxt		<=  last_period_on_sig;
						else
							period_sig_int_nxt	<=  period_sig;
							period_on_int_nxt(period_on_sig'length-1 downto 0)	<=  period_on_sig;
							period_on_int_nxt(period_on_int_nxt'length-1 downto period_on_sig'length)	<= (others => '0');
						end if;
					end if;
				else
					n_periods_cnt_nxt			<=  n_periods_cnt;
					period_sig_int_nxt		<=  period_sig_int;
					period_on_int_nxt			<=  period_on_int;
				end if;
	end process period_former;	
	
end rtl;