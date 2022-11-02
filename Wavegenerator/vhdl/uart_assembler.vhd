library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.function_pkg.all;

entity uart_assembler is
	generic (
      BAUD_RATE   	: integer := 115200;	 -- baud rate value
      PARITY_BIT 		 : string  := "none"; -- type of parity: "none", "even", "odd", "mark", "space"
		NUM_PORTS		: integer := 8;  		 -- Number of Ports
		PWM_STEPS		: integer := 512; 	 -- Number of Steps
		CLOCK_MHZ		: integer := 50; 	 	 -- Clock signal in MHZ
		AMP_STEPS		: integer := 255;		 -- Amplitude Divider (100 steps)
		MAX_FREQ			: integer := 512;		 -- Maximum Frequency of Output in Hz
		NUM_FUNCS		: integer := 5;		 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
		UART_TIMEOUT	: integer := 5	
	);
	port(
		clock							: in	std_ulogic;
		reset							: in	std_ulogic;
		
		-- outgoing uart data
		data_uart_out     		: out std_logic_vector(7 downto 0); -- input data
      data_valid_out   			: out std_logic; -- when DATA_SEND = 1, input data are valid and will be transmit
      busy        				: in  std_logic; -- when BUSY = 1, transmitter is busy and you must not set DATA_SEND to 1
      
		-- incoming uart data
      data_uart_in    			: in  std_logic_vector(7 downto 0); -- output data
      data_valid_in   			: in  std_logic; -- when DATA_VLD = 1, output data are valid
      frame_error 				: in  std_logic;
		
		-- set single wave unit with UART data
		ext_request					: out std_ulogic := '0';
		type_request				: out	std_ulogic_vector(integer(ceil(log2(real((5)))))-1 downto 0); -- 0: function select -- 1: frequency select -- 2: multiplier select -- 3: phase select -- 4: request data
		wave_unit_select			: out std_ulogic_vector(max(integer(ceil(log2(real((NUM_PORTS*1))))),1) downto 0)  := (others => '0');
		function_select			: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0)  := (others => '0');
		frequency_select			: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
		mult_select					: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0)  := (others => '0');
		phasereference_select	: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_PORTS*1)))),1) downto 0)  := (others => '0');
		phase_value_select		: out std_ulogic_vector(8 downto 0)  := (others => '0');
		
		-- Set wave units asynchronous (faster)
		async_wave_unit_select	: out std_ulogic_vector(NUM_PORTS-1 downto 0)  := (others => '0');		
		async_data					: out std_ulogic_vector(max(max(integer(ceil(log2(real(AMP_STEPS*1)))),integer(ceil(log2(real(MAX_FREQ*1))))),integer(ceil(log2(real(NUM_FUNCS)))))-1 downto 0) := (others => '0');
		async_req_type				: out std_ulogic_vector(1 downto 0) := (others => '0');
		async_ack					: in  std_ulogic := '0';

		-- write to custom RAM
		write_custom_request		: out std_ulogic := '0';
		custom_select				: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS-5)))),1) downto 0)  := (others => '0');
		address_request			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		pwm_value_request			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');

		-- data was written
		ack_ext						: in  std_ulogic := '0';
		-- for requesting data via UART
		data_back					: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0')
		
	);
end uart_assembler;

architecture rtl of uart_assembler is


signal wave_unit_select_int			: std_ulogic_vector(wave_unit_select'length-1 downto 0) := (others => '0');
signal wave_unit_select_nxt			: std_ulogic_vector(wave_unit_select_int'length-1 downto 0) := (others => '0');

signal type_request_int					: std_ulogic_vector(type_request'length-1 downto 0) := (others => '0');
signal type_request_nxt					: std_ulogic_vector(type_request'length-1 downto 0) := (others => '0');

signal function_select_int				: std_ulogic_vector(function_select'length-1 downto 0) := (others => '0');
signal function_select_nxt				: std_ulogic_vector(function_select'length-1 downto 0) := (others => '0');

signal frequency_select_int			: std_ulogic_vector(frequency_select'length-1 downto 0) := (others => '0');
signal frequency_select_nxt			: std_ulogic_vector(frequency_select'length-1 downto 0) := (others => '0');

signal mult_select_int					: std_ulogic_vector(mult_select'length-1 downto 0) := (others => '0');
signal mult_select_nxt					: std_ulogic_vector(mult_select'length-1 downto 0) := (others => '0');

signal phasereference_select_int		: std_ulogic_vector(phasereference_select'length-1 downto 0) := (others => '0');
signal phasereference_select_nxt		: std_ulogic_vector(phasereference_select'length-1 downto 0) := (others => '0');

signal phase_value_select_int			: std_ulogic_vector(phase_value_select'length-1 downto 0) := (others => '0');
signal phase_value_select_nxt			: std_ulogic_vector(phase_value_select'length-1 downto 0) := (others => '0');

signal address_request_select_int	: std_ulogic_vector(address_request'length-1 downto 0) := (others => '0');
signal address_request_select_nxt	: std_ulogic_vector(address_request'length-1 downto 0) := (others => '0');

signal pwm_value_request_int			: std_ulogic_vector(pwm_value_request'length-1 downto 0) := (others => '0');
signal pwm_value_request_nxt			: std_ulogic_vector(pwm_value_request'length-1 downto 0) := (others => '0');

signal custom_select_int			: std_ulogic_vector(custom_select'length-1 downto 0) := (others => '0');
signal custom_select_nxt			: std_ulogic_vector(custom_select'length-1 downto 0) := (others => '0');

signal cnt_state, cnt_state_nxt		: std_ulogic_vector(integer(ceil(log2(real((CLOCK_MHZ*UART_TIMEOUT*1000000)))))-1 downto 0);
signal error_sent, error_sent_nxt	: std_ulogic  := '0';

signal data_back_int, data_back_nxt	: std_ulogic_vector(data_back'length-1 downto 0);


type STATE_UART  		is (IDLE, CMD_FIN, WAVE_SELECT, TYPE_SELECT, TYPE_FREQ, TYPE_MUL, TYPE_FUNC, TYPE_PHASE, CUSTOM_WRITE, TYPES_REQUEST, CMD_ERROR);

type STATE_FREQ  		is (IDLE, VAL_0, VAL_1, FIN);

type STATE_MUL   		is (IDLE, VAL_0, FIN);

type STATE_FUNC  		is (IDLE, VAL_0, FIN);


type STATE_PHASE 		is (IDLE, VAL_0, VAL_1, WAVE_REF ,FIN);

type STATE_REQUEST	is (IDLE, REQUEST_TYPE, GET_DATA, DATA_OUT, SENT);

type STATE_FIN			is (IDLE,CLR,LF);

type STATE_CUSTOM		is (IDLE_1,IDLE,ADDRESS_0,ADDRESS_1,PWM_VALUE_0,PWM_VALUE_1,FIN);

type STATE_ERROR		is (IDLE,E,R1,R2,O,R3,FIN);


signal state, state_nxt 								: STATE_UART;

signal state_frequency, state_frequency_nxt 		: STATE_FREQ;
signal state_function, state_function_nxt 		: STATE_FUNC;
signal state_multiply, state_multiply_nxt 		: STATE_MUL;
signal state_phaseshift, state_phaseshift_nxt	: STATE_PHASE;
signal state_requestdat, state_requestdat_nxt	: STATE_REQUEST;
signal state_finished, state_finished_nxt			: STATE_FIN;
signal state_custom_wr, state_custom_wr_nxt		: STATE_CUSTOM;
signal state_error_cmd, state_error_cmd_nxt		: STATE_ERROR;

begin
type_request			<= type_request_int;
wave_unit_select		<= wave_unit_select_int;
function_select			<= function_select_int;
frequency_select		<= frequency_select_int;
mult_select				<= mult_select_int;
phasereference_select	<= phasereference_select_int;
phase_value_select		<= phase_value_select_int;
address_request			<= address_request_select_int;
pwm_value_request		<= pwm_value_request_int;
custom_select			<= custom_select_int;
	
	ff:
		process(reset,clock)
			begin	
				if reset = '1' then
					state 							<= IDLE;
					state_frequency 				<= IDLE;
					state_function 				<= IDLE;
					state_multiply 				<= IDLE;
					state_phaseshift 				<= IDLE;
					state_requestdat 				<= IDLE;
					state_finished					<= IDLE;
					state_custom_wr				<= IDLE;
					state_error_cmd				<= IDLE;
					
					cnt_state						<= (others => '0');
					wave_unit_select_int			<= (others => '0');
					type_request_int				<= (others => '0');
					function_select_int			<= (others => '0');
					frequency_select_int			<= (others => '0');
					mult_select_int				<= (others => '0');
					phasereference_select_int	<= (others => '0');
					phase_value_select_int		<= (others => '0');
					address_request_select_int	<= (others => '0');
					pwm_value_request_int		<= (others => '0');
					data_back_int					<= (others => '0');
					custom_select_int			<= (others => '1');
				elsif rising_edge(clock) then
					state 							<= state_nxt;
					state_frequency 				<= state_frequency_nxt;
					state_function 				<= state_function_nxt;
					state_multiply 				<= state_multiply_nxt;
					state_phaseshift 				<= state_phaseshift_nxt;
					state_requestdat 				<= state_requestdat_nxt;
					state_finished					<= state_finished_nxt;
					state_custom_wr				<= state_custom_wr_nxt;
					state_error_cmd				<= state_error_cmd_nxt;
					
					wave_unit_select_int			<= wave_unit_select_nxt;
					type_request_int				<= type_request_nxt;
					function_select_int			<= function_select_nxt;
					frequency_select_int			<= frequency_select_nxt;
					mult_select_int				<= mult_select_nxt;
					phasereference_select_int	<= phasereference_select_nxt;
					phase_value_select_int		<= phase_value_select_nxt;
					address_request_select_int	<= address_request_select_nxt;
					custom_select_int			<= custom_select_nxt;
					pwm_value_request_int		<= pwm_value_request_nxt;
					cnt_state						<= cnt_state_nxt;
					error_sent						<= error_sent_nxt;
					data_back_int					<= data_back_nxt;
				end if;
	end process ff;

	state_machine:	 
	-- handling incoming requests and outgoing data
		process(state,state_frequency,state_function,state_multiply,state_phaseshift,state_requestdat,state_finished,state_custom_wr,state_error_cmd,custom_select_int,
				wave_unit_select_int,type_request_int,function_select_int,frequency_select_int,mult_select_int,phasereference_select_int,phase_value_select_int,
				address_request_select_int,pwm_value_request_int,data_valid_in,frame_error,data_uart_in,ack_ext,busy,error_sent,data_back_int,cnt_state,data_back,async_ack)
		begin
			ext_request							<= '0';
			data_valid_out						<= '0';
			state_nxt 							<= state; 
			state_frequency_nxt 				<= state_frequency; 
			state_function_nxt 				<= state_function; 
			state_multiply_nxt 				<= state_multiply; 
			state_phaseshift_nxt 			<= state_phaseshift; 
			state_requestdat_nxt 			<= state_requestdat; 
			state_finished_nxt				<=	state_finished;
			state_custom_wr_nxt				<= state_custom_wr; 
			state_error_cmd_nxt				<= state_error_cmd; 
			
			wave_unit_select_nxt				<= wave_unit_select_int;
			type_request_nxt					<= type_request_int;
			function_select_nxt				<= function_select_int;
			frequency_select_nxt				<= frequency_select_int;
			mult_select_nxt					<= mult_select_int;
			phasereference_select_nxt		<= phasereference_select_int;
			phase_value_select_nxt			<= phase_value_select_int;
			address_request_select_nxt		<= address_request_select_int;
			pwm_value_request_nxt			<= pwm_value_request_int;
			error_sent_nxt						<= error_sent;
			data_back_nxt						<= data_back_int;
			write_custom_request				<= '0';
			custom_select_nxt					<= custom_select_int;
			data_uart_out						<= (others => '0');
			
			async_req_type						<= (others => '0');
			async_wave_unit_select			<= (others => '0');
			async_data							<= (others => '0');
								
			
			case state is
			
				when IDLE =>	
				-- waiting for data
					error_sent_nxt	<='0';
					cnt_state_nxt	<= (others => '0');
					if data_valid_in = '1' and frame_error = '0' then
						-- detect M or m in data
						if (unsigned(data_uart_in) = to_unsigned(77,data_uart_in'length)) or (unsigned(data_uart_in) = to_unsigned(109,data_uart_in'length)) then
							state_nxt	<=	WAVE_SELECT;
						-- detect C or c in data
						elsif (unsigned(data_uart_in) = to_unsigned(67,data_uart_in'length)) or (unsigned(data_uart_in) = to_unsigned(99,data_uart_in'length)) then
							state_nxt	<=	CUSTOM_WRITE;
						end if;
					end if;
					
				when WAVE_SELECT =>
				-- select wave unit 
					cnt_state_nxt	<= std_ulogic_vector(unsigned(cnt_state)+1);
					if data_valid_in = '1' and frame_error = '0' then
						wave_unit_select_nxt(minimum(wave_unit_select'length-1,data_uart_in'length-1) downto 0)	<= std_ulogic_vector(unsigned(data_uart_in(minimum(wave_unit_select'length-1,data_uart_in'length-1) downto 0)));
						state_nxt				<=	TYPE_SELECT;
						cnt_state_nxt	<= (others => '0');
					end if;
					if unsigned(cnt_state) = to_unsigned(CLOCK_MHZ*UART_TIMEOUT*1000000,cnt_state'length) then
						state_nxt	<=	CMD_ERROR;
						cnt_state_nxt	<= (others => '0');
					end if;
				when TYPE_SELECT =>
				-- select type of request
				-- 0: function select 
				-- 1: frequency select 
				-- 2: multiplier select 
				-- 3: phase select 
				-- 4: request data
					cnt_state_nxt	<= std_ulogic_vector(unsigned(cnt_state)+1);
					if data_valid_in = '1' and frame_error = '0' then
						cnt_state_nxt	<= (others => '0');
						type_request_nxt	<= std_ulogic_vector(unsigned(data_uart_in(type_request'length-1 downto 0)));
						if (unsigned(data_uart_in) = to_unsigned(0,data_uart_in'length)) then
							state_nxt	<=	TYPE_FUNC;
						elsif (unsigned(data_uart_in) = to_unsigned(1,data_uart_in'length)) then
							state_nxt	<=	TYPE_FREQ;
						elsif (unsigned(data_uart_in) = to_unsigned(2,data_uart_in'length)) then
							state_nxt	<=	TYPE_MUL;
						elsif (unsigned(data_uart_in) = to_unsigned(3,data_uart_in'length)) then
							state_nxt	<=	TYPE_PHASE;
						elsif(unsigned(data_uart_in) = to_unsigned(4,data_uart_in'length)) then
							state_nxt	<=	TYPES_REQUEST;
						else
							state_nxt	<=	CMD_ERROR;
						end if;
					end if;
					if unsigned(cnt_state) = to_unsigned(CLOCK_MHZ*UART_TIMEOUT*1000000,cnt_state'length) then
						state_nxt	<=	CMD_ERROR;
						cnt_state_nxt	<= (others => '0');
					end if;
					
				when TYPE_FUNC =>
				-- choose function
					cnt_state_nxt	<= std_ulogic_vector(unsigned(cnt_state)+1);
					case state_function is
						when IDLE =>
							if data_valid_in = '1' and frame_error = '0' then
								function_select_nxt	<= std_ulogic_vector(unsigned(data_uart_in(function_select_nxt'length-1 downto 0)));
								state_function_nxt	<=	VAL_0;
								cnt_state_nxt	<= (others => '0');
							end if;
							
						when VAL_0 =>
							ext_request	<= '1';
							async_req_type				<= std_ulogic_vector(to_unsigned(0,async_req_type'length));
							async_wave_unit_select(to_integer(unsigned(wave_unit_select_int)))	<= '1';
							async_data(function_select_int'length-1 downto 0) <= function_select_int;
								
							if ack_ext = '1' or async_ack = '1'then
								state_function_nxt	<=	FIN;
								cnt_state_nxt	<= (others => '0');
							end if;
							
						when FIN =>
							state_function_nxt	<=	IDLE;
							state_nxt				<=	CMD_FIN;
							cnt_state_nxt	<= (others => '0');
							
						when others =>  
							state_function_nxt	<=	IDLE;
							state_nxt	<=	CMD_ERROR;
							cnt_state_nxt	<= (others => '0');
					end case;
					if unsigned(cnt_state) = to_unsigned(CLOCK_MHZ*UART_TIMEOUT*1000000,cnt_state'length) then
						state_nxt	<=	CMD_ERROR;
						cnt_state_nxt	<= (others => '0');
					end if;
					
				when TYPE_FREQ =>
				-- choose frequency
					cnt_state_nxt	<= std_ulogic_vector(unsigned(cnt_state)+1);
					case state_frequency is
						when IDLE =>
							if data_valid_in = '1' and frame_error = '0' then
								frequency_select_nxt		<= (others => '0');
								frequency_select_nxt(frequency_select_nxt'length-1 downto data_uart_in'length)	<= std_ulogic_vector(unsigned(data_uart_in(frequency_select_nxt'length-data_uart_in'length-1 downto 0)));
								state_frequency_nxt		<=	VAL_0;
								cnt_state_nxt				<= (others => '0');
							end if;
							
						when VAL_0 =>
							if data_valid_in = '1' and frame_error = '0' then
								frequency_select_nxt(data_uart_in'length-1 downto 0)	<= std_ulogic_vector(unsigned(data_uart_in));
								state_frequency_nxt		<=	VAL_1;
								cnt_state_nxt	<= (others => '0');
							end if;
							
						when VAL_1 =>
							ext_request	<= '1';
							async_req_type				<= std_ulogic_vector(to_unsigned(1,async_req_type'length));
							async_wave_unit_select(to_integer(unsigned(wave_unit_select_int)))	<= '1';
							async_data(frequency_select_int'length-1 downto 0) <= frequency_select_int;
								
							if ack_ext = '1' or async_ack = '1'then
								state_frequency_nxt	<=	FIN;
								cnt_state_nxt	<= (others => '0');
							end if;
							
						when FIN =>
							state_frequency_nxt	<=	IDLE;
							state_nxt				<=	CMD_FIN;
							cnt_state_nxt	<= (others => '0');
							
						when others =>  
							state_frequency_nxt	<=	IDLE;
							state_nxt				<=	CMD_ERROR;
							cnt_state_nxt	<= (others => '0');
					end case;
					if unsigned(cnt_state) = to_unsigned(CLOCK_MHZ*UART_TIMEOUT*1000000,cnt_state'length) then
						state_nxt	<=	CMD_ERROR;
						cnt_state_nxt	<= (others => '0');
					end if;
					
				when TYPE_MUL =>
				-- amplifier
					cnt_state_nxt	<= std_ulogic_vector(unsigned(cnt_state)+1);
					case state_multiply is
						when IDLE =>
							if data_valid_in = '1' and frame_error = '0' then
								mult_select_nxt		<= std_ulogic_vector(unsigned(data_uart_in));
								state_multiply_nxt	<=	VAL_0;
								cnt_state_nxt	<= (others => '0');
							end if;
							
						when VAL_0 =>
							ext_request	<= '1';
							async_req_type				<= std_ulogic_vector(to_unsigned(2,async_req_type'length));
							async_wave_unit_select(to_integer(unsigned(wave_unit_select_int)))	<= '1';
							async_data(mult_select_int'length-1 downto 0) <= mult_select_int;
								
							if ack_ext = '1' or async_ack = '1'then
								state_multiply_nxt	<=	FIN;
								cnt_state_nxt	<= (others => '0');
							end if;
							
						when FIN =>
							state_multiply_nxt	<=	IDLE;
							state_nxt				<=	CMD_FIN;
							cnt_state_nxt	<= (others => '0');
							
						when others =>  
							state_multiply_nxt	<=	IDLE;
							state_nxt				<=	CMD_ERROR;
							cnt_state_nxt	<= (others => '0');
					end case;
					if unsigned(cnt_state) = to_unsigned(CLOCK_MHZ*UART_TIMEOUT*1000000,cnt_state'length) then
						state_nxt	<=	CMD_ERROR;
						cnt_state_nxt	<= (others => '0');
					end if;
					
				when TYPE_PHASE =>
				-- phase of unit
					cnt_state_nxt	<= std_ulogic_vector(unsigned(cnt_state)+1);
					case state_phaseshift is
						when IDLE =>
							if data_valid_in = '1' and frame_error = '0' then
								phase_value_select_nxt	<= (others => '0');
								phase_value_select_nxt(phase_value_select_nxt'length-1 downto data_uart_in'length)	<= std_ulogic_vector(unsigned(data_uart_in(phase_value_select'length-data_uart_in'length-1 downto 0)));
								state_phaseshift_nxt	<=	VAL_0;
								cnt_state_nxt			<= (others => '0');
							end if;
							
						when VAL_0 =>
							if data_valid_in = '1' and frame_error = '0' then
								phase_value_select_nxt(data_uart_in'length-1 downto 0)	<= std_ulogic_vector(unsigned(data_uart_in));
								state_phaseshift_nxt	<=	VAL_1;
								cnt_state_nxt			<= (others => '0');
							end if;
							
						when VAL_1 =>
							if data_valid_in = '1' and frame_error = '0' then
								phasereference_select_nxt(minimum(phasereference_select_nxt'length-1,data_uart_in'length-1) downto 0)	<= std_ulogic_vector(unsigned(data_uart_in(minimum(phasereference_select_nxt'length-1,data_uart_in'length-1) downto 0)));
								state_phaseshift_nxt	<=	WAVE_REF;
								cnt_state_nxt			<= (others => '0');
							end if;
							
						when WAVE_REF =>
							ext_request	<= '1';
							if ack_ext = '1' then
								state_phaseshift_nxt	<=	FIN;
								cnt_state_nxt			<= (others => '0');
							end if;
							
						when FIN =>
							state_phaseshift_nxt		<=	IDLE;
							state_nxt					<=	CMD_FIN;
							cnt_state_nxt				<= (others => '0');
							
						when others =>  
							state_phaseshift_nxt		<=	IDLE;
							state_nxt					<=	CMD_ERROR;	
							cnt_state_nxt				<= (others => '0');	
					end case;
					if unsigned(cnt_state) = to_unsigned(CLOCK_MHZ*UART_TIMEOUT*1000000,cnt_state'length) then
						state_nxt						<=	CMD_ERROR;
						cnt_state_nxt					<= (others => '0');
					end if;
					
				when CUSTOM_WRITE =>
				-- write custom data to RAM
					cnt_state_nxt	<= std_ulogic_vector(unsigned(cnt_state)+1);
					case state_custom_wr is
						when IDLE =>
						
							if data_valid_in = '1' and frame_error = '0' then
								custom_select_nxt		<= std_ulogic_vector(unsigned(data_uart_in(minimum(custom_select_nxt'length,data_uart_in'length)-1 downto 0)));
								state_custom_wr_nxt		<=	IDLE_1;
								cnt_state_nxt			<= (others => '0');
							end if;
							
						when IDLE_1 =>
							if data_valid_in = '1' and frame_error = '0' then
								address_request_select_nxt(address_request_select_int'length-1 downto data_uart_in'length)		<= std_ulogic_vector(unsigned(data_uart_in(address_request_select_nxt'length-data_uart_in'length-1 downto 0)));
								state_custom_wr_nxt		<=	ADDRESS_0;
								cnt_state_nxt			<= (others => '0');
							end if;
							
						when ADDRESS_0 =>
							if data_valid_in = '1' and frame_error = '0' then
								address_request_select_nxt(data_uart_in'length-1 downto 0)		<= std_ulogic_vector(unsigned(data_uart_in));
								state_custom_wr_nxt		<=	ADDRESS_1;
								cnt_state_nxt			<= (others => '0');
							end if;
							
						when ADDRESS_1 =>
							if data_valid_in = '1' and frame_error = '0' then
								pwm_value_request_nxt(pwm_value_request'length-1 downto data_uart_in'length)		<= std_ulogic_vector(unsigned(data_uart_in(pwm_value_request_nxt'length-data_uart_in'length-1 downto 0)));
								state_custom_wr_nxt		<=	PWM_VALUE_0;
								cnt_state_nxt			<= (others => '0');
							end if;
							
						when PWM_VALUE_0 =>
							if data_valid_in = '1' and frame_error = '0' then
								pwm_value_request_nxt(data_uart_in'length-1 downto 0)		<= std_ulogic_vector(unsigned(data_uart_in));
								state_custom_wr_nxt		<=	PWM_VALUE_1;
								cnt_state_nxt			<= (others => '0');
							end if;
							
						when PWM_VALUE_1 =>
							write_custom_request		<= '1';
							state_custom_wr_nxt			<=	FIN;
							cnt_state_nxt				<= (others => '0');
								
						when FIN =>
							custom_select_nxt			<= (others => '1');
							address_request_select_nxt	<= (others => '0');
							pwm_value_request_nxt		<= (others => '0');
							write_custom_request		<= '0';
							state_custom_wr_nxt			<=	IDLE;
							state_nxt					<=	CMD_FIN;
							cnt_state_nxt				<= (others => '0');
						
						when others =>  
							state_custom_wr_nxt	<=	IDLE;
							state_nxt				<=	CMD_ERROR;
							cnt_state_nxt	<= (others => '0');
					end case;
					if unsigned(cnt_state) = to_unsigned(CLOCK_MHZ*UART_TIMEOUT*1000000,cnt_state'length) then
						state_nxt	<=	CMD_ERROR;
						cnt_state_nxt	<= (others => '0');
					end if;
					
				when TYPES_REQUEST =>
				-- requesting status of single waveunit
					cnt_state_nxt	<= std_ulogic_vector(unsigned(cnt_state)+1);
					case state_requestdat is
						when IDLE =>
							if data_valid_in = '1' and frame_error = '0' and unsigned(data_uart_in) < 4 then
								type_request_nxt 		<= std_ulogic_vector(unsigned(data_uart_in(type_request_nxt'length-1 downto 0)));
								type_request_nxt(2)	<= '1';
								state_requestdat_nxt	<=	REQUEST_TYPE;
								ext_request				<= '1';
								cnt_state_nxt	<= (others => '0');
							end if;
							
						when REQUEST_TYPE =>
							ext_request	<= '1';
							if ack_ext = '1' then
								if busy = '0' then
									data_valid_out			<= '1';
									data_back_nxt			<= data_back;
									data_uart_out			<= (others => '0');
									data_uart_out(data_back'length-data_uart_out'length-1 downto 0) <= std_logic_vector(unsigned(data_back(data_back'length-1 downto data_uart_out'length)));
									--data_uart_out			<= std_logic_vector(unsigned(data_back(data_back'length-1 downto data_uart_out'length)));
									state_requestdat_nxt	<= GET_DATA;
									cnt_state_nxt	<= (others => '0');
								end if;
							end if;
							
						when GET_DATA =>
							ext_request	<= '1';
							--if ack_ext = '1' then
								if 	busy = '0' then
									data_valid_out			<= '1';
									data_uart_out			<= std_logic_vector(data_back_int(data_uart_out'length-1 downto 0));
									state_requestdat_nxt	<= SENT;
									cnt_state_nxt	<= (others => '0');
								end if;
							--end if;
							
						when SENT =>
							state_requestdat_nxt	<= IDLE;
							state_nxt				<=	CMD_FIN;
							cnt_state_nxt	<= (others => '0');
							
						when others =>  
							state_requestdat_nxt	<=	IDLE;
							state_nxt				<=	CMD_ERROR;
							cnt_state_nxt	<= (others => '0');
					end case;
					if unsigned(cnt_state) = to_unsigned(CLOCK_MHZ*UART_TIMEOUT*1000000,cnt_state'length) then
						state_nxt	<=	CMD_ERROR;
						cnt_state_nxt	<= (others => '0');
					end if;
					
				when CMD_FIN =>
				-- when data handling is finished CLR and LF will be sent back
					cnt_state_nxt	<= std_ulogic_vector(unsigned(cnt_state)+1);
					case state_finished is
						when IDLE =>
						-- Send CLR
							if busy = '0' then
								data_valid_out			<= '1';
								data_uart_out			<= std_logic_vector(to_unsigned(13,data_uart_out'length));
								state_finished_nxt	<= CLR;
								cnt_state_nxt	<= (others => '0');
							end if;
							
						when CLR =>
						-- Send LF
							if busy = '0' then
								data_valid_out			<= '1';
								data_uart_out			<= std_logic_vector(to_unsigned(10,data_uart_out'length));
								state_finished_nxt	<= LF;
								cnt_state_nxt	<= (others => '0');
							end if;
							
						when LF  =>
							state_finished_nxt	<= IDLE;
							state_nxt				<=	IDLE;
							cnt_state_nxt	<= (others => '0');
							
						when others =>  -- prevent endless loops with errors
							state_finished_nxt	<=	IDLE;
							state_nxt				<=	IDLE;
							cnt_state_nxt	<= (others => '0');
					end case;
					if unsigned(cnt_state) = to_unsigned(CLOCK_MHZ*UART_TIMEOUT*1000000,cnt_state'length) then
						state_nxt	<=	CMD_ERROR;
						cnt_state_nxt	<= (others => '0');
					end if;
					
				when CMD_ERROR =>
				-- When errors occur send ERROR back
					cnt_state_nxt	<= std_ulogic_vector(unsigned(cnt_state)+1);
					if error_sent = '1' then
						state_nxt	<=	IDLE;
					else
						case state_error_cmd is
							when IDLE =>
								error_sent_nxt	<='1';
								if busy = '0' then
									data_valid_out			<= '1';
									data_uart_out			<= std_logic_vector(to_unsigned(69,data_uart_out'length));
									state_error_cmd_nxt	<= E;
									cnt_state_nxt	<= (others => '0');
								end if;
								
							when E =>
								if busy = '0' then
									data_valid_out			<= '1';
									data_uart_out			<= std_logic_vector(to_unsigned(82,data_uart_out'length));
									state_error_cmd_nxt	<= R1;
									cnt_state_nxt	<= (others => '0');
								end if;
								
							when R1 =>
								if busy = '0' then
									data_valid_out			<= '1';
									data_uart_out			<= std_logic_vector(to_unsigned(82,data_uart_out'length));
									state_error_cmd_nxt	<= R2;
									cnt_state_nxt	<= (others => '0');
								end if;
								
							when R2 =>
								if busy = '0' then
									data_valid_out			<= '1';
									data_uart_out			<= std_logic_vector(to_unsigned(79,data_uart_out'length));
									state_error_cmd_nxt	<= O;
									cnt_state_nxt	<= (others => '0');
								end if;
								
							when O =>
								if busy = '0' then
									data_valid_out			<= '1';
									data_uart_out			<= std_logic_vector(to_unsigned(82,data_uart_out'length));
									state_error_cmd_nxt	<= R3;
									cnt_state_nxt	<= (others => '0');
								end if;
								
							when R3 =>
								state_error_cmd_nxt		<= IDLE;
								state_nxt					<=	CMD_FIN;
								cnt_state_nxt	<= (others => '0');
								
							when others =>  -- prevent endless loops with errors
								state_error_cmd_nxt		<= IDLE;
								state_nxt					<=	CMD_FIN;
								cnt_state_nxt	<= (others => '0');
						end case;
						if unsigned(cnt_state) = to_unsigned(CLOCK_MHZ*UART_TIMEOUT*1000000,cnt_state'length) then
							state_nxt	<=	IDLE;
							cnt_state_nxt	<= (others => '0');
						end if;
					end if;
				
					
				when others => -- unknown state
					state_nxt	<=	CMD_ERROR;
			end case;
	end process state_machine;	
	
	
end rtl;