library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Led_blink is
	Port (clk : in STD_LOGIC;
			led : out STD_LOGIC;
			led2 : out STD_LOGIC);
end Led_blink;


architecture Behavioral of Led_blink is

	signal pulse : std_LOGIC := '0';
	signal pulse2 : std_LOGIC := '0';
	signal count : integer range 0 to 50000000 := 0;
	signal count2 : integer range 0 to 50000000 := 0;
	
begin

	--process 1
	process(clk)
	begin
		if clk' event and clk = '1' then
			if count = 49999999 then
				count <= 0;
				pulse <= not pulse;
			else
				count <= count + 1;
			end if;
		end if;
	led <= pulse;
	end process;
	--end process 1
	
	--process 2
	process(clk)
	begin
		if clk'event and clk = '1' then
			if count2 = 49999999 then
				count2 <= 0;
				pulse2 <= not pulse2;
			else
				count2 <= count2 + 1;
			end if;
		end if;
	led2 <= pulse2;
	
	end process;
	--end process 2
	

	
end Behavioral;