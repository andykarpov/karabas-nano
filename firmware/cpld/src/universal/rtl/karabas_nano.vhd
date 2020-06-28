-- --------------------------------------------------------------------
-- Karabas-nano universal firmware
-- v1.0
-- (c) 2020 Andy Karpov
-- --------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity karabas_nano is
	generic (
		-- global configuration
		ram_ext_std        : integer range 0 to 3 := 3; -- 0 - pentagon-512 via 6,7 bits of the #7FFD port (bit 5 is for 48k lock)
																      -- 1 - pentagon-1024 via 5,6,7 bits of the #7FFD port (no 48k lock)
																      -- 2 - profi-1024 via 0,1,2 bits of the #DFFD port
																      -- 3 - pentagon-128
		enable_port_ff 	    : boolean := true; -- enable video attribute read on port #FF
		enable_port_7ffd_read : boolean := false; -- enable port 7ffd read by CPU
		enable_divmmc 	       : boolean := true;  -- enable DivMMC
		enable_zcontroller    : boolean := false; -- enable Z-Controller
		enable_ay_uart 	    : boolean := true;  -- enable AY port A UART
		enable_bus_n_romcs    : boolean := true;  -- enable external BUS_N_ROMCS signal handling
		enable_bus_n_iorqge   : boolean := true   -- enable external BUS_N_IORQGE signal handling
	);
	port(
		-- Clock
		CLK28				: in std_logic;
		CLKX 				: in std_logic; -- unused

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
		N_NMI 			: out std_logic := 'Z';
		
		-- Unused CPU signals
		N_BUSREQ 		: in std_logic; -- unused
		N_BUSACK 		: in std_logic; -- unused
		N_WAIT 			: in std_logic; -- unused
		N_HALT			: in std_logic; -- unused
		N_RFSH			: in std_logic; -- unused
		
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
		BUS_N_IORQGE 	: in std_logic  := '0';
		BUS_N_ROMCS 	: in std_logic  := '0';
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
		CLK_AY			: out std_logic; -- not used by Atmega8
		AY_BC1			: out std_logic;
		AY_BDIR			: out std_logic;

		-- SD card
		SD_CLK 			: out std_logic := '0';
		SD_DI 			: out std_logic;
		SD_DO 			: in std_logic;
		SD_N_CS 			: out std_logic := '1';
		
		-- Keyboard
		KB					: in std_logic_vector(4 downto 0) := "11111"; -- KB(7 downto 5) reseved
		
		-- Other in signals
		TURBO				: in std_logic;  -- reserved
		MAGIC				: in std_logic;  -- reserved
		SPECIAL			: in std_logic;  -- reserved
		IO16 				: out std_logic; -- reserved  
		IO13 				: out std_logic; -- reserved
		IOE				: in std_logic;  -- reserved, input only
		
		MAPCOND 			: out std_logic; -- debug divMMC mapcond signal
		BTN_NMI			: in std_logic := '1'

	);
end karabas_nano;

architecture rtl of karabas_nano is

	signal clk_14 		: std_logic := '0';
	signal clk_7 		: std_logic := '0';
	signal clkcpu 		: std_logic := '1';

	signal attr_r   	: std_logic_vector(7 downto 0);
	signal rgb 	 		: std_logic_vector(2 downto 0);
	signal i 			: std_logic;
	signal vid_a 		: std_logic_vector(13 downto 0);
	signal hcnt0 		: std_logic;
	signal hcnt1 		: std_logic;
	
	signal border_attr: std_logic_vector(2 downto 0) := "000";

	signal port_7ffd	: std_logic_vector(7 downto 0); -- D0-D2 - RAM page from address #C000
																	  -- D3 - video RAM page: 0 - bank5, 1 - bank7 
																	  -- D4 - ROM page A14: 0 - basic 128, 1 - basic48
																	  -- D5 - 48k RAM lock, 1 - locked, 0 - extended memory enabled
																	  -- D6 - not used
																	  -- D7 - not used
																	  
	signal ram_ext : std_logic_vector(2 downto 0) := "000";
	signal ram_do : std_logic_vector(7 downto 0);
	signal ram_oe_n : std_logic := '1';
	
	signal fd_port : std_logic := '1';
	signal fd_sel : std_logic;	
																	  
	signal ay_port		: std_logic := '0';
	signal bdir 		: std_logic;
	signal bc1 			: std_logic;
		
	signal vbus_mode  : std_logic := '0';
	signal vid_rd		: std_logic := '0';
	
	signal hsync     	: std_logic := '1';
	signal vsync     	: std_logic := '1';

	signal sound_out 	: std_logic := '0';
	signal mic 			: std_logic := '0';
	
	signal port_read	: std_logic := '0';
	signal port_write	: std_logic := '0';
	
	signal divmmc_do	: std_logic_vector(7 downto 0);
	
	signal divmmc_ram : std_logic;
	signal divmmc_rom : std_logic;
	
	signal divmmc_disable_zxrom : std_logic;
	signal divmmc_eeprom_cs_n : std_logic;
	signal divmmc_eeprom_we_n : std_logic;
	signal divmmc_sram_cs_n : std_logic;
	signal divmmc_sram_we_n : std_logic;
	signal divmmc_sram_hiaddr : std_logic_vector(5 downto 0);
	signal divmmc_sd_cs_n : std_logic;
	signal divmmc_wr : std_logic;
	signal divmmc_sd_di: std_logic;
	signal divmmc_sd_clk: std_logic;
	
	signal zc_do_bus	: std_logic_vector(7 downto 0);
	signal zc_wr 		: std_logic :='0';
	signal zc_rd		: std_logic :='0';
	signal zc_sd_cs_n: std_logic;
	signal zc_sd_di: std_logic;
	signal zc_sd_clk: std_logic;
	
	signal trdos	: std_logic :='0';
	
begin

	divmmc_rom <= '1' when (divmmc_disable_zxrom = '1' and divmmc_eeprom_cs_n = '0') else '0';
	divmmc_ram <= '1' when (divmmc_disable_zxrom = '1' and divmmc_sram_cs_n = '0') else '0';
	
	BEEPER <= sound_out;

	ay_port <= '1' when A(7 downto 0) = x"FD" and A(15)='1' and fd_port = '1' and ((enable_bus_n_iorqge and BUS_N_IORQGE = '0') or not(enable_bus_n_iorqge)) else '0';
	bdir <= '1' when ay_port = '1' and N_IORQ = '0' and N_WR = '0' else '0';
	bc1 <= '1' when ay_port = '1' and A(14) = '1' and N_IORQ = '0' and (N_WR='0' or N_RD='0') else '0';
	AY_BC1 <= bc1;
	AY_BDIR <= bdir; 	
	
	--N_NMI <= '0' when BTN_NMI = '0' or MAGIC = '1' else 'Z';
	N_NMI <= '0' when BTN_NMI = '0' else 'Z';
	
	MAPCOND <= divmmc_disable_zxrom;
	
	 -- #FD port correction
	 G_FD_PORT: if ram_ext_std < 3 generate
		 fd_sel <= '0' when vbus_mode='0' and D(7 downto 4) = "1101" and D(2 downto 0) = "011" else '1'; -- IN, OUT Z80 Command Latch

		 process(fd_sel, N_M1, N_RESET)
		 begin
				if N_RESET='0' then
					  fd_port <= '1';
				elsif rising_edge(N_M1) then 
					  fd_port <= fd_sel;
				end if;
		 end process;
	end generate G_FD_PORT;

	-- CPU clock 
	process( N_RESET, clk_14, clk_7, hcnt0 )
	begin
		if clk_14'event and clk_14 = '1' then
			if clk_7 = '1' then
				clkcpu <= hcnt0;
			end if;
		end if;
	end process;
	
	CLK_CPU <= clkcpu;
	CLK_BUS <= not(clkcpu);
	CLK_AY	<= hcnt1;
	
	TAPE_OUT <= mic;
	
	port_write <= '1' when N_IORQ = '0' and N_WR = '0' and N_M1 = '1' else '0'; -- and vbus_mode = '0' else '0';
	port_read <= '1' when N_IORQ = '0' and N_RD = '0' and N_M1 = '1' and ((enable_bus_n_iorqge and BUS_N_IORQGE = '0') or not(enable_bus_n_iorqge)) else '0';
	
	-- read ports by CPU
	D(7 downto 0) <= 
		ram_do when ram_oe_n = '0' else -- #memory
		'1' & TAPE_IN & '1' & kb(4 downto 0) when port_read = '1' and A(0) = '0' else -- #FE - keyboard 
		divmmc_do when enable_divmmc and divmmc_wr = '1' else -- divmmc
		zc_do_bus when enable_zcontroller and port_read = '1' and A(7 downto 6) = "01" and A(4 downto 0) = "10111" else -- ZC
		port_7ffd when enable_port_7ffd_read and port_read = '1' and A = x"7FFD" else -- #7FFD
		attr_r when enable_port_ff and port_read = '1' and A(7 downto 0) = x"FF" else -- #FF
		"ZZZZZZZZ";
		
	-- z-controller 
	G_ZC_SIG: if enable_zcontroller generate
		zc_wr <= '1' when (N_IORQ = '0' and N_WR = '0' and A(7 downto 6) = "01" and A(4 downto 0) = "10111") else '0';
		zc_rd <= '1' when (N_IORQ = '0' and N_RD = '0' and A(7 downto 6) = "01" and A(4 downto 0) = "10111") else '0';
	end generate G_ZC_SIG;
	
	-- clocks
	process (CLK28)
	begin 
		if (CLK28'event and CLK28 = '1') then 
			clk_14 <= not(clk_14);
		end if;
	end process;
	
	process (clk_14)
	begin 
		if (clk_14'event and clk_14 = '1') then 
			clk_7 <= not(clk_7);
		end if;
	end process;
	
	-- ports, write by CPU
	process( clk_14, clk_7, N_RESET, A, D, port_write, port_7ffd, N_M1, N_MREQ )
	begin
		if N_RESET = '0' then
			port_7ffd <= "00000000";
			ram_ext <= "000";
			sound_out <= '0';
		elsif clk_14'event and clk_14 = '1' then 
			--if clk_7 = '1' then
				if port_write = '1' then

					 -- port #7FFD  
					if A(15)='0' and A(1) = '0' then -- short decoding #FD
						if ram_ext_std = 0 and port_7ffd(5) = '0' then -- penragon-512
							port_7ffd <= D;
							ram_ext <= '0' & D(6) & D(7); 
						elsif ram_ext_std = 1 then -- pentagon-1024
							port_7ffd <= D;
							ram_ext <= D(5) & D(6) & D(7);
						elsif ram_ext_std = 2 and port_7ffd(5) = '0' then -- profi 1024
							port_7ffd <= D;
						elsif ram_ext_std = 3 and port_7ffd(5) = '0' then -- pentagon-128
							port_7ffd <= D;
							ram_ext <= "000";
						end if;
					end if;

					-- port #DFFD (profi ram ext)
					if ram_ext_std = 2 and A = X"DFFD" and port_7ffd(5) = '0' and fd_port='1' then
							ram_ext <= D(2 downto 0);
					end if;
					
					-- port #FE
					if A(0) = '0' then
						border_attr <= D(2 downto 0); -- border attr
						mic <= D(3); -- MIC
						sound_out <= D(4); -- BEEPER
					end if;
										
				end if;
								
			--end if;
		end if;
	end process;	
	
	-- trdos flag
	G_TRDOS_FLAG: if enable_zcontroller generate	
		process(clk_14, N_RESET, N_M1, N_MREQ)
		begin 
			if N_RESET = '0' then 
				trdos <= '1'; -- 1 - boot into service rom, 0 - boot into 128 menu
			elsif clk_14'event and clk_14 = '1' then 
				if N_M1 = '0' and N_MREQ = '0' and A(15 downto 8) = X"3D" and port_7ffd(4) = '1' then 
					trdos <= '1';
				elsif N_M1 = '0' and N_MREQ = '0' and A(15 downto 14) /= "00" then 
					trdos <= '0'; 
				end if;
			end if;
		end process;
	end generate G_TRDOS_FLAG;

	-- memory manager
	U1: entity work.memory 
	generic map (
		enable_divmmc => enable_divmmc,
		enable_zcontroller => enable_zcontroller,
		enable_bus_n_romcs => enable_bus_n_romcs,
		ram_ext_std => ram_ext_std
	)
	port map ( 
		CLK14 => CLK_14,
		CLK7  => CLK_7,
		HCNT0 => hcnt0,		
		BUS_N_ROMCS => BUS_N_ROMCS,
		
		-- cpu signals
		A => A,
		D => D,
		N_MREQ => N_MREQ,
		N_IORQ => N_IORQ,
		N_WR => N_WR,
		N_RD => N_RD,
		N_M1 => N_M1,

		-- ram 
		MA => MA,
		MD => MD,
		N_MRD => N_MRD,
		N_MWR => N_MWR,
		
		-- ram out to cpu
		DO => ram_do,
		N_OE => ram_oe_n,
		
		-- ram pages
		RAM_BANK => port_7ffd(2 downto 0),
		RAM_EXT => ram_ext,

		-- divmmc
		DIVMMC_A => divmmc_sram_hiaddr,
		IS_DIVMMC_RAM => divmmc_ram,
		IS_DIVMMC_ROM => divmmc_rom,

		-- video
		VA => vid_a,
		VID_PAGE => port_7ffd(3),

		-- video bus control signals
		VBUS_MODE_O => vbus_mode, -- video bus mode: 0 - ram, 1 - vram
		VID_RD_O => vid_rd, -- read bitmap or attribute from video memory
		
		-- TRDOS 
		TRDOS => trdos,
		
		-- rom
		ROM_BANK => port_7ffd(4),
		ROM_A14 => ROM_A14,
		ROM_A15 => ROM_A15,
		N_ROMCS => N_ROMCS		
	);
	
	-- divmmc interface
	G_DIVMMC: if enable_divmmc generate
		U2: entity work.divmmc
		port map (
			I_CLK		=> clkcpu,
			I_CS		=> '1',
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
			O_SCLK		=> divmmc_sd_clk,
			O_MOSI		=> divmmc_sd_di,
			I_MISO		=> SD_DO);

		SD_N_CS <= divmmc_sd_cs_n;
		SD_CLK <= divmmc_sd_clk;
		SD_DI <= divmmc_sd_di;
	end generate G_DIVMMC;
		
	-- Z-Controller
	G_ZC: if enable_zcontroller generate
		U3: entity work.zcontroller 
		port map(
			RESET => not(N_RESET),
			CLK => clk_7,
			A => A(5),
			DI => D,
			DO => zc_do_bus,
			RD => zc_rd,
			WR => zc_wr,
			SDDET => '0',
			SDPROT => '0',
			CS_n => zc_sd_cs_n,
			SCLK => zc_sd_clk,
			MOSI => zc_sd_di,
			MISO => SD_DO
		);
		
		SD_N_CS <= zc_sd_cs_n;
		SD_CLK <= zc_sd_clk;
		SD_DI <= zc_sd_di;
	end generate G_ZC;
	
	-- video module
	U5: entity work.video 
	port map (
		CLK => CLK_14,
		ENA7 => CLK_7,
		BORDER => border_attr,
		DI => MD,
		INTA => N_IORQ or N_M1,
		INT => N_INT,
		ATTR_O => attr_r, 
		A => vid_a,
		BLANK => open,
		RGB => rgb,
		I => i,
		HSYNC => hsync,
		VSYNC => vsync,
		VBUS_MODE => vbus_mode,
		VID_RD => vid_rd,
		HCNT0 => hcnt0,
		HCNT1 => hcnt1
	);
	
	-- RGBS output
	process(clk_14, clk_7, rgb, i)
	begin
		if clk_14'event and clk_14 = '1' then
			if (clk_7 = '1') then
				if (i = '1' and rgb = "000") then 
					VIDEO_R <= "ZZZ";
					VIDEO_G <= "ZZZ";
					VIDEO_B <= "ZZZ";
				else
					if (i = '1') then
						VIDEO_R <= rgb(2) & rgb(2) & '1';
						VIDEO_G <= rgb(1) & rgb(1) & '1';
						VIDEO_B <= rgb(0) & rgb(0) & '1';
					else 
						VIDEO_R <= rgb(2) & "ZZ";
						VIDEO_G <= rgb(1) & "ZZ";
						VIDEO_B <= rgb(0) & "ZZ";
					end if;
				end if;
				VIDEO_CSYNC <= not (vsync xor hsync);		
			end if;
		end if;
	end process;
	
	-- UART (via AY port A) 	
	G_AY_UART: if enable_ay_uart generate
		U16: entity work.ay_uart 
		port map(
			CLK_I => CLK_14,
			RESET_I => not(N_RESET),
			EN_I => hcnt1,
			BDIR_I => bdir,
			BC_I => bc1,			
			CS_I => ay_port,
			DATA_I => D,
			DATA_O => D,
			UART_TX => IO13,
			UART_RX => IOE,
			UART_RTS => IO16
		);
	end generate G_AY_UART;
	
end;
