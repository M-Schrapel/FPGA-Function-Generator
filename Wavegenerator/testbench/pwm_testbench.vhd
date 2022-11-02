library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pwm_testbench is
	generic (
		PWM_STEPS	: integer := 512;  -- Number of Steps
		CLOCK_MHZ	: integer := 50   -- Clock signal in MHZ
	);
end entity pwm_testbench;

architecture rtl of pwm_testbench is

signal clock			: std_ulogic := '0';
signal reset		 	: std_ulogic := '0';
signal ack		 		: std_ulogic := '0';
signal wave		 		: std_ulogic := '0';
signal pwm_step		: std_ulogic_vector((integer(ceil(log2(real(PWM_STEPS*1)))))-1 downto 0)  := (others => '0');
signal period			: std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0)  := (others => '0'); -- Minimum update rate at 1Hz
signal period_on		: std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0)  := (others => '0'); -- Minimum update rate at 1Hz


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
		pwm_step		: out std_ulogic_vector((integer(ceil(log2(real(PWM_STEPS*1)))))-1 downto 0);
		wave			: out std_ulogic
    );
	end component wavecounter;

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

	gen_pwm : process(clock)
	begin
		if rising_edge(clock) then
		period		<= std_ulogic_vector(to_unsigned(20,period'length));
		period_on 	<= std_ulogic_vector(to_unsigned(0,period_on'length));
		end if;
	end process gen_pwm;
	
	waver : wavecounter -- counter for every pwm step
		generic map(
			PWM_STEPS 	=> PWM_STEPS,
			CLOCK_MHZ 	=> CLOCK_MHZ
		)
		port map(
			clock 		=> clock,
			reset			=> reset,
			period		=> period,
			period_on	=> period_on,
			ack			=> ack,
			pwm_step		=> pwm_step,
			wave			=> wave
		 );	

end architecture rtl;