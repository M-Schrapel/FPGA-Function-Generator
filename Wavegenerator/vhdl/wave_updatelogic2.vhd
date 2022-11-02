library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.function_pkg.all;

entity wave_updatelogic2 is
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
		function_request_wave			: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0);
		-- response 
		data_avail_response_wave		: out std_ulogic_vector(max(NUM_PORTS-1,1) downto 0);
		mult_response_wave				: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		period_on_response_wave			: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods_response_wave			: out std_ulogic_vector(16 downto 0);
		last_period_response_wave		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on_response_wave	: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		freq_response_wave				: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_response_wave			: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0);
		pwm_step_response_wave			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
	
		-- rom reader communication
		
		-- requesting data
		data_request_rom					: out std_ulogic := '0';
		function_request_rom				: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0) := (others => '0');
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
		function_select					: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0) := (others => '0');
		frequency_select					: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
		mult_select							: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0)  := (others => '0');
		phasereference_select			: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_PORTS*1)))),1) downto 0)  := (others => '0');
		phase_value_select				: in  std_ulogic_vector(8 downto 0)  := (others => '0');
		data_back							: out std_ulogic_vector(max(integer(ceil(log2(real(PWM_STEPS*1)))),integer(ceil(log2(real(MAX_FREQ*1)))))-1 downto 0) := (others => '0');
		write_custom_request				: in  std_ulogic := '0';
		address_request					: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		pwm_value_request					: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		ack_ext								: out std_ulogic := '0'
	);
end wave_updatelogic2;

architecture rtl of wave_updatelogic2 is

signal cnt_delay					: std_ulogic_vector(max(integer(ceil(log2(real((8))))),1) downto 0) := (others => '0');
signal cnt_delay_nxt				: std_ulogic_vector(max(integer(ceil(log2(real((8))))),1) downto 0) := (others => '0');

signal data_request_rom_nxt					: std_ulogic := '0';
signal data_request_rom_int					: std_ulogic := '0';

-- counter through units
signal unit_count						: std_ulogic_vector(max(integer(ceil(log2(real((NUM_PORTS*1))))),1) downto 0) := (others => '0');
signal unit_count_nxt				: std_ulogic_vector(max(integer(ceil(log2(real((NUM_PORTS*1))))),1) downto 0) := (others => '0');

signal mult_int						: std_ulogic_vector(mult_request_rom'length-1 downto 0) := (others => '0');
signal function_int					: std_ulogic_vector(function_select'length-1 downto 0) := (others => '0');
signal frequency_int					: std_ulogic_vector(frequency_request_rom'length-1 downto 0) := (others => '0');
signal pwm_step_int					: std_ulogic_vector(step_request_rom'length-1 downto 0) := (others => '0');

signal phase_reference				: std_ulogic_vector(max(integer(ceil(log2(real(NUM_PORTS*1)))),1) downto 0)  := (others => '0');
signal phase_reference_val			: std_ulogic_vector(pwm_step_request_wave'length-1 downto 0) := (others => '0');
signal phase_reference_val_nxt	: std_ulogic_vector(pwm_step_request_wave'length-1 downto 0) := (others => '0');

-- found reference
signal phase_ref_written			: std_ulogic := '0';
signal phase_ref_written_nxt		: std_ulogic := '0';


-- value of phase shift
signal phase_val						: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
signal phase_val_int					: std_logic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
-- for writing to custom ROM
signal write_custom_sig				: std_ulogic := '0';
signal address_sig					: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal pwm_value_sig					: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');

component phase_LUT_512 is
	PORT
	(
		address		: in 	std_logic_vector (8 downto 0);
		clock			: in 	std_logic  := '1';
		q				: out std_logic_vector (8 downto 0)
	);
end component phase_LUT_512;

component phase_LUT_1024 is
	PORT
	(
		address		: in 	std_logic_vector (8 downto 0);
		clock			: in 	std_logic  := '1';
		q				: out std_logic_vector (9 downto 0)
	);
end component phase_LUT_1024;


begin
phase_val						<= std_ulogic_vector(phase_val_int);
phase_reference				<= phasereference_select;
write_custom_sig				<= write_custom_request;
address_sig						<= address_request;
pwm_value_sig					<= pwm_value_request;
write_custom_request_rom	<= write_custom_sig;
address_request_rom			<= address_sig;
pwm_value_request_rom		<= pwm_value_sig;
--data_request_rom				<= data_request_rom_int;
period_on_response_wave		<= period_on_response_rom;
n_periods_response_wave		<= n_periods_response_rom;
last_period_response_wave			<= last_period_response_rom;
last_period_on_response_wave		<= last_period_on_response_rom;


phase_512_gen: if PWM_STEPS = 512 generate
	phase_LUT_inst : phase_LUT_512
		port map(
			address		=> std_logic_vector(phase_value_select),
			clock			=> clock,
			q				=> phase_val_int
		);
end generate phase_512_gen;

phase_1024_gen: if PWM_STEPS = 1024 generate
	phase_LUT_inst : phase_LUT_1024
		port map(
			address		=> std_logic_vector(phase_value_select),
			clock			=> clock,
			q				=> phase_val_int
		);
end generate phase_1024_gen;

	ff:
		process(reset,clock)
				begin	
					if reset = '1' then
						unit_count	<= (others => '0');	
						phase_ref_written	<= '0';	
						phase_reference_val	<= (others => '0');	
						data_request_rom_int		<= '0';
						cnt_delay					<= (others => '0');	
					elsif rising_edge(clock) then
						unit_count	<= unit_count_nxt;
						phase_ref_written <= phase_ref_written_nxt;	
						phase_reference_val <= phase_reference_val_nxt;
						data_request_rom_int	<= data_request_rom_nxt;
						cnt_delay					<= cnt_delay_nxt;	
					end if;
	end process ff;	

	unit_select:
		process(unit_count,data_request_wave,cnt_delay,ext_request,type_request,wave_unit_select,phasereference_select,phase_ref_written,data_avail_response_rom)
			begin
				enable_request_wave	<= (others => '0');	
				-- check if unit requests data
				if data_request_wave(to_integer(unsigned(unit_count))) = '1' then
					unit_count_nxt		<= unit_count;	
					enable_request_wave(to_integer(unsigned(unit_count)))	<= '1';	
					if unsigned(cnt_delay) < 1 then -- delay for setteling signals
						cnt_delay_nxt				<= std_ulogic_vector(unsigned(cnt_delay)+1);
					else -- after delay take values
						data_request_rom				<= '1';
						if ext_request	= '0' or unsigned(wave_unit_select) /= unsigned(unit_count) then	-- no external changes
							ack_ext							<= '0';
							function_request_rom			<=	function_request_wave;
							frequency_request_rom		<=	freq_request_wave;
							step_request_rom				<=	pwm_step_request_wave;
							mult_request_rom				<=	mult_request_wave;
							function_int				<=	function_request_wave;
							frequency_int				<=	freq_request_wave;
							pwm_step_int				<=	pwm_step_request_wave;
							mult_int						<=	mult_request_wave;
							if  ext_request = '1' and unsigned(phasereference_select) = unsigned(wave_unit_select) then
								phase_reference_val_nxt	<= std_ulogic_vector(phase_val_int);
								phase_ref_written_nxt	<= '1';
							else
								phase_reference_val_nxt	<= phase_reference_val;
								phase_ref_written_nxt	<= phase_ref_written;
							end if;
							
						else
							data_back <= (others => '0');
							if unsigned(type_request) = 0 then -- 0: function select
								function_request_rom			<=	function_select;
								frequency_request_rom		<=	freq_request_wave;
								step_request_rom				<=	pwm_step_request_wave;
								mult_request_rom				<=	mult_request_wave;
								function_int				<=	function_select;
								frequency_int				<=	freq_request_wave;
								pwm_step_int				<=	pwm_step_request_wave;
								mult_int						<=	mult_request_wave;
							elsif unsigned(type_request) = 1 then -- 1: frequency select
								function_request_rom			<=	function_request_wave;
								frequency_request_rom		<=	frequency_select;
								step_request_rom				<=	pwm_step_request_wave;
								mult_request_rom				<=	mult_request_wave;
								function_int				<=	function_request_wave;
								frequency_int				<=	freq_request_wave;
								pwm_step_int				<=	pwm_step_request_wave;
								mult_int						<=	mult_request_wave;
							elsif unsigned(type_request) = 2 then -- 2: multiplier select
								function_request_rom			<=	function_request_wave;
								frequency_request_rom		<=	freq_request_wave;
								step_request_rom				<=	pwm_step_request_wave;
								mult_request_rom				<=	mult_select;
							function_int				<=	function_request_wave;
							frequency_int				<=	freq_request_wave;
							pwm_step_int				<=	pwm_step_request_wave;
							mult_int						<=	mult_select;
							elsif unsigned(type_request) = 3 then-- 3: phase select
								function_request_rom			<=	function_request_wave;
								frequency_request_rom		<=	freq_request_wave;
								mult_request_rom				<=	mult_request_wave;
							function_int				<=	function_request_wave;
							frequency_int				<=	freq_request_wave;
							mult_int						<=	mult_request_wave;
								if phase_ref_written = '1' and unsigned(wave_unit_select) = unsigned(unit_count) then -- reference has been stored
									if	unsigned(phase_reference_val) + unsigned(pwm_step_request_wave) >= to_unsigned(PWM_STEPS,pwm_step_request_wave'length+1) then
										step_request_rom		<= std_ulogic_vector(to_unsigned(PWM_STEPS,pwm_step_request_wave'length) - unsigned(phase_reference_val) - unsigned(pwm_step_request_wave));
										pwm_step_int			<=	std_ulogic_vector(to_unsigned(PWM_STEPS,pwm_step_request_wave'length) - unsigned(phase_reference_val) - unsigned(pwm_step_request_wave));
									else
										step_request_rom		<= std_ulogic_vector(unsigned(phase_reference_val) + unsigned(pwm_step_request_wave));
										pwm_step_int			<= std_ulogic_vector(unsigned(phase_reference_val) + unsigned(pwm_step_request_wave));
									end if;	
								else
									step_request_rom			<=	pwm_step_request_wave;
									pwm_step_int				<=	pwm_step_request_wave;
								end if;
							elsif unsigned(type_request)>3 then -- 4: request data
								function_request_rom			<=	function_request_wave;
								frequency_request_rom		<=	freq_request_wave;
								step_request_rom				<=	pwm_step_request_wave;
								mult_request_rom				<=	mult_request_wave;
								if unsigned(type_request(1 downto 0)) = 0 then
									data_back(function_int'length-1 downto 0)		<= function_request_wave;
									data_back(data_back'length-1 downto function_int'length)<= (others => '0');
								elsif unsigned(type_request(1 downto 0)) = 1 then
									data_back(frequency_int'length-1 downto 0)	<= freq_request_wave;
									--data_back(data_back'length-1 downto frequency_int'length)<= (others => '0');
								elsif unsigned(type_request(1 downto 0)) = 2 then 
									data_back(mult_int'length-1 downto 0)			<= mult_request_wave;
									data_back(data_back'length-1 downto mult_int'length)<= (others => '0');
								else
									data_back(pwm_step_int'length-1 downto 0)		<= pwm_step_request_wave;
									--data_back(data_back'length-1 downto pwm_step_int'length)<= (others => '0');
								end if;
							end if;
						end if;
						if data_avail_response_rom = '1' then
							data_avail_response_wave(to_integer(unsigned(unit_count)))		<= '1';
							--period_on_response_wave			<= period_on_response_rom;
							--n_periods_response_wave			<= n_periods_response_rom;
							--last_period_response_wave		<= last_period_response_rom;
							--last_period_on_response_wave	<= last_period_on_response_rom;
							mult_response_wave				<= mult_int;
							freq_response_wave				<= frequency_int;
							function_response_wave			<= function_int;
							pwm_step_response_wave			<= pwm_step_int;
							
							if ext_request	= '1' and unsigned(wave_unit_select) = unsigned(unit_count) then
								if unsigned(type_request) = 3 then-- 3: phase select
									if phase_ref_written = '1' then
										ack_ext	<= '1';
									else
										ack_ext	<= '0';
									end if;
								else
									ack_ext	<= '1';
								end if;
							end if;
						end if;
					end if;
				else
					if unsigned(unit_count) 	< to_unsigned(NUM_PORTS-1,unit_count'length) then
						unit_count_nxt				<= std_ulogic_vector(unsigned(unit_count)+1);
					else
						unit_count_nxt 			<= (others => '0');	
					end if;
					cnt_delay_nxt				<= (others => '0');
					data_request_rom			<= '0';
					function_request_rom		<=	(others => '0');
					frequency_request_rom	<=	(others => '0');
					step_request_rom			<=	(others => '0');
					mult_request_rom			<=	(others => '0');
					ack_ext						<= '0';
					if ext_request = '1' then
						phase_reference_val_nxt	<= phase_reference_val;
						phase_ref_written_nxt	<= phase_ref_written;
					else
						phase_reference_val_nxt	<= (others => '0');
						phase_ref_written_nxt	<= '0';
					end if;
					data_back						<= (others => '0');
					data_avail_response_wave	<= (others => '0');
					function_int					<=	(others => '0');
					frequency_int					<=	(others => '0');
					pwm_step_int					<=	(others => '0');
					mult_int							<=	(others => '0');	
				end if;
	end process unit_select;	
	
end rtl;