-----------------------------------------------------------
-- 	Human-Computer Interaction Group
-- 	Leibniz University Hannover
-----------------------------------------------------------
-- project:			Waveganerator
--	file :			counter.vhdl
--	authors :		Maximilian Schrapel	
--	last update :	08/2018
--	description :	Wave Counter
--						Generates PWM Signal with data from ROM
-----------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity wavecounter is
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
end wavecounter;

architecture rtl of wavecounter is

signal next_pwmstep		 : std_ulogic := '0';
--signal pwm_step			 : std_ulogic_vector((integer(ceil(log2(real(PWM_STEPS*1)))))-1 downto 0);

signal period_sig			 : std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');
signal period_sig_nxt	 : std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');

signal period_cnt			 : std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');
signal period_cnt_nxt	 : std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');

signal period_on_sig		 : std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');
signal period_on_sig_nxt : std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');


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

begin

	pwmsteps : counter -- counter for every pwm step
		generic map(
			MAX_VALUE 	=> (CLOCK_MHZ*1000000/PWM_STEPS)/PWM_STEPS
		)
		port map(
			clock 		=> clock,
			reset			=> reset,

			set_count	=> '0',
			count_new	=> (others => '0'),

			
			enable		=> next_pwmstep,
			count			=> pwm_step
		 );		
	
	ff:
		process(reset,clock)
				begin	
					if reset = '1' then
						period_sig		<= (others => '0');			
						period_cnt		<= (others => '0');	
						period_on_sig 	<= (others => '0');	
					elsif rising_edge(clock) then
						period_sig		<= period_sig_nxt;
						period_cnt  	<= period_cnt_nxt;
						period_on_sig 	<= period_on_sig_nxt;
					end if;
	end process ff;	
	
	period_ack:
		process(period_sig,period_on,period,period_on_sig,period_cnt)
				begin		
					if unsigned(period_sig) = unsigned(period_cnt) then
						ack 					<= '1';	
						period_sig_nxt 	<= period;
						period_on_sig_nxt	<= period_on;
						next_pwmstep 		<= '1';	
						period_cnt_nxt		<= (others => '0');	
					else
						ack 					<= '0';	
						period_sig_nxt 	<= period_sig;
						period_on_sig_nxt	<= period_on_sig;
						next_pwmstep 		<= '0';
						period_cnt_nxt 	<= std_ulogic_vector( unsigned(period_cnt) + 1 );
					end if;	
	end process period_ack;	

	pwm_cnt:
		process(period_on_sig,period_cnt)
			begin	
				if ((unsigned(period_on_sig) < unsigned(period_cnt)) and (unsigned(period_on_sig) > 0)) or (unsigned(period_on_sig) = 0) then
					wave <= '0';
				else
					wave <= '1';
				end if;
	end process pwm_cnt;

	
end architecture rtl;