library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MLX90614 is 
	port(
		i_clk 		:in std_logic;
		i_rst_low	:in std_logic;
		i_enable		:in std_logic;

		io_sda		:inout std_logic;

		o_estado 	:out std_logic_vector(4 downto 0);
		o_busy 		:out std_logic;
		o_scl 		:out std_logic;	
		o_temp_inf	:out std_logic_vector(15 downto 0)
	);
end entity MLX90614;

architecture behav of MLX90614 is 

	type FSM_states is (IDLE, ADDR1, ADDR2, COMANDO, BYTE_LOW, BYTE_HIGH, PEC, STOP,
							TEMP1, TEMP2, TEMP3, TEMP4, TEMP5, TEMP6, 
							SACK1, SACK2, WSACK, RACK1, RACK2, RACK3);
	signal current_state, next_state 	:FSM_states;
	
	--Establezco el estilo de codificacion.
	attribute syn_encoding :string;
	attribute syn_encoding of FSM_states : type is "one_hot";
	
	signal shift_add	:std_logic_vector(6 downto 0);	--Registro de direccion
	signal shift_data	:std_logic_vector(7 downto 0);	--Registro de comando 
	signal shift_temp :std_logic_vector(15 downto 0);	--Registro de datos de temperatura
	signal shift_pec	:std_logic_vector(7 downto 0);	--Registro pec (package error control)
	signal rw 			:std_logic;								--Bit de lectura/escritura. Igual a 1 ya que leemos todo el tiempo.
	signal ack_add 	:std_logic;								--ACK address 
	signal ack_dat 	:std_logic;								--ACK dato 
	signal contador 	:unsigned(3 downto 0);				--Contador de proposito general 
	
	signal clk_100KHz	:std_logic;
	signal salida 		:std_logic := '0';
	signal clk_cnt		:integer range 0 to 63;
		
begin 
		
	--Proceso divisor de frecuencia
	div: process(i_clk, i_rst_low)
		begin 
			if(i_rst_low = '0') then 
				salida <= '0';
				clk_cnt <= 0;
			elsif(rising_edge(i_clk)) then
				if(clk_cnt = 63) then 
					clk_cnt 	<= 0;
					salida 	<= not salida;
				else 
					clk_cnt <= clk_cnt + 1;
				end if;
			end if;
		end process;
		
	clk_100KHz <= salida; 
		
	--Proceso de proximo estado
	nx_pr: process (clk_100KHz, i_rst_low)
		begin 
			if(i_rst_low = '0') then 
				io_sda 			<= '1';
				o_scl 			<= '1';
				shift_add 		<= "0000000";
				shift_data 		<= x"00";
				contador 		<= x"0";
				o_busy 			<= '1';
				next_state 		<= IDLE;
			elsif(clk_100KHz'event and clk_100KHz = '0') then 
				case next_state is 
					when IDLE => 	
						o_busy 	<= '1';
						io_sda 	<= '1';
						o_scl		<= '1';
						if (i_enable = '0') then 
							o_busy 		<= '1';
							io_sda 		<= '0';			--bit de start
							shift_add 	<= "1011010";	--Direccion de periferico
							shift_data 	<= x"07";		--Comando para lectura de temperatura objeto
							rw 			<= '0';			--bit de escritura
							contador 	<= "0000";
							next_state 	<= ADDR1;
						else 
							next_state 	<= IDLE;
						end if;
					
					when ADDR1 => 							--Cargo direccion y rw bit
						if (contador < x"7") then 
							o_busy 		<= '1';
							o_scl 		<= '0';
							io_sda 		<= shift_add(6);
							shift_add 	<= shift_add(5 downto 0) & 'U';
							contador		<= contador + 1;
							next_state 	<= TEMP1;
						elsif(contador = x"7") then 
							o_busy 		<= '1';
							o_scl 		<= '0';
							io_sda 		<= rw;
							contador 	<= contador + 1;
							next_state 	<= TEMP1;
						elsif(contador = x"8") then
							o_busy 		<= '0';
							o_scl			<= '0';
							io_sda 		<= 'Z';
							next_state 	<= SACK1;
--						elsif(contador < x"B") then 
--							o_busy 		<= '1';
--							io_sda 		<= '1';
--							o_scl 		<= '0';
--							contador <= contador + 1;
--							next_state <= ADDR1;
						else 
							o_scl 		<= '0';
							contador 	<= x"0";
							next_state 	<= COMANDO;
						end if;
						
					when SACK1 => 		--ACK de esclavo posterior a envio de direccion
						ack_add 			<= io_sda;
						o_scl 			<= '1';
						contador 		<= contador + 1;
						next_state 		<= ADDR1;
						
					when COMANDO => 
						if (contador < x"8") then 
							o_busy 		<= '1';
							o_scl 		<= '0';
							io_sda 		<= shift_data(7);
							shift_data 	<= shift_data(6 downto 0) & 'U';
							contador 	<= contador + 1; 
							next_state 	<= TEMP2;
						elsif(contador = x"8") then 	--ACK 
							o_busy 		<= '0';
							io_sda 		<= 'Z';
							o_scl 		<= '0';
							next_state 	<= WSACK;
						else 
							o_busy 		<= '1';
							o_scl 		<= '1';
							io_sda 		<= '1';
							contador 	<= x"0";
							next_state 	<= ADDR2;
						end if;
						
					when WSACK =>		--ACK de esclavo para escritura 
						ack_dat 			<= io_sda;
						contador 		<= contador + 1;
						o_scl 			<= '1';
						next_state 		<= COMANDO;
											
					when ADDR2 => 
						if (contador = x"0") then 
							o_busy 		<= '1';
							io_sda 		<= '0';			--bit de start
							shift_add 	<= "1011010";	--Direccion de periferico
							shift_data 	<= x"07";		--Comando para lectura de temperatura objeto
							rw 			<= '1';			--bit de lectura
							contador 	<= contador + 1;
							next_state 	<= ADDR2;
						elsif (contador < x"8" and contador > x"0") then 
							o_busy 		<= '1';
							o_scl 		<= '0';
							io_sda 		<= shift_add(6);
							shift_add 	<= shift_add(5 downto 0) & 'U';
							contador		<= contador + 1;
							next_state 	<= TEMP3;
						elsif(contador = x"8") then 
							o_busy 		<= '1';
							o_scl 		<= '0';
							io_sda 		<= rw;
							contador 	<= contador + 1;
							next_state 	<= TEMP3;
						elsif(contador = x"9") then
							o_busy 		<= '0';
							io_sda 		<= 'Z';
							o_scl			<= '0';
							next_state 	<= SACK2;
						else 
							o_scl 		<= '0';
							contador 	<= x"0";
							next_state 	<= BYTE_LOW;
						end if;
						
					when SACK2 => 		--ACK de esclavo posterior a envio de direccion
						ack_add 			<= io_sda;
						o_scl 			<= '1';
						contador 		<= contador + 1;
						next_state 		<= ADDR2;					 
						
					when BYTE_LOW => 
						if (contador < x"8") then --Lectura del dato que manda el esclavo
							o_scl 		<= '1';
							shift_temp(7 downto 0) <= shift_temp(6 downto 0) & io_sda;
							contador 	<= contador + 1;
							next_state 	<= TEMP4;
						elsif(contador = x"8") then --ACK
							o_busy 		<= '1';
							o_scl 		<= '0';
							io_sda 		<= '0';	--ACK;
							contador 	<= contador + 1;
							next_state 	<= RACK1; 
						else	
							contador 	<= x"0";
							next_state 	<= BYTE_HIGH;
						end if;
						
					when RACK1 => --ACK read
						o_scl 			<= '1';
						next_state 		<= BYTE_LOW;
						
					when BYTE_HIGH => 
						if (contador < x"8") then --Lectura del dato que manda el esclavo
							o_scl 		<= '0';
							shift_temp(15 downto 8) <= shift_temp(14 downto 8) & io_sda;
							contador 	<= contador + 1;
							next_state 	<= TEMP5;
						elsif(contador = x"8") then --ACK
							o_busy 		<= '1';
							o_scl 		<= '0';
							o_temp_inf	<= shift_temp;
							io_sda 		<= '0';	--ACK;
							contador 	<= contador + 1;
							next_state 	<= RACK2; 
						else	--Regresa a IDLE
							contador 	<= x"0";
							next_state	<= PEC;
						end if;
						
					when RACK2 => --ACK read
						o_scl 			<= '1';
						next_state 		<= BYTE_HIGH;
						
					when PEC => 
						if (contador < x"8") then --Lectura del dato que manda el esclavo
							o_scl 		<= '0';
							shift_pec(7 downto 0) <= shift_pec(6 downto 0) & io_sda;
							contador 	<= contador + 1;
							next_state 	<= TEMP6;
						elsif(contador = x"8") then --ACK
							o_busy 		<= '1';
							o_scl 		<= '0';
							io_sda 		<= '1';	--ACK;
							contador 	<= contador + 1;
							next_state 	<= RACK3; 
						else	--Regresa a IDLE
							next_state 	<= STOP;
						end if;
						
					when STOP => 
						o_busy 		<= '1';
						o_scl 		<= '1';
						io_sda 		<= '1';
						contador 	<= x"0";
						next_state 	<= IDLE;
						
					when RACK3 => --ACK read
						o_scl 			<= '1';
						next_state 		<= PEC;
					
					--Los estados temporales se usan para el control de SCLK
					when TEMP1 => 
						o_scl 			<= '1';
						next_state 		<= ADDR1; 
					
					when TEMP2 => 
						o_scl 			<= '1';
						next_state 		<= COMANDO; 
					
					when TEMP3 => 
						o_scl 			<= '1';
						next_state 		<= ADDR2; 
					
					when TEMP4 => 
						o_scl 			<= '0';
						next_state 		<= BYTE_LOW; 
						
					when TEMP5 => 
						o_scl 			<= '1';
						next_state 		<= BYTE_HIGH;
							
					when TEMP6 => 
						o_scl 			<= '1';
						next_state 		<= PEC;
				end case;
			end if;
		end process nx_pr;

	-- Create a signal for simulation purposes (allows waveform display)
  o_estado		<= "00000" when next_state = IDLE 		else
					"00001" when next_state = ADDR1 		else
               "00010" when next_state = ADDR2 		else
               "00011" when next_state = COMANDO 	else
               "00100" when next_state = BYTE_LOW 	else
					"00101" when next_state = BYTE_HIGH else
					"00110" when next_state = PEC 		else
					"00111" when next_state = TEMP1 		else
					"01000" when next_state = TEMP2 		else
					"01001" when next_state = TEMP3 		else
					"01010" when next_state = TEMP4 		else
					"01011" when next_state = TEMP5 		else
					"01100" when next_state = TEMP6 		else
					"01101" when next_state = SACK1 		else
					"01110" when next_state = SACK2 		else
					"01111" when next_state = WSACK 		else
					"10000" when next_state = RACK1 		else
					"10001" when next_state = RACK2 		else
					"10010" when next_state = RACK3 		else
               "00101"; -- should never get here
end architecture behav;