library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.function_pkg.all;

entity clk_communicator is
	generic (
		FCLK_0			: integer := 5;
		FCLK_1			: integer := 5
	);
	port(
		clock0			: in	std_ulogic;
		clock1			: in	std_ulogic;
		in_0				: in	std_ulogic;
		in_1				: in	std_ulogic;
		out_0				: out	std_ulogic;
		out_1				: out	std_ulogic
	);
end clk_communicator;

architecture rtl of clk_communicator is

begin

end rtl;