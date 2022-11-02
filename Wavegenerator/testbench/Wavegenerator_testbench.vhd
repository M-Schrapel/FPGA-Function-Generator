library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity Wavegenerator_testbench is
	generic (
      BAUD_RATE   : integer := 115200; -- baud rate value
      PARITY_BIT  : string  := "none"; -- type of parity: "none", "even", "odd", "mark", "space"
		NUM_PORTS	: integer := 170;  	 -- Number of Ports
		PWM_STEPS	: integer := 512;  -- Number of Steps
		CLOCK_MHZ	: integer := 100;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 255;	 -- Amplitude Divider (100 steps)
		MAX_FREQ		: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 5		 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
	);
	end Wavegenerator_testbench;

architecture rtl of Wavegenerator_testbench is

signal clock			: std_ulogic := '0';
signal reset		 	: std_ulogic := '0';
signal uart_rxd		: std_ulogic := '0';
signal uart_txd		: std_ulogic := '0';
signal wave				: std_ulogic_vector(NUM_PORTS-1 downto 0);
component Wavegenerator is
	generic (
      BAUD_RATE   : integer := 115200; -- baud rate value
      PARITY_BIT  : string  := "none"; -- type of parity: "none", "even", "odd", "mark", "space"
		NUM_PORTS	: integer := 1;  	 -- Number of Ports
		PWM_STEPS	: integer := 1024;  -- Number of Steps
		CLOCK_MHZ	: integer := 350;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 255;	 -- Amplitude Divider (100 steps)
		MAX_FREQ		: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 5		 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)

	);
	port(
		clock		: in	std_ulogic;
		reset		: in	std_ulogic;
      uart_rxd	: in  std_ulogic;
		uart_txd	: out std_ulogic;
		wave		: out	std_ulogic_vector(NUM_PORTS-1 downto 0)
	);
end component Wavegenerator;

begin

	gen_reset : process
	begin
		reset <= '1';
		wait for 80 ns;
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
	
	wave_gen : Wavegenerator -- counter for every pwm step
		generic map(
			BAUD_RATE   => BAUD_RATE,
			PARITY_BIT  => PARITY_BIT,
			NUM_PORTS	=> NUM_PORTS,
			PWM_STEPS	=> PWM_STEPS,
			CLOCK_MHZ	=> CLOCK_MHZ,
			AMP_STEPS	=> AMP_STEPS,
			MAX_FREQ		=> MAX_FREQ,
			NUM_FUNCS	=> NUM_FUNCS
		)
		port map(
			clock 		=> clock,
			reset			=> reset,
			uart_rxd		=> uart_rxd,
			uart_txd		=> uart_txd,
			wave			=> wave
		 );	
	

end rtl;