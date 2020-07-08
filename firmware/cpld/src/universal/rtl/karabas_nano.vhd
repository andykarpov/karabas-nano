-- --------------------------------------------------------------------
-- Karabas-nano test firmware for profi video mode
-- v1.0
-- (c) 2020 Andy Karpov
-- --------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity karabas_nano is
	generic (
		enable_ay_uart 	 : boolean := true; -- enable AY port A UART
		enable_turbo 		 : boolean := false; -- enable Turbo mode 7MHz
		enable_bus_n_romcs : boolean := true; -- enable external BUS_N_ROMCS signal handling
		enable_bus_n_iorqge: boolean := true  -- enable external BUS_N_IORQGE signal handling
	);
	port(
		-- Clock
		CLK28				: in std_logic;
		CLK24 			: in std_logic;

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
		KB					: inout std_logic_vector(7 downto 0) := "00111111"; -- KB(7 downto 6) reseved
		
		-- Other in signals
		TURBO				: in std_logic;
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

	signal CLK 			: std_logic := '0';
	
	signal clk_div2 	: std_logic := '0';
	signal clk_div4 	: std_logic := '0';
	signal clk_div8 	: std_logic := '0';
	signal clk_div16	: std_logic := '0';
	
	signal clkcpu 		: std_logic := '1';	

	signal attr_r   	: std_logic_vector(7 downto 0);
	signal vid_a 		: std_logic_vector(13 downto 0);
	
	signal border_attr: std_logic_vector(2 downto 0) := "000";

	signal port_7ffd	: std_logic_vector(7 downto 0) := (others => '0'); 
	-- CMR0 port:
	-- D0-D2 - RAM seg A0,A1,A2 (column access)
	-- D3 - POLEK. Video page.
						-- 80DS=0: 0 - seg 05, 1 - seg 07 
						-- 80DS=1: 0 - pixels seg 04, attributes seg 38
						--         1 - pixels seg 06, attributes seg 3A
	-- D4 - ROM14. 
						-- CPM=0: 0 - spectrum 128, 1 - spectrum 48
						-- CPM=1: Ext device modifier for CP/M mode
	-- D5 - BLOCK. Block port CMR0 (WOROM=0)
	-- D6,D7 - unused
																	  
	signal port_dffd : std_logic_vector(7 downto 0) := (others => '0');
	-- CMR1 port:
	-- D0-D2 - RAM seg A3,A4,A5 (row access)
	-- D3 - SCO. Window position for segments:
						-- 0 - window 1 (#C000 - #FFFF)
						-- 1 - window 2 (#4000 - #7FFF)
	-- D4 - WOROM. 1 = disable CMR0 port lock, also disable ROM and switch RAM seg 00 instead of it
	-- D5 - CPM. 1  = block controller from TR-DOS ROM and enables ports to access from RAM (ROM14=0)
						-- also when ROM14=1 - mod. access to extended devices in CP/M mode
	-- D6 - SCR. CPU memory instead of seg 02, also CMR0 D3 must be 1 (#8000 - #BFFF)
	-- D7 - 80DS. 0 - Spectrum video mode (seg 05)
				  -- 1 - Profi video mode (seg 06, 3A, 04, 38)
																	  
	signal ram_ext : std_logic_vector(2 downto 0) := "000";
	signal ram_do : std_logic_vector(7 downto 0);
	signal ram_oe_n : std_logic := '1';
	
	signal fd_port : std_logic := '1';
	signal fd_sel : std_logic;	
																	  
	signal ay_port		: std_logic := '0';
	signal bdir 		: std_logic;
	signal bc1 			: std_logic;
		
	signal vbus_mode  : std_logic := '0';
	
	signal sound_out 	: std_logic := '0';
	signal mic 			: std_logic := '0';
	
	signal port_read	: std_logic := '0';
	signal port_write	: std_logic := '0';
	
	signal zc_do_bus	: std_logic_vector(7 downto 0);
	signal zc_wr 		: std_logic :='0';
	signal zc_rd		: std_logic :='0';
	signal zc_sd_cs_n: std_logic;
	signal zc_sd_di: std_logic;
	signal zc_sd_clk: std_logic;
	
	signal vid_rd : std_logic;
	
	signal trdos	: std_logic :='1';
	
	-- UART 
	signal uart_oe_n   : std_logic := '1';
	signal uart_do_bus : std_logic_vector(7 downto 0);
	
	-- profi special signals
	signal cpm : std_logic := '0';
	signal worom : std_logic := '0';
	signal ds80 : std_logic := '0';
	signal scr : std_logic := '0';
	signal sco : std_logic := '0';
	signal u25 : std_logic := '0';
	signal onoff : std_logic := '1'; -- disable CMR1 (port_dffd)	
	
begin

	-- AY signals
	ay_port <= '1' when A(7 downto 0) = x"FD" and A(15)='1' and fd_port = '1' and ((enable_bus_n_iorqge and BUS_N_IORQGE = '0') or not(enable_bus_n_iorqge)) else '0';
	bdir <= '1' when ay_port = '1' and N_IORQ = '0' and N_WR = '0' else '0';
	bc1 <= '1' when ay_port = '1' and A(14) = '1' and N_IORQ = '0' and (N_WR='0' or N_RD='0') else '0';
	AY_BC1 <= bc1;
	AY_BDIR <= bdir; 	

	-- beeper
	BEEPER <= sound_out;
	
	-- NMI button
	N_NMI <= BTN_NMI;	
	
	-- Mapcond LED control
	MAPCOND <= '1';
	
	 -- #FD port correction
	 fd_sel <= '0' when vbus_mode='0' and D(7 downto 4) = "1101" and D(2 downto 0) = "011" else '1'; -- IN, OUT Z80 Command Latch

	 process(fd_sel, N_M1, N_RESET)
	 begin
			if N_RESET='0' then
				  fd_port <= 	'1';
			elsif rising_edge(N_M1) then 
				  fd_port <= fd_sel;
			end if;
	 end process;
	 
	 -- main clock selector
	 U0: entity work.clk_mux
	 port map(
		data0 => CLK28,
		data1 => CLK24,
		sel => ds80,
		result => CLK
	 );

	clkcpu <= clk_div8;
	
--	rom14 <= port_7ffd(4);	
	cpm <= port_dffd(5); -- 1 - блокирует работу контроллера из ПЗУ TR-DOS и включает порты на доступ из ОЗУ (ROM14=0); При ROM14=1 - мод. доступ к расширен. периферии
	worom <= port_dffd(4); -- 1 - отключает блокировку порта 7ffd и выключает ПЗУ, помещая на его место ОЗУ из seg 00
	ds80 <= port_dffd(7); -- 0 = seg05 spectrum bitmap, 1 = profi bitmap seg06 & seg 3a & seg 04 & seg 38
	scr <= port_dffd(6); -- памяти CPU на место seg 02, при этом бит D3 CMR0 должен быть в 1 (#8000-#BFFF)
	sco <= port_dffd(3); -- Выбор положения окна проецирования сегментов:
								-- 0 - окно номер 1 (#C000-#FFFF)
								-- 1 - окно номер 2 (#4000-#7FFF)
	
	ram_ext <= port_dffd(2 downto 0);
	
	CLK_CPU <= clkcpu;
	CLK_BUS <= not(clkcpu);
	CLK_AY	<= clk_div16;
	
	TAPE_OUT <= mic;
	
	port_write <= '1' when N_IORQ = '0' and N_WR = '0' and N_M1 = '1' else '0';
	port_read <= '1' when N_IORQ = '0' and N_RD = '0' and N_M1 = '1' and ((enable_bus_n_iorqge and BUS_N_IORQGE = '0') or not(enable_bus_n_iorqge)) else '0';
	
	-- read ports by CPU
	D(7 downto 0) <= 
		ram_do when ram_oe_n = '0' else -- #memory
		port_dffd when port_read = '1' and A = X"DFFD" else -- #DFFD read
		port_7ffd when port_read = '1' and A = X"7FFD" else  -- #7FFD read
		'1' & TAPE_IN & '1' & kb(4 downto 0) when port_read = '1' and A(0) = '0' else -- #FE - keyboard 
		zc_do_bus when port_read = '1' and A(7 downto 6) = "01" and A(4 downto 0) = "10111" else -- Z-controller
		attr_r when port_read = '1' and A(7 downto 0) = x"FF" and trdos = '0' else -- #FF - attributes (timex port never set)
		"ZZZZZZZZ";

	-- z-controller 
	zc_wr <= '1' when (N_IORQ = '0' and N_WR = '0' and A(7 downto 6) = "01" and A(4 downto 0) = "10111") else '0';
	zc_rd <= '1' when (N_IORQ = '0' and N_RD = '0' and A(7 downto 6) = "01" and A(4 downto 0) = "10111") else '0';
	
	-- clocks
	process (CLK)
	begin 
		if (CLK'event and CLK = '1') then 
			clk_div2 <= not(clk_div2);
		end if;
	end process;
	
	process (clk_div2)
	begin 
		if (clk_div2'event and clk_div2 = '1') then 
			clk_div4 <= not(clk_div4);
		end if;
	end process;
	
	process (clk_div4)
	begin 
		if (clk_div4'event and clk_div4 = '1') then 
			clk_div8 <= not(clk_div8);
		end if;
	end process;

	process (clk_div8)
	begin 
		if (clk_div8'event and clk_div8 = '1') then 
			clk_div16 <= not(clk_div16);
		end if;
	end process;
	
	-- ports, write by CPU
	process( CLK, clk_div2, clk_div4, N_RESET, A, D, port_write, port_7ffd, N_M1, N_MREQ )
	begin
		if N_RESET = '0' then
			u25 <= '1';
			port_7ffd <= (others => '0'); 
			port_dffd <= (others => '0');
			sound_out <= '0';
			trdos <= '1'; -- 1 - boot into service rom, 0 - boot into 128 menu
		elsif CLK'event and CLK = '1' then 
		
				if port_write = '1' then

					 -- port #7FFD  
					if A(15)='0' and A(1) = '0' and port_dffd(5) = '0' then 
						u25 <= D(4);
					end if;
					 
					if A(15)='0' and A(1) = '0' and (port_7ffd(5) = '0' or port_dffd(4)='1') then -- short decoding #FD
						port_7ffd <= D;
					end if;
					
					-- port #DFFD (profi ram ext)
					if A = X"DFFD" and fd_port='1' then
						port_dffd <= D;
					end if;
					
					-- port #FE
					if A(0) = '0' then
						border_attr <= D(2 downto 0); -- border attr
						mic <= D(3); -- MIC
						sound_out <= D(4); -- BEEPER
					end if;
					
				end if;
				
				if port_dffd(5) = '1' then u25 <= '0'; end if;
				
				-- trdos flag
				if N_M1 = '0' and N_MREQ = '0' and A(15 downto 8) = X"3D" and u25 = '1' and port_dffd(5) = '0' then 
					trdos <= '1';
				elsif ((N_M1 = '0' and N_MREQ = '0' and A(15 downto 14) /= "00") or (port_dffd(5) = '1')) then 
					trdos <= '0'; 
				end if;
				
		end if;
	end process;	

	-- memory manager
	U1: entity work.memory 
	generic map (
		enable_bus_n_romcs => enable_bus_n_romcs
	)
	port map ( 
		CLK2X => CLK,
		CLKX => clk_div2,
		CLK_CPU => clkcpu,
		--TURBO => turbo,
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
		RAM_EXT => ram_ext, -- seg A3 - seg A5

		-- video
		VA => vid_a,
		VID_PAGE => port_7ffd(3), -- seg A0 - seg A2
		DS80 => ds80,
		CPM => cpm,
		SCO => sco,
		SCR => scr,
		WOROM => worom,

		-- video bus control signals
		VBUS_MODE_O => vbus_mode, -- video bus mode: 0 - ram, 1 - vram
		VID_RD_O => vid_rd, -- read attribute or pixel
		
		-- TRDOS 
		TRDOS => trdos,
		
		-- rom
		ROM_BANK => port_7ffd(4),
		ROM_A14 => ROM_A14,
		ROM_A15 => ROM_A15,
		N_ROMCS => N_ROMCS		
	);
		
	-- Z-Controller
	U3: entity work.zcontroller 
	port map(
		RESET => not(N_RESET),
		CLK => clk_div4,
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

	-- SD card
	SD_N_CS <= zc_sd_cs_n;
	SD_CLK <= zc_sd_clk;
	SD_DI <= zc_sd_di;
	
-- video controller
	U5: entity work.video 
	generic map (
		enable_turbo => enable_turbo
	)
	port map (
		CLK => clk_div2, -- 14
		CLK2x => CLK, -- 28
		ENA => clk_div4, -- 7
		
		BORDER => border_attr,
		DI => MD,
		TURBO => turbo,
		INTA => N_IORQ or N_M1,
		INT => N_INT,
		ATTR_O => attr_r, 
		A => vid_a,
		DS80 => ds80,
		
		VIDEO_R => VIDEO_R,
		VIDEO_G => VIDEO_G,
		VIDEO_B => VIDEO_B,
		
		HSYNC => open,
		VSYNC => open,
		CSYNC => VIDEO_CSYNC,

		VBUS_MODE => vbus_mode,
		VID_RD => vid_rd
	);
	
	-- UART (via AY port A) 	
	G_AY_UART: if enable_ay_uart generate
		U16: entity work.ay_uart 
		port map(
			CLK_I => CLK,
			RESET_I => not(N_RESET),
			EN_I => clk_div16,
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
