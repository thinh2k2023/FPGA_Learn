library ieee;																
use IEEE.STD_LOGIC_1164.ALL;																
use ieee.std_logic_arith.all;																
use IEEE.std_logic_unsigned.all;																
--FPGA ID : uint16_t 0x121																
--STM32 ID: uint16_t 0x111--																



entity SignalConverterV11 is -- need to confirm address of Remote's FPGA 																
	 generic ( -- declare constant with name g_CLKS_PER_BIT															
	 g_CLKS_PER_BIT : integer := 2500;     -- Needs to be set correctly = 50Mhz(FPGA pulse frequency) / 20Khz(CAN speed)															
	 --devide_time_for_1_pulse: integer:= 2499; -- 2499 = 50Mhz/20Khz (20Khz is frequency of CAN-bus communication)															
	 data_length: integer := 50; -- data length - 1															
	 PATTERN_A: integer:= 1;															
	 PATTERN_B: integer:= 0															
    );																
	 															
	port (															
			clock_50mhz : in std_logic;													
			--reset: in std_logic;													
			--key_1: in std_logic; -- phim bam de chuyen data truyen di (have to use reset button to enough state)													
			--key_2: in std_logic;													
																
			--LED_P73: out std_logic; -- khoi tao cho LED tat													
			--LED_P74: out std_logic := '1';													
																
			-- declare IN - OUT pulse													
			PIN_IN_1: in std_logic;													
			PIN_IN_2: in std_logic;													
			PIN_IN_3: in std_logic;													
			PIN_IN_4: in std_logic;													
																
			PIN_OUT_1_1: out std_logic := '1';  -- khoi tao muc cua cac chan output													
			PIN_OUT_1_2: out std_logic := '1'; 													
			PIN_OUT_2_1: out std_logic := '1'; 													
			PIN_OUT_2_2: out std_logic := '1'; 													
			PIN_OUT_3_1: out std_logic := '1'; 													
			PIN_OUT_3_2: out std_logic := '1'; 													
			PIN_OUT_4_1: out std_logic := '1'; 													
			PIN_OUT_4_2: out std_logic := '1'; 													
																
			-- i have clean pin to test pulse output													
			PIN_33: out std_logic:= '0'; 													
																
			CAN_TX: out std_logic := '1'; -- data TX -- dung de truyen data sang STM32													
																
			i_CAN_RX_serial: in std_logic -- read signal from CAN of STM32													
--			o_RX_DV: out std_logic; -- i dont know why, just do it													
			--o_RX_Byte: out std_logic_vector(0 to 50):= "111111111111111111111111111111111111111111111111111"  													
			);													
end SignalConverterV11;	







																
architecture Behavioral of SignalConverterV11 is																
	-- cover theo guidelines															
	type t_SM_Main is (state_Idle, state_RX_Start_Bit, state_RX_Data_Bits,															
                     state_RX_Stop_Bit, state_Cleanup); -- dinh nghia kieu du lieu moi																
	signal received_SM_Main : t_SM_Main := state_Idle; -- gan received_SM_Main theo kieu t_SM_Main va khoi tao voi trang thai Idle															
	--signal r_RX_Data_R : std_logic := '0'; -- r_RX_Data_R dung de lam bien trung gian, chua cu the la muc dich gi?															
	signal r_RX_Data   : std_logic := '0'; -- not understand yet why use 2 variables															
																
   signal r_Clk_Count : integer range 0 to 52000:= 0; -- 20*g_CLKS_PER_BIT + g_CLKS_PER_BIT/2 receive clock counter																
   signal r_Bit_Index : integer range 0 to 50 := 0;  -- 53 + 3 (protection - safe) Bits Total -- at new version we use 51 bits because no have enough output pin																
   signal r_RX_Byte   : std_logic_vector(0 to 50);-- := (others => '0');																
--   signal r_RX_DV     : std_logic := '0'; -- cover theo guidelines																
   signal number_data_received : integer range -1 to 99 := 0; -- data nhan dc se la so nguyen nao? -- until now i have done for decrypted with 100 symbols																
   																
	------ from November 22th 2019 it become pulse output // default 0 ___________________|----|____|-|_____															
																
	---------- we have to get parameter from Controller to control output signal----------															
	signal numerical_order_receive_data: integer range 0 to 195 := 0;															
	signal counter_refresh_numerical_order_data: integer range 0 to 50000000 := 0; ---- counter and refresh numerical_order_receive_data															
	signal receive_data_done: integer range 0 to 1 := 0; --0: still receive -- 1: complete															
--	signal update_data_avaiable: integer range 0 to 1 := 1; --0: disable -- 1: enable															
																
	-- create variable for start small pulse															
	signal out_1_pattern_A_avaiable: integer range 0 to 1:= 0; -- 0: disable /// 1: avaiable															
	signal out_2_pattern_A_avaiable: integer range 0 to 1:= 0; -- 0: disable /// 1: avaiable															
	signal out_3_pattern_A_avaiable: integer range 0 to 1:= 0; -- 0: disable /// 1: avaiable															
	signal out_4_pattern_A_avaiable: integer range 0 to 1:= 0; -- 0: disable /// 1: avaiable															
																
	signal out_1_pattern_B_avaiable: integer range 0 to 1:= 0; -- 0: disable /// 1: avaiable															
	signal out_2_pattern_B_avaiable: integer range 0 to 1:= 0; -- 0: disable /// 1: avaiable															
	signal out_3_pattern_B_avaiable: integer range 0 to 1:= 0; -- 0: disable /// 1: avaiable															
	signal out_4_pattern_B_avaiable: integer range 0 to 1:= 0; -- 0: disable /// 1: avaiable															
--	signal out_patternB_conter:				integer range 0 to 50000000:= 0; -- this counter variable for count time RX data finish and enable 											
																
	signal select_pattern: integer range 0 to 1 := 1; -- 1 ->  A, others -> B;															
	signal data_1:  integer range 0 to 99 := 0;															
	signal data_2:  integer range 0 to 99 := 0;															
	signal data_3:  integer range 0 to 99 := 0;															
	signal data_4:  integer range 0 to 99 := 0;															
	signal data_5:  integer range 0 to 99 := 0;															
	signal data_6:  integer range 0 to 99 := 0;															
	signal data_7:  integer range 0 to 99 := 0;															
	signal data_8:  integer range 0 to 99 := 0;															
	signal data_9:  integer range 0 to 99 := 0;															
	signal data_10: integer range 0 to 99 := 0;															
	signal data_11: integer range 0 to 99 := 0;															
	signal data_12: integer range 0 to 99 := 0;															
	signal data_13: integer range 0 to 99 := 0;															
	signal data_14: integer range 0 to 99 := 0;															
	signal data_15: integer range 0 to 99 := 0;															
	signal data_16: integer range 0 to 99 := 0;															
	signal data_17: integer range -1 to 99 := -1;															
	signal data_18: integer range 0 to 99 := 0;															
	signal data_19: integer range 0 to 99 := 0;															
	signal data_20: integer range 0 to 99 := 0;															
	signal data_21: integer range 0 to 99 := 0;															
	signal data_22: integer range 0 to 99 := 0;															
	signal data_23: integer range 0 to 99 := 0;															
	signal data_24: integer range 0 to 99 := 0;															
	signal data_25: integer range 0 to 99 := 0;															
	signal data_26: integer range 0 to 99 := 0;															
	signal data_27: integer range 0 to 99 := 0;															
	signal data_28: integer range 0 to 99 := 0;															
	signal data_29: integer range 0 to 99 := 0;															
	signal data_30: integer range 0 to 99 := 0;															
	signal data_31: integer range 0 to 99 := 0;															
	signal data_32: integer range 0 to 99 := 0;															
	signal data_33: integer range 0 to 99 := 0;															
	signal data_34: integer range 0 to 99 := 0;															
	signal data_35: integer range -1 to 99 := -1;															
	signal data_36: integer range 0 to 99 := 0;															
																
	------------------- some variables for pulse generate--------------------															
		------------ Pattern A ------------														
	signal n1: integer range 0 to 99 := 0;															
	signal n2: integer range 0 to 99 := 0;															
	signal B_time: integer range 0 to 9999 := 0; -- 20 Micro second															
	signal C_time: integer range 0 to 9999 := 0; -- 30 Micro second															
	signal D_time: integer range 0 to 9999 := 0; -- 30 Micro second															
																
		------------ Pattern B ------------														
	signal PatternB_n1: integer range 0 to 99 := 0;															
	signal PatternB_n2: integer range 0 to 99 := 0;															
	signal B1_time: integer range 0 to 9999 := 0;															
	signal C1_time: integer range 0 to 9999 := 0;															
	signal B2_time: integer range 0 to 9999 := 0;															
	signal D1_time: integer range 0 to 9999 := 0;															
	signal E_time:  integer range 0 to 9999 := 0;															
	signal D2_time: integer range 0 to 9999 := 0;															
	signal C2_time: integer range 0 to 9999 := 0;															
																
		------------ pattern A ------------														
	signal counter_for_11: integer range -2 to 50000000 := -2; -- this variable to count time to pull high and pull low  pulse output															
	signal counter_for_12: integer range -2 to 50000000 := -2; -- this variable to count time to pull high and pull low  pulse output															
	signal n1_counter_1: integer range 0 to 99 := 0; -- when any pulse have done this variable incease 1. If this value is lager than n1. the pulse will be off															
	signal n2_counter_1: integer range 0 to 99 := 0; -- when any pulse have done this variable incease 1. If this value is lager than n1. the pulse will be off															
	signal counter_for_D_time_1: integer range 0 to 50000000 := 0;															
																
	signal counter_for_21: integer range -2 to 50000000 := -2;															
	signal counter_for_22: integer range -2 to 50000000 := 0;															
	signal n1_counter_2: integer range 0 to 99 := 0;															
	signal n2_counter_2: integer range 0 to 99 := 0;															
	signal counter_for_D_time_2: integer range 0 to 50000000 := 0;															
																
	signal counter_for_31: integer range -2 to 50000000 := -2;															
	signal counter_for_32: integer range -2 to 50000000 := 0;															
	signal n1_counter_3: integer range 0 to 99 := 0;															
	signal n2_counter_3: integer range 0 to 99 := 0;															
	signal counter_for_D_time_3: integer range -2 to 50000000 := -2;															
																
	signal counter_for_41: integer range -2 to 50000000 := -2;															
	signal counter_for_42: integer range -2 to 50000000 := 0; -- this variable begin when A input pull low															
	signal n1_counter_4: integer range 0 to 99 := 0;															
	signal n2_counter_4: integer range 0 to 99 := 0;															
	signal counter_for_D_time_4: integer range 0 to 50000000 := 0;															
																
		------------ pattern B ------------														
	signal PatternB_counter_for_11: integer range -2 to 50000000 := -2;															
	signal PatternB_counter_for_12: integer range -2 to 50000000 := 0;															
	signal PatternB_n1_counter_1: integer range 0 to 99 := 0;															
	signal PatternB_n2_counter_1: integer range 0 to 99 := 0;															
	signal PatternB_counter_for_D_time_1: integer range 0 to 50000000 := 0;															
																
	signal PatternB_counter_for_21: integer range -2 to 50000000 := -2;															
	signal PatternB_counter_for_22: integer range -2 to 50000000 := 0;															
	signal PatternB_n1_counter_2: integer range 0 to 99 := 0;															
	signal PatternB_n2_counter_2: integer range 0 to 99 := 0;															
	signal PatternB_counter_for_D_time_2: integer range 0 to 50000000 := 0;															
																
	signal PatternB_counter_for_31: integer range -2 to 50000000 := -2;															
	signal PatternB_counter_for_32: integer range -2 to 50000000 := 0;															
	signal PatternB_n1_counter_3: integer range 0 to 99 := 0;															
	signal PatternB_n2_counter_3: integer range 0 to 99 := 0;															
	signal PatternB_counter_for_D_time_3: integer range -2 to 50000000 := -2;															
																
	signal PatternB_counter_for_41: integer range -2 to 50000000 := -2;															
	signal PatternB_counter_for_42: integer range -2 to 50000000 := 0;															
	signal PatternB_n1_counter_4: integer range 0 to 99 := 0;															
	signal PatternB_n2_counter_4: integer range 0 to 99 := 0;															
	signal PatternB_counter_for_D_time_4: integer range 0 to 50000000 := 0;															
																
	-- declare some constant															
	constant disable: integer := 0;															
	constant enable: integer := 1;															
																
	-- initialize std_logic_vector of 10 numbers															
--	constant data_length: integer := 55; -- data length - 1															
--this below data suitable for data with frequency = 20Mhz. For other frequency we have change pulse (read on osclloscope's screen)																
	constant number_0_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010000010000100000100001101111111"; -- data structure: 24 bits same + 24 bits DATA + 5 bits same (11111)															
	--Although same symbol to send and get we have to work for a little different pulse. -- the commently pulse is data to transfer to STM32. the outside data is data we have to compare with incoming wave															
	constant number_1_vec_temp:  std_logic_vector(0 to 50):= "000100010001000001010000010011100101100101001111111"; -- 000100100001000001010000 + DATA + 11111															
	constant number_2_vec_temp:  std_logic_vector(0 to 50):= "000100010001000001010000010101101110101001101111111";															
	constant number_3_vec_temp:  std_logic_vector(0 to 50):= "000100010001000001010000010110101011001111101111111";															
	constant number_4_vec_temp:  std_logic_vector(0 to 50):= "000100010001000001010000011001111000110000101111111";															
	constant number_5_vec_temp:  std_logic_vector(0 to 50):= "000100010001000001010000011010111101010110111111111";															
	constant number_6_vec_temp:  std_logic_vector(0 to 50):= "000100010001000001010000011100110110011010011111111";															
	constant number_7_vec_temp:  std_logic_vector(0 to 50):= "000100010001000001010000011111011001111101000011111";															
	constant number_8_vec_temp:  std_logic_vector(0 to 50):= "000100010001000001010000100010101000001010101111111";															
	constant number_9_vec_temp:  std_logic_vector(0 to 50):= "000100010001000001010000100100100011001001111111111";															
																
	constant number_10_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010000101000110101010000111111111"; --															
	constant number_11_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010000101110111110001110001111111"; --															
	constant number_12_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010000110000011100110001011111111"; --															
	constant number_13_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010000110110010010101110011111111"; --															
	constant number_14_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010000111010000100110111011111111"; --															
	constant number_15_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010000111100001111101101111111111"; --															
	constant number_16_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001000001001101100110101111111"; --															
	constant number_17_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001000110010000010000111111111"; --															
	constant number_18_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001001010000110011000111111111"; --															
	constant number_19_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001001100001101010100011111111"; --															
																
	constant number_20_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001010010101010101010111111111"; --															
	constant number_21_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001010100100001100110011111111"; --															
	constant number_22_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001011000110111110111101111111"; --															
	constant number_23_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001011110111100110011111111111"; --															
	constant number_24_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001100011110011001110111111111"; --															
	constant number_25_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001100101111000001001001111111"; --															
	constant number_26_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001101001101110011011011111111"; --															
	constant number_27_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001101111100010101011111111111"; --															
	constant number_28_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001110001000010101001011111111"; --															
	constant number_29_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001110111001001100101111111111"; --															
																
	constant number_30_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001111011011111011110011111111"; --															
	constant number_31_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010001111100101010011000001111111"; --															
	constant number_32_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010000011111001100100011111111"; --															
	constant number_33_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010000101111100101110101111111"; --															
	constant number_34_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010001001101011000100011111111"; --"00010001000100000101000010001001101011000100011111111111"; -- phien ban cu															
	constant number_35_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010001111100000100010001111111"; --															
	constant number_36_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010010001000111110011001111111"; --															
	constant number_37_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010010111001100111010111111111"; --															
	constant number_38_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010011011011010100011111111111"; --															
	constant number_39_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010011101010001101111011111111"; --															
																
	constant number_40_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010100000101111001001001111111"; --															
	constant number_41_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010100110010101011110111111111"; --															
	constant number_42_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010101010000011100011111111111"; --															
	constant number_43_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010101100001000001101101111111"; --															
	constant number_44_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010110010101111101010111111111"; --															
	constant number_45_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010110100100100111001011111111"; --															
	constant number_46_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010111000110010100000101111111"; --															
	constant number_47_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010010111110011100110110011111111"; --															
	constant number_48_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011000010101101011010011111111"; --															
	constant number_49_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011000100100110010110111111111"; --															
																
	constant number_50_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011001000110000010111110111111"; --															
	constant number_51_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011001110111011000011011111111"; --															
	constant number_52_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011010000011110011110111111111"; --															
	constant number_53_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011010110010111110000101111111"; --															
	constant number_54_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011011010000010110100001111111"; --															
	constant number_55_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011011100001010100100111111111"; --															
	constant number_56_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011100001000101011001111111111"; --															
	constant number_57_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011100111001110010101011111111"; --															
	constant number_58_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011101011011000001110001111111"; --															
	constant number_59_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011101101010011000001011111111"; --															
																
	constant number_60_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011110011110100111110001111111"; --															
	constant number_61_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011110101111101111001011111111"; --															
	constant number_62_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011111000110100110101111111111"; --															
	constant number_63_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010011111011110001010011101111111"; --															
	constant number_64_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100000101010011110010001111111"; --															
	constant number_65_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100000110010110010100011111111"; --															
	constant number_66_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100001000111010110001111111111"; --															
	constant number_67_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100001110110001111100101111111"; --															
	constant number_68_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100010000011011000001111111111"; --															
	constant number_69_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100010110011101001111011111111"; --															
																
	constant number_70_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100011010001011010110011111111"; --															
	constant number_71_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100011100000100001101011111111"; --															
	constant number_72_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100100001001111100011111111111";--															
	constant number_73_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100100111000100101011011111111";--															
	constant number_74_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100101011010010110010011111111";--															
	constant number_75_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100101101011001111101011111111";--															
	constant number_76_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100110011111011000001000111111";--															
	constant number_77_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100110101110101001100111111111";--															
	constant number_78_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100111001100011010101111111111";--															
	constant number_79_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010100111110110100001100101111111";--															
																
	constant number_80_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101000011111010010111110111111";--															
	constant number_81_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101000101110111100011011111111";--															
	constant number_82_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101001001100001111010011111111";--															
	constant number_83_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101001111100101011011011111111";--															
	constant number_84_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101010001001101001000011111111";--															
	constant number_85_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101010111000110000100111111111";--															
	constant number_86_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101011011010000011110111111111";--															
	constant number_87_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101011101011011010001011111111";--															
	constant number_88_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101100000101010010110001111111";--															
	constant number_89_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101100110011111010000011111111";--															
																
	constant number_90_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101101010001001111001111111111";--															
	constant number_91_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101101100000101011010101111111";--															
	constant number_92_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101110010100101001011111111111";--															
	constant number_93_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101110100101110000111011111111";--															
	constant number_94_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101111000111000011110011111111";--															
	constant number_95_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010101111101011001101001011111111";--															
	constant number_96_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010110000010001000111001101111111";--															
	constant number_97_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010110000110011010111110111111111";--															
	constant number_98_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010110001010001100100110111111111";--															
	constant number_99_vec_temp: std_logic_vector(0 to 50):= "000100010001000001010110001100000111110010100111111";															
																
		begin														
			-- Purpose: Control RX state machine--													
			----- CAN - Bus communication -------													
			process (clock_50mhz)													
			begin													
				if rising_edge(clock_50mhz) then												
					r_RX_Data   <=  i_CAN_RX_Serial; -- Data go to pin RX - PIN_80											
					case received_SM_Main is -- trang thai chinh cua qua trinh nhan du lieu											
					  when state_Idle => -- when in state idle											
--						 r_RX_DV     <=  '0'; 										
						 r_Clk_Count <= 0; -- bien dem theo tan so 50Mhz to count time to get data										
						 r_Bit_Index <= 0; -- number of data in vector that you wanna get										
			 													
						 if (r_RX_Data = '0') then       -- Start bit detected if input pulse of RX was pulled low (nomarlly it will be pulled up)										
							received_SM_Main <= state_RX_Start_Bit;									
							--receive_data_done <= 0; -- receive data is do not have pulse out									
						 else										
							received_SM_Main <= state_Idle;									
						 end if;										
						  										
					  -- Check middle of start bit to make sure it's still low											
					  when state_RX_Start_Bit =>											
							if (r_Clk_Count >= (g_CLKS_PER_BIT/2)) then --((g_CLKS_PER_BIT-1)/2) = 1250    -- Wait for middle bit low (in this case wait for about 100 micro sencond)									
								if (r_RX_Data = '0') then -- r_RX_Data is receiver data (du lieu tuc thoi`)								
								  r_Clk_Count <= 0;  -- reset counter since we found the middle								
								  received_SM_Main   <= state_RX_Data_Bits;								
								  								
								else								
								  received_SM_Main   <= state_Idle;								
								end if;								
							else									
																
							r_Clk_Count <= r_Clk_Count + 1;									
							received_SM_Main   <= state_RX_Start_Bit; -- still in start bit state to count clock									
						 end if;										
						 										
					  -- Wait g_CLKS_PER_BIT-1 clock cycles to sample serial data											
					  when state_RX_Data_Bits =>											
						r_RX_Byte(0) <=  '0'; -- khong co start bit rieng cho giao thuc CAN nen can nhan truoc gia tri '0' vao thoi diem start bit den										
						 if (r_Clk_Count < g_CLKS_PER_BIT-1) then										
							r_Clk_Count <= r_Clk_Count + 1;									
							received_SM_Main   <= state_RX_Data_Bits; -- still stay in "state_RX_Data_Bits" to continue get data									
						 else										
							r_Clk_Count            <= 0;									
							r_RX_Byte(r_Bit_Index + 1) <= r_RX_Data; -- get serial data									
							 									
							-- Check if we have sent out all bits									
							if (r_Bit_Index < data_length) then -- 3 is data_length - 1									
							  r_Bit_Index <= r_Bit_Index + 1;									
							  received_SM_Main   <= state_RX_Data_Bits; -- still stay in "state_RX_Data_Bits" to continue get data									
							else -- when receiver enough data in the frame 									
							  r_Bit_Index <= 0; -- reset order									
							  received_SM_Main   <= state_RX_Stop_Bit;									
							end if;									
						 end if;										
						 										
					  when state_RX_Stop_Bit =>  -- Receive Stop bit.  Stop bit = 1											
						 if (r_Clk_Count < g_CLKS_PER_BIT - 1) then -- Wait g_CLKS_PER_BIT-1 clock cycles for Stop bit to finish										
							r_Clk_Count <= r_Clk_Count + 1;									
							received_SM_Main   <= state_RX_Stop_Bit;									
						 else										
--							r_RX_DV     <=  '1';									
							r_Clk_Count <= 0;									
							received_SM_Main   <= state_Cleanup;									
							numerical_order_receive_data <= numerical_order_receive_data + 1;									
						 end if;										
									 							
					  -- Stay here 1 clock											
					  when state_Cleanup =>											
						 received_SM_Main <= state_Idle;										
--						 r_RX_DV   <=  '0';										
							 									
					  when others =>											
						 received_SM_Main <= state_Idle;										
					end case;											
																
			-- refresh "counter_refresh_numerical_order_data" variable value													
					if (r_RX_Data = '1' and received_SM_Main = state_Idle and numerical_order_receive_data > 70) then -- Slect 50 because 70 < PA (18*4) khi xung vao o muc cao va giao tiep CAN o trang thai nghi											
						counter_refresh_numerical_order_data <= counter_refresh_numerical_order_data + 1;										
						if (counter_refresh_numerical_order_data >= 1250000) then -- after 25ms have not receive any data, numerical_order_receive_data will be reset										
							counter_refresh_numerical_order_data <= 0;									
							numerical_order_receive_data <= 0;									
							--PIN_33 <= '1'; -- test time									
						end if;										
					else											
						counter_refresh_numerical_order_data <= 0;										
					end if;											
																
					case r_RX_Byte is -- recognize each symbol with any pulse input of "r_RX_Byte"											
						when number_0_vec_temp =>  number_data_received <= 0;  										
						when number_1_vec_temp =>  number_data_received <= 1;  										
						when number_2_vec_temp =>  number_data_received <= 2;  										
						when number_3_vec_temp =>  number_data_received <= 3; 										
						when number_4_vec_temp =>  number_data_received <= 4;  										
						when number_5_vec_temp =>  number_data_received <= 5; 										
						when number_6_vec_temp =>  number_data_received <= 6;  										
						when number_7_vec_temp =>  number_data_received <= 7;  										
						when number_8_vec_temp =>  number_data_received <= 8;  										
						when number_9_vec_temp =>  number_data_received <= 9;  										
																
						when number_10_vec_temp => number_data_received <= 10; 										
						when number_11_vec_temp => number_data_received <= 11; 										
						when number_12_vec_temp => number_data_received <= 12;  										
						when number_13_vec_temp => number_data_received <= 13;  										
						when number_14_vec_temp => number_data_received <= 14; 										
						when number_15_vec_temp => number_data_received <= 15; 										
						when number_16_vec_temp => number_data_received <= 16; 										
						when number_17_vec_temp => number_data_received <= 17; 										
						when number_18_vec_temp => number_data_received <= 18; 										
						when number_19_vec_temp => number_data_received <= 19; 										
																
						when number_20_vec_temp => number_data_received <= 20; 										
						when number_21_vec_temp => number_data_received <= 21; 										
						when number_22_vec_temp => number_data_received <= 22; 										
						when number_23_vec_temp => number_data_received <= 23; 										
						when number_24_vec_temp => number_data_received <= 24;  										
						when number_25_vec_temp => number_data_received <= 25; 										
						when number_26_vec_temp => number_data_received <= 26;  										
						when number_27_vec_temp => number_data_received <= 27; 										
						when number_28_vec_temp => number_data_received <= 28; 										
						when number_29_vec_temp => number_data_received <= 29;  										
																
						when number_30_vec_temp => number_data_received <= 30;										
						when number_31_vec_temp => number_data_received <= 31; 										
						when number_32_vec_temp => number_data_received <= 32; 										
						when number_33_vec_temp => number_data_received <= 33; 										
						when number_34_vec_temp => number_data_received <= 34;   										
						when number_35_vec_temp => number_data_received <= 35; 										
						when number_36_vec_temp => number_data_received <= 36;  										
						when number_37_vec_temp => number_data_received <= 37; 										
						when number_38_vec_temp => number_data_received <= 38;   										
						when number_39_vec_temp => number_data_received <= 39; 										
																
						when number_40_vec_temp => number_data_received <= 40; 										
						when number_41_vec_temp => number_data_received <= 41; 										
						when number_42_vec_temp => number_data_received <= 42;										
						when number_43_vec_temp => number_data_received <= 43; 										
						when number_44_vec_temp => number_data_received <= 44; 										
						when number_45_vec_temp => number_data_received <= 45;										
						when number_46_vec_temp => number_data_received <= 46;  										
						when number_47_vec_temp => number_data_received <= 47;  										
						when number_48_vec_temp => number_data_received <= 48; 										
						when number_49_vec_temp => number_data_received <= 49; 										
																
						when number_50_vec_temp => number_data_received <= 50;  										
						when number_51_vec_temp => number_data_received <= 51;   										
						when number_52_vec_temp => number_data_received <= 52; 										
						when number_53_vec_temp => number_data_received <= 53;  										
						when number_54_vec_temp => number_data_received <= 54; 										
						when number_55_vec_temp => number_data_received <= 55; 										
						when number_56_vec_temp => number_data_received <= 56;  										
						when number_57_vec_temp => number_data_received <= 57; 										
						when number_58_vec_temp => number_data_received <= 58; 										
						when number_59_vec_temp => number_data_received <= 59; 										
																
						when number_60_vec_temp => number_data_received <= 60; 										
						when number_61_vec_temp => number_data_received <= 61;  										
						when number_62_vec_temp => number_data_received <= 62;  										
						when number_63_vec_temp => number_data_received <= 63; 										
						when number_64_vec_temp => number_data_received <= 64;  										
						when number_65_vec_temp => number_data_received <= 65;  										
						when number_66_vec_temp => number_data_received <= 66; 										
						when number_67_vec_temp => number_data_received <= 67; 										
						when number_68_vec_temp => number_data_received <= 68; 										
						when number_69_vec_temp => number_data_received <= 69;  										
																
						when number_70_vec_temp => number_data_received <= 70;  										
						when number_71_vec_temp => number_data_received <= 71; 										
						when number_72_vec_temp => number_data_received <= 72; 										
						when number_73_vec_temp => number_data_received <= 73;  										
						when number_74_vec_temp => number_data_received <= 74;  										
						when number_75_vec_temp => number_data_received <= 75;  										
						when number_76_vec_temp => number_data_received <= 76;  										
						when number_77_vec_temp => number_data_received <= 77; 										
						when number_78_vec_temp => number_data_received <= 78;										
						when number_79_vec_temp => number_data_received <= 79;										
																
						when number_80_vec_temp => number_data_received <= 80;										
						when number_81_vec_temp => number_data_received <= 81;										
						when number_82_vec_temp => number_data_received <= 82; 										
						when number_83_vec_temp => number_data_received <= 83; 										
						when number_84_vec_temp => number_data_received <= 84; 										
						when number_85_vec_temp => number_data_received <= 85; 										
						when number_86_vec_temp => number_data_received <= 86; 										
						when number_87_vec_temp => number_data_received <= 87; 										
						when number_88_vec_temp => number_data_received <= 88; 										
						when number_89_vec_temp => number_data_received <= 89; 										
																
						when number_90_vec_temp => number_data_received <= 90; 										
						when number_91_vec_temp => number_data_received <= 91; 										
						when number_92_vec_temp => number_data_received <= 92; 										
						when number_93_vec_temp => number_data_received <= 93; 										
						when number_94_vec_temp => number_data_received <= 94; 										
						when number_95_vec_temp => number_data_received <= 95; 										
						when number_96_vec_temp => number_data_received <= 96; 										
						when number_97_vec_temp => number_data_received <= 97; 										
						when number_98_vec_temp => number_data_received <= 98; 										
						when number_99_vec_temp => number_data_received <= 99; 										
																
						when others => number_data_received <= -1;										
					end case;											
				 												
					case numerical_order_receive_data is -- with every data come, we have to know the -- thoroughly work with this variable											
						--when 0 to 3    => select_pattern <= number_data_received;										
						--when 4 to 7    => select_pattern <= number_data_received;										
						--when 8 to 11    => select_pattern <= number_data_received;										
						--when 12 to 15    => select_pattern <= number_data_received;										
						when 17 to 18   => select_pattern <= number_data_received; 			--PIN_33 <= '0'; PIN_34 <= '0'; -- test time -- test time-- PATTERN A or B --------------------------------------							
						when 21 to 22 	 => data_1  <= number_data_received; -- N1								N1 PB	
						when 25 to 26   => data_2  <= number_data_received; -- N2								N2 PB		
						when 29  to 30  => data_3  <= number_data_received; -- B HIGH								B1 HIGH PB		
						when 33  to 34  => data_4  <= number_data_received; -- B LOW								B1 LOW PB		
						when 37  to 38  => data_5  <= number_data_received; -- C HIGH								C1 HIGH PB		
						when 41  to 42  => data_6  <= number_data_received; -- C LOW								C1 LOW PB		
						when 45  to 46  => data_7  <= number_data_received; -- D HIGH								B2 HIGH PB		
						when 49  to 50  => data_8  <= number_data_received; -- D LOW 								B2 LOW PB		
						when 53  to 54  => data_9  <= number_data_received; -- PATTERN A ------------			D1 HIGH PB							
						when 57  to 58  => data_10 <= number_data_received; -- N1									D1 LOW PB	
						when 61  to 62  => data_11 <= number_data_received; -- N2									E HIGH HIGHPB	
						when 65  to 66  => data_12 <= number_data_received; -- B HIGH								E HIGH PB		
						when 69  to 70  => data_13 <= number_data_received; -- B LOW								E LOW PB		
						when 73  to 74  => data_14 <= number_data_received; -- C HIGH								D2 HIGH PB		
						when 77  to 78  => data_15 <= number_data_received; -- C LOW								D2 LOW PB		
						when 81  to 82  => data_16 <= number_data_received; -- D HIGH								C2 HIGH PB		
						when 85  to 86  => data_17 <= number_data_received; -- D LOW 								C2 LOW PB		
						when 89  to 90  => data_18 <= number_data_received; --- void	---	PATTERN B -----------------------------------								
						when 93  to 94  => data_19 <= number_data_received; --									N1 PB	
						when 97  to 98  => data_20 <= number_data_received; --									N2 PB	
						when 101 to 102 => data_21 <= number_data_received; --										B1 HIGH PB
						when 105 to 106 => data_22 <= number_data_received; --										B1 LOW PB
						when 109 to 110 => data_23 <= number_data_received; --										C1 HIGH PB
						when 113 to 114 => data_24 <= number_data_received; --										C1 LOW PB
						when 117 to 118 => data_25 <= number_data_received; --										B2 HIGH PB
						when 121 to 122 => data_26 <= number_data_received; --										B2 LOW PB
						when 125 to 126 => data_27 <= number_data_received; --										D1 HIGH PB
						when 129 to 130 => data_28 <= number_data_received; --										D1 LOW PB 
						when 133 to 134 => data_29 <= number_data_received; --										E HIGH HIGH PB
						when 137 to 138 => data_30 <= number_data_received; --										E HIGH PB
						when 141 to 142 => data_31 <= number_data_received; --										E LOW PB
						when 145 to 146 => data_32 <= number_data_received; --										D2 HIGH PB
						when 149 to 150 => data_33 <= number_data_received; --										D2 LOW PB
						when 153 to 154 => data_34 <= number_data_received; --										C2 HIGH PB
						when 157 to 158 => data_35 <= number_data_received; --										C2 LOW PB
																
						when others => data_36 <= number_data_received;										
					end case;											
																
					-- pattern A was selected--											
					if (select_pattern = data_9 and select_pattern = pattern_A and data_17 /= -1) then -- data_18 != -1 mean receive data finish											
						if (data_1 = data_10 and data_2 = data_11 and data_3 = data_12 and data_4 = data_13 										
							and data_5 = data_14 and data_6 = data_15 and data_7 = data_16 and data_8 = data_17) then									
							if (PIN_IN_1 = '1' or PIN_IN_2 = '1' or PIN_IN_3 = '1' or PIN_IN_4 = '1') then									
								n1 <= data_1;								
								n2 <= data_2;								
								B_time <= data_3*100 + data_4;								
								C_time <= data_5*100 + data_6;								
								D_time <= data_7*100 + data_8;								
--								B_time <= shift_left(unsigned(data_3), 7) + data_4;								
--								C_time <= shift_left(unsigned(data_5), 7) + data_6;								
--								D_time <= shift_left(unsigned(data_7), 7) + data_8;								
																
								receive_data_done <= 1; -- enable generae pulse output								
								data_17 <= -1;								
								--PIN_33 <= '1'; -- test time								
							end if;									
						end if;										
																
					-- pattern B was selected--											
					elsif (select_pattern = data_18 and select_pattern = PATTERN_B and data_35 /= -1) then -- data_36 != -1 mean receive data finish											
						if (data_1 = data_19 and data_2 = data_20 and data_3 = data_21 and data_4 = data_22 and data_5 = data_23	and data_6 = data_24 									
							and data_7 = data_25 and data_8 = data_26 and data_9 = data_27 and data_10 = data_28 and data_11 = data_29 and data_12 = data_30 									
							and data_13 = data_31 and data_14 = data_32 and data_15 = data_33 and data_16 = data_34 and data_17 = data_35) then									
							if (PIN_IN_1 = '1' or PIN_IN_2 = '1' or PIN_IN_3 = '1' or PIN_IN_4 = '1') then									
								PatternB_n1  <= data_1;								
								PatternB_n2  <= data_2;								
								B1_time		 <= data_3*100 + data_4;						
								C1_time		 <= data_5*100 + data_6;						
								B2_time 		 <= data_7*100 + data_8;						
								D1_time 		 <= data_9*100 + data_10;						
								E_time 		 <= data_11*10000 + data_12*100 + data_13;						
								D2_time 		 <= data_14*100 + data_15;						
								C2_time 		 <= data_16*100 + data_17;						
																
								receive_data_done <= 1; -- enable generae pulse output								
								data_35 <= -1;								
								--PIN_33 <= '1';  -- test time								
							end if;									
						end if; -- check synchronous data										
					end if; -- pattern											
																
				end if; -- rising												
	 															
			end process;													
																
		--------------------------- generate pulse for signal converter ----------------------------														
		---------------------------- Channel 1-1 ------ pattern A + B --------------------														
		process(clock_50mhz)														
		begin														
			if rising_edge(clock_50mhz) then
				if (select_pattern = PATTERN_A and receive_data_done = 1) then -- if we use Pattern A for test signal converter												
					------------------------- begin 1-1 part -----------------PATTERN A -------------											
						if (PIN_IN_1 = '1') then -- use P119_pin for read pulse										
							counter_for_11 <= -2;									
							PIN_OUT_1_1 <= '0'; -- xung dau ra se bang xung dau vao khi xung dau vao = 1;									
							n1_counter_1 <= n1 + 1;									
							out_1_pattern_A_avaiable <= enable;									
						elsif (PIN_IN_1 = '0' and out_1_pattern_A_avaiable = enable) then										
							counter_for_11 <= counter_for_11 + 1;									
						end if;										
																
						if (counter_for_11 >= -1 and counter_for_11 < B_time*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_1 <= '1';									
						elsif (counter_for_11 = B_time*50 and PIN_IN_1 = '0') then 										
							PIN_OUT_1_1 <= '0';									
							n1_counter_1 <= n1_counter_1 - 1; -- first time to plus n									
						elsif (counter_for_11 > B_time*50 and counter_for_11 <= (B_time + C_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_1 <= '0';									
						elsif (counter_for_11 > (B_time + C_time)*50 and PIN_IN_1 = '0') then 										
							PIN_OUT_1_1 <= '1';									
							counter_for_11 <= -2; 									
						end if;										
																
						if (n1_counter_1 = 0) then 										
							counter_for_11 <= -1; 									
						end if;										
																
						--------------------------- complete 1-1 part ----------------PATTERN A--------------		
						
						--------------------------- begin 1-2 part -------------------PATTERN A--------------				 						
						if (PIN_IN_1 = '1') then -- pin 119										
							counter_for_12 <= -2; -- variable for counter second D -- begin when input low									
							counter_for_D_time_1 <= counter_for_D_time_1 + 1;									
							n2_counter_1 <= n2 + 1;									
						elsif (PIN_IN_1 = '0' and out_1_pattern_A_avaiable = enable) then										
							counter_for_12 <= counter_for_12 + 1;									
						end if;										
																
						if (counter_for_D_time_1 <= D_time*50 and PIN_IN_1 = '1') then -- case D_time*50 + 1 when D_time*50 = 0										
							PIN_OUT_1_2 <= '1'; -- OUTPUT LOW									
						elsif (counter_for_D_time_1 > D_time*50 and PIN_IN_1 = '1') then										
							PIN_OUT_1_2 <= '0'; -- OUTPUT HIGH									
						end if;										
																
						if (counter_for_12 > 0 and counter_for_12 <= D_time*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '0'; -- OUTPUT HIGH									
							counter_for_D_time_1 <= 0;									
						elsif (counter_for_12 > D_time*50 and counter_for_12 < (D_time + B_time)*50 and PIN_IN_1 = '0') then 										
							PIN_OUT_1_2 <= '1';									
						elsif (counter_for_12 = (D_time + B_time)*50 + 1 and PIN_IN_1 = '0') then 										
							PIN_OUT_1_2 <= '0'; 									
							n2_counter_1 <= n2_counter_1 - 1; -- tang gia tri bien n de kiem tra va thuc hien									
						elsif (counter_for_12 > (D_time + B_time)*50 and counter_for_12 <= (D_time + B_time + C_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '0';									
						elsif (counter_for_12 > (D_time + B_time + C_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '1';									
							counter_for_12 <= D_time*50 - 1;									
						end if;										
																
						if (n2_counter_1 = 0) then										
							PIN_OUT_1_2 <= '1';									
							counter_for_12 <= -2; 									
						end if;										
																
						------------------------- complete 1-2 part ----------------PATTERN A--------------										
																
						--------------------------- begin 2-1 part --------------PATTERN A -----------------										
						if (PIN_IN_2 = '1') then -- use P120_pin for read pulse										
							counter_for_21 <= -2;									
							PIN_OUT_2_1 <= '0'; -- xung dau ra se bang xung dau vao khi xung dau vao = 1;									
							n1_counter_2 <= n1 + 1;									
							out_2_pattern_A_avaiable <= enable;									
						elsif (PIN_IN_2 = '0' and out_2_pattern_A_avaiable = enable) then										
							counter_for_21 <= counter_for_21 + 1;									
						end if;										
																
						if (counter_for_21 >= -1 and counter_for_21 < B_time*50 and PIN_IN_2 = '0') then --B_time*50										
							PIN_OUT_2_1 <= '1';									
						elsif (counter_for_21 = B_time*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_1 <= '0';									
							n1_counter_2 <= n1_counter_2 - 1; --first time to plus n									
						elsif (counter_for_21 > B_time*50 and counter_for_21 <= (B_time + C_time)*50 and PIN_IN_2 = '0') then --(B_time + C_time)*50										
							PIN_OUT_2_1 <= '0';									
						elsif (counter_for_21 > (B_time + C_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_1 <= '1';									
							counter_for_21 <= -2; 									
						end if;										
						if (n1_counter_2 = 0) then -- n1 <= 3										
							counter_for_21 <= -1; -- + 1; 									
						end if;										
						------------------------- complete 2-1 part -------------PATTERN A-----------------										
																
																
						--------------------------- begin 2-2 part --------------PATTERN A -----------------										
						if (PIN_IN_2 = '1') then --pin120										
							counter_for_22 <= -2; -- variable for counter second D -- begin when input low									
							counter_for_D_time_2 <= counter_for_D_time_2 + 1;									
							n2_counter_2 <= n2 + 1;									
						elsif (PIN_IN_2 = '0' and out_2_pattern_A_avaiable = enable) then										
							counter_for_22 <= counter_for_22 + 1;									
						end if;										
																
						if (counter_for_D_time_2 < D_time*50 and PIN_IN_2 = '1') then										
							PIN_OUT_2_2 <= '1'; -- out = 0									
						elsif (counter_for_D_time_2 >= D_time*50 and PIN_IN_2 = '1') then										
							PIN_OUT_2_2 <= '0';									
						end if;										
																
						if (counter_for_22 > 0 and counter_for_22 <= D_time*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '0';	
							counter_for_D_time_2 <= 0;																	
						elsif (counter_for_22 > D_time*50 and counter_for_22 < (D_time + B_time)*50 and PIN_IN_2 = '0') then 										
							PIN_OUT_2_2 <= '1';									
						elsif (counter_for_22 = (D_time + B_time)*50 + 1 and PIN_IN_2 = '0') then -- when B_time = 0										
							PIN_OUT_2_2 <= '1';									
							n2_counter_2 <= n2_counter_2 - 1; -- first time plus n									
						elsif (counter_for_22 > (D_time + B_time)*50 and counter_for_22 <= (D_time + B_time + C_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '0';									
						elsif (counter_for_22 > (D_time + B_time + C_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '1';									
							counter_for_22 <= D_time*50 - 1;								
						end if;										
																
						if (n2_counter_2 = 0) then										
						PIN_OUT_2_2 <= '1';											
						counter_for_22 <= -2; 										
						end if;										
						------------------------- complete 2-2 part -------------PATTERN A-----------------										
																
						------------------------- begin 3-1 part ------------------PATTERN A------------										
						if (PIN_IN_3 = '1') then -- use P121_pin for read pulse										
							counter_for_31 <= -2;									
							PIN_OUT_3_1 <= '0'; -- xung dau ra se bang xung dau vao khi xung dau vao = 1;									
							n1_counter_3 <= n1 + 1;									
							out_3_pattern_A_avaiable <= enable;									
						elsif (PIN_IN_3 = '0' and out_3_pattern_A_avaiable = enable) then										
							counter_for_31 <= counter_for_31 + 1;									
						end if;										
																
						if (counter_for_31 >= -1 and counter_for_31 < B_time*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_1 <= '1';									
						elsif (counter_for_31 = B_time*50 and PIN_IN_3 = '0') then 										
							PIN_OUT_3_1 <= '0';									
							n1_counter_3 <= n1_counter_3 - 1; -- first time to plus n									
						elsif (counter_for_31 > B_time*50 and counter_for_31 <= (B_time + C_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_1 <= '0';									
						elsif (counter_for_31 > (B_time + C_time)*50 and PIN_IN_3 = '0') then 										
							PIN_OUT_3_1 <= '1';									
							counter_for_31 <= -2; 									
						end if;										
																
						if (n1_counter_3 = 0) then 										
							counter_for_31 <= -1; 									
						end if;										
						------------------------- complete 3-1 part ---------------PATTERN A---------------										
																
																
						-------------------------- begin 3-2 part -----------------PATTERN A---------------										
						if (PIN_IN_3 = '1') then --pin 121										
							counter_for_32 <= -2; -- variable for counter second D -- begin when input low									
							counter_for_D_time_3 <= counter_for_D_time_3 + 1;									
							n2_counter_3 <= n2 + 1;									
						elsif (PIN_IN_3 = '0' and out_3_pattern_A_avaiable = enable) then										
							counter_for_32 <= counter_for_32 + 1;									
						end if;										
																
						if (counter_for_D_time_3 < D_time*50 and PIN_IN_3 = '1') then										
							PIN_OUT_3_2 <= '1';-- out = 0									
						elsif (counter_for_D_time_3 >= D_time*50 and PIN_IN_3 = '1') then										
							PIN_OUT_3_2 <= '0';									
						end if;										
																
						if (counter_for_32 > 0 and counter_for_32 <= D_time*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '0';								
							counter_for_D_time_3 <= 0;									
						elsif (counter_for_32 = D_time*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '0'; -- OUTPUT HIGH									
						elsif (counter_for_32 > D_time*50 and counter_for_32 < (D_time + B_time)*50 and PIN_IN_3 = '0') then  ---- dong lenh thu K3B										
							PIN_OUT_3_2 <= '1';									
						elsif (counter_for_32 = (D_time + B_time)*50 + 1 and PIN_IN_3 = '0') then  ---- dong lenh thu K3B										
							PIN_OUT_3_2 <= '1';									
							n2_counter_3 <= n2_counter_3 - 1; -- frist time plus n									
						elsif (counter_for_32 > (D_time + B_time)*50 and counter_for_32 <= (D_time + B_time + C_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '0';									
						elsif (counter_for_32 > (D_time + B_time + C_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '1';									
							counter_for_32 <= D_time*50 - 1;									
						end if;										
																
						if (n2_counter_3 = 0) then										
							PIN_OUT_3_2 <= '1';									
							counter_for_32 <= -2; 										
						end if;										
						------------------------- complete 3-2 part ------------PATTERN A------------------										
																
																
						------------------------- begin 4-1 part -----------------PATTERN A---------------										
						if (PIN_IN_4 = '1') then -- use P124_pin for read pulse										
							counter_for_41 <=	-2;								
							PIN_OUT_4_1 <= '0'; -- xung dau ra se bang xung dau vao khi xung dau vao = 1;									
							n1_counter_4 <= n1 + 1;									
							out_4_pattern_A_avaiable <= enable;									
						elsif (PIN_IN_4 = '0' and out_4_pattern_A_avaiable = enable) then										
							counter_for_41 <= counter_for_41 + 1;									
						end if;										
																
							if (counter_for_41 >= -1 and counter_for_41 < B_time*50 and PIN_IN_4 = '0') then									
								PIN_OUT_4_1 <= '1';								
							elsif (counter_for_41 = B_time*50 and PIN_IN_4 = '0') then 									
								PIN_OUT_4_1 <= '0';								
								n1_counter_4 <= n1_counter_4 - 1; -- first time to plus n								
							elsif (counter_for_41 > B_time*50 and counter_for_41 <= (B_time + C_time)*50 and PIN_IN_4 = '0') then									
								PIN_OUT_4_1 <= '0';								
							elsif (counter_for_41 > (B_time + C_time)*50 and PIN_IN_4 = '0') then 									
								PIN_OUT_4_1 <= '1';								
								counter_for_41 <= -2; 								
							end if;									
																
						if (n1_counter_4 = 0) then 										
							counter_for_41 <= -1; 									
						end if;										
					------------------------- complete 4-1 part --------------PATTERN A----------------											
																
																
					------------------------- begin 4-2 part -----------------PATTERN A---------------											
						if (PIN_IN_4 = '1') then --pin124										
							counter_for_42 <= -2; -- variable for counter second D -- begin when input low									
							counter_for_D_time_4 <= counter_for_D_time_4 + 1;									
							n2_counter_4 <= n2 + 1;									
						elsif (PIN_IN_4 = '0' and out_4_pattern_A_avaiable = enable) then										
							counter_for_42 <= counter_for_42 + 1;									
						end if;										
																
						if (counter_for_D_time_4 < D_time*50 and PIN_IN_4 = '1') then										
							PIN_OUT_4_2 <= '1'; -- output LOW									
						elsif (counter_for_D_time_4 >= D_time*50 and PIN_IN_4 = '1') then										
							PIN_OUT_4_2 <= '0';									
						end if;										
																
						if (counter_for_42 > 0 and counter_for_42 <= D_time*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '0'; -- OUTPUT HIGH						
							counter_for_D_time_4 <= 0;										
						elsif (counter_for_42 > D_time*50 and counter_for_42 < (D_time + B_time)*50 and PIN_IN_4 = '0') then 										
							PIN_OUT_4_2 <= '1';									
						elsif (counter_for_42 = (D_time + B_time)*50 + 1 and PIN_IN_4 = '0') then 										
							PIN_OUT_4_2 <= '1';									
							n2_counter_4 <= n2_counter_4 - 1; -- first time plus n									
						elsif (counter_for_42 > (D_time + B_time)*50 and counter_for_42 <= (D_time + B_time + C_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '0'; -- OUTPUT HIGH									
						elsif (counter_for_42 > (D_time + B_time + C_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '1';											
							counter_for_42 <= D_time*50 - 1;									
						end if;										
																
						if (n2_counter_4 = 0) then										
							PIN_OUT_4_2 <= '1';									
							counter_for_42 <= -2; 									
						end if;										
						------------------------- complete 4-2 part ----------------PATTERN A--------------										
																
																
												----------- START PATTERN B -----------				
				elsif (select_pattern = PATTERN_B and receive_data_done = 1) then  -- pattern B was selected												
						--------------------------- begin 1-1 part --------------- PATTERN B---------------------------										
						if (PIN_IN_1 = '1') then -- use P119_pin for read pulse										
							PatternB_counter_for_11 <= -2;									
							PIN_OUT_1_1 <= '0'; -- xung dau ra se bang xung dau vao khi xung dau vao = 1;									
							PatternB_n1_counter_1 <= PatternB_n1 + 1;									
							out_1_pattern_B_avaiable <= enable;									
						elsif (PIN_IN_1 = '0' and out_1_pattern_B_avaiable = enable) then										
								PatternB_counter_for_11 <= PatternB_counter_for_11 + 1;								
						end if;										
																
						if (PatternB_counter_for_11 > -2 and PatternB_counter_for_11 < B1_time*50 and PIN_IN_1 = '0') then --B_time*50										
							PIN_OUT_1_1 <= '1'; -- Output LOW									
						elsif (PatternB_counter_for_11 = B1_time*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_1 <= '1'; -- Output LOW									
							PatternB_n1_counter_1 <= PatternB_n1_counter_1 - 1; -- first time to plus n1									
						elsif (PatternB_counter_for_11 > B1_time*50 and PatternB_counter_for_11 < (B1_time + C1_time)*50 and PIN_IN_1 = '0') then --(B_time + C_time)*50										
							PIN_OUT_1_1 <= '0';									
						elsif (PatternB_counter_for_11 = (B1_time + C1_time)*50 and PIN_IN_1 = '0') then 										
							PIN_OUT_1_1 <= '0';									
							PatternB_n1_counter_1 <= PatternB_n1_counter_1 - 1; -- second time to plus n1									
						elsif (PatternB_counter_for_11 > (B1_time + C1_time)*50 and PatternB_counter_for_11 <= (B1_time + C1_time + B2_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_1 <= '1';									
						elsif (PatternB_counter_for_11 > (B1_time + C1_time + B2_time)*50 and PatternB_counter_for_11 <= (B1_time + C1_time + B2_time + C1_time)*50 and PIN_IN_1 = '0') then -- and counter_for_41 < 19999999) then										
							PIN_OUT_1_1 <= '0';									
						elsif (PatternB_counter_for_11 > (B1_time + C1_time + B2_time + C1_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_1 <= '1';									
							PatternB_counter_for_11 <= (B1_time + C1_time)*50; 									
						end if;										
																
						if (PatternB_n1_counter_1 <= 0 ) then --      - 1) then -- n1 <= 1										
							PIN_OUT_1_1 <= '1';									
							PatternB_counter_for_11 <= -2;									
						end if;										
						------------------------- complete 1-1 part --------------PATTERN B-------------------------										
																
																
						------------------------- begin 1-2 part -----------------PATTERN B-------------------------										
						if (PIN_IN_1 = '1') then  -- input pin 119										
							PatternB_n2_counter_1 <= PatternB_n2 + 1;									
							PIN_OUT_1_2 <= '1';									
							PatternB_counter_for_12 <= -2;									
						elsif (PIN_IN_1 = '0' and out_1_pattern_B_avaiable = enable) then										
								PatternB_counter_for_12 <= PatternB_counter_for_12 + 1;								
						end if;										
																
						if (PatternB_counter_for_12 > -2 and PatternB_counter_for_12 <= D1_time*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '1';									
						elsif (PatternB_counter_for_12 > D1_time*50 and PatternB_counter_for_12 <= (D1_time + E_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '0'; -- Output High									
						elsif (PatternB_counter_for_12 > (D1_time + E_time)*50 and PatternB_counter_for_12 < (B1_time + C1_time + D2_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '1';									
						elsif (PatternB_counter_for_12 = (B1_time + C1_time + D2_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '1';									
							PatternB_n2_counter_1 <= PatternB_n2_counter_1 - 1; -- first time to plus n1									
						elsif (PatternB_counter_for_12 > (B1_time + C1_time + D2_time)*50 and PatternB_counter_for_12 < (B1_time + C1_time + D2_time + C2_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '0';									
						elsif (PatternB_counter_for_12 = (B1_time + C1_time + D2_time + C2_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '0';									
							PatternB_n2_counter_1 <= PatternB_n2_counter_1 - 1; -- second time to plus n1									
						elsif (PatternB_counter_for_12 > (B1_time + C1_time + D2_time + C2_time)*50 and PatternB_counter_for_12 <= (B1_time + C1_time + B2_time + C1_time + D2_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '1';									
						elsif (PatternB_counter_for_12 > (B1_time + C1_time + B2_time + C1_time + D2_time)*50 and PatternB_counter_for_12 <= (B1_time + C1_time + B2_time + C1_time + D2_time + C2_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '0';									
						elsif (PatternB_counter_for_12 > (B1_time + C1_time + B2_time + C1_time + D2_time + C2_time)*50 and PIN_IN_1 = '0') then										
							PIN_OUT_1_2 <= '1';									
							PatternB_counter_for_12 <= (B1_time + C1_time + D2_time + C2_time)*50;									
						end if;										
																
						if (PatternB_n2_counter_1 <= 0 ) then -- when the n2 enough the pulse is LOW										
							PIN_OUT_1_2 <= '1';									
							PatternB_counter_for_12 <= 0 + 1;									
						end if;										
						------------------------ complete 1-2 part ----------------PATTERN B---------------------------										
																
																
						------------------------- begin 2-1 part ------------------PATTERN B---------------------										
						if (PIN_IN_2 = '1') then -- use P120_pin for read pulse										
							PatternB_counter_for_21 <= -2;									
							PIN_OUT_2_1 <= '0'; -- xung dau ra se bang xung dau vao khi xung dau vao = 1;									
							PatternB_n1_counter_2 <= PatternB_n1 + 1;									
							out_2_pattern_B_avaiable <= enable;									
						elsif (PIN_IN_2 = '0' and out_2_pattern_B_avaiable = enable) then										
							PatternB_counter_for_21 <= PatternB_counter_for_21 + 1;									
						end if;										
																
						if (PatternB_counter_for_21 > -2 and PatternB_counter_for_21 < B1_time*50 and PIN_IN_2 = '0') then --B_time*50										
							PIN_OUT_2_1 <= '1'; -- Output LOW									
						elsif (PatternB_counter_for_21 = B1_time*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_1 <= '1'; -- Output LOW									
							PatternB_n1_counter_2 <= PatternB_n1_counter_2 - 1; -- first time to plus n1									
						elsif (PatternB_counter_for_21 > B1_time*50 and PatternB_counter_for_21 < (B1_time + C1_time)*50 and PIN_IN_2 = '0') then --(B_time + C_time)*50										
							PIN_OUT_2_1 <= '0';									
						elsif (PatternB_counter_for_21 = (B1_time + C1_time)*50 and PIN_IN_2 = '0') then 										
							PIN_OUT_2_1 <= '0';									
							PatternB_n1_counter_2 <= PatternB_n1_counter_2 - 1; -- second time to plus n1									
						elsif (PatternB_counter_for_21 > (B1_time + C1_time)*50 and PatternB_counter_for_21 <= (B1_time + C1_time + B2_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_1 <= '1';									
						elsif (PatternB_counter_for_21 > (B1_time + C1_time + B2_time)*50 and PatternB_counter_for_21 <= (B1_time + C1_time + B2_time + C1_time)*50 and PIN_IN_2 = '0') then -- and counter_for_41 < 19999999) then										
							PIN_OUT_2_1 <= '0';									
						elsif (PatternB_counter_for_21 > (B1_time + C1_time + B2_time + C1_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_1 <= '1';									
							PatternB_counter_for_21 <= (B1_time + C1_time)*50; 									
						end if;										
																
						if (PatternB_n1_counter_2 <= 0 ) then --      - 1) then -- n1 <= 2										
							PIN_OUT_2_1 <= '1';									
							PatternB_counter_for_21 <= -2;									
						end if;										
						------------------------- complete 2-1 part ------------PATTERN B---------------------------										
																
																
						--------------------------- begin 2-2 part -------------PATTERN B---------------------------										
						if (PIN_IN_2 = '1') then -- pin120										
							PatternB_n2_counter_2 <= PatternB_n2 + 1;									
							PIN_OUT_2_2 <= '1';									
							PatternB_counter_for_22 <= -2;									
						elsif (PIN_IN_2 = '0' and out_2_pattern_B_avaiable = enable) then										
								PatternB_counter_for_22 <= PatternB_counter_for_22 + 1;								
						end if;										
																
						if (PatternB_counter_for_22 > -2 and PatternB_counter_for_22 <= D1_time*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '1';									
						elsif (PatternB_counter_for_22 > D1_time*50 and PatternB_counter_for_22 <= (D1_time + E_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '0';									
						elsif (PatternB_counter_for_22 > (D1_time + E_time)*50 and PatternB_counter_for_22 < (B1_time + C1_time + D2_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '1';									
						elsif (PatternB_counter_for_22 = (B1_time + C1_time + D2_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '1';									
							PatternB_n2_counter_2 <= PatternB_n2_counter_2 - 1; -- first time to plus n1									
						elsif (PatternB_counter_for_22 > (B1_time + C1_time + D2_time)*50 and PatternB_counter_for_22 < (B1_time + C1_time + D2_time + C2_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '0';									
						elsif (PatternB_counter_for_22 = (B1_time + C1_time + D2_time + C2_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '0';									
							PatternB_n2_counter_2 <= PatternB_n2_counter_2 - 1; -- second time to plus n1									
						elsif (PatternB_counter_for_22 > (B1_time + C1_time + D2_time + C2_time)*50 and PatternB_counter_for_22 <= (B1_time + C1_time + B2_time + C1_time + D2_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '1';									
						elsif (PatternB_counter_for_22 > (B1_time + C1_time + B2_time + C1_time + D2_time)*50 and PatternB_counter_for_22 <= (B1_time + C1_time + B2_time + C1_time + D2_time + C2_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '0';									
						elsif (PatternB_counter_for_22 > (B1_time + C1_time + B2_time + C1_time + D2_time + C2_time)*50 and PIN_IN_2 = '0') then										
							PIN_OUT_2_2 <= '1';									
							PatternB_counter_for_22 <= (B1_time + C1_time + D2_time + C2_time)*50;									
						end if;										
																
						if (PatternB_n2_counter_2 <= 0) then -- when the n2 enough the pulse is LOW										
							PIN_OUT_2_2 <= '1';									
							PatternB_counter_for_22 <= 0 + 1;									
						end if;										
						------------------------- complete 2-2 part --------------PATTERN B-------------------------										
																
																
						--------------------------- begin 3-1 part ---------------PATTERN B----------------------										
						if (PIN_IN_3 = '1') then -- use P121_pin for read pulse										
							PatternB_counter_for_31 <= -2;									
							PIN_OUT_3_1 <= '0'; -- xung dau ra se bang xung dau vao khi xung dau vao = 1;									
							PatternB_n1_counter_3 <= PatternB_n1 + 1;									
							out_3_pattern_B_avaiable <= enable;									
						elsif (PIN_IN_3 = '0' and out_3_pattern_B_avaiable = enable) then										
							PatternB_counter_for_31 <= PatternB_counter_for_31 + 1;									
						end if;										
						 										
						if (PatternB_counter_for_31 > -2 and PatternB_counter_for_31 < B1_time*50 and PIN_IN_3 = '0') then --B_time*50										
							PIN_OUT_3_1 <= '1'; -- Output LOW									
						elsif (PatternB_counter_for_31 = B1_time*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_1 <= '1'; -- Output LOW									
							PatternB_n1_counter_3 <= PatternB_n1_counter_3 - 1; -- first time to plus n1									
						elsif (PatternB_counter_for_31 > B1_time*50 and PatternB_counter_for_31 < (B1_time + C1_time)*50 and PIN_IN_3 = '0') then --(B_time + C_time)*50										
							PIN_OUT_3_1 <= '0';									
						elsif (PatternB_counter_for_31 = (B1_time + C1_time)*50 and PIN_IN_3 = '0') then 										
							PIN_OUT_3_1 <= '0';									
							PatternB_n1_counter_3 <= PatternB_n1_counter_3 - 1; -- second time to plus n1									
						elsif (PatternB_counter_for_31 > (B1_time + C1_time)*50 and PatternB_counter_for_31 <= (B1_time + C1_time + B2_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_1 <= '1';									
						elsif (PatternB_counter_for_31 > (B1_time + C1_time + B2_time)*50 and PatternB_counter_for_31 <= (B1_time + C1_time + B2_time + C1_time)*50 and PIN_IN_3 = '0') then -- and counter_for_41 < 19999999) then										
							PIN_OUT_3_1 <= '0';									
						elsif (PatternB_counter_for_31 > (B1_time + C1_time + B2_time + C1_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_1 <= '1';									
							PatternB_counter_for_31 <= (B1_time + C1_time)*50; 									
						end if;										
																
						if (PatternB_n1_counter_3 <= 0 or PIN_IN_4 = '1') then --      - 1) then -- n1 <= 3										
							PIN_OUT_3_1 <= '1';									
							PatternB_counter_for_31 <= -2;									
						end if;										
						------------------------- complete 3-1 part --------------PATTERN B----------------										
																
																
						------------------------- begin 3-2 part -----------------PATTERN B----------------------										
						if (PIN_IN_3 = '1') then -- pin 121										
							PatternB_n2_counter_3 <= PatternB_n2 + 1;									
							PIN_OUT_3_2 <= '1';									
							PatternB_counter_for_32 <= -2;									
						elsif (PIN_IN_3 = '0' and out_3_pattern_B_avaiable = enable) then										
							PatternB_counter_for_32 <= PatternB_counter_for_32 + 1;									
						end if;										
																
						if (PatternB_counter_for_32 > -2 and PatternB_counter_for_32 <= D1_time*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '1';									
						elsif (PatternB_counter_for_32 > D1_time*50 and PatternB_counter_for_32 <= (D1_time + E_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '0';									
						elsif (PatternB_counter_for_32 > (D1_time + E_time)*50 and PatternB_counter_for_32 < (B1_time + C1_time + D2_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '1';									
						elsif (PatternB_counter_for_32 = (B1_time + C1_time + D2_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '1';									
							PatternB_n2_counter_3 <= PatternB_n2_counter_3 - 1; -- first time to plus n1									
						elsif (PatternB_counter_for_32 > (B1_time + C1_time + D2_time)*50 and PatternB_counter_for_32 < (B1_time + C1_time + D2_time + C2_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '0';									
						elsif (PatternB_counter_for_32 = (B1_time + C1_time + D2_time + C2_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '0';									
							PatternB_n2_counter_3 <= PatternB_n2_counter_3 - 1; -- second time to plus n1									
						elsif (PatternB_counter_for_32 > (B1_time + C1_time + D2_time + C2_time)*50 and PatternB_counter_for_32 <= (B1_time + C1_time + B2_time + C1_time + D2_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '1';									
						elsif (PatternB_counter_for_32 > (B1_time + C1_time + B2_time + C1_time + D2_time)*50 and PatternB_counter_for_32 <= (B1_time + C1_time + B2_time + C1_time + D2_time + C2_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '0';									
						elsif (PatternB_counter_for_32 > (B1_time + C1_time + B2_time + C1_time + D2_time + C2_time)*50 and PIN_IN_3 = '0') then										
							PIN_OUT_3_2 <= '1';									
							PatternB_counter_for_32 <= (B1_time + C1_time + D2_time + C2_time)*50;									
						end if;										
																
						if (PatternB_n2_counter_3 <= 0 or PIN_IN_4 = '1') then -- when the n2 enough the pulse is LOW										
							PIN_OUT_3_2 <= '1';									
							PatternB_counter_for_32 <= 0 + 1;									
						end if;										
						------------------------- complete 3-2 part --------------PATTERN B-------------------------										
																
																
						------------------------- begin 4-1 part -----------------PATTERN B----------------------										
						if (PIN_IN_4 = '1') then -- use P124_pin for read pulse										
							PatternB_counter_for_41 <= -2;									
							PIN_OUT_4_1 <= '0'; -- xung dau ra se bang xung dau vao khi xung dau vao = 1;									
							PatternB_n1_counter_4 <= PatternB_n1 + 1;									
							out_4_pattern_B_avaiable <= enable;									
						elsif (PIN_IN_4 = '0' and out_4_pattern_B_avaiable = enable) then										
							PatternB_counter_for_41 <= PatternB_counter_for_41 + 1;									
						end if;										
																
						if (PatternB_counter_for_41 > -2 and PatternB_counter_for_41 < B1_time*50 and PIN_IN_4 = '0') then --B_time*50										
							PIN_OUT_4_1 <= '1'; -- Output LOW									
						elsif (PatternB_counter_for_41 = B1_time*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_1 <= '1'; -- Output LOW									
							PatternB_n1_counter_4 <= PatternB_n1_counter_4 - 1; -- first time to plus n1									
						elsif (PatternB_counter_for_41 > B1_time*50 and PatternB_counter_for_41 < (B1_time + C1_time)*50 and PIN_IN_4 = '0') then --(B_time + C_time)*50										
							PIN_OUT_4_1 <= '0';									
						elsif (PatternB_counter_for_41 = (B1_time + C1_time)*50 and PIN_IN_4 = '0') then 										
							PIN_OUT_4_1 <= '0';									
							PatternB_n1_counter_4 <= PatternB_n1_counter_4 - 1; -- second time to plus n1									
						elsif (PatternB_counter_for_41 > (B1_time + C1_time)*50 and PatternB_counter_for_41 <= (B1_time + C1_time + B2_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_1 <= '1';									
						elsif (PatternB_counter_for_41 > (B1_time + C1_time + B2_time)*50 and PatternB_counter_for_41 <= (B1_time + C1_time + B2_time + C1_time)*50 and PIN_IN_4 = '0') then -- and counter_for_41 < 19999999) then										
							PIN_OUT_4_1 <= '0';									
						elsif (PatternB_counter_for_41 > (B1_time + C1_time + B2_time + C1_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_1 <= '1';									
							PatternB_counter_for_41 <= (B1_time + C1_time)*50; 									
						end if;										
																
						if (PatternB_n1_counter_4 <= 0 or PIN_IN_1 = '1') then -- if you counter with 2 edge of both sides C1 you have to plus 1 unit for "PatternB_n1"										
							PIN_OUT_4_1 <= '1';									
							PatternB_counter_for_41 <= 0;									
						end if;										
						------------------------- complete 4-1 part -------------PATTERN B-----------------										
																
																
						-------------------------- begin 4-2 part ---------------PATTERN B----------------------										
						if (PIN_IN_4 = '1') then -- pin 124										
							PatternB_n2_counter_4 <= PatternB_n2 + 1;									
							PIN_OUT_4_2 <= '1';									
							PatternB_counter_for_42 <= -2;									
						elsif (PIN_IN_4 = '0' and out_4_pattern_B_avaiable = enable) then										
							PatternB_counter_for_42 <= PatternB_counter_for_42 + 1;									
						end if;										
																
						if (PatternB_counter_for_42 > 0 and PatternB_counter_for_42 <= D1_time*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '1';									
						elsif (PatternB_counter_for_42 > D1_time*50 and PatternB_counter_for_42 <= (D1_time + E_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '0';									
						elsif (PatternB_counter_for_42 > (D1_time + E_time)*50 and PatternB_counter_for_42 < (B1_time + C1_time + D2_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '1';									
						elsif (PatternB_counter_for_42 = (B1_time + C1_time + D2_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '1';									
							PatternB_n2_counter_4 <= PatternB_n2_counter_4 - 1; -- first time to plus n1									
						elsif (PatternB_counter_for_42 > (B1_time + C1_time + D2_time)*50 and PatternB_counter_for_42 < (B1_time + C1_time + D2_time + C2_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '0';									
						elsif (PatternB_counter_for_42 = (B1_time + C1_time + D2_time + C2_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '0';									
							PatternB_n2_counter_4 <= PatternB_n2_counter_4 - 1; -- second time to plus n1									
						elsif (PatternB_counter_for_42 > (B1_time + C1_time + D2_time + C2_time)*50 and PatternB_counter_for_42 <= (B1_time + C1_time + B2_time + C1_time + D2_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '1';									
						elsif (PatternB_counter_for_42 > (B1_time + C1_time + B2_time + C1_time + D2_time)*50 and PatternB_counter_for_42 <= (B1_time + C1_time + B2_time + C1_time + D2_time + C2_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '0';									
						elsif (PatternB_counter_for_42 > (B1_time + C1_time + B2_time + C1_time + D2_time + C2_time)*50 and PIN_IN_4 = '0') then										
							PIN_OUT_4_2 <= '1';									
							PatternB_counter_for_42 <= (B1_time + C1_time + D2_time + C2_time)*50;									
						end if;										
																
						if (PatternB_n2_counter_4 <= 0 or PIN_IN_1 = '1') then -- when the n2 enough the pulse is LOW  -- if you counter with 2 edge of both sides C1 you have to plus 1 unit for "PatternB_n1"										
							PIN_OUT_4_2 <= '1';									
							PatternB_counter_for_42 <= 0 + 1;									
						end if;										
--						------------------------- complete 4-2 part ------------PATTERN B---------------------------										
																
				end if; -- selected part 												
																
			end if; -- rising													
		end process;														
																
end Behavioral;																
