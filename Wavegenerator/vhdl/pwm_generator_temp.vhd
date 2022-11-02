library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pwm_generator is
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
end pwm_generator;

architecture rtl of pwm_generator is

signal period_on_act				: std_ulogic_vector(period_on'length - 1 downto 0) 		:= (others => '0');
signal period_on_act_nxt		: std_ulogic_vector(period_on'length - 1 downto 0) 		:= (others => '0');
signal period_on_tmp				: std_ulogic_vector(period_on'length - 1 downto 0) 		:= (others => '0');
signal period_on_tmp_nxt		: std_ulogic_vector(period_on'length - 1 downto 0) 		:= (others => '0');


signal n_periods_act				: std_ulogic_vector(n_periods'length - 1 downto 0) 		:= (others => '0');
signal n_periods_act_nxt		: std_ulogic_vector(n_periods'length - 1 downto 0) 		:= (others => '0');
signal n_periods_tmp				: std_ulogic_vector(n_periods'length - 1 downto 0) 		:= (others => '0');
signal n_periods_tmp_nxt		: std_ulogic_vector(n_periods'length - 1 downto 0) 		:= (others => '0');

signal n_periods_cnt				: std_ulogic_vector(n_periods'length - 1 downto 0) 		:= (others => '0');
signal n_periods_cnt_nxt		: std_ulogic_vector(n_periods'length - 1 downto 0) 		:= (others => '0');
signal period_cnt					: std_ulogic_vector(n_periods'length - 1 downto 0) 		:= (others => '0');
signal period_cnt_nxt			: std_ulogic_vector(n_periods'length - 1 downto 0) 		:= (others => '0');


signal last_period_act			: std_ulogic_vector(last_period'length - 1 downto 0) 		:= (others => '0');
signal last_period_act_nxt		: std_ulogic_vector(last_period'length - 1 downto 0) 		:= (others => '0');
signal last_period_tmp			: std_ulogic_vector(last_period'length - 1 downto 0) 		:= (others => '0');
signal last_period_tmp_nxt		: std_ulogic_vector(last_period'length - 1 downto 0) 		:= (others => '0');

signal last_period_on_act		: std_ulogic_vector(last_period_on'length - 1 downto 0) 	:= (others => '0');
signal last_period_on_act_nxt	: std_ulogic_vector(last_period_on'length - 1 downto 0) 	:= (others => '0');
signal last_period_on_tmp		: std_ulogic_vector(last_period_on'length - 1 downto 0)	:= (others => '0');
signal last_period_on_tmp_nxt	: std_ulogic_vector(last_period_on'length - 1 downto 0) 	:= (others => '0');

signal data_request_int			: std_ulogic := '0';
signal data_request_int_nxt	: std_ulogic := '0';
--signal data_valid_int			: std_ulogic := '0';
--signal data_valid_int_nxt		: std_ulogic := '0';

begin

data_request	<=	data_request_int;

	ff:
		process(reset,clock)
				begin	
					if reset = '1' then
						period_on_act			<= (others => '0');
						period_on_tmp			<= (others => '0');
						n_periods_act			<= (others => '0');
						n_periods_tmp			<= (others => '0');
						last_period_act		<= (others => '0');
						last_period_tmp		<= (others => '0');
						last_period_on_act	<= (others => '0');
						last_period_on_tmp	<= (others => '0');
						n_periods_cnt			<= (others => '0');
						period_cnt				<= (others => '0');
						data_request_int		<= '1';
					elsif rising_edge(clock) then
						period_on_act			<= period_on_act_nxt;
						period_on_tmp			<= period_on_tmp_nxt;
						n_periods_act			<= n_periods_act_nxt;
						n_periods_tmp			<= n_periods_tmp_nxt;
						last_period_act		<= last_period_act_nxt;
						last_period_tmp		<= last_period_tmp_nxt;
						last_period_on_act	<= last_period_on_act_nxt;
						last_period_on_tmp	<= last_period_on_tmp_nxt;
						n_periods_cnt			<= n_periods_cnt_nxt;
						period_cnt				<= period_cnt_nxt;
						data_request_int		<= data_request_int_nxt;
					end if;
	end process ff;	

--	counters:
--		process(period_cnt,period_on_act,n_periods_cnt)
--				begin	
--					if to_unsigned(PWM_STEPS-1,period_cnt'length)	>	unsigned(period_cnt) then
--						period_cnt_nxt	<= std_ulogic_vector(unsigned(period_cnt) + 1);
--						n_periods_cnt_nxt	<= n_periods_cnt;
--					else
--						period_cnt_nxt	<= (others => '0');
--						n_periods_cnt_nxt	<= std_ulogic_vector(unsigned(n_periods_cnt) + 1);
--					end if;
--					
--
--	end process counters;	

	gen_wave:
		process(period_on,last_period,last_period_on,n_periods,data_request_int,data_valid,n_periods_cnt,n_periods_act,period_cnt,period_on_act,period_on_tmp,last_period_act,n_periods_tmp,last_period_tmp,last_period_on_tmp,last_period_on_act)
				begin	
					if data_request_int = '1' then
						if data_valid = '1' then
							period_on_tmp_nxt			<=	period_on;
							last_period_tmp_nxt		<=	last_period;
							last_period_on_tmp_nxt	<= last_period_on;
							n_periods_tmp_nxt			<= n_periods;
							--data_valid_int				<= data_valid;
						else
							period_on_tmp_nxt			<=	period_on_tmp;
							last_period_tmp_nxt		<=	last_period_tmp;
							last_period_on_tmp_nxt	<= last_period_on_tmp;
							n_periods_tmp_nxt			<= n_periods_tmp;
							--data_valid_int				<= '0';--data_valid_int_nxt;
						end if;
					else
						--data_valid_int					<= '0';
						period_on_tmp_nxt				<=	period_on_tmp;
						last_period_tmp_nxt			<=	last_period_tmp;
						last_period_on_tmp_nxt		<= last_period_on_tmp;
						n_periods_tmp_nxt				<= n_periods_tmp;
					end if;
				
					if unsigned(n_periods_cnt) < unsigned(n_periods_act) then
						step_trigger		<=  '0';
						if to_unsigned(PWM_STEPS-1,period_cnt'length)	>	unsigned(period_cnt) then
							period_cnt_nxt	<= std_ulogic_vector(unsigned(period_cnt) + 1);
							n_periods_cnt_nxt	<= n_periods_cnt;
						else
							period_cnt_nxt	<= (others => '0');
							n_periods_cnt_nxt	<= std_ulogic_vector(unsigned(n_periods_cnt) + 1);
						end if;
						period_on_act_nxt				<=	period_on_act;
						last_period_act_nxt			<= last_period_act;
						n_periods_act_nxt				<= n_periods_act;
						last_period_on_act_nxt		<= last_period_on_act;
						if data_valid = '0' then
							data_request_int_nxt		<= data_request_int;
						else
							data_request_int_nxt		<=  '0';
						end if;
						if unsigned(period_cnt) < unsigned(period_on_act)+1 and unsigned(period_on_act) > 0 then
							wave							<=  '1';
						else
							if unsigned(period_on_act) = to_unsigned(PWM_STEPS-1,period_on_act'length) then
								wave						<=  '1';
							else
								wave						<=  '0';
							end if;
						end if;
					else
						-- last step
						
						if unsigned(last_period_act)	>	unsigned(period_cnt)+1 then
							period_cnt_nxt		<= std_ulogic_vector(unsigned(period_cnt) + 1);
							n_periods_cnt_nxt	<= n_periods_cnt;
							step_trigger		<=  '0';
						else
							period_cnt_nxt		<= (others => '0');
							n_periods_cnt_nxt	<= (others => '0');
							step_trigger		<=  '1';
						end if;
						
						if unsigned(period_cnt) < unsigned(last_period_on_act) then
							wave		<=  '1';
						else
							wave		<=  '0';
						end if;
						
						if unsigned(period_cnt)+1 < unsigned(last_period_act) then
							period_on_act_nxt			<=	period_on_act;
							last_period_act_nxt		<= last_period_act;
							n_periods_act_nxt			<= n_periods_act;
							last_period_on_act_nxt	<= last_period_on_act;
							if data_valid = '0' then
								data_request_int_nxt		<= data_request_int;
							else
								data_request_int_nxt		<=  '0';
							end if;
						else
							period_on_act_nxt			<=	period_on_tmp;
							last_period_act_nxt		<=	last_period_tmp;
							last_period_on_act_nxt	<= last_period_on_tmp;
							n_periods_act_nxt			<= n_periods_tmp;
							if data_valid = '0' then
								data_request_int_nxt		<= '1';
							else
								data_request_int_nxt		<=  '0';
							end if;
						end if;
					end if;
	end process gen_wave;	
	
--	
--	get_data:
--		process(data_request_int)
--			begin	
--				if data_request_int = '1' then
--					if data_valid = '1' then
--						period_on_tmp_nxt			<=	period_on;
--						last_period_tmp_nxt		<=	last_period;
--						last_period_on_tmp_nxt	<= last_period_on;
--						n_periods_tmp_nxt			<= n_periods;
--						data_valid_int				<= data_valid;
--					else
--						period_on_tmp_nxt			<=	period_on_tmp;
--						last_period_tmp_nxt		<=	last_period_tmp;
--						last_period_on_tmp_nxt	<= last_period_on_tmp;
--						n_periods_tmp_nxt			<= n_periods_tmp;
--						data_valid_int				<= data_valid_int_nxt;
--					end if;
--				else
--					data_valid_int					<= '0';
--					period_on_tmp_nxt				<=	period_on_tmp;
--					last_period_tmp_nxt			<=	last_period_tmp;
--					last_period_on_tmp_nxt		<= last_period_on_tmp;
--					n_periods_tmp_nxt				<= n_periods_tmp;
--				end if;
--	end process get_data;	
	
end rtl;