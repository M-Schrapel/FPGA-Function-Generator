library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pwm_calculator is
	generic (
		PWM_STEPS		: integer := 512;  -- Number of Steps
		CLOCK_MHZ		: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS		: integer := 256	 -- Amplitude Divider (100 steps + gain)
	);
	port (
		clock 			: in  std_ulogic;
		reset				: in 	std_ulogic;
	
		data_request	: in  std_ulogic;
		period_in		: in  std_logic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0);
		period_on_in	: in  std_logic_vector(integer(ceil(log2(real((PWM_STEPS-1)))))-1 downto 0);
		amp				: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		
		data_avail		: out std_ulogic;
--		period			: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		period_on		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods		: out std_ulogic_vector(16 downto 0);
		last_period		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on	: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0)
    );
end pwm_calculator;


architecture rtl of pwm_calculator is
--
--signal period_on_tmp			: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0):= (others => '0');

--signal delay_cnt				: std_ulogic_vector(17 downto 0)   := (others => '0');
--signal delay_cnt_nxt			: std_ulogic_vector(delay_cnt'length-1 downto 0)   := (others => '0');

signal gain_fin				: std_ulogic := '0';
signal data_avail_int		: std_ulogic := '0';

-- enable caluclation units
signal enable_calc			: std_ulogic := '0';
signal enable_div				: std_ulogic := '0';
-- internal amplification of signal
signal amp_int					: std_ulogic_vector(amp'length-1 downto 0)  := (others => '0');
-- internal signal of period_on_in
signal period_on_int			: std_logic_vector(9 downto 0)   := (others => '0');
-- internal signal of period_on
signal period_in_int			: std_logic_vector(9 downto 0) := (others => '0');
-- internal signal of period
signal period_in_int_sig	: std_logic_vector(19 downto 0) := (others => '0');

-- internal  clock counter 
signal count_int				: std_logic_vector(3 downto 0) := (others => '0');
-- internal  clock counter flip flop
signal count_nxt				: std_logic_vector(3 downto 0) := (others => '0');

-- internal signal
signal gain_res_sig			: std_logic_vector(9 downto 0) := (others => '0');
-- calculated number of HIGH clock ticks for last period after amplification
--signal gain_res				: std_logic_vector(7 downto 0)  := (others => '0');
-- calculated last period signal
signal last_period_int		: std_logic_vector (9 downto 0)  := (others => '0');
signal last_period_int_sig	: std_logic_vector (9 downto 0)  := (others => '0');

-- calculated number of full periods
signal nperiods_int			: std_logic_vector (16 downto 0) := (others => '0');
-- calculated number of HIGH clock ticks for last period
signal last_period_on_int	: std_logic_vector (9 downto 0)  := (others => '0');
--signal last_period_on_tmp	: std_logic_vector (7 downto 0)  := (others => '0');
component gain_unit is
	generic (
		PWM_STEPS		: integer := 512  -- Number of Steps
	);
	port (
		clock			: in  std_ulogic;
		enable			: in  std_ulogic;
		amp				: in  std_ulogic_vector(7 downto 0);
		period_on		: in  std_logic_vector(9 downto 0);
		period_in		: in  std_logic_vector(9 downto 0);
		data_avail		: out std_ulogic;
		period			: out std_logic_vector(9 downto 0)
    );
end component gain_unit;

component last_step_calc is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port (
		clock			: in  std_ulogic;
		enable		: in  std_ulogic;
		period		: in  std_logic_vector(19 downto 0);
		
		nperiods		: out std_logic_vector (16 downto 0);
		last_period	: out std_logic_vector (9 downto 0)
    );
end component last_step_calc;

component mapping_unit is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port (
		clock			: in  std_ulogic;
		enable		: in  std_ulogic;
		last_period	: in  std_logic_vector(9 downto 0);
		period_on	: in  std_logic_vector(9 downto 0);
		data_avail	: out std_ulogic;
		result		: out std_logic_vector(9 downto 0)
    );
end component mapping_unit;
--


begin
period_in_int_sig(period_in'length-1 downto 0)			<= period_in;
last_period_int_sig(last_period_int'length-1 downto 0)	<= last_period_int;

period_on 		<= std_ulogic_vector(unsigned(gain_res_sig(period_on'length-1 downto 0)));
n_periods		<= std_ulogic_vector(unsigned(nperiods_int));
last_period 	<= std_ulogic_vector(unsigned(last_period_int(last_period'length-1 downto 0)));
last_period_on	<= std_ulogic_vector(unsigned(last_period_on_int(last_period_on'length-1 downto 0)));

	gain_calc: gain_unit 
		generic map(
			PWM_STEPS 	=> PWM_STEPS
		)
		port map(
			clock				=> clock,
			enable	 		=> enable_calc,
			amp				=> amp_int,
			period_on 		=> period_on_int,
			period_in		=> period_in_int,
			data_avail		=> gain_fin,
			--data_avail		=> data_avail_int,
			period			=> gain_res_sig
		 );	
		 
	last_step: last_step_calc 
		generic map(
			PWM_STEPS 	=> PWM_STEPS
		)
		port map(
			clock				=> clock,
			enable 			=> enable_calc,
			period			=> period_in_int_sig,
			nperiods 		=> nperiods_int,
			last_period		=> last_period_int
		 );	

	mapping_calc: mapping_unit -- critical path
		generic map(
			PWM_STEPS 	=> PWM_STEPS
		)
		port map(
			clock			=> clock,
			enable 		=> enable_div,
			last_period	=> last_period_int_sig,	
			period_on	=> gain_res_sig,
			data_avail	=> data_avail_int,
			result		=> last_period_on_int	
		 );	
		 
--	ff:
--		process(reset,clock)
--				begin	
--					if reset = '1' then
--						delay_cnt				<= (others => '0');
--					elsif rising_edge(clock) then
--						delay_cnt				<= delay_cnt_nxt;
--					end if;
--	end process ff;		 
--		 
	calc_handler:
		process(data_request, amp, period_on_in,data_avail_int)
				begin	
					if data_request = '1' then
						if data_avail_int	= '1' then
							--if unsigned(delay_cnt) < 7000 then
								--delay_cnt_nxt <= std_ulogic_vector(unsigned(delay_cnt_nxt)+1);
								--data_avail			<= '0';
							--else
--								delay_cnt_nxt <= delay_cnt;
								data_avail			<= '1';
							--end if;
						else
--							delay_cnt_nxt <= (others => '0');
							data_avail			<= '0';	
						end if;
						
						enable_calc			<= '1';					
						amp_int				<= amp;
						period_in_int		<= std_logic_vector(to_unsigned(PWM_STEPS-1,period_in_int'length));
						period_on_int		<= (others => '0');
						period_on_int(period_on_in'length-1 downto 0)	<= std_logic_vector(unsigned(period_on_in));
						--period_on_int(period_on_int'length-1 downto period_on_in'length) <= (others => '0');	
					else
						data_avail			<= '0';
						enable_calc 		<= '0';	
						amp_int				<= (others => '0');	
						period_in_int		<= (others => '0');
						period_on_int		<= (others => '0');	
--						delay_cnt_nxt		<= (others => '0');	
					end if;
	end process calc_handler;	
	
	en_handler:
		process(gain_fin,enable_calc)
				begin	
					if enable_calc = '1' and gain_fin = '1' then
						enable_div <= '1';
					else
						enable_div <= '0';
					end if;
	end process en_handler;		 
--
--	test:
--		process(data_request)
--			begin
--				if data_request = '1' then
--					data_avail_int <='1';
--				else
--					data_avail_int <='0';
--				end if;
--	end process test;
end rtl;