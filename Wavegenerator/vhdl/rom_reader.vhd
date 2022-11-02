library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.function_pkg.all;

entity rom_reader is
	generic (
		PWM_STEPS	: integer := 512;  -- Number of Steps
		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 256;	 -- Amplitude Divider (100 steps + gain)
		MAX_FREQ		: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 6	 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
		--CALC_TICKS	: integer := 5		 -- internal number of clocks until result is valid
	);
	port(
		clock				: in  std_ulogic := '0';
		reset				: in  std_ulogic := '0';
		
		data_request	: in  std_ulogic := '0';
		function_sel	: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0) := (others => '0');
		frequency		: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
		step				: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		factor			: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
		
		data_avail		: out std_ulogic;
		period_on		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods		: out std_ulogic_vector(16 downto 0);
		last_period		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on	: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		
		
		write_custom	: in  std_ulogic := '0';
		custom_select	: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS-5)))),1) downto 0)  := (others => '0');
		address			: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		pwm_value		: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0')
	);
end rom_reader;

architecture rtl of rom_reader is

-- selection of ROM
signal rom_sel				: std_logic_vector(max(NUM_FUNCS,1) downto 0) := (others => '0');
signal rom_wr_sel			: std_logic_vector(max(NUM_FUNCS-5,1) downto 0) := (others => '0');
signal rom_wr_sel_sig		: std_logic_vector(rom_wr_sel'length-1 downto 0) := (others => '0');
-- next (full) period
signal period_next		: std_logic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');
-- next read period from rom 
signal period_pwm_next	: std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal period_pwm_next_sin	: std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal period_pwm_next_rec	: std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal period_pwm_next_tri	: std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal period_pwm_next_saw	: std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
-- signal period_pwm_next_cus	: std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal period_pwm_next_dc	: std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');

type   period_pwm_cus_array is array (0 to max(NUM_FUNCS-6,1)) of std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
signal period_pwm_next_cus			: period_pwm_cus_array;

-- Calculation signals
-- start calculation
signal start_calc			: std_ulogic := '0';
signal start_calc_nxt		: std_ulogic := '0';

signal fin_calc			: std_ulogic := '0';

---- first calculation result (Multiplier)
--signal res_mul1			: std_logic_vector (28 downto 0) := (others => '0');
---- second calculation result (Divider)
--signal res_div				: std_logic_vector (28 downto 0) := (others => '0');
---- final calculation result (amplified)
--signal amplitude			: std_logic_vector (20 downto 0) := (others => '0');

---- Clock counter for valid results
--signal count_clk			: std_ulogic_vector (3 downto 0) := (others => '0');
--signal count_clk_nxt		: std_ulogic_vector (3 downto 0) := (others => '0');

-- 
signal step_int			: std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal frequency_int		: std_logic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
--signal factor_int			: std_logic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
signal pwm_value_int		: std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal period_pwm_int	: std_logic_vector(integer(ceil(log2(real((PWM_STEPS-1)))))-1 downto 0)  := (others => '0');
--signal period_next_int	: std_logic_vector(19 downto 0) := (others => '0');


-- ROM for signals
component sine_ROM_512 is
	port
	(
		address		: in  std_logic_vector (8 downto 0);
		clken			: in  std_logic;
		clock			: in  std_logic;
		q				: out std_logic_vector (8 downto 0)
	);
end component sine_ROM_512;

component triangle_ROM_512 is
	port
	(
		address		: in  std_logic_vector (8 downto 0);
		clken			: in  std_logic;
		clock			: in  std_logic;
		q				: out std_logic_vector (8 downto 0)
	);
end component triangle_ROM_512;

component sawtooth_ROM_512 is
	port
	(
		address		: in  std_logic_vector (8 downto 0);
		clken			: in  std_logic;
		clock			: in  std_logic;
		q				: out std_logic_vector (8 downto 0)
	);
end component sawtooth_ROM_512;

component custom_RAM_512 is
	port
	(
		clock			: in  std_logic;
		data			: in  std_logic_vector (8 downto 0);
		rdaddress	: in  std_logic_vector (8 downto 0);
		rden			: in  std_logic;
		wraddress	: in  std_logic_vector (8 downto 0);
		wren			: in  std_logic;
		q				: out std_logic_vector (8 downto 0)
	);
end component custom_RAM_512;


component sine_ROM_1024 is
	port
	(
		address		: in  std_logic_vector (9 downto 0);
		clken			: in  std_logic  := '1';
		clock			: in  std_logic  := '1';
		q				: out std_logic_vector (9 downto 0)
	);
end component sine_ROM_1024;

component triangle_ROM_1024 is
	port
	(
		address		: in  std_logic_vector (9 downto 0);
		clken			: in  std_logic  := '1';
		clock			: in  std_logic  := '1';
		q				: out std_logic_vector (9 downto 0)
	);
end component triangle_ROM_1024;

component sawtooth_ROM_1024 is
	port
	(
		address		: in  std_logic_vector (9 downto 0);
		clken			: in  std_logic  := '1';
		clock			: in  std_logic  := '1';
		q				: out std_logic_vector (9 downto 0)
	);
end component sawtooth_ROM_1024;

component custom_RAM_1024 is
	port
	(
		clock			: in  std_logic  := '1';
		data			: in  std_logic_vector (9 downto 0);
		rdaddress	: in  std_logic_vector (9 downto 0);
		rden			: in  std_logic  := '1';
		wraddress	: in  std_logic_vector (9 downto 0);
		wren			: in  std_logic  := '0';
		q				: out std_logic_vector (9 downto 0)
	);
end component custom_RAM_1024;

component rect_generator is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port (
		address		: in  	std_logic_vector((integer(ceil(log2(real(PWM_STEPS-1)))))-1 downto 0);
		clken			: in  	std_logic  := '0';
		clock			: in  	std_logic  := '0';
		q				: out   	std_logic_vector((integer(ceil(log2(real(PWM_STEPS-1)))))-1 downto 0)
    );
end component rect_generator;

component dc_generator is
	generic (
		PWM_STEPS	: integer := 512  -- Number of Steps
	);
	port (
		en				: in  	std_logic  := '0';
		q				: out   	std_logic_vector((integer(ceil(log2(real(PWM_STEPS-1)))))-1 downto 0)
    );
end component dc_generator;

-- periods 
component period_ROM_s_512_f_50 is
	port
	(
		address		: in  std_logic_vector (8 downto 0);
		clock			: in  std_logic  := '1';
		q				: out std_logic_vector (16 downto 0)
	);
end component period_ROM_s_512_f_50;

component period_ROM_s_512_f_100 is
	port
	(
		address		: in  std_logic_vector (8 downto 0);
		clock			: in  std_logic  := '1';
		q				: out std_logic_vector (17 downto 0)
	);
end component period_ROM_s_512_f_100;

component period_ROM_s_512_f_350 is
	port
	(
		address		: in  std_logic_vector (8 downto 0);
		clock			: in  std_logic  := '1';
		q				: out std_logic_vector (19 downto 0)
	);
end component period_ROM_s_512_f_350;

component period_ROM_s_1024_f_50 is
	port
	(
		address		: in  std_logic_vector (8 downto 0);
		clock			: in  std_logic  := '1';
		q				: out std_logic_vector (15 downto 0)
	);
end component period_ROM_s_1024_f_50;

component period_ROM_s_1024_f_100 is
	port
	(
		address		: in  std_logic_vector (8 downto 0);
		clock			: in  std_logic  := '1';
		q				: out std_logic_vector (16 downto 0)
	);
end component period_ROM_s_1024_f_100;

component period_ROM_s_1024_f_350 is
	port
	(
		address		: in  std_logic_vector (8 downto 0);
		clock			: in 	std_logic  := '1';
		q				: out std_logic_vector (18 downto 0)
	);
end component period_ROM_s_1024_f_350;

---- Amplitude calculation
--component pwm_calculator is
--	generic (
--		PWM_STEPS	: integer := 512;  -- Number of Steps
--		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
--		AMP_STEPS	: integer := 255;	 -- Amplitude Divider (100 steps + gain)
--		MAX_FREQ		: integer := 512;	 -- Maximum Frequency of Output in Hz
--		CALC_TICKS	: integer := 5		 -- internal number of clocks until result is valid
--	);
--	port (
--		clock				: in  std_ulogic := '0';
--		reset				: in  std_ulogic := '0';
--		
--		start_calc		: in  std_ulogic := '0';
--		factor			: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
--		period			: in  std_logic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0) := (others => '0');
--		period_on		: in  std_logic_vector(9 downto 0);
--		
--		result			: out std_ulogic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0);
--		data_avail		: out std_ulogic
--	);
--end component pwm_calculator;	


component pwm_calculator is
	generic (
		PWM_STEPS		: integer := 512;  -- Number of Steps
		CLOCK_MHZ		: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS		: integer := 256
	);
	port (
		clock 			: in  std_ulogic;
		reset				: in 	std_ulogic;
	
		data_request	: in  std_ulogic;
		period_in		: in  std_logic_vector((integer(ceil(log2(real((CLOCK_MHZ*1000000)/PWM_STEPS)))))-1 downto 0);
		period_on_in	: in  std_logic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		amp				: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		
		data_avail		: out std_ulogic;
--		period			: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		period_on		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods		: out std_ulogic_vector(16 downto 0);
		last_period		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on	: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0)
    );
end component pwm_calculator;


begin
rom_wr_sel_sig(0)		<= write_custom;
-- select function
rom_sel 				<= std_logic_vector(shift_left(to_unsigned(1,NUM_FUNCS+1), to_integer(unsigned(function_sel)) ));
rom_wr_sel 				<= std_logic_vector(shift_left(unsigned(rom_wr_sel_sig), to_integer(unsigned(custom_select)) ));
--rom_sel 				<= std_logic_vector(to_unsigned(1,NUM_FUNCS));
-- output period
--period				<= std_ulogic_vector(period_next);

step_int				<= std_logic_vector(unsigned(unsigned(step)-1));
frequency_int		<= std_logic_vector(unsigned(frequency));
--factor_int			<= std_logic_vector(signed(factor));
pwm_value_int 		<= std_logic_vector(unsigned(pwm_value)-1);
period_pwm_int(period_pwm_next'length-1 downto 0)	<= period_pwm_next;
--period_next_int(period_next'length-1 downto 0)		<= period_next;

-- ROM for wave with pwm steps 
rom_512_gen: if PWM_STEPS = 512 generate

	sine_inst : sine_ROM_512
		port map(
			address		=> step_int,
			clken			=> rom_sel(0),
			clock			=> clock,
			q				=> period_pwm_next_sin
		);
	triangle_inst : triangle_ROM_512
		port map(
			address		=> step_int,
			clken			=> rom_sel(1),
			clock			=> clock,
			q				=> period_pwm_next_tri
		);
	sawtooth_inst : sawtooth_ROM_512
		port map(
			address		=> step_int,
			clken			=> rom_sel(2),
			clock			=> clock,
			q				=> period_pwm_next_saw
		);
	-- custom_inst : custom_RAM_512
		-- port map(
			-- clock			=> clock,
			-- data			=> pwm_value_int,
			-- rdaddress	=> step_int,
			-- rden			=> rom_sel(5),
			-- wraddress	=> std_logic_vector(address),
			-- wren			=> std_logic(write_custom),
			-- q				=> period_pwm_next_cus
		-- );
	custom_rams : if NUM_FUNCS>5 generate
		begin
		custom_gen : for i in 1 to NUM_FUNCS-5 generate
			custom_inst : custom_RAM_512
				port map(
					clock		=> clock,
					data		=> pwm_value_int,
					rdaddress	=> step_int,
					rden		=> rom_sel(i+5),
					wraddress	=> std_logic_vector(address),
					wren		=> std_logic(rom_wr_sel(i-1)),
					q			=> period_pwm_next_cus(i-1)
				);
		end generate custom_gen;
	end generate custom_rams;
		
end generate rom_512_gen;


rom_1024_gen: if PWM_STEPS = 1024 generate

	sine_inst : sine_ROM_1024
		port map(
			address		=> step_int,
			clken			=> rom_sel(0),
			clock			=> clock,
			q				=> period_pwm_next_sin
		);
	triangle_inst : triangle_ROM_1024
		port map(
			address		=> step_int,
			clken			=> rom_sel(1),
			clock			=> clock,
			q				=> period_pwm_next_tri
		);
	sawtooth_inst : sawtooth_ROM_1024
		port map(
			address		=> step_int,
			clken			=> rom_sel(2),
			clock			=> clock,
			q				=> period_pwm_next_saw
		);
	custom_rams : if NUM_FUNCS>5 generate
		begin
		custom_gen : for i in 1 to NUM_FUNCS-5 generate
			custom_inst : custom_RAM_1024
				port map(
					clock		=> clock,
					data		=> pwm_value_int,
					rdaddress	=> step_int,
					rden		=> rom_sel(i+4),
					wraddress	=> std_logic_vector(address),
					wren		=> std_logic(rom_wr_sel(i-1)),
					q			=> period_pwm_next_cus(i-1)
				);
		end generate custom_gen;
	end generate custom_rams;
	
end generate rom_1024_gen;

	rect_inst : rect_generator
		generic map(
			PWM_STEPS	=> PWM_STEPS
		)
		port map(
			address		=> step_int,
			clken			=> rom_sel(3),
			clock			=> clock,
			q				=> period_pwm_next_rec
		 );
	dc_inst : dc_generator
		generic map(
			PWM_STEPS	=> PWM_STEPS
		)
		port map(
			en				=> rom_sel(4),
			q				=> period_pwm_next_dc
		 );
		 
period_rom_512_50_gen: if PWM_STEPS = 512 and CLOCK_MHZ=50 generate	
	period_inst : period_ROM_s_512_f_50
		port map(
			address		=> frequency_int,
			clock			=> clock,
			q				=> period_next
		);
end generate period_rom_512_50_gen;

period_rom_512_100_gen: if PWM_STEPS = 512 and CLOCK_MHZ=100 generate	
	period_inst : period_ROM_s_512_f_100
		port map(
			address		=> frequency_int,
			clock			=> clock,
			q				=> period_next
		);
end generate period_rom_512_100_gen;


period_rom_512_350_gen: if PWM_STEPS = 512 and CLOCK_MHZ=350 generate	
	period_inst : period_ROM_s_512_f_350
		port map(
			address		=> frequency_int,
			clock			=> clock,
			q				=> period_next
		);
end generate period_rom_512_350_gen;

period_rom_1024_50_gen: if PWM_STEPS = 1024 and CLOCK_MHZ=50 generate	
	period_inst : period_ROM_s_1024_f_50
		port map(
			address		=> frequency_int,
			clock			=> clock,
			q				=> period_next
		);
end generate period_rom_1024_50_gen;

period_rom_1024_100_gen: if PWM_STEPS = 1024 and CLOCK_MHZ=100 generate	
	period_inst : period_ROM_s_1024_f_100
		port map(
			address		=> frequency_int,
			clock			=> clock,
			q				=> period_next
		);
end generate period_rom_1024_100_gen;

period_rom_1024_350_gen: if PWM_STEPS = 1024 and CLOCK_MHZ=350 generate	
	period_inst : period_ROM_s_1024_f_350
		port map(
			address		=> frequency_int,
			clock			=> clock,
			q				=> period_next
		);
end generate period_rom_1024_350_gen;


---- calculations for amplitude of signal
--calculator_inst : pwm_calculator 
--	generic map(
--		PWM_STEPS	=> PWM_STEPS,
--		CLOCK_MHZ	=> CLOCK_MHZ,
--		AMP_STEPS	=> AMP_STEPS,
--		MAX_FREQ		=> MAX_FREQ,
--		CALC_TICKS	=> CALC_TICKS
--	)
--	port map(
--		clock			=> clock,
--		reset			=> reset,
--		
--		start_calc	=> start_calc,
--		factor		=> factor,
--		period_on	=> period_pwm_int,
--		period		=> period_next,
--		
--		result		=> period_on,
--		data_avail	=> fin_calc
--	);

-- calculations for amplitude of signal
calculator_inst : pwm_calculator 
	generic map(
		PWM_STEPS		=> PWM_STEPS,
		CLOCK_MHZ		=> CLOCK_MHZ,
		AMP_STEPS		=> AMP_STEPS
	)
	port map(
		clock				=> clock,
		reset				=> reset,
		
		data_request	=> start_calc,
		period_in		=> period_next,
		period_on_in	=> period_pwm_int,
		amp				=> factor,

		data_avail		=> fin_calc,
		period_on		=> period_on,
		n_periods		=> n_periods,
		last_period		=> last_period,
		last_period_on	=> last_period_on
	);		 
	-- check for clipping of amplitude
--	clipping_check:
--		process(amplitude,period_next)	
--			begin 
--
--	end process clipping_check;	
		 
	ff:
		process(reset,clock)
				begin	
					if reset = '1' then
						start_calc	<= '0';
					elsif rising_edge(clock) then
						start_calc	<= start_calc_nxt;
					end if;
	end process ff;	

	-- count ticks & communication
	handle_data:
		process(data_request,fin_calc,start_calc)
				begin	
					if data_request = '1' then
						start_calc_nxt	<= '1';
					else
						start_calc_nxt	<= '0';
					end if;
					if	fin_calc	= '1' and start_calc = '1' then
						data_avail	<= '1';
					else
						data_avail	<= '0';
					end if;
	end process handle_data;	
	
	period_sel:
		process(rom_sel,period_pwm_next_sin,period_pwm_next_tri,period_pwm_next_saw,period_pwm_next_rec,period_pwm_next_dc,period_pwm_next_cus)
				begin	
					period_pwm_next<= (others => '0');	
					if rom_sel(0) = '1' then
						period_pwm_next	<= period_pwm_next_sin;
					elsif rom_sel(1) = '1' then
						period_pwm_next	<= period_pwm_next_tri;
					elsif rom_sel(2) = '1' then
						period_pwm_next	<= period_pwm_next_saw;
					elsif rom_sel(3) = '1' then
						period_pwm_next	<= period_pwm_next_rec;
					elsif rom_sel(4) = '1' then
						period_pwm_next	<= period_pwm_next_dc;
						-- period_pwm_next	<= period_pwm_next_cus;
					else
						if to_unsigned(NUM_FUNCS,8) >  5 then
							for i in 5 to NUM_FUNCS-1 loop
								if rom_sel(i) = '1' then
									period_pwm_next	<= period_pwm_next_cus(i-5);
									exit;
								end if;
							end loop;
						else
							period_pwm_next	<= (others => '0');
						end if;
					end if;
	end process period_sel;	
	
end rtl;