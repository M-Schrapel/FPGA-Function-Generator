library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity period_mul is
	PORT
	(
		clken		: in  std_logic ;
		clock		: in  std_logic ;
		dataa		: in  std_logic_vector (9 downto 0);
		datab		: in  std_logic_vector (9 downto 0);
		result	: out std_logic_vector (19 downto 0)
	);
end period_mul;

architecture rtl of period_mul is

signal dataa_int	: std_logic_vector (19 downto 0) := (others => '0');
--signal datab_int	: std_logic_vector (19 downto 0) := (others => '0');

signal cnt			: std_logic_vector (2 downto 0) := (others => '0');
signal cnt_nxt		: std_logic_vector (2 downto 0) := (others => '0');

type mul_array0 is array (0 to 9) of std_logic_vector(19 downto 0);
type mul_array1 is array (0 to 4) of std_logic_vector(19 downto 0);
type mul_array2 is array (0 to 2) of std_logic_vector(19 downto 0);

signal m0		: mul_array0;
signal m1		: mul_array1;
signal m2		: mul_array2;

begin


dataa_int(dataa'length-1 downto 0)						<= dataa;
dataa_int(dataa_int'length-1 downto dataa'length)	<= (others => '0');
--datab_int(datab'length-1 downto 0)						<= datab;
--datab_int(datab_int'length-1 downto datab'length)	<= (others => '0');

	ff:
		process(clock)
				begin	
					if rising_edge(clock) then
						cnt	<= cnt_nxt;
					end if;
	end process ff;

	m_0:
		process(clken,dataa_int,datab,cnt)
				begin	
					if clken = '1' then
						for i in 0 to 9 loop
							cnt_nxt	<= std_logic_vector(unsigned(cnt)+1);
							if (datab(i) = '1') then
								m0(i)	<= std_logic_vector(shift_left(unsigned(dataa_int),i));
							else
								m0(i)	<= (others => '0');
							end if;
						end loop;
					else
						cnt_nxt	<= (others => '0');
						for i in 0 to 9 loop
							m0(i)	<= (others => '0');
						end loop;
					end if;
	end process m_0; 

	m_1:
		process(cnt,m0)
			begin
				if unsigned(cnt) > 0 then
					for i in 0 to 4 loop
						m1(i)	<= std_logic_vector(unsigned(m0(i*2)) + unsigned(m0(i*2+1))); 
					end loop;
				else
					for i in 0 to 4 loop
						m1(i)	<= (others => '0');
					end loop;
				end if;
	end process m_1; 
	
	m_2:
		process(cnt,m1)
			begin
				if unsigned(cnt) > 1 then
					result	<= std_logic_vector(unsigned(m1(0)) + unsigned(m1(1)) + unsigned(m1(2)) + unsigned(m1(3)) + unsigned(m1(4)));
				else
					result	<= (others => '0');
				end if;
	end process m_2; 
	
--	ff:
--		process(clken,dataa_int,datab_int,clock)
--				begin	
--					if rising_edge(clock) then
--						if clken = '1' then
--							result	<= std_logic_vector(unsigned(dataa)*unsigned(datab));
--						else
--							result	<= (others => '0');
--						end if;
--					end if;
--	end process ff; 
--
--	ff:
--		process(clken,numer,clock)
--				begin	
--					if rising_edge(clock) then
--						if clken = '1' then
--							if datab(0) = '1' then
--								res0	<= dataa_int;
--							else
--								res0	<= (others => '0');
--							end if;
--							
--							if datab(1) = '1' then
--								res1	<= shift_left(unsigned(dataa_int),1);
--							else
--								res1	<= (others => '0');
--							end if;
--							if datab(2) = '1' then
--								res2	<= shift_left(unsigned(dataa_int),2);
--							else
--								res2	<= (others => '0');
--							end if;
--							if datab(3) = '1' then
--								res2	<= shift_left(unsigned(dataa_int),3);
--							else
--								res2	<= (others => '0');
--							end if;
--						else
--							res01	<= (others => '0');
--							res23	<= (others => '0');
--							res45	<= (others => '0');
--							res67	<= (others => '0');
--							res89	<= (others => '0');
--						end if;
--					end if;
--	end process ff; 

end rtl;