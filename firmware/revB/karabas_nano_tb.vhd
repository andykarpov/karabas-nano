library ieee;
use ieee.std_logic_1164.all;

entity karabas_nano_tb is
end karabas_nano_tb;

architecture behavior of karabas_nano_tb is

    component karabas_nano is
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
		BUS_N_IORQGE 	: in std_logic := '0';
		BUS_N_ROMCS 	: in std_logic := '0';
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
		
		-- Other in signals
		TURBO				: in std_logic := '0';
		MAGIC				: in std_logic := '0';
		SPECIAL			: in std_logic := '0';
		IO16 				: inout std_logic := 'Z';
		IO13 				: inout std_logic := 'Z';
		IO10 				: inout std_logic := 'Z'
		
	);
    end component;
	 
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

    signal clk  : std_logic := '0';
	 signal clk_bus : std_logic := '0';
    signal cnt : std_logic := '0';

    signal clk_cpu : std_logic := '0';
    signal n_reset : std_logic := '1';
    signal n_int : std_logic := '1';
    signal n_rd : std_logic := '1';
    signal n_wr : std_logic := '1';
    signal n_iorq : std_logic := '1';
    signal n_mreq : std_logic := '1';
    signal n_m1 : std_logic := '1';
    signal a : std_logic_vector(15 downto 0);
    signal a14 : std_logic;
    signal a15 : std_logic;
    signal d : std_logic_vector(7 downto 0);

    signal BUS_N_IORQGE : std_logic := '0';
    signal BUS_N_ROMCS: std_logic := '0';

    signal MA      : std_logic_vector(20 downto 0) := "ZZZZZZZZZZZZZZZZZZZZZ";
    signal MD      : std_logic_vector(7 downto 0) := "ZZZZZZZZ";
    signal N_MRD   : std_logic := '1';
    signal N_MWR   : std_logic := '1';

    signal N_ROMCS : std_logic := '1';
    signal ROM_A14 : std_logic := '0';
    signal ROM_A15 : std_logic := '0';
        
    signal VIDEO_CSYNC : std_logic := '1';
    signal VIDEO_R       : std_logic_vector(2 downto 0) := "000";
    signal VIDEO_G       : std_logic_vector(2 downto 0) := "000";
    signal VIDEO_B       : std_logic_vector(2 downto 0) := "000";

    signal TAPE_IN         : std_logic;
    signal TAPE_OUT        : std_logic := '1';
    signal BEEPER : std_logic := '1';

    signal CLK_AY  : std_logic;
    signal AY_BC1  : std_logic;
    signal AY_BDIR : std_logic;

    signal KB  : std_logic_vector(4 downto 0) := "11111";

begin
    u_tb: karabas_nano 
    port map (
        CLK28 => clk,
		  CLKX => clk,

        CLK_CPU => clk_cpu,
		  CLK_BUS => clk_bus,
        N_RESET => n_reset,

        N_INT => n_int,
        N_RD => n_rd,
        N_WR => n_wr,
        N_IORQ => n_iorq,
        N_MREQ => n_mreq,
        N_M1 => n_m1,
        A => a,
        D => d,
		  N_BUSREQ => '1',
		  N_BUSACK => '1',
		  N_WAIT => '1',
		  N_HALT => '1',
		  N_NMI => '1',
		  N_RFSH => '1',
		  SD_DO => '1',
		  
		  TURBO => '1',
		  MAGIC => '0',
		  SPECIAL => '0',
        
        BUS_N_IORQGE => BUS_N_IORQGE,
        BUS_N_ROMCS => BUS_N_ROMCS,

        MA      => MA,
        MD      => MD,
        N_MRD   => N_MRD,
        N_MWR   => N_MWR,

        N_ROMCS => N_ROMCS,
        ROM_A14 => ROM_A14,
        ROM_A15 => ROM_A15,
        
        VIDEO_CSYNC => VIDEO_CSYNC,
        VIDEO_R => VIDEO_R,
        VIDEO_G => VIDEO_G,
        VIDEO_B => VIDEO_B,

        TAPE_IN => TAPE_IN,
        TAPE_OUT => TAPE_OUT,
        BEEPER => BEEPER,

        CLK_AY => CLK_AY,
        AY_BC1 => AY_BC1,
        AY_BDIR => AY_BDIR,

        KB => KB
    );

    -- simulate reset
    n_reset <=
        '1' after 0 ns,
        '0' after 300 ns,
        '1' after 1000 ns;

    -- simulate clk
    clk <=  '1' after 35 ns when clk = '0' else
        '0' after 35 ns when clk = '1';
		  
	 -- TODO: simulate CPU read / write cycles

    -- simulate adc_data
    -- "11111111" / "00000000"
    --adc_data <= '0' when cnt='0' and adc_cs_n='0' and adc_clk='0' else 
    --            '1' when cnt='1' and adc_cs_n='0' and adc_clk='0' else 
    --            'Z';

    --process (adc_cs_n) 
    --begin
    --    if falling_edge(adc_cs_n) then 
    --        if (cnt = '1') then cnt <= '0'; else cnt <= '1'; end if;
    --    end if;
    --end process;

end;
