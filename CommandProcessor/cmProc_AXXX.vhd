library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
-- library UNISIM;
--use UNISIM.VCOMPONENTS.ALL;
-- use UNISIM.VPKG.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity cmdProc is
   port (
      clk:	in std_logic;
      reset:	in std_logic;
      rxnow:	in std_logic;
      rxData:	in std_logic_vector (7 downto 0);
      txData:	out std_logic_vector (7 downto 0);
      rxdone:	out std_logic;
      ovErr:	in std_logic;
      framErr:	in std_logic;
      txnow:	out std_logic;
      txdone:	in std_logic;
      start:    out std_logic;
      numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
      dataReady: in std_logic;
      byte:     in std_logic_vector(7 downto 0);
      maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
      dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
      seqDone:  in std_logic
    );
end cmdProc;

architecture Behavioral of cmdProc is
   Type state_type is (INIT, TRANSMIT, BYTE_TO_BCD, RX_DONE_LOW, SEND_TO_DP, START_HIGH, DETA_READY, SEND_TX_1, SEND_TX_2, SEND_SPACE);
   Signal curState, nextState : state_type;
   signal count_numbers, count_send : integer := 0;
   signal tem_BCD, tem_Data_to_BCD : std_logic_vector(11 downto 0);
   signal rxdone_temp : std_logic := '0';
   signal ASCII1, ASCII2 : std_logic_vector(7 downto 0);
begin

-- This process increment counter when a number is received from rxData and reset otherwise
count_number: process(rxData)
begin
--   if clk'event and clk = '1' then
      if rxData = "00110000" or 
         rxData = "00110001" or 
         rxData = "00110010" or 
         rxData = "00110011" or 
         rxData = "00110100" or 
         rxData = "00110101" or 
         rxData = "00110110" or 
         rxData = "00110111" or 
         rxData = "00111000" or 
         rxData = "00111001" then
         count_numbers <= count_numbers + 1;
      else
         count_numbers <= 0;
      end if;
--   end if;
end process;


-- This register saves the BCD of numbers to be sent to Data processor
numbers_register: process(clk, tem_Data_to_BCD)
begin
   if clk'event and clk = '1' then
      tem_BCD <= tem_Data_to_BCD;
   end if;
end process;

process(txdone)
begin
   if txdone = '0' then
      txnow <= '0';
   end if;
end process;

set_rxdone_high_proc: process(clk, rxdone_temp)
begin
   
   if clk'event and clk= '1' then
      if rxdone_temp = '1' then
         rxdone <= '1';
      else
         rxdone <= '0';
      end if;
      rxdone_temp <= '0';
   end if;
end process;

byte_to_ASCII: process(byte)
  begin
      case byte(7 downto 4) is
        when "0000" => ASCII1 <= "00110000";  -- '0'
        when "0001" => ASCII1 <= "00110001";  -- '1'
        when "0010" => ASCII1 <= "00110010";  -- '2'
        when "0011" => ASCII1 <= "00110011";  -- '3'
        when "0100" => ASCII1 <= "00110100";  -- '4'
        when "0101" => ASCII1 <= "00110101";  -- '5'
        when "0110" => ASCII1 <= "00110110";  -- '6'
        when "0111" => ASCII1 <= "00110111";  -- '7'
        when "1000" => ASCII1 <= "00111000";  -- '8'
        when "1001" => ASCII1 <= "00111001";  -- '9'
        when "1010" => ASCII1 <= "01000001";  -- 'A'
        when "1011" => ASCII1 <= "01000010";  -- 'B'
        when "1100" => ASCII1 <= "01000011";  -- 'C'
        when "1101" => ASCII1 <= "01000100";  -- 'D'
        when "1110" => ASCII1 <= "01000101";  -- 'E'
        when "1111" => ASCII1 <= "01000110";  -- 'F'
        when others => ASCII1 <= "01000110";  -- '?' (default for unknown values)
      end case;
            case byte(3 downto 0) is
        when "0000" => ASCII2 <= "00110000";  -- '0'
        when "0001" => ASCII2 <= "00110001";  -- '1'
        when "0010" => ASCII2 <= "00110010";  -- '2'
        when "0011" => ASCII2 <= "00110011";  -- '3'
        when "0100" => ASCII2 <= "00110100";  -- '4'
        when "0101" => ASCII2 <= "00110101";  -- '5'
        when "0110" => ASCII2 <= "00110110";  -- '6'
        when "0111" => ASCII2 <= "00110111";  -- '7'
        when "1000" => ASCII2 <= "00111000";  -- '8'
        when "1001" => ASCII2 <= "00111001";  -- '9'
        when "1010" => ASCII2 <= "01000001";  -- 'A'
        when "1011" => ASCII2 <= "01000010";  -- 'B'
        when "1100" => ASCII2 <= "01000011";  -- 'C'
        when "1101" => ASCII2 <= "01000100";  -- 'D'
        when "1110" => ASCII2 <= "01000101";  -- 'E'
        when "1111" => ASCII2 <= "01000110";  -- 'F'
        when others => ASCII2 <= "01000110";  -- '?' (default for unknown values)
      end case;
  end process;


nextState_logic: process(curState, rxData, byte, txdone, dataReady)
begin
   case curState is     
      when INIT =>
         rxdone <= '0';
         txnow <= '0';
         start <= '0';
         nextState <= TRANSMIT;
      when TRANSMIT =>
         if rxnow = '1' then
            if rxData = "01000001" or rxData = "01100001" then
               nextState <= BYTE_TO_BCD;
               rxdone <= '1';
            else
              nextState <= BYTE_TO_BCD;
            end if;
         end if;
      when BYTE_TO_BCD =>
        if rxnow = '1' then
         if rxData = "00110000" or 
            rxData = "00110001" or 
            rxData = "00110010" or 
            rxData = "00110011" or 
            rxData = "00110100" or 
            rxData = "00110101" or 
            rxData = "00110110" or 
            rxData = "00110111" or 
            rxData = "00111000" or 
            rxData = "00111001" then
            if count_numbers = 1 then
               tem_Data_to_BCD(11 downto 8) <= rxData(3 downto 0);
            elsif count_numbers = 2 then
               tem_Data_to_BCD(7 downto 4) <= rxData(3 downto 0);      
            elsif count_numbers = 3 then
               tem_Data_to_BCD(3 downto 0) <= rxData(3 downto 0);
            end if;
            rxdone <= '1';
            nextState <= RX_DONE_LOW;
         else
            nextState <= INIT;
         end if;
       end if;
      when RX_DONE_LOW =>
         rxdone <= '0';
         if count_numbers = 3 then
            nextState <= SEND_TO_DP;
         else
            nextState <= INIT;
         end if;
      when SEND_TO_DP =>
         numWords_bcd(2) <= tem_BCD(11 downto 8);
         numWords_bcd(1) <= tem_BCD(7 downto 4);
         numWords_bcd(0) <= tem_BCD(3 downto 0);
         nextState <= START_HIGH;

      when START_HIGH =>
         start <= '1';
         nextState <= DETA_READY;
      when DETA_READY =>
         if dataReady = '1' then
            nextState <= SEND_TX_1;
         else
            nextState <= DETA_READY;
         end if;
      when SEND_TX_1 =>
            if txdone = '1' then
               txnow <= '1';
               txData <= ASCII1;
               count_send <= count_send + 1;
               nextState <= SEND_TX_2;
            else
               nextState <= SEND_TX_1;
            end if;
      when SEND_TX_2 =>
            if txdone = '1' then
               txnow <= '1';
               txData <= ASCII2;
               count_send <= count_send + 1;
               nextState <= SEND_SPACE;
            else
               nextState <= SEND_TX_2;
            end if;
      when SEND_SPACE =>
            if txdone = '1' then
               txnow <= '1';
               txData <= "00100000";
               count_send <= count_send + 1;
               if seqDone = '0' then
                  nextState <= DETA_READY;
               else
                  nextState <= INIT;
               end if;
            end if;
      when others =>
         nextState <= INIT;
   end case;
end process;


seq_state: process(clk, reset)
begin
   if reset = '1' then
      curState <= INIT;
   elsif clk'event and clk = '1' then
      curState <= nextState;
   end if;
end process;

end Behavioral;
