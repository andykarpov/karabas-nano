-- --------------------------------------------------------------------
-- Karabas-Nano rev.B DivMMC firmware
-- v1.0
-- (c) 2019 Andy Karpov
-- --------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity karabas_nano is
	port(
		-- Clock
		CLK28				: in std_logic;
		CLKX 				: in std_logic;

		-- CPU signals
		CLK_CPU			: out std_logic := '1';
		N_RESET			: in std_logic;
		N_INT				: out std_logic := '1';
		N_RD				: in std_logic;
		N_WR				: in std_logic;
		N_IORQ			: in std_logic;
		N_MREQ			: in std_logic;
		N_M1				: in std_logic;
		A					: in std_logic_vector(15 downto 0);
		D 					: inout std_logic_vector(7 downto 0) := "ZZZZZZZZ";
		
		-- Unused CPU signals
		N_BUSREQ 		: in std_logic;
		N_BUSACK 		: in std_logic;
		N_WAIT 			: in std_logic;
		N_HALT			: in std_logic;
		N_NMI 			: in std_logic;
		N_RFSH			: in std_logic;		

		-- RAM 
		MA 				: out std_logic_vector(20 downto 0);
		MD 				: inout std_logic_vector(7 downto 0) := "ZZZZZZZZ";
		N_MRD				: out std_logic := '1';
		N_MWR				: out std_logic := '1';

		-- ROM
		N_ROMCS			: out std_logic := '1';
		ROM_A14 			: out std_logic := '0';
		ROM_A15 			: out std_logic := '0';
		
		-- ZX BUS signals
--		BUS_N_IORQGE 	: in std_logic := '0';
--		BUS_N_ROMCS 	: in std_logic := '0';
		CLK_BUS 			: out std_logic := '1';

		-- Video
		VIDEO_CSYNC    : out std_logic;
		VIDEO_R       	: out std_logic_vector(2 downto 0) := "000";
		VIDEO_G       	: out std_logic_vector(2 downto 0) := "000";
		VIDEO_B       	: out std_logic_vector(2 downto 0) := "000";

		-- Interfaces 
		TAPE_IN 			: in std_logic;
		TAPE_OUT			: out std_logic := '1';
		BEEPER			: out std_logic := '1';

		-- AY
		CLK_AY			: out std_logic;
		AY_BC1			: out std_logic;
		AY_BDIR			: out std_logic;

		-- SD card
		SD_CLK 			: out std_logic := '0';
		SD_DI 			: out std_logic;
		SD_DO 			: in std_logic;
		SD_N_CS 			: out std_logic := '1';
		
		-- Keyboard
		KB					: in std_logic_vector(4 downto 0) := "11111";
		-- TODO: extra signals KB 7 downto 5
		
		-- Other in signals
		TURBO				: in std_logic := '0';
		MAGIC				: in std_logic := '0';
		SPECIAL			: in std_logic := '0';
		IO16 				: inout std_logic := 'Z';
		IO13 				: inout std_logic := 'Z';
		IO10 				: inout std_logic := 'Z'
	);
end karabas_nano;

architecture rtl of karabas_nano is

	signal clk_14 		: std_logic := '0';
	signal clk_7 		: std_logic := '0';
	signal clk_3_5 	: std_logic := '0';
	signal clk_1_75	: std_logic := '0';
	signal clk 			: std_logic := '0'; -- cpu clk

	signal buf_md		: std_logic_vector(7 downto 0) := "11111111";
	signal is_buf_wr	: std_logic := '0';	
	
	signal invert   	: unsigned(4 downto 0) := "00000";

	signal chr_col_cnt: unsigned(2 downto 0) := "000"; -- Character column counter
	signal chr_row_cnt: unsigned(2 downto 0) := "000"; -- Character row counter

	signal hor_cnt  	: unsigned(5 downto 0) := "000000"; -- Horizontal counter
	signal ver_cnt  	: unsigned(5 downto 0) := "000000"; -- Vertical counter

	signal attr     	: std_logic_vector(7 downto 0);
	signal shift    	: std_logic_vector(7 downto 0);
	
	signal paper_r  	: std_logic;
	signal blank_r  	: std_logic;
	signal attr_r   	: std_logic_vector(7 downto 0);
	signal shift_r  	: std_logic_vector(7 downto 0);
	signal rgbi 	 	: std_logic_vector(3 downto 0);

	signal border_attr: std_logic_vector(2 downto 0) := "000";

	signal port_7ffd	: std_logic_vector(7 downto 0); -- D0-D2 - RAM page from address #C000
																	  -- D3 - video RAM page: 0 - bank5, 1 - bank7 
																	  -- D4 - ROM page A14: 0 - basic 128, 1 - basic48
																	  -- D5 - 48k RAM lock, 1 - locked, 0 - extended memory enabled
																	  -- D6 - not used
																	  -- D7 - not used
	
	signal ay_port		: std_logic := '0';
		
	signal vbus_req	: std_logic := '1';
	signal vbus_ack	: std_logic := '1';
	signal vbus_mode	: std_logic := '1';	
	signal vbus_rdy	: std_logic := '1';
	
	signal vid_rd		: std_logic := '0';
	
	signal paper     	: std_logic;

	signal hsync     	: std_logic := '1';
	signal vsync     	: std_logic := '1';

	signal vram_acc	: std_logic;
	
	signal n_is_ram   : std_logic := '1';
	signal ram_page	: std_logic_vector(5 downto 0) := "000000";

	signal n_is_rom   : std_logic := '1';
	signal rom_page	: std_logic_vector(1 downto 0) := "00";
	
	signal sound_out 	: std_logic := '0';
	signal ear 			: std_logic := '1';
	signal mic 			: std_logic := '0';
	signal port_read	: std_logic := '0';
	signal port_write	: std_logic := '0';
	
	signal divmmc_enable : std_logic := '0';
	signal divmmc_do	: std_logic_vector(7 downto 0);
	
	signal divmmc_ram : std_logic;
	signal divmmc_rom : std_logic;
	
	signal divmmc_disable_zxrom : std_logic;
	signal divmmc_eeprom_cs_n : std_logic;
	signal divmmc_eeprom_we_n : std_logic;
	signal divmmc_sram_cs_n : std_logic;
	signal divmmc_sram_we_n : std_logic;
	signal divmmc_sram_hiaddr : std_logic_vector(3 downto 0);
	signal divmmc_sd_cs_n : std_logic;
	signal divmmc_wr : std_logic;

begin

	divmmc_rom <= '1' when (divmmc_disable_zxrom = '1' and divmmc_eeprom_cs_n = '0') else '0';
	divmmc_ram <= '1' when (divmmc_disable_zxrom = '1' and divmmc_sram_cs_n = '0') else '0';
	
	n_is_rom <= '0' when N_MREQ = '0' and ((A(15 downto 14)  = "00" and divmmc_rom = '0' and divmmc_ram = '0') or divmmc_rom = '1') else '1';
	n_is_ram <= '0' when N_MREQ = '0' and ((A(15 downto 14) /= "00" and divmmc_rom = '0' and divmmc_ram = '0') or divmmc_ram = '1') else '1';

	-- speccy ROM banks map (A14, A15):
	-- 00 - bank 0, ESXDOS 0.8.7
	-- 01 - bank 1, empty
	-- 10 - bank 2, Basic-128
	-- 11 - bank 3, Basic-48
	rom_page <= "00" when divmmc_rom = '1' else '1' & (port_7ffd(4));
	ROM_A14 <= rom_page(0);
	ROM_A15 <= rom_page(1);	
	
	N_ROMCS <= '0' when n_is_rom = '0' and N_RD = '0' else '1';

	ram_page <=	
				"100" & divmmc_sram_hiaddr(3 downto 1) when divmmc_ram = '1' else
				"000000" when A(15) = '0' and A(14) = '0' else
				"000101" when A(15) = '0' and A(14) = '1' else
				"000010" when A(15) = '1' and A(14) = '0' else
				"000" & port_7ffd(2 downto 0); -- 128kb ext ram

	MA(13 downto 0) <= 
		divmmc_sram_hiaddr(0) & A(12 downto 0) when vbus_mode = '0' and divmmc_ram = '1' else
		A(13 downto 0) when vbus_mode = '0' else 
		std_logic_vector( "0" & ver_cnt(4 downto 3) & chr_row_cnt & ver_cnt(2 downto 0) & hor_cnt(4 downto 0) ) when vid_rd = '0' else
		std_logic_vector( "0110" & ver_cnt(4 downto 0) & hor_cnt(4 downto 0) );
	MA(14) <= ram_page(0) when vbus_mode = '0' else '1';
	MA(15) <= ram_page(1) when vbus_mode = '0' else port_7ffd(3);
	MA(16) <= ram_page(2) when vbus_mode = '0' else '1';
	MA(17) <= ram_page(3) when vbus_mode = '0' else '0';
	MA(18) <= ram_page(4) when vbus_mode = '0' else '0';
	MA(19) <= ram_page(5) when vbus_mode = '0' else '0';
	MA(20) <= '0';
	
	MD(7 downto 0) <= 
		D(7 downto 0) when vbus_mode = '0' and ((n_is_ram = '0' or (N_IORQ = '0' and N_M1 = '1')) and N_WR = '0') else 
		(others => 'Z');

	vbus_req <= '0' when ( N_MREQ = '0' or N_IORQ = '0' ) and ( N_WR = '0' or N_RD = '0' ) else '1';
	vbus_rdy <= '0' when clk_7 = '0' or chr_col_cnt(0) = '0' else '1';
	
	N_MRD <= '0' when (vbus_mode = '1' and vbus_rdy = '0') or (vbus_mode = '0' and N_RD = '0' and N_MREQ = '0') else '1';  
	N_MWR <= '0' when vbus_mode = '0' and n_is_ram = '0' and N_WR = '0' and chr_col_cnt(0) = '0' else '1';

	paper <= '0' when hor_cnt(5) = '0' and ver_cnt(5) = '0' and ( ver_cnt(4) = '0' or ver_cnt(3) = '0' ) else '1';      

	VIDEO_R <= rgbi(3) & rgbi(0) & 'Z';
	VIDEO_G <= rgbi(2) & rgbi(0) & 'Z';
	VIDEO_B <= rgbi(1) & rgbi(0) & 'Z';
	VIDEO_CSYNC <= not (vsync xor hsync);
	
	BEEPER <= sound_out;
	TAPE_OUT <= mic;
	ear <= TAPE_IN;

	CLK_AY	<= clk_1_75;
	ay_port <= '1' when A(15)='1' and A(1) = '0' and N_IORQ = '0' and N_M1 = '1' else '0'; -- and BUS_N_IORQGE = '0' else '0';
	AY_BC1 <= '1' when A(14) = '1' and ay_port = '1' else '0';
	AY_BDIR <= '1' when N_WR = '0' and ay_port = '1' else '0';

	-- TODO: turbo for internal bus / video memory
	is_buf_wr <= '1' when vbus_mode = '0' and chr_col_cnt(0) = '0' else '0';
	
	-- todo
	process( N_RESET, clk_14, clk_7 )
	begin
		if N_RESET = '0' then 
			clk <= '0';
		elsif clk_14'event and clk_14 = '1' then
			if clk_7 = '1' then
				clk <= chr_col_cnt(0);
			end if;
		end if;
	end process;

	CLK_CPU <= clk;
	CLK_BUS <= not(clk);
	
	port_write <= '1' when N_IORQ = '0' and N_WR = '0' and N_M1 = '1' and vbus_mode = '0' else '0';
	port_read <= '1' when N_IORQ = '0' and N_RD = '0' and N_M1 = '1' else '0'; -- and BUS_N_IORQGE = '0' else '0';
	
	-- read ports by CPU
	D(7 downto 0) <= 
		buf_md(7 downto 0) when n_is_ram = '0' and N_RD = '0' else -- MD buf	
		'1' & ear & '1' & KB(4 downto 0) when port_read = '1' and A(0) = '0' else -- #FE
		port_7ffd when port_read = '1' and A = X"7FFD" else -- #7FFD
		divmmc_do when divmmc_wr = '1' else -- divMMC
		attr_r when port_read = '1' and A(7 downto 0) = "11111111" else -- #FF
		"ZZZZZZZZ";

	divmmc_enable <= '1';
	
	-- clocks
	process (CLK28, clk_14)
	begin 
		if (CLK28'event and CLK28 = '1') then 
			clk_14 <= not(clk_14);
		end if;
	end process;
	
	process (clk_14, clk_7)
	begin 
		if (clk_14'event and clk_14 = '1') then 
			clk_7 <= not(clk_7);
		end if;
	end process;
	
	process (clk_7, clk_3_5)
	begin 
		if (clk_7'event and clk_7 = '1') then 
			clk_3_5 <= not(clk_3_5);
		end if;
	end process;

	process (clk_3_5, clk_1_75)
	begin 
		if (clk_3_5'event and clk_3_5 = '1') then 
			clk_1_75 <= not(clk_1_75);
		end if;
	end process;
	
	-- fill memory buf
	process(is_buf_wr, MD)
	begin 
		if (is_buf_wr'event and is_buf_wr = '0') then  -- high to low transition to lattch the MD into BUF
			buf_md(7 downto 0) <= MD(7 downto 0);
		end if;
	end process;	
	
	-- sync, counters
	process( clk_14, clk_7, chr_col_cnt, hor_cnt, chr_row_cnt, ver_cnt)
	begin
		if clk_14'event and clk_14 = '1' then
		
			if clk_7 = '1' then
			
				if chr_col_cnt = 7 then
				
					if hor_cnt = 55 then
						hor_cnt <= (others => '0');
					else
						hor_cnt <= hor_cnt + 1;
					end if;
					
					if hor_cnt = 39 then
						if chr_row_cnt = 7 then
							if ver_cnt = 39 then
								ver_cnt <= (others => '0');
								invert <= invert + 1;
							else
								ver_cnt <= ver_cnt + 1;
							end if;
						end if;
						chr_row_cnt <= chr_row_cnt + 1;
					end if;
				end if;

				-- h/v sync

				if chr_col_cnt = 7 then

					if (hor_cnt(5 downto 2) = "1010") then 
						hsync <= '0';
					else 
						hsync <= '1';
					end if;
					
					if ver_cnt /= 31 then
						vsync <= '1';
					elsif chr_row_cnt = 3 or chr_row_cnt = 4 or ( chr_row_cnt = 5 and ( hor_cnt >= 40 or hor_cnt < 12 ) ) then
						vsync <= '0';
					else 
						vsync <= '1';
					end if;
					
				end if;
			
				-- int
				if chr_col_cnt = 6 and hor_cnt(2 downto 0) = "111" then
					if ver_cnt = 29 and chr_row_cnt = 7 and hor_cnt(5 downto 3) = "100" then
						N_INT <= '0';
					else
						N_INT <= '1';
					end if;
				end if;

				chr_col_cnt <= chr_col_cnt + 1;
			end if;
		end if;
	end process;

	-- video mem
	process( clk_14, clk_7, chr_col_cnt, vbus_mode, vid_rd, vbus_req, vbus_ack )
	begin
		-- lower edge of 7 mhz clock
		if clk_14'event and clk_14 = '1' then 
			if chr_col_cnt(0) = '1' and clk_7 = '0' then
			
				if vbus_mode = '1' then
					if vid_rd = '0' then
						shift <= MD;
					else
						attr  <= MD;
					end if;
				end if;
				
				if vbus_req = '0' and vbus_ack = '1' then
					vbus_mode <= '0';
				else
					vbus_mode <= '1';
					vid_rd <= not vid_rd;
				end if;	
				vbus_ack <= vbus_req;
			end if;
		end if;
	end process;

	-- r/g/b
	process( clk_14, clk_7, paper_r, shift_r, attr_r, invert, blank_r )
	begin
		if clk_14'event and clk_14 = '1' then
			if (clk_7  = '1') then
				if paper_r = '0' then           
					if( shift_r(7) xor ( attr_r(7) and invert(4) ) ) = '1' then
						rgbi(3) <= attr_r(1);
						rgbi(2) <= attr_r(2);
						rgbi(1) <= attr_r(0);
					else
						rgbi(3) <= attr_r(4);
						rgbi(2) <= attr_r(5);
						rgbi(1) <= attr_r(3);
					end if;
				else
					if blank_r = '0' then
						rgbi(3 downto 1) <= "ZZZ";
					else
						rgbi(3) <= border_attr(1);
						rgbi(2) <= border_attr(2);
						rgbi(1) <= border_attr(0);
					end if;
				end if;
			end if;
		end if;
	end process;

	-- brightness
	process( clk_14, clk_7, paper_r, attr_r, rgbi(3 downto 1) )
	begin
		if clk_14'event and clk_14 = '1' then
			if (clk_7 = '1') then
				if paper_r = '0' and attr_r(6) = '1' and rgbi(3 downto 1) /= "000" then
					rgbi(0) <= '1';
				else
					rgbi(0) <= '0';
				end if;
			end if;
		end if;
	end process;

	-- paper, blank
	process( clk_14, clk_7, chr_col_cnt, hor_cnt, ver_cnt )
	begin
		if clk_14'event and clk_14 = '1' then
			if (clk_7 = '1') then
				if chr_col_cnt = 7 then
					attr_r <= attr;
					shift_r <= shift;

					if ((hor_cnt(5 downto 0) > 38 and hor_cnt(5 downto 0) < 48) or ver_cnt(5 downto 1) = 15) then
						blank_r <= '0';
					else 
						blank_r <= '1';
					end if;
					
					paper_r <= paper;
				else
					shift_r(7 downto 1) <= shift_r(6 downto 0);
					shift_r(0) <= '0';
				end if;
			end if;
		end if;
	end process;

	-- ports, write by CPU
	process( clk_14, clk_7, N_RESET, A, D, port_write, port_7ffd, N_M1, N_MREQ )
	begin
		if N_RESET = '0' then
			port_7ffd <= "00000000";
			sound_out <= '0';
			mic <= '0';
		elsif clk_14'event and clk_14 = '1' then 
			if clk_7 = '1' then
				if port_write = '1' then

					 -- port #7FFD  
					if A = X"7FFD" and port_7ffd(5) = '0' then 
						port_7ffd <= D;
					elsif A(15)='0' and A(1) = '0' and port_7ffd(5) = '0' then
						port_7ffd <= D;
					end if;
					 
					-- port #FE
					if A(0) = '0' then
						border_attr <= D(2 downto 0); -- border attr
						mic <= D(3); -- MIC
						sound_out <= D(4); -- BEEPER
					end if;
				end if;
				
			end if;
		end if;
	end process;	

	-- divmmc interface
	U1: entity work.divmmc
	port map (
		I_CLK		=> clk,
		I_SCLK 	=> clk,
		I_CS		=> divmmc_enable,
		I_RESET		=> not(N_RESET),
		I_ADDR		=> A,
		I_DATA		=> D,
		O_DATA		=> divmmc_do,
		I_WR_N		=> N_WR,
		I_RD_N		=> N_RD,
		I_IORQ_N		=> N_IORQ,
		I_MREQ_N		=> N_MREQ,
		I_M1_N		=> N_M1,
		
		O_WR 				 => divmmc_wr,
		O_DISABLE_ZXROM => divmmc_disable_zxrom,
		O_EEPROM_CS_N 	 => divmmc_eeprom_cs_n,
		O_EEPROM_WE_N 	 => divmmc_eeprom_we_n,
		O_SRAM_CS_N 	 => divmmc_sram_cs_n,
		O_SRAM_WE_N 	 => divmmc_sram_we_n,
		O_SRAM_HIADDR	 => divmmc_sram_hiaddr,
		
		O_CS_N		=> divmmc_sd_cs_n,
		O_SCLK		=> SD_CLK,
		O_MOSI		=> SD_DI,
		I_MISO		=> SD_DO);
		
	SD_N_CS <= divmmc_sd_cs_n;
	
end;