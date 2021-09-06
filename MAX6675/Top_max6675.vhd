library ieee;
use ieee.std_logic_1164.all;

entity Top_max6675 is 
	port(
		i_rst_low		:in std_logic;
		i_clk 			:in std_logic;
		i_MISO			:in std_logic;
		
		o_sclk			:out std_logic;
		o_MOSI			:out std_logic;
		o_CS_low			:out std_logic;
		o_displays		:out std_logic_vector(6 downto 0);
		o_digitos 		:out std_logic_vector(3 downto 0);
		o_dp 				:out std_logic;
		--o_temp			:out std_logic_vector(9 downto 0);
		--o_bcd				:out std_logic_vector(15 downto 0);
		
		o_tx				:out std_logic;
		
		o_rw 				:out std_logic;
		o_rs				:out std_logic;
		b_e				:buffer std_logic;
		o_db				:out std_logic_vector(7 downto 0) 
	);
end entity Top_max6675;

architecture behav of Top_max6675 is 

	component max6675 is
		port(
			i_rst_low 		:in std_logic;
			i_clk 			:in std_logic;
			i_SPI_MISO		:in std_logic;
		
			o_SPI_clk		:out std_logic;
			o_SPI_MOSI		:out std_logic;
			o_SPI_CS_low	:out std_logic;
			o_temp			:out std_logic_vector(9 downto 0)
		);
	end component max6675;
	
	component conversor_BCD is 
		port (
			i_temp			:in std_logic_vector(9 downto 0);
			i_clk				:in std_logic;
		
			o_unidad_mil	:out std_logic_vector(3 downto 0);
			o_centenas		:out std_logic_vector(3 downto 0);
			o_decenas 		:out std_logic_vector(3 downto 0);
			o_unidades 		:out std_logic_vector(3 downto 0)
		);
	end component conversor_BCD;
	
	component mod_7seg is 
		port(
			x		:in std_logic_vector(15 downto 0);
			clk	:in std_logic;
			clr 	:in std_logic;
			salida:out std_logic_vector(6 downto 0);
			dig 	:out std_logic_vector(3 downto 0);
			dp 	:out std_logic
		);
	end component mod_7seg;
	
	component FSM_LCD is 
		generic(clk_divisor: integer := 100000);					--50Mhz a 500Hz.
		port(
			clk 			:in std_logic;								--Reloj del sistema.
			reset_low	:in std_logic;								--Reinicio activo en bajo.
			i_temp 		:in std_logic_vector(15 downto 0);

			rw				:out std_logic;							--Escritura/lectura.
			rs 			:out std_logic;							--Datos/Instrucciones.
			e				:buffer std_logic := '0';				--Señal de habilitacion del modulo LCD.								
			db			 	:out std_logic_vector(7 downto 0)	--Señales de datos para el LCD.								--
			);
	end component FSM_LCD;
	
	component txRS232 is 
		generic(
			BITS			:positive	:= 8;
			BAUD_RATE	:positive 	:= 9600
		);
		port(
			i_clk			:in std_logic;
			i_rst_low	:in std_logic;
			i_enviando 	:in std_logic;
			i_temp		:in std_logic_vector(15 downto 0);
			o_dat			:out std_logic
		);
	end component txRS232;
	
	signal temp :std_logic_vector(9 downto 0);
	signal bcd 	:std_logic_vector(15 downto 0);
	
begin 
	max: max6675 port map(
									i_rst_low 		=> i_rst_low,
									i_clk 			=> i_clk,
									i_SPI_MISO		=> i_MISO, 
		
									o_SPI_clk		=> o_sclk,
									o_SPI_MOSI		=> o_MOSI, 
									o_SPI_CS_low	=> o_CS_low,
									o_temp			=> temp
								);
	
	conversor: conversor_BCD port map(
									i_temp			=> temp,
									i_clk				=> i_clk,
		
									o_unidad_mil	=> bcd(15 downto 12),
									o_centenas		=> bcd(11 downto 8),
									o_decenas 		=> bcd(7 downto 4),
									o_unidades 		=> bcd(3 downto 0)
								);
	
	mod7: mod_7seg port map(
									x			=> bcd,
									clk		=> i_clk,
									clr 	 	=> i_rst_low,
									salida	=> o_displays,
									dig 		=> o_digitos,
									dp 		=> o_dp
								);
								
	LCD: FSM_LCD 	generic map(clk_divisor => 100000)
						port map(
									clk 			=> i_clk,
									reset_low	=> i_rst_low,
									i_temp 		=> bcd,

									rw				=> o_rw,
									rs 			=> o_rs,
									e				=> b_e,								
									db			 	=> o_db		
								);
	uart: txRS232 port map(
									i_clk			=>	i_clk,
									i_rst_low	=>	i_rst_low,
									i_enviando 	=> '1',
									i_temp		=> bcd,
									o_dat			=> o_tx
								);

	
--o_bcd <= bcd;
--o_temp <= temp;
end architecture behav;