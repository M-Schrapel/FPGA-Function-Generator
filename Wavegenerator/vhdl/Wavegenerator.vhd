library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.function_pkg.all;

entity Wavegenerator is
	generic (
		NUM_PORTS		: integer := 80;--27+7*80;  	 -- Number of Ports
		PWM_STEPS		: integer := 1024;  -- Number of Steps
		CLOCK_MHZ		: integer := 100;   -- Clock signal in MHZ
		AMP_STEPS		: integer := 255;	 -- Amplitude Divider (100 steps + gain)
		MAX_FREQ			: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS		: integer := 128;	 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=DC, 5=custom_0, 6=custom_1, N=custom_N-5)
      BAUD_RATE   	: integer := 2000000; -- baud rate value
      PARITY_BIT  	: string  := "none"; -- type of parity: "none", "even", "odd", "mark", "space"
		USE_DEBOUNCER  : boolean := True;
		UART_TIMEOUT	: integer := 5
		);
	port(
		clock		: in	std_ulogic;
		reset		: in	std_ulogic;
      uart_rxd	: in  std_ulogic;
		uart_txd	: out std_ulogic;
		wave		: out	std_ulogic_vector(NUM_PORTS-1 downto 0)
	);
end Wavegenerator;

architecture rtl of Wavegenerator is

signal clock_50						: std_ulogic := '0';
signal clock_100						: std_ulogic := '0';
signal clock_350						: std_ulogic := '0';

signal clock_int_20						: std_ulogic := '0';
signal clock_int							: std_ulogic := '0';
signal reset_int							: std_ulogic := '0';
signal n_reset_int						: std_ulogic := '0';
signal n_reset								: std_logic := '0';
--signal n_reset								: std_ulogic := '0';
		-- waveunit communication
signal enable_request_wave				: std_ulogic_vector(max(NUM_PORTS-1,1) downto 0);
		-- incoming request
signal data_request_wave				: std_ulogic_vector(max(NUM_PORTS-1,1) downto 0) := (others => '0');
signal mult_request_wave				: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
signal pwm_step_request_wave			: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
signal freq_request_wave				: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
signal function_request_wave			: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0);
		-- response 
signal data_avail_response_wave		: std_ulogic_vector(max(NUM_PORTS-1,1) downto 0);
signal mult_response_wave				: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
signal period_on_response_wave		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal n_periods_response_wave		: std_ulogic_vector(16 downto 0);
signal last_period_response_wave		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal last_period_on_response_wave	: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal freq_response_wave				: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
signal function_response_wave			: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0);
signal pwm_step_response_wave			: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
	
		-- rom reader communication
		
		-- requesting data
signal data_request_rom					: std_ulogic := '0';
signal function_request_rom				: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0) := (others => '0');
signal frequency_request_rom			: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
signal step_request_rom					: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal mult_request_rom					: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0) := (others => '0');
		-- response of rom
signal data_avail_response_rom			: std_ulogic;
signal period_on_response_rom			: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal n_periods_response_rom			: std_ulogic_vector(16 downto 0);
signal last_period_response_rom			: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
signal last_period_on_response_rom		: std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		-- write data to custom rom
signal write_custom_request_rom			: std_ulogic := '0';
signal custom_select_rom				: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS-5)))),1) downto 0)  := (others => '0');
signal address_request_rom				: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal pwm_value_request_rom			: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		
		--communication with external data
signal ext_request						: std_ulogic := '0';
signal type_request						: std_ulogic_vector(integer(ceil(log2(real((5)))))-1 downto 0) := (others => '0');
		-- 0: function select
		-- 1: frequency select
		-- 2: multiplier select
		-- 3: phase select
		-- 4: request data
		
signal wave_unit_select					: std_ulogic_vector(max(integer(ceil(log2(real((NUM_PORTS*1))))),1) downto 0)  := (others => '0');
signal function_select					: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0) := (others => '0');
signal frequency_select					: std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
signal mult_select						: std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0)  := (others => '0');
signal phasereference_select			: std_ulogic_vector(max(integer(ceil(log2(real(NUM_PORTS*1)))),1) downto 0)  := (others => '0');
signal phase_value_select				: std_ulogic_vector(8 downto 0)  := (others => '0');
signal data_back						: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal write_custom_request				: std_ulogic := '0';
signal custom_select					: std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS-5)))),1) downto 0)  := (others => '0');
signal address_request					: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal pwm_value_request				: std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
signal ack_ext							: std_ulogic := '0';

	-- outgoing uart data
signal data_uart_out     				: std_logic_vector(7 downto 0) := (others => '0');
signal data_valid_out   				: std_logic := '0';
signal busy        						: std_logic := '0';
      
	-- incoming uart data
signal data_uart_in    					: std_logic_vector(7 downto 0) := (others => '0');
signal data_valid_in   					: std_logic := '0';	
signal frame_error 						: std_logic := '0';

	-- signals for waveunit communication
type mult_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
type pwm_step_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
type freq_request_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
type func_request_array is array (0 to NUM_PORTS-1) of std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS))))-1 downto 0);

signal mul_request_wave_unit		: mult_array;
signal pwm_step_out_unit			: pwm_step_array;
signal freq_request_unit			: freq_request_array;
signal function_request_unit		: func_request_array;

	-- Asynchronous signals for setting wave units
type async_data_array is array (0 to NUM_PORTS) of std_ulogic_vector(max(max(integer(ceil(log2(real(AMP_STEPS*1)))),integer(ceil(log2(real(MAX_FREQ*1))))),integer(ceil(log2(real(NUM_FUNCS)))))-1 downto 0);
type async_req_type_array is array (0 to NUM_PORTS) of std_ulogic_vector(1 downto 0);
type async_ack_array is array (0 to NUM_PORTS) of std_ulogic;

signal async_data_wave_unit		: async_data_array;
signal async_req_type_wave_unit	: async_req_type_array;
signal async_ack_wave_unit			: async_ack_array   := (others => '0');

signal async_wave_unit_select 	: std_ulogic_vector(NUM_PORTS-1 downto 0)  := (others => '0');

component pll is
port (
	areset		: IN STD_LOGIC  := '0';
	inclk0		: IN STD_LOGIC  := '0';
	c0				: OUT STD_LOGIC ;
	c1				: OUT STD_LOGIC ;
	c2				: OUT STD_LOGIC ;
	locked		: OUT STD_LOGIC 
 );
end component pll;

component pll_50 is
port (
	areset		: IN STD_LOGIC  := '0';
	inclk0		: IN STD_LOGIC  := '0';
	c0				: OUT STD_LOGIC ;
	c1				: OUT STD_LOGIC ;
	locked		: OUT STD_LOGIC 
 );
end component pll_50;

component pll_100 is
port (
	areset		: IN STD_LOGIC  := '0';
	inclk0		: IN STD_LOGIC  := '0';
	c0				: OUT STD_LOGIC ;
	locked		: OUT STD_LOGIC 
 );
end component pll_100;

component pll_350 is
port (
	areset		: IN STD_LOGIC  := '0';
	inclk0		: IN STD_LOGIC  := '0';
	c0				: OUT STD_LOGIC ;
	locked		: OUT STD_LOGIC 
 );
end component pll_350;

component pll_20 is
port (
	areset		: IN STD_LOGIC  := '0';
	inclk0		: IN STD_LOGIC  := '0';
	c0				: OUT STD_LOGIC ;
	locked		: OUT STD_LOGIC 
 );
end component pll_20;

component UART is
    Generic (
        CLK_FREQ      : integer := 50e6;   -- system clock frequency in Hz
        BAUD_RATE     : integer := 115200; -- baud rate value
        PARITY_BIT    : string  := "none"; -- type of parity: "none", "even", "odd", "mark", "space"
        USE_DEBOUNCER : boolean := True    -- enable/disable debouncer
    );
    Port (
        CLK         : in  std_logic; -- system clock
        RST         : in  std_logic; -- high active synchronous reset
        -- UART INTERFACE
        UART_TXD    : out std_logic; -- serial transmit data
        UART_RXD    : in  std_logic; -- serial receive data
        -- USER DATA INPUT INTERFACE
        DATA_IN     : in  std_logic_vector(7 downto 0); -- input data
        DATA_SEND   : in  std_logic; -- when DATA_SEND = 1, input data are valid and will be transmit
        BUSY        : out std_logic; -- when BUSY = 1, transmitter is busy and you must not set DATA_SEND to 1
        -- USER DATA OUTPUT INTERFACE
        DATA_OUT    : out std_logic_vector(7 downto 0); -- output data
        DATA_VLD    : out std_logic; -- when DATA_VLD = 1, output data are valid
        FRAME_ERROR : out std_logic  -- when FRAME_ERROR = 1, stop bit was invalid
    );
end component UART;
		
component uart_assembler is
	generic (
      BAUD_RATE   	: integer := 115200; -- baud rate value
      PARITY_BIT 		: string  := "none"; -- type of parity: "none", "even", "odd", "mark", "space"
		NUM_PORTS		: integer := 1;  	 -- Number of Ports
		PWM_STEPS		: integer := 512;  -- Number of Steps
		CLOCK_MHZ		: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS		: integer := 255;	 -- Amplitude Divider (100 steps)
		MAX_FREQ			: integer := 512;	 -- Maximum Frequency of Output in Hz
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
end component uart_assembler;
	
	
component rom_reader is
	generic (
		PWM_STEPS	: integer := 512;  -- Number of Steps
		CLOCK_MHZ	: integer := 50;   -- Clock signal in MHZ
		AMP_STEPS	: integer := 255;	 -- Amplitude Divider (100 steps + gain)
		MAX_FREQ		: integer := 512;	 -- Maximum Frequency of Output in Hz
		NUM_FUNCS	: integer := 5	 -- Number of functions ( 0=sine, 1=triagle, 2=sawtooth, 3=rectangle, 4=custom)
		--CALC_TICKS	: integer := 5		 -- internal number of clocks until result is valid
	);
	port(
		clock				: in  std_ulogic := '0';
		reset				: in  std_ulogic := '0';
		
		data_request	: in  std_ulogic := '0';
		function_sel	: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS)))),1)-1 downto 0) := (others => '0');
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
end component rom_reader;		
	
component wave_updatelogic is
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
		function_request_wave			: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0);
		-- response 
		data_avail_response_wave		: out std_ulogic_vector(max(NUM_PORTS-1,1) downto 0);
		mult_response_wave				: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		period_on_response_wave			: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods_response_wave			: out std_ulogic_vector(16 downto 0);
		last_period_response_wave		: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on_response_wave	: out std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		freq_response_wave				: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_response_wave			: out std_ulogic_vector(integer(ceil(log2(real(NUM_FUNCS*1))))-1 downto 0);
		pwm_step_response_wave			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
	
		-- rom reader communication
		
		-- requesting data
		data_request_rom					: out std_ulogic := '0';
		function_request_rom				: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0) := (others => '0');
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
		custom_select_rom				: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS-5)))),1) downto 0)  := (others => '0');
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
		function_select						: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0) := (others => '0');
		frequency_select					: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0)  := (others => '0');
		mult_select							: in  std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0)  := (others => '0');
		phasereference_select				: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_PORTS*1)))),1) downto 0)  := (others => '0');
		phase_value_select					: in  std_ulogic_vector(8 downto 0)  := (others => '0');
		data_back							: out std_ulogic_vector(max(integer(ceil(log2(real(PWM_STEPS*1)))),integer(ceil(log2(real(MAX_FREQ*1)))))-1 downto 0) := (others => '0');
		write_custom_request				: in  std_ulogic := '0';
		custom_select						: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS-5)))),1) downto 0)  := (others => '0');
		address_request						: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		pwm_value_request					: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0) := (others => '0');
		ack_ext								: out std_ulogic := '0'
	);
end component wave_updatelogic;
		
component waveunit is
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
		period_on_in	: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		n_periods		: in  std_ulogic_vector(16 downto 0);
		last_period		: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		last_period_on	: in  std_ulogic_vector(integer(ceil(log2(real((PWM_STEPS*1)))))-1 downto 0);
		freq_in			: in  std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_in		: in  std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS*1))))-1,1) downto 0);
		pwm_step_in		: in  std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		
		req_enable		: in  std_ulogic;
		data_request	: out std_ulogic;
		multiplier_chain	: in std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		multiplier_out	: out std_ulogic_vector(integer(ceil(log2(real(AMP_STEPS*1))))-1 downto 0);
		pwm_step_chain			: in std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		pwm_step			: out std_ulogic_vector(integer(ceil(log2(real(PWM_STEPS*1))))-1 downto 0);
		freq_chain			: in std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		freq_out			: out std_ulogic_vector(integer(ceil(log2(real(MAX_FREQ*1))))-1 downto 0);
		function_chain	: in std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0);
		function_out	: out std_ulogic_vector(max(integer(ceil(log2(real(NUM_FUNCS))))-1,1) downto 0);
		
		-- For faster asynchronous changes
		async_data_chain			: in  std_ulogic_vector(max(max(integer(ceil(log2(real(AMP_STEPS*1)))),integer(ceil(log2(real(MAX_FREQ*1))))),integer(ceil(log2(real(NUM_FUNCS)))))-1 downto 0);
		async_data_out				: out std_ulogic_vector(max(max(integer(ceil(log2(real(AMP_STEPS*1)))),integer(ceil(log2(real(MAX_FREQ*1))))),integer(ceil(log2(real(NUM_FUNCS)))))-1 downto 0);
		async_req_enable			: in  std_ulogic;
		async_req_type_chain		: in  std_ulogic_vector(1 downto 0);
		async_req_type				: out std_ulogic_vector(1 downto 0);
		async_ack_chain			: in  std_ulogic;	
		async_ack					: out std_ulogic;	
		
--		ack				: out	std_ulogic;
		wave				: out std_ulogic
    );
	end component waveunit;
		
begin

	-- internal reset when pll is not locked
	reset_int <= not(n_reset_int);
	n_reset	 <= not(reset);
	-- internal clock signal

	clk_50_gen: if CLOCK_MHZ = 350 generate
		clock_int	<=	clock_350;
	end generate clk_50_gen;
	
	clk_100_gen: if CLOCK_MHZ = 100 generate
		clock_int	<=	clock_100;
	end generate clk_100_gen;
	
	clk_350_gen: if CLOCK_MHZ = 50 generate
		clock_int	<=	clock_50;
	end generate clk_350_gen;
	
--	clk_50_gen: if CLOCK_MHZ = 50 generate
--		pll_inst : pll_50
--			port map(
--				areset		=> n_reset,
--				inclk0		=> clock,
--				c0				=> clock_int,
--				c1				=> clock_int_20,
--				locked		=> n_reset_int
--			);
--	end generate clk_50_gen;
--	
--	clk_100_gen: if CLOCK_MHZ = 100 generate
--		pll_inst : pll_100
--			port map(
--				areset		=> n_reset,
--				inclk0		=> clock,
--				c0				=> clock_int,
--				locked		=> n_reset_int
--			);
--	end generate clk_100_gen;
--	
--	clk_350_gen: if CLOCK_MHZ = 350 generate
--		pll_inst : pll_350
--			port map(
--				areset		=> n_reset,
--				inclk0		=> clock,
--				c0				=> clock_int,
--				locked		=> n_reset_int
--			);
--	end generate clk_350_gen;

	-- pll for internal clock
	pll_inst : pll
		port map(
			areset		=> reset,
			inclk0		=> clock,
			c0				=> clock_50,
			c1				=> clock_100,
			c2				=> clock_350,
			locked		=> n_reset_int
		);
	
rom_reader_inst : rom_reader
		generic map(
			PWM_STEPS	=> PWM_STEPS,
			CLOCK_MHZ	=> CLOCK_MHZ,
			AMP_STEPS	=> AMP_STEPS,
			MAX_FREQ		=> MAX_FREQ,
			NUM_FUNCS	=> NUM_FUNCS
			--CALC_TICKS	=> CALC_TICKS
		)
		port map(
			clock				=> clock_int,
			reset				=> reset_int,
			
			data_request	=> data_request_rom,
			function_sel	=> function_request_rom,
			frequency		=> frequency_request_rom,
			step				=> step_request_rom,
			factor			=> mult_request_rom,
			
			data_avail		=> data_avail_response_rom,
			period_on		=> period_on_response_rom,
			n_periods		=> n_periods_response_rom,
			last_period		=> last_period_response_rom,
			last_period_on	=> last_period_on_response_rom,
			
			write_custom	=> write_custom_request_rom,
			custom_select	=> custom_select_rom,
			address			=> address_request_rom,
			pwm_value		=> pwm_value_request_rom
		 );

wave_handler : wave_updatelogic
	generic map(
		NUM_PORTS	=> NUM_PORTS,
		PWM_STEPS	=> PWM_STEPS,
		CLOCK_MHZ	=> CLOCK_MHZ,
		AMP_STEPS	=> AMP_STEPS,
		MAX_FREQ	=> MAX_FREQ,
		NUM_FUNCS	=> NUM_FUNCS
	)
	port map(
		clock							=> clock_int,
		reset							=> reset_int,
		-- waveunit communication
		enable_request_wave				=> enable_request_wave,
		-- incoming request
		data_request_wave				=> data_request_wave,
		mult_request_wave				=> mult_request_wave,
		pwm_step_request_wave			=> pwm_step_request_wave,
		freq_request_wave				=> freq_request_wave,
		function_request_wave			=> function_request_wave,
		-- response 
		data_avail_response_wave		=> data_avail_response_wave,
		mult_response_wave				=> mult_response_wave,
		period_on_response_wave			=> period_on_response_wave,
		n_periods_response_wave			=> n_periods_response_wave,
		last_period_response_wave		=> last_period_response_wave,
		last_period_on_response_wave	=> last_period_on_response_wave,
		freq_response_wave				=> freq_response_wave,
		function_response_wave			=> function_response_wave,
		pwm_step_response_wave			=> pwm_step_response_wave,
	
		-- rom reader communication
		
		-- requesting data
		data_request_rom				=> data_request_rom,
		function_request_rom			=> function_request_rom,
		frequency_request_rom			=> frequency_request_rom,
		step_request_rom				=> step_request_rom,
		mult_request_rom				=> mult_request_rom,
		-- response of rom
		data_avail_response_rom			=> data_avail_response_rom,
		period_on_response_rom			=> period_on_response_rom,
		n_periods_response_rom			=> n_periods_response_rom,
		last_period_response_rom		=> last_period_response_rom,
		last_period_on_response_rom		=> last_period_on_response_rom,
		-- write data to custom rom
		write_custom_request_rom		=> write_custom_request_rom,
		custom_select_rom				=> custom_select_rom,
		address_request_rom				=> address_request_rom,
		pwm_value_request_rom			=> pwm_value_request_rom,
		
		--communication with external data
		ext_request						=> ext_request,
		type_request					=> type_request,
		wave_unit_select				=> wave_unit_select,
		function_select					=> function_select,
		frequency_select				=> frequency_select,
		mult_select						=> mult_select,
		phasereference_select			=> phasereference_select,
		phase_value_select				=> phase_value_select,
		data_back						=> data_back,
		write_custom_request			=> write_custom_request,
		custom_select					=> custom_select,
		address_request					=> address_request,
		pwm_value_request				=> pwm_value_request,
		ack_ext							=> ack_ext
	);
	
--	
--	gen_ext:
--		process(req_cnt,req_wcnt,ack_ext)
--				begin	
--					if unsigned(req_cnt) = to_unsigned(REQ_DELAY+4,req_cnt'length) then
--						ext_request		<= '1';
--						type_request	<= req_wcnt(type_request'length-1 downto 0);
--						if unsigned(req_wcnt(type_request'length-1 downto 0)) > 3 then
--							req_cnt_nxt		<= (others => '0');	--std_ulogic_vector(unsigned(req_cnt)+1);
--						else
--							if ack_ext = '0' then
--								req_cnt_nxt		<= std_ulogic_vector(unsigned(req_cnt)+0);
--							else
--								req_cnt_nxt		<= (others => '0');	--std_ulogic_vector(unsigned(req_cnt)+1);
--							end if;
--						end if;
--						
--						phasereference_select	<= (others => '0');	
--						phase_value_select		<= std_ulogic_vector(to_unsigned(PHASE*1,phase_value_select'length));
--						mult_select			<= std_ulogic_vector(to_unsigned(MUL_WAVE*1,mult_select'length));
--						frequency_select	<= std_ulogic_vector(to_unsigned(FREQ_WAVE*1,frequency_select'length));
--						function_select	<= std_ulogic_vector(to_unsigned(FUNC_WAVE*1,function_select'length));
----						wave_unit_select	<= req_wcnt(wave_unit_select'length-1 downto 0);
--						wave_unit_select	<= std_ulogic_vector(to_unsigned(UNIT_SELECT*1,wave_unit_select'length));
--						req_wcnt_nxt		<= req_wcnt;
--					else
--						ext_request		<= '0';
--						type_request	<= (others => '0');	
--						req_wcnt_nxt	<= std_ulogic_vector(unsigned(req_wcnt)+1);
--						req_cnt_nxt			<= std_ulogic_vector(unsigned(req_cnt)+1);
--						phasereference_select	<= (others => '0');	
--						phase_value_select		<= (others => '0');
--						mult_select			<= (others => '0');
--						frequency_select	<= (others => '0');
--						function_select	<= (others => '0');
--						wave_unit_select	<= (others => '0');
--						
--					end if;
--	end process gen_ext;
	
--	REQUEST TYPES
--	3 = phase
--	2 = multiplier
--	1 = frequency
--	0 = function

	-- generating unit instances
	waver_gen : for i in 1 to NUM_PORTS generate
		begin
		first: if i=1 generate
		waver : waveunit -- counter for every pwm step	waver : waveunit -- counter for every pwm step
		generic map(
			PWM_STEPS 	=> PWM_STEPS,
			CLOCK_MHZ 	=> CLOCK_MHZ,
			AMP_STEPS 	=> AMP_STEPS,
			MAX_FREQ 	=> MAX_FREQ,
			NUM_FUNCS	=> NUM_FUNCS
		)
		port map(
			clock 			=> clock_int,
			reset				=> reset_int,
			
			data_avail		=> data_avail_response_wave(i-1),
			multiplier_in	=> mult_response_wave,

			period_on_in	=> period_on_response_wave,
			n_periods		=> n_periods_response_wave,
			last_period		=> last_period_response_wave,
			last_period_on	=> last_period_on_response_wave,
			function_in		=> function_response_wave,
			freq_in			=> freq_response_wave,
			pwm_step_in		=> pwm_step_response_wave,		
			
			req_enable		=> enable_request_wave(i-1),
			data_request	=> data_request_wave(i-1),
			multiplier_chain	=>	 (others=> '0'),
			multiplier_out	=> mul_request_wave_unit(i-1),
			pwm_step_chain	=>	 (others=> '0'),
			pwm_step			=> pwm_step_out_unit(i-1),
			freq_chain	=>	 (others=> '0'),
			freq_out			=> freq_request_unit(i-1),		
			function_chain	=>	 (others=> '0'),	
			function_out	=> function_request_unit(i-1),	
			
			async_data_chain			=> async_data_wave_unit(i-1),
			async_data_out				=> async_data_wave_unit(i),
			async_req_enable			=> async_wave_unit_select(i-1),
			async_req_type_chain		=> async_req_type_wave_unit(i-1),
			async_req_type				=> async_req_type_wave_unit(i),
			async_ack_chain			=> async_ack_wave_unit(i-1),
			async_ack					=> async_ack_wave_unit(i),
			
--			ack				=> ack,
			wave				=> wave(i-1)		
		 );
		 end generate first;
		other: if i>1 generate
		waver : waveunit -- counter for every pwm step	waver : waveunit -- counter for every pwm step
		generic map(
			PWM_STEPS 	=> PWM_STEPS,
			CLOCK_MHZ 	=> CLOCK_MHZ,
			AMP_STEPS 	=> AMP_STEPS,
			MAX_FREQ 	=> MAX_FREQ,
			NUM_FUNCS	=> NUM_FUNCS
		)
		port map(
			clock 			=> clock_int,
			reset				=> reset_int,
			
			data_avail		=> data_avail_response_wave(i-1),
			multiplier_in	=> mult_response_wave,

			period_on_in	=> period_on_response_wave,
			n_periods		=> n_periods_response_wave,
			last_period		=> last_period_response_wave,
			last_period_on	=> last_period_on_response_wave,
			function_in		=> function_response_wave,
			freq_in			=> freq_response_wave,
			pwm_step_in		=> pwm_step_response_wave,		
			
			req_enable		=> enable_request_wave(i-1),
			data_request	=> data_request_wave(i-1),
			multiplier_chain	=>	 mul_request_wave_unit(i-2),
			multiplier_out	=> mul_request_wave_unit(i-1),
			pwm_step_chain	=>	 pwm_step_out_unit(i-2),
			pwm_step			=> pwm_step_out_unit(i-1),
			freq_chain		=>	freq_request_unit(i-2),
			freq_out			=> freq_request_unit(i-1),		
			function_chain	=>	function_request_unit(i-2),
			function_out	=> function_request_unit(i-1),	
			
			async_data_chain			=> async_data_wave_unit(i-1),
			async_data_out				=> async_data_wave_unit(i),
			async_req_enable			=> async_wave_unit_select(i-1),
			async_req_type_chain		=> async_req_type_wave_unit(i-1),
			async_req_type				=> async_req_type_wave_unit(i),
			async_ack_chain			=> async_ack_wave_unit(i-1),
			async_ack					=> async_ack_wave_unit(i),
			
--			ack				=> ack,
			wave				=> wave(i-1)		
		 );
		 end generate other;

		-- mul_gen: if i=NUM_PORTS generate
		-- mult_request_wave			<=	std_ulogic_vector(unsigned(mul_request_wave_unit(i-1)));
		-- pwm_step_request_wave	<=	std_ulogic_vector(unsigned(pwm_step_out_unit(i-1)));
		-- function_request_wave	<=	std_ulogic_vector(unsigned(function_request_unit(i-1)));
		-- freq_request_wave			<=	std_ulogic_vector(unsigned(freq_request_unit(i-1)));
		-- end generate mul_gen;
	end generate waver_gen;
		mult_request_wave			<=	std_ulogic_vector(unsigned(mul_request_wave_unit(NUM_PORTS-1)));
		pwm_step_request_wave	<=	std_ulogic_vector(unsigned(pwm_step_out_unit(NUM_PORTS-1)));
		function_request_wave	<=	std_ulogic_vector(unsigned(function_request_unit(NUM_PORTS-1)));
		freq_request_wave			<=	std_ulogic_vector(unsigned(freq_request_unit(NUM_PORTS-1)));
	
uart_asm : uart_assembler
	generic map(
      BAUD_RATE  		=>	BAUD_RATE,
      PARITY_BIT	  	=>	PARITY_BIT,
		NUM_PORTS		=>	NUM_PORTS,
		PWM_STEPS		=>	PWM_STEPS,
		CLOCK_MHZ		=>	CLOCK_MHZ,
		AMP_STEPS		=>	AMP_STEPS,
		MAX_FREQ		=>	MAX_FREQ,
		NUM_FUNCS		=>	NUM_FUNCS,
		UART_TIMEOUT	=> UART_TIMEOUT
	)
	port map(
		clock						=> clock_int,
		reset						=> reset_int,
		
		-- outgoing uart data
		data_uart_out     			=> data_uart_out,
		data_valid_out   			=> data_valid_out,
		busy        				=> busy,
      
		-- incoming uart data
		data_uart_in    			=> data_uart_in,
		data_valid_in   			=> data_valid_in,
		frame_error 				=> frame_error,
		
		-- set single wave unit with UART data
		ext_request					=> ext_request,
		type_request				=> type_request,
		wave_unit_select			=> wave_unit_select,
		function_select				=> function_select,
		frequency_select			=> frequency_select,
		mult_select					=> mult_select,
		phasereference_select		=> phasereference_select,
		phase_value_select			=> phase_value_select,
		
		-- write to custom RAM
		write_custom_request		=> write_custom_request,
		custom_select				=> custom_select,
		address_request				=> address_request,
		pwm_value_request			=> pwm_value_request,
		
		-- For faster asynchronous changes
		async_wave_unit_select	=> async_wave_unit_select,
		async_data					=> async_data_wave_unit(0),
		async_req_type				=> async_req_type_wave_unit(0),
		async_ack					=> async_ack_wave_unit(0),
		
		-- data was written
		ack_ext						=>	ack_ext,
		-- for requesting data via UART
		data_back					=>	data_back
	);
	
uart_inst : uart
    generic map(
        CLK_FREQ      => CLOCK_MHZ*1000000,
        BAUD_RATE     => BAUD_RATE,
        PARITY_BIT    => PARITY_BIT,
        USE_DEBOUNCER => USE_DEBOUNCER
    )
    port map(
        CLK         => clock_int,
        RST         => reset_int,
        -- UART INTERFACE
        UART_TXD    => uart_txd,
        UART_RXD    => uart_rxd,
        -- USER DATA INPUT INTERFACE
        DATA_IN     => data_uart_out,
        DATA_SEND   => data_valid_out,
        BUSY        => busy,
        -- USER DATA OUTPUT INTERFACE
        DATA_OUT    => data_uart_in,
        DATA_VLD    => data_valid_in,
        FRAME_ERROR => frame_error
    );
		
		
	
end rtl;