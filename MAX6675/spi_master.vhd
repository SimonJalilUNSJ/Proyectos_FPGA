library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is 
	generic(
		MODO				:integer := 1;							--Modo spi: 0,1,2,3
		CLKS_MITAD_BIT	:integer := 2							--Setea la frecuencia de o_spi_clk. 
	);
	port(
		i_rst_low	:in std_logic;								--Reset Bajo FPGA
		i_clk			:in std_logic;								--Clk FPGA
		i_tx_byte 	:in std_logic_vector(7 downto 0); 	--Byte a transmitir en MOSI
		i_tx_dv		:in std_logic;								--Pulso de dato valido TX
		i_MISO 		:in std_logic;								--MISO
		
		o_tx_listo 	:out std_logic;							--Transmision lista para el siguiente byte.
		o_rx_dv	 	:out std_logic;							--Pulso de dato valido RX
		o_rx_byte 	:out std_logic_vector(7 downto 0);	--Byte recibido de MISO
		o_MOSI		:out std_logic;							--MOSI
		o_spi_clk	:out std_logic								--SPI CLK
	);
end entity spi_master;

architecture behav of spi_master is

	signal CPOL					:std_logic;						--Clock polarity
	signal CPHA					:std_logic;						--Clock phase
	signal spi_clk				:std_logic;
	signal spi_clk_cont		:integer range 0 to CLKS_MITAD_BIT*2-1;
	signal spi_clk_flancos	:integer range 0 to 16;
	signal flanco_principal :std_logic;
	signal flanco_ultimo		:std_logic;
	signal tx_dv				:std_logic;
	signal tx_byte 			:std_logic_vector(7 downto 0);
	signal rx_bit_cont		:unsigned(2 downto 0);
	signal tx_bit_cont		:unsigned(2 downto 0);
	signal tx_listo			:std_logic;
	
begin

	CPOL <= '1' when (MODO = 2) or (MODO = 3) else '0';
	CPHA <= '1' when (MODO = 1) or (MODO = 3) else '0';
	
--Genera el correcto numero de clk del spi cuando un pulso de dato valido viene
pr_1: process (i_clk, i_rst_low)
	begin 
		if(i_rst_low = '0') then 
			tx_listo 			<= '0';
			spi_clk_flancos 	<= 0;
			flanco_principal	<= '0';
			flanco_ultimo 		<= '0';
			spi_clk 				<= CPOL;		--Asigno de estado predeterminado el estado inactivo
			spi_clk_cont 		<= 0;
		elsif(rising_edge(i_clk)) then 
			flanco_principal 	<= '0';
			flanco_ultimo 		<= '0';
			if(i_tx_dv = '1') then 
				tx_listo				<= '0';
				spi_clk_flancos 	<= 16;	--Numero total de flancos en un byte.
			elsif(spi_clk_flancos > 0) then 
				tx_listo <= '0';
				if(spi_clk_cont = CLKS_MITAD_BIT*2-1) then 
					spi_clk_flancos 	<= spi_clk_flancos - 1;
					flanco_ultimo 		<= '1';
					spi_clk_cont 		<= 0;
					spi_clk				<= not spi_clk;
				elsif(spi_clk_cont = CLKS_MITAD_BIT - 1) then
					spi_clk_flancos 	<= spi_clk_flancos - 1;
					flanco_principal  <= '1';
					spi_clk_cont		<= spi_clk_cont + 1;
					spi_clk 				<= not spi_clk;
				else 
					spi_clk_cont <= spi_clk_cont + 1;
				end if;
			else 
				tx_listo <= '1';
			end if;
		end if;
	end process pr_1;
	
	--Retengo en un registro el valor a transmitir
	pr_2:process(i_clk, i_rst_low) 
		begin
			if(i_rst_low = '0') then 
				tx_byte 	<= x"00";
				tx_dv 	<= '0';
			elsif(rising_edge(i_clk)) then
				tx_dv <= i_tx_dv;				
				if(i_tx_dv = '1') then
					tx_byte <= i_tx_byte;
				end if;
			end if;
		end process pr_2;
	
	--MOSI data (Opera para CPHA= 1 o 0)
	pr_3: process(i_clk, i_rst_low)
		begin 
			if(i_rst_low = '0') then 
				o_MOSI		<= '0';
				tx_bit_cont	<= "111";			--Envio el MSB primero
			elsif(rising_edge(i_clk)) then 
				if(tx_listo = '1') then			--Si listo es verdadero, reseteo el contador de bits al valor default.
					tx_bit_cont <= "111";
				elsif(tx_dv = '1' and CPHA = '0') then
					o_MOSI <= tx_byte(7);
					tx_bit_cont <= "110";
				elsif((flanco_principal = '1' and CPHA = '1') or (flanco_ultimo = '1' and CPHA = '0')) then
					tx_bit_cont <= tx_bit_cont - 1;
					o_MOSI 		<= tx_byte(to_integer(tx_bit_cont));
				end if;
			end if;
		end process pr_3;
	
	--Leer dato MISO
	pr_4: process(i_clk, i_rst_low)
		begin 
			if(i_rst_low = '0') then 
				o_rx_byte 	<= x"00";
				o_rx_dv		<= '0';
				rx_bit_cont	<= "111";
			elsif(rising_edge(i_clk)) then	
				o_rx_dv	<= '0';
				if(tx_listo = '1') then 
					rx_bit_cont <= "111";
				elsif((flanco_principal = '1' and CPHA = '0') or (flanco_ultimo = '1' and CPHA = '1')) then
					o_rx_byte(to_integer(rx_bit_cont)) <= i_MISO;
					rx_bit_cont	<= rx_bit_cont-1;
					if(rx_bit_cont = "000")then 
						o_rx_dv <= '1';
					end if;
				end if;
			end if;
		end process pr_4;
	
	--Añado retardo de reloj para alinear los clocks
	pr_5: process(i_clk, i_rst_low)
		begin 
			if(i_rst_low = '0') then 
				o_spi_clk <= CPOL;
			elsif(rising_edge(i_clk)) then
				o_spi_clk <= spi_clk;
			end if;
		end process;
	
	o_tx_listo <= tx_listo;
				
end architecture behav;
	