library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master_cs is
  generic (
    MODO_SPI          	: integer := 1;
    CLKS_MITAD_BIT 		: integer := 2;
    MAX_BYTES_POR_CS  	: integer := 2;
    CS_CLKS_INACTIVOS  	: integer := 1
	 
    );
  port (
   i_rst_low  	:in std_logic;     						-- FPGA Reset
   i_clk   		:in std_logic;     						-- FPGA Clock
   i_tx_cont 	:in  std_logic_vector(1 downto 0);  
   i_tx_byte  	:in  std_logic_vector(7 downto 0); 
   i_tx_dv    	:in  std_logic;     
	i_MISO 		:in  std_logic;
	
   o_tx_listo 	:out std_logic;     						-- 
   o_rx_cont 	:out std_logic_vector(1 downto 0);  -- 
   o_rx_dv    	:out std_logic;  							-- 
   o_rx_byte  	:out std_logic_vector(7 downto 0);  -- 
   o_spi_clk  	:out std_logic;
   o_MOSI 		:out std_logic;
   o_CS_low 	:out std_logic
   );
end entity spi_master_cs;

architecture RTL of spi_master_cs is

	component spi_master is 
		generic(
			MODO				:integer := 0;		--Modo spi: 0,1,2,3
			CLKS_MITAD_BIT	:integer := 2		--Setea la frecuencia de o_clk. 
		);
		port(
			i_rst_low	:in std_logic;								--Reset Bajo FPGA
			i_clk			:in std_logic;								--Clk FPGA
			i_tx_byte 	:in std_logic_vector(7 downto 0); 	--Byte a transmitir en MOSI
			i_tx_dv		:in std_logic;								--Pulso de dato valido TX
			i_MISO 		:in std_logic;								--MISO
		
			o_tx_listo 	:out std_logic;						--Transmision lista para el siguiente byte.
			o_rx_dv	 	:out std_logic;							--Pulso de dato valido RX
			o_rx_byte 	:out std_logic_vector(7 downto 0);	--Byte recibido de MISO
			o_MOSI		:out std_logic;							--MOSI
			o_spi_clk	:out std_logic								--SPI CLK
		);
	end component spi_master;

  type estado is (IDLE, TRANSFERENCIA, CS_INACTIVO);

  signal proximo : estado;
  signal cs_low : std_logic;
  signal cs_inactivo_cont : integer range 0 to CS_CLKS_INACTIVOS;
  signal tx_cont : integer range 0 to MAX_BYTES_POR_CS + 1;
  signal tx_listo : std_logic;
  signal rx_dv		:std_logic;
  signal rx_cont 	:std_logic_vector(1 downto 0);

begin

  -- Instantiate Master
  master: entity work.spi_master
    generic map (
      MODO          => MODO_SPI,
      CLKS_MITAD_BIT => CLKS_MITAD_BIT)
    port map (
      i_rst_low 	=> i_rst_low,            
      i_clk      	=> i_clk,              
      i_tx_byte  	=> i_tx_byte,         
      i_tx_dv    	=> i_tx_dv,  
		i_MISO 		=> i_MISO,
      o_tx_listo 	=> tx_listo,    
      o_rx_dv    	=> rx_dv,           
      o_rx_byte  	=> o_RX_Byte,        
      o_spi_clk  	=> o_spi_clk,  
      o_MOSI		=> o_MOSI
      );
  
  pr_1 : process (i_clk, i_rst_low) is
  begin
    if i_rst_low = '0' then
      proximo           <= IDLE;
      cs_low            <= '1';  
      tx_cont          	<= 0;
      cs_inactivo_cont 	<= CS_CLKS_INACTIVOS;
    elsif rising_edge(i_Clk) then

      case proximo is
        when IDLE =>
			if (cs_low = '1' and i_tx_dv = '1') then 
            tx_cont <= to_integer(unsigned(i_tx_cont) - 1); 
            cs_low     <= '0';       
            proximo    <= TRANSFERENCIA;  
          end if;

        when TRANSFERENCIA =>
			if tx_listo = '1' then
				if tx_cont > 0 then
					if i_tx_dv = '1' then
						tx_cont <= tx_cont - 1;
					end if;
            else
					cs_low            <= '1'; 
					cs_inactivo_cont	<= CS_CLKS_INACTIVOS;
					proximo          	<= CS_INACTIVO;
            end if;
          end if;
          
        when CS_INACTIVO =>
			 
          if cs_inactivo_cont > 0 then
            cs_inactivo_cont <= cs_inactivo_cont - 1;
          else
            proximo <= IDLE;
          end if;

        when others => 
          cs_low  <= '1';
          proximo <= IDLE;
      end case;
    end if;
  end process pr_1; 

  
  pr_2 : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if cs_low = '1' then
        rx_cont <= std_logic_vector(to_unsigned(0, rx_cont'length));
      elsif rx_dv = '1' then
        rx_cont <= std_logic_vector(unsigned(rx_cont) + 1);
      end if;
    end if;
  end process pr_2;
  
  o_tx_listo <= '1' when i_tx_dv /= '1' and ((proximo = IDLE) or (proximo = TRANSFERENCIA and tx_listo = '1' and tx_cont > 0)) else '0';
  o_rx_dv <= rx_dv;
  o_rx_cont <= rx_cont;
  o_CS_low <= cs_low;  
end architecture RTL;