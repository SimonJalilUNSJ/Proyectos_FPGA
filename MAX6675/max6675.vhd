library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity max6675 is
	port(
		i_rst_low 		:in std_logic;
		i_clk 			:in std_logic;
		i_SPI_MISO		:in std_logic;
		
		o_SPI_clk		:out std_logic;
		o_SPI_MOSI		:out std_logic;
		o_SPI_CS_low	:out std_logic;
		o_temp			:out std_logic_vector(9 downto 0)
	);
end entity max6675;

architecture behav of max6675 is 
	component spi_master_cs is
		generic (
			MODO_SPI          	: integer;
			CLKS_MITAD_BIT 		: integer;
			MAX_BYTES_POR_CS  	: integer;
			CS_CLKS_INACTIVOS  	: integer 
			);
		port (
			i_rst_low  	:in std_logic;     						
			i_clk   		:in std_logic;     						
			i_tx_cont 	:in  std_logic_vector(1 downto 0);  
			i_tx_byte  	:in  std_logic_vector(7 downto 0); 
			i_tx_dv    	:in  std_logic;     
			i_MISO 		:in  std_logic;
	
			o_tx_listo 	:out std_logic;     						
			o_rx_cont 	:out std_logic_vector(1 downto 0);  
			o_rx_dv    	:out std_logic;  							
			o_rx_byte  	:out std_logic_vector(7 downto 0);  
			o_spi_clk  	:out std_logic;
			o_MOSI 		:out std_logic;
			o_CS_low 	:out std_logic
			);
	end component spi_master_cs;
		
	component conversor_BCD is 
		port (
			i_temp			:in std_logic_vector(9 downto 0);
		
			o_unidad_mil	:out std_logic_vector(3 downto 0);
			o_centenas		:out std_logic_vector(3 downto 0);
			o_decenas 		:out std_logic_vector(3 downto 0);
			o_unidades 		:out std_logic_vector(3 downto 0)
		);
	end component conversor_BCD;
	
	constant SPI_MODO				:integer := 1;		 
	constant CLKS_MITAD_BITS	:integer := 200;		
	constant CS_CLKS_INACTIVOS	:integer := 50000;	
	
	signal rx_cont		:std_logic_vector(1 downto 0);
	signal rx_dv 		:std_logic;
	signal rx_byte		:std_logic_vector(7 downto 0);
	signal tx_listo 	:std_logic;
	signal tx_dv		:std_logic;
	signal ADC 			:std_logic_vector(15 downto 0);
	--signal temp			:std_logic_vector(9 downto 0);
	signal convertir	:std_logic := '0';

begin 
	
	SPI: spi_master_cs generic map (
										MODO_SPI				=> SPI_MODO,
										CLKS_MITAD_BIT		=> CLKS_MITAD_BITS,
										MAX_BYTES_POR_CS 	=> 2,
										CS_CLKS_INACTIVOS => CS_CLKS_INACTIVOS
									)
							 port map(
										i_rst_low  	=> i_rst_low,     						
										i_clk   		=> i_clk,     						
										i_tx_cont 	=> "10",  
										i_tx_byte  	=> x"00", 
										i_tx_dv    	=> tx_dv,     
										i_MISO 		=> i_SPI_MISO,
										o_tx_listo 	=> tx_listo,      						
										o_rx_cont 	=> rx_cont,
										o_rx_dv    	=> rx_dv,  							
										o_rx_byte  	=> rx_byte,  
										o_spi_clk  	=> o_SPI_clk,
										o_MOSI 		=> o_SPI_MOSI,
										o_CS_low 	=> o_SPI_CS_low
									);    
	
	pr1: process (i_clk) is 
			variable cont :integer range 0 to 50_000_000 := 0;
		begin
			if(rising_edge(i_clk)) then 
				--tx_dv <= tx_listo;
				if(cont > 25_000_000 and tx_listo = '1') then
					tx_dv <= '1';
				else 
					tx_dv <= '0';
					cont := cont + 1; 
				end if;
			end if;
		end process;
	
	adc_pr: process(i_clk) is
		begin 
			if(rising_edge(i_clk)) then 
				if(rx_dv = '1') then 
					if(rx_cont = "00") then 
						ADC(15 downto 8) <= rx_byte;
					else 
						ADC(7 downto 0) <= rx_byte;
					end if;
				end if;
			end if;
		end process;
		
o_temp <= ADC(14 downto 5);
		
end architecture behav;