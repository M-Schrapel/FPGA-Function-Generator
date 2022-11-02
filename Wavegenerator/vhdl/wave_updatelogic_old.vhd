library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.function_pkg.all;

entity wave_updatelogic_old is
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
end wave_updatelogic_old;

architecture rtl of wave_updatelogic_old is

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
data_request_rom				<= data_request_rom_int;
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
		process(cnt_delay,reset,data_avail_response_rom,pwm_step_int,function_int,frequency_int,function_request_wave,mult_int,function_select,freq_request_wave,frequency_select,mult_select,phase_val,phasereference_select,phase_reference_val,wave_unit_select,phase_value_select,type_request,ext_request,phase_reference,phase_ref_written,unit_count,data_request_wave,mult_request_wave,pwm_step_request_wave)
				begin	
					cnt_delay_nxt	<= cnt_delay;		
					if data_request_wave(to_integer(unsigned(unit_count))) = '1' and reset = '0' and unsigned(cnt_delay)>1 then
						enable_request_wave <= (others => '0');
						enable_request_wave(to_integer(unsigned(unit_count))) <= '1';
						--enable_request_wave(enable_request_wave'length-1 downto to_integer(unsigned(unit_count)+1)) <= (others => '0');
						--enable_request_wave(to_integer(unsigned(unit_count)-1)downto 0) <= (others => '0');
						if data_avail_response_rom = '0' then
							data_request_rom_nxt				<= data_request_wave(to_integer(unsigned(unit_count)));
						else
							data_request_rom_nxt				<= '0';
						end if;
						--- external request for new wave generation
						
						-- phase ( find reference)
						if unsigned(unit_count) = unsigned(phase_reference) and ext_request = '1' and phase_ref_written = '0' and unsigned(type_request) = 3 then
							phase_reference_val_nxt	<= pwm_step_request_wave;
							phase_ref_written_nxt	<= '1';
						else
							if unsigned(type_request) /= 3 then
								phase_reference_val_nxt	<= (others => '0');--phase_reference_val;
								phase_ref_written_nxt	<= '0';--phase_ref_written;
							else
								phase_reference_val_nxt	<= phase_reference_val;
								phase_ref_written_nxt	<= phase_ref_written;
							end if;
--							if unsigned(wave_unit_select) /= unsigned(unit_count) then
--								phase_reference_val_nxt	<= phase_reference_val;
--								phase_ref_written_nxt	<= phase_ref_written;
--							else
--								if unsigned(type_request) /= 3 then
--									phase_reference_val_nxt	<= (others => '0');--phase_reference_val;
--									phase_ref_written_nxt	<= '0';--phase_ref_written;
--								else
--									phase_reference_val_nxt	<= phase_reference_val;
--									phase_ref_written_nxt	<= phase_ref_written;
--								end if;
--							end if;
						end if;
						-- phase (reconfigure target)
						if unsigned(wave_unit_select) = unsigned(unit_count) and phase_ref_written = '1' and unsigned(type_request) = 3 and ext_request = '1' then
							if	unsigned(phase_reference_val) + unsigned(phase_val) >= to_unsigned(PWM_STEPS,phase_val'length+1) then
								pwm_step_int				<= std_ulogic_vector(to_unsigned(PWM_STEPS,phase_val'length) - unsigned(phase_reference_val) - unsigned(phase_val));
							else
								pwm_step_int				<= std_ulogic_vector(unsigned(phase_reference_val) + unsigned(phase_val));
							end if;		
--							pwm_step_int				<= std_ulogic_vector(unsigned(phase_val) );
							--phase_ref_written_nxt	<= '0';
						else
							pwm_step_int				<= pwm_step_request_wave;
						end if;
						-- multiplier
						if unsigned(wave_unit_select) = unsigned(unit_count) and unsigned(type_request) = 2 and ext_request = '1' then
							mult_int						<= mult_select;
						else
							mult_int						<= mult_request_wave;
						end if;
						-- frequency
						if unsigned(wave_unit_select) = unsigned(unit_count) and unsigned(type_request) = 1 and ext_request = '1' then
							frequency_int				<= frequency_select;
						else
							frequency_int				<= freq_request_wave;
						end if;
						-- function
						if unsigned(wave_unit_select) = unsigned(unit_count) and unsigned(type_request) = 0 and ext_request = '1' then
							function_int				<= function_select(function_int'length-1 downto 0);
						else
							function_int				<= function_request_wave;
						end if;
						
						
						mult_response_wave			<= mult_int;
						mult_request_rom				<= mult_int;
						
						freq_response_wave			<= frequency_int;
						frequency_request_rom		<= frequency_int;
						
						function_response_wave		<= function_int;
						function_request_rom			<= function_int;
						
						
						pwm_step_response_wave		<= pwm_step_int;
						step_request_rom				<= pwm_step_int;
						
						data_avail_response_wave	<= (others => '0');
						data_avail_response_wave(to_integer(unsigned(unit_count)))	<= data_avail_response_rom;
						---
						-- if the external unit awaits status of unit 
						if type_request(2) = '1' and unsigned(wave_unit_select) = unsigned(unit_count) then
							data_back <= (others => '0');
							ack_ext		<= '1';
							if unsigned(type_request(1 downto 0)) = 0 then
								data_back(function_int'length-1 downto 0)		<= function_int;
								data_back(data_back'length-1 downto function_int'length)<= (others => '0');
							elsif unsigned(type_request(1 downto 0)) = 1 then
								data_back(frequency_int'length-1 downto 0)	<= frequency_int;
								--data_back(data_back'length-1 downto frequency_int'length)<= (others => '0');
							elsif unsigned(type_request(1 downto 0)) = 2 then 
								data_back(mult_int'length-1 downto 0)			<= mult_int;
								data_back(data_back'length-1 downto mult_int'length)<= (others => '0');
							else
								
								data_back(pwm_step_int'length-1 downto 0)		<= pwm_step_int;
								--data_back(data_back'length-1 downto pwm_step_int'length)<= (others => '0');
							end if;
						else
								data_back	<= (others => '0');
						end if;
						
						if data_avail_response_rom = '0' then
							unit_count_nxt		<= unit_count;
							ack_ext				<= '0';
						else
							if unsigned(wave_unit_select) = unsigned(unit_count) and unsigned(type_request) = 3 then
								phase_ref_written_nxt	<= '0';
								phase_reference_val_nxt	<= (others => '0');
							end if;
							if ext_request = '1' and unsigned(wave_unit_select) = unsigned(unit_count)  then
								ack_ext		<= '1';
							else
								ack_ext		<= '0';
							end if;
							if unsigned(unit_count) < to_unsigned(NUM_PORTS-1,unit_count'length) then
								unit_count_nxt	<= std_ulogic_vector(unsigned(unit_count)+1);
								cnt_delay_nxt	<= (others => '0');
							else
								unit_count_nxt	<= (others => '0');
							end if;
						end if;
						
					else
					
						if ext_request = '1' and unsigned(type_request) = 3 then
							phase_reference_val_nxt	<= phase_reference_val;
							phase_ref_written_nxt	<= phase_ref_written;
						else
							phase_reference_val_nxt	<= (others => '0');
							phase_ref_written_nxt	<= '0';
						end if;
						cnt_delay_nxt					<= std_ulogic_vector(unsigned(cnt_delay)+1);
						ack_ext							<= '0';
						mult_int							<= (others => '0');
						enable_request_wave			<= (others => '0');
						data_request_rom_nxt			<= '0';
						data_avail_response_wave	<= (others => '0');
						frequency_request_rom		<= (others => '0');
						freq_response_wave			<= (others => '0');
						function_response_wave		<= (others => '0');
						function_request_rom 		<= (others => '0');
						step_request_rom				<= (others => '0');
						pwm_step_response_wave		<= (others => '0');
						mult_request_rom				<= (others => '0');
						mult_response_wave			<= (others => '0');
						mult_int							<= (others => '0');
						frequency_int					<= (others => '0');
						function_int					<= (others => '0');
						pwm_step_int					<= (others => '0');
						data_back						<= (others => '0');
						if unsigned(unit_count) 	< to_unsigned(NUM_PORTS-1,unit_count'length) then
							unit_count_nxt				<= std_ulogic_vector(unsigned(unit_count)+1);
						else
							unit_count_nxt 			<= (others => '0');	
						end if;
					end if;
	end process unit_select;	
	
end rtl;