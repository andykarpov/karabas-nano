-- --------------------------------------------------------------------
-- Karabas-Nano rev.B firmware
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

	component zcontroller is
	 port (
		RESET	: in std_logic;
		CLK     : in std_logic;
		A       : in std_logic;
		DI		: in std_logic_vector(7 downto 0);
		DO		: out std_logic_vector(7 downto 0);
		RD		: in std_logic;
		WR		: in std_logic;
		SDDET	: in std_logic;
		SDPROT	: in std_logic;
		CS_n	: out std_logic;
		SCLK	: out std_logic;
		MOSI	: out std_logic;
		MISO	: in std_logic );
	 end component;

	signal reset      : std_logic := '0';
	
	signal clk_14 		: std_logic := '0';
	signal clk_7 		: std_logic := '0';
	signal clk_3_5 	: std_logic := '0';
	signal clk_1_75	: std_logic := '0';

	signal clk_int   	: std_logic := '0'; -- 7MHz short pulse to access zx bus
	signal clk_vid 	: std_logic := '0'; -- 7MHz inversed and delayed short pulse to access video memory
	
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
	
	signal port_dffd  : std_logic_vector(7 downto 0); -- D0 - RAM A17'
																	  -- D1 - RAM A18'
																	  -- D2 - RAM A19'
																	  -- D3 - D7 not used

--	signal port_1ffd  : std_logic_vector(7 downto 0); -- D0 - ext mem mode: 0 - normal, 1 - special, 
																	  -- D1 - not used,
																	  -- D2 - ROM A15,
																	  -- D3 - motor,
																	  -- D4 - printer
																	  -- D5, D6, D7 - not used

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
	
	signal fd_port 	: std_logic;
	signal fd_sel 		: std_logic;
	
	signal zc_do_bus	: std_logic_vector(7 downto 0);
	signal zc_wr 		: std_logic :='0';
	signal zc_rd		: std_logic :='0';
	
	signal trdos	: std_logic :='1';

begin
	reset <= not(N_RESET);

	n_is_rom <= '0' when N_MREQ = '0' and A(15 downto 14)  = "00" else '1';
	n_is_ram <= '0' when N_MREQ = '0' and A(15 downto 14) /= "00" else '1';

	-- pentagon ROM banks map (A14, A15):
	-- 00 - bank 0, He Gluk Reset Service
	-- 01 - bank 1, TR-DOS
	-- 10 - bank 2, Basic-128
	-- 11 - bank 3, Basic-48
	rom_page <= (not(trdos)) & (port_7ffd(4));
	ROM_A14 <= rom_page(0);
	ROM_A15 <= rom_page(1);	
	
	N_ROMCS <= '0' when n_is_rom = '0' and N_RD = '0' else '1';

	ram_page <=	"000000" when A(15) = '0' and A(14) = '0' else
				"000101" when A(15) = '0' and A(14) = '1' else
				"000010" when A(15) = '1' and A(14) = '0' else
				--port_1ffd(7) & port_7ffd(7) & port_1ffd(4) & port_7ffd(2 downto 0); -- pentagon 1024
				port_dffd(2 downto 0) & port_7ffd(2 downto 0); -- profi 1024

	MA(13 downto 0) <= A(13 downto 0) when vbus_mode = '0' else 
		std_logic_vector( "0" & ver_cnt(4 downto 3) & chr_row_cnt & ver_cnt(2 downto 0) & hor_cnt(4 downto 0) ) when vid_rd = '0' else
		std_logic_vector( "0110" & ver_cnt(4 downto 0) & hor_cnt(4 downto 0) );
	MA(14) <= ram_page(0) when vbus_mode = '0' else '1';
	MA(15) <= ram_page(1) when vbus_mode = '0' else port_7ffd(3);
	MA(16) <= ram_page(2) when vbus_mode = '0' else '1';
	MA(17) <= ram_page(3) when vbus_mode = '0' else '0';
	MA(18) <= ram_page(4) when vbus_mode = '0' else '0';
	MA(19) <= ram_page(5) when vbus_mode = '0' else '0';
	MA(20) <= '0'; -- TODO
	
	MD(7 downto 0) <= 
		D(7 downto 0) when vbus_mode = '0' and ((n_is_ram = '0' or (N_IORQ = '0' and N_M1 = '1')) and N_WR = '0') else 
		(others => 'Z');

	vbus_req <= '0' when ( N_MREQ = '0' or N_IORQ = '0' ) and ( N_WR = '0' or N_RD = '0' ) else '1';
	vbus_rdy <= '0' when clk_vid = '1' or chr_col_cnt(0) = '0' else '1';
	
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
	clk_int <= clk_14 and clk_7;-- when TURBO = '0' else CLK28 and clk_14; -- internal clock for counters
	clk_vid <= not(clk_14) and not(clk_7);-- when TURBO = '0' else CLK28 and not(clk_14); --when TURBO = '0' else CLK28 and not(clk_14) and not(clk_7); -- internal clock for video read
	is_buf_wr <= '1' when vbus_mode = '0' and chr_col_cnt(0) = '0' else '0';
	
	-- todo
	process( clk_14, clk_7 )
	begin
	-- rising edge of CLK14
		if clk_14'event and clk_14 = '1' then
			if clk_7 = '1' then
				CLK_CPU <= chr_col_cnt(0);
				CLK_BUS <= not(chr_col_cnt(0));
			end if;
		end if;
	end process;

	
	-- #FD port correction
	fd_sel <= '0' when D(7 downto 4) = "1101" and D(2 downto 0) = "011" else '1'; -- IN, OUT Z80 Command Latch
	 
	port_write <= '1' when N_IORQ = '0' and N_WR = '0' and N_M1 = '1' and vbus_mode = '0' else '0';
	port_read <= '1' when N_IORQ = '0' and N_RD = '0' and N_M1 = '1' else '0'; -- and BUS_N_IORQGE = '0' else '0';
	
	-- read ports by CPU
	D(7 downto 0) <= 
		buf_md(7 downto 0) when n_is_ram = '0' and N_RD = '0' else -- MD buf	
		'1' & ear & '1' & KB(4 downto 0) when port_read = '1' and A(0) = '0' else -- #FE
		port_7ffd when port_read = '1' and A = X"7FFD" else -- #7FFD
		--port_1ffd when port_read = '1' and A = X"1FFD" else -- #1FFD
		--port_dffd when port_read = '1' and A = X"DFFD" else -- #DFFD
		zc_do_bus when port_read = '1' and A(7 downto 6) = "01" and A(4 downto 0) = "10111" else -- Z-controller
--		attr_r when port_read = '1' and A(7 downto 0) = "11111111" else -- #FF
		"ZZZZZZZZ";

	-- z-controller 
	zc_wr <= '1' when (N_IORQ = '0' and N_WR = '0' and A(7 downto 6) = "01" and A(4 downto 0) = "10111") else '0';
	zc_rd <= '1' when (N_IORQ = '0' and N_RD = '0' and A(7 downto 6) = "01" and A(4 downto 0) = "10111") else '0';
	
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

	-- fd port correction
	process(fd_sel, N_M1, N_RESET)
	begin
		if N_RESET='0' then
			fd_port <= '1';
		elsif rising_edge(N_M1) then 
			fd_port <= fd_sel;
		end if;
	end process;
	
	-- ports, write by CPU
	process( clk_14, clk_7, N_RESET, A, D, port_write, fd_port, port_7ffd, trdos, N_M1, N_MREQ )
	begin
		if N_RESET = '0' then
			port_7ffd <= "00000000";
			port_dffd <= "00000000";
--			port_1ffd <= "00000000";
			sound_out <= '0';
			mic <= '0';
			trdos <= '1'; -- 1 - boot into service rom, 0 - boot into 128 menu
		elsif clk_14'event and clk_14 = '1' then 
			if clk_7 = '1' then
				if port_write = '1' then

					 -- port #7FFD  
					if A = X"7FFD" then 
						port_7ffd <= D;
					elsif A(15)='0' and A(1) = '0' and port_7ffd(5) = '0' then
						port_7ffd <= D;
					end if;
					 
					 -- port #DFFD (ram ext)
					if A = X"DFFD" and port_7ffd(5) = '0' and fd_port='1' then  
							port_dffd <= D;
					end if;
					
					-- port #1FFD
--					if A = X"1FFD" and fd_port='1' then -- short decoding by A0 + A12-A15
--							port_1ffd <= D;
--					end if;
					
					-- port #FE
					if A(0) = '0' then
						border_attr <= D(2 downto 0); -- border attr
						mic <= D(3); -- MIC
						sound_out <= D(4); -- BEEPER
					end if;
				end if;
				
				-- trdos flag
				if N_M1 = '0' and N_MREQ = '0' and A(15 downto 8) = X"3D" and port_7ffd(4) = '1' then 
					trdos <= '1';
				elsif N_M1 = '0' and N_MREQ = '0' and A(15 downto 14) /= "00" then 
					trdos <= '0'; 
				end if;
			end if;
		end if;
	end process;	
		
	U1: zcontroller 
	port map(
		RESET => reset,
		CLK => clk_7,
		A => A(5),
		DI => D,
		DO => zc_do_bus,
		RD => zc_rd,
		WR => zc_wr,
		SDDET => '0',
		SDPROT => '0',
		CS_n => SD_N_CS,
		SCLK => SD_CLK,
		MOSI => SD_DI,
		MISO => SD_DO
	);

end;