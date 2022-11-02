library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



package function_pkg is
	function max(a, b: integer) return integer;
	function max(a, b: unsigned) return unsigned;
	function minimum(a, b: integer) return integer;
	function minimum(a, b: unsigned) return unsigned;
end;

package body function_pkg is

	function max(a, b: integer) return integer is
	begin
		if a > b then
			return a;
		else
			return b;
		end if;
	end function;
	
	function max(a, b: unsigned) return unsigned is
	begin
		if a > b then
			return a;
		else
			return b;
		end if;
	end function;
	
	function minimum(a, b: integer) return integer is
	begin
		if a < b then
			return a;
		else
			return b;
		end if;
	end function;
	
	function minimum(a, b: unsigned) return unsigned is
	begin
		if a < b then
			return a;
		else
			return b;
		end if;
	end function;
	
end function_pkg;
