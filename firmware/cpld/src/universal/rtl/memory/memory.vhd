library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.conv_integer;
use IEEE.numeric_std.all;

entity memory is
generic (
		enable_divmmc 	    : boolean := true;
		enable_zcontroller : boolean := false;
		enable_bus_n_romcs : boolean := true;
		ram_ext_std			 : integer range 0 to 9 := 0
);
port (
	CLK14	   	: in std_logic;
	CLK7			: in std_logic;
	HCNT0 		: in std_logic;
	BUS_N_ROMCS : in std_logic;

	A           : in std_logic_vector(15 downto 0); -- address bus
	D 				: in std_logic_vector(7 downto 0);
	N_MREQ		: in std_logic;
	N_IORQ 		: in std_logic;
	N_WR 			: in std_logic;
	N_RD 			: in std_logic;
	N_M1 			: in std_logic;
	
	DO 			: out std_logic_vector(7 downto 0);
	N_OE 			: out std_logic;
	
	MA 			: out std_logic_vector(20 downto 0);
	MD 			: inout std_logic_vector(7 downto 0);
	N_MRD 		: out std_logic;
	N_MWR 		: out std_logic;
	
	RAM_BANK		: in std_logic_vector(2 downto 0);
	RAM_EXT 		: in std_logic_vector(2 downto 0);
	
	DIVMMC_A 	  : in std_logic_vector(5 downto 0);
	IS_DIVMMC_RAM : in std_logic;
	IS_DIVMMC_ROM : in std_logic;
	
	TRDOS 		: in std_logic;
	
	VA				: in std_logic_vector(13 downto 0);
	VID_PAGE 	: in std_logic := '0';
	
	VBUS_MODE_O : out std_logic;
	VID_RD_O 	: out std_logic;
	
	ROM_BANK : in std_logic := '0';
	ROM_A14 	: out std_logic;
	ROM_A15  : out std_logic;
	N_ROMCS 	: out std_logic
);
end memory;

architecture RTL of memory is

	signal buf_md		: std_logic_vector(7 downto 0) := "11111111";
	signal is_buf_wr	: std_logic := '0';	
	
	signal is_rom : std_logic := '0';
	signal is_ram : std_logic := '0';
	
	signal rom_page : std_logic_vector(1 downto 0) := "00";
	signal ram_page : std_logic_vector(6 downto 0) := "0000000";

	signal vbus_req	: std_logic := '1';
	signal vbus_mode	: std_logic := '1';	
	signal vbus_rdy	: std_logic := '1';
	signal vid_rd 		: std_logic := '0';
	signal vbus_ack 	: std_logic := '1';
begin

	is_rom <= '1' when N_MREQ = '0' and ((A(15 downto 14)  = "00" and IS_DIVMMC_ROM = '0' and IS_DIVMMC_RAM = '0') or IS_DIVMMC_ROM = '1') else '0';
	is_ram <= '1' when N_MREQ = '0' and ((A(15 downto 14) /= "00" and IS_DIVMMC_ROM = '0' and IS_DIVMMC_RAM = '0') or IS_DIVMMC_RAM = '1') else '0';
	
	-- 00 - bank 0, ESXDOS 0.8.7 or GLUK
	-- 01 - bank 1, empty or TRDOS
	-- 10 - bank 2, Basic-128
	-- 11 - bank 3, Basic-48
	rom_page <= "00" when enable_divmmc and IS_DIVMMC_ROM = '1' else 
		(not(TRDOS)) & ROM_BANK when enable_zcontroller else
		'1' & ROM_BANK;
		
	ROM_A14 <= rom_page(0);
	ROM_A15 <= rom_page(1);	
	N_ROMCS <= '0' when is_rom = '1' and N_RD = '0' and ((enable_bus_n_romcs and BUS_N_ROMCS = '0') or not(enable_bus_n_romcs)) else '1';

	vbus_req <= '0' when ( N_MREQ = '0' or N_IORQ = '0' ) and ( N_WR = '0' or N_RD = '0' ) else '1';
	vbus_rdy <= '0' when (CLK7 = '0' or HCNT0 = '0') else '1';

	VBUS_MODE_O <= vbus_mode;
	VID_RD_O <= vid_rd;
	
	N_MRD <= '0' when (vbus_mode = '1' and vbus_rdy = '0') or (vbus_mode = '0' and N_RD = '0' and N_MREQ = '0') else '1';  
	N_MWR <= '0' when vbus_mode = '0' and is_ram = '1' and N_WR = '0' and HCNT0 = '0' else '1';

	is_buf_wr <= '1' when vbus_mode = '0' and HCNT0 = '0' else '0';
	
	DO <= buf_md;
	N_OE <= '0' when is_ram = '1' and N_RD = '0' else '1';
		
	-- memory map for RAM > 128k
	G_RAM_EXT: if ram_ext_std > 0 generate
		ram_page <=	
					"10" & DIVMMC_A(5 downto 1) when IS_DIVMMC_RAM = '1' else -- 512KB DivMMC RAM
					"0000000" when A(15) = '0' and A(14) = '0' else
					"0000101" when A(15) = '0' and A(14) = '1' else
					"0000010" when A(15) = '1' and A(14) = '0' else
					"0" & RAM_EXT(2 downto 0) & RAM_BANK(2 downto 0);
	end generate G_RAM_EXT;

	-- memory map for RAM = 128k
	G_RAM_128: if ram_ext_std = 0 generate
		ram_page <=	
					"0100" & DIVMMC_A(3 downto 1) when IS_DIVMMC_RAM = '1' else -- 128KB DivMMC RAM
					"0000000" when A(15) = '0' and A(14) = '0' else
					"0000101" when A(15) = '0' and A(14) = '1' else
					"0000010" when A(15) = '1' and A(14) = '0' else
					"0000" & RAM_BANK(2 downto 0);
	end generate G_RAM_128;
	
	MA(13 downto 0) <= 
		DIVMMC_A(0) & A(12 downto 0) when vbus_mode = '0' and IS_DIVMMC_RAM = '1' else -- divmmc ram 
		A(13 downto 0) when vbus_mode = '0' else -- spectrum ram 
		VA; -- video ram

	MA(14) <= ram_page(0) when vbus_mode = '0' else '1';
	MA(15) <= ram_page(1) when vbus_mode = '0' else VID_PAGE;
	MA(16) <= ram_page(2) when vbus_mode = '0' else '1';
	MA(17) <= ram_page(3) when vbus_mode = '0' else '0';
	MA(18) <= ram_page(4) when vbus_mode = '0' else '0';
	MA(19) <= ram_page(5) when vbus_mode = '0' else '0';
	MA(20) <= ram_page(6) when vbus_mode = '0' else '0';
	
	MD(7 downto 0) <= 
		D(7 downto 0) when vbus_mode = '0' and ((is_ram = '1' or (N_IORQ = '0' and N_M1 = '1')) and N_WR = '0') else 
		(others => 'Z');
		
	-- fill memory buf
	process(is_buf_wr)
	begin 
		if (is_buf_wr'event and is_buf_wr = '0') then  -- high to low transition to lattch the MD into BUF
			buf_md(7 downto 0) <= MD(7 downto 0);
		end if;
	end process;	
	
	-- video mem
	process( CLK14, CLK7, HCNT0, vbus_mode, vid_rd, vbus_req, vbus_ack )
	begin
		-- lower edge of 7 mhz clock
		if CLK14'event and CLK14 = '1' then 
			if (HCNT0 = '1' and CLK7 = '0') then
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
		
end RTL;

