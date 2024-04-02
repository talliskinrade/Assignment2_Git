----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.02.2024 12:56:30
-- Design Name: 
-- Module Name: cmdProc - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


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
   Type state_type is (TRANSMIT, BYTE_TO_BCD, RX_DONE, SEND_TO_DP, START_HIGH, BYTE_TO_ASCII, RESET_COUNTER, SEND_TX, SEND_SPACE, STORE_RESULT);
   Signal curState, nextState : state_type;
   signal count_numbers, count_send : integer := 0;
   signal tem_BCD, tem_Data_to_BCD : std_logic_vector(11 downto 0);
   signal tem_ASCII, tem_ASCII_in : std_logic_vector(7 downto 0);
begin

-- This process increment counter when a number is received from rxData and reset otherwise
count_number: process(clk)
begin
   if clk'event and clk = '1' then
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
   end if;
end process;


-- This register saves the BCD of numbers to be sent to Data processor
numbers_register: process(clk)
begin
   if clk'event and clk = '1' then
      tem_BCD <= tem_Data_to_BCD;
   end if;
end process;


--  This register save the ASCII values before bing send 
byte_to_ASCII_register: process(clk)
begin
   if clk'event and clk = '1' then
      tem_ASCII <= tem_ASCII_in;
   end if;
end process;
      

nextState_logic: process(curState)
begin
   case curState is
      when TRANSMIT =>
         if rxNow = '1' and (rxData = "01000001" or rxData = "01100001") then
           nextState <= BYTE_TO_BCD;
         else
           nextState <= TRANSMIT;
         end if;
      when BYTE_TO_BCD =>
         if rxData = "00110000" or rxData = "00110001" or rxData = "00110010" or rxData = "00110011" or rxData = "00110100" or rxData = "00110101" or rxData = "00110110" or rxData = "00110111" or rxData = "00111000" or rxData = "00111001" then
            if count_numbers = 1 then
               tem_Data_to_BCD(11 downto 8) <= rxData(3 downto 0);
            elsif count_numbers = 2 then
               tem_Data_to_BCD(7 downto 4) <= rxData(3 downto 0);      
            elsif count_numbers = 3 then
               tem_Data_to_BCD(3 downto 0) <= rxData(3 downto 0);
            end if;
            nextState <= RX_DONE;
         else
            nextState <= TRANSMIT;
         end if;
      when RX_DONE =>
         rxdone <= '1';
         nextState <= SEND_TO_DP;
      when SEND_TO_DP =>
         numWords_bcd(2) <= tem_BCD(11 downto 8);
         numWords_bcd(1) <= tem_BCD(7 downto 4);
         numWords_bcd(0) <= tem_BCD(3 downto 0);
         nextState <= START_HIGH;

      when START_HIGH =>
         start <= '1';
         nextState <= BYTE_TO_ASCII;

      when BYTE_TO_ASCII =>
         if dataready = '1' then
            -- 0
            if byte(7 downto 0) = "00000000" then
               tem_ASCII_in(7 downto 0) <= "00110000";
            -- 1
            elsif byte(7 downto 0) = "00000001" then
               tem_ASCII_in(7 downto 0) <= "00110001";
            -- 2
            elsif byte(7 downto 0) = "00000010" then
               tem_ASCII_in(7 downto 0) <= "00110010";
            -- 3
            elsif byte(7 downto 0) = "00000011" then
               tem_ASCII_in(7 downto 0) <= "00110011";
            -- 4
            elsif byte(7 downto 0) = "00000100" then
               tem_ASCII_in(7 downto 0) <= "00110100";
            -- 5
            elsif byte(7 downto 0) = "00000101" then
               tem_ASCII_in(7 downto 0) <= "00110101";
            -- 6
            elsif byte(7 downto 0) = "00000110" then
               tem_ASCII_in(7 downto 0) <= "00110110";
            -- 7
            elsif byte(7 downto 0) = "00000111" then
               tem_ASCII_in(7 downto 0) <= "00110111";
            -- 8
            elsif byte(7 downto 0) = "00001000" then
               tem_ASCII_in(7 downto 0) <= "00111000";
            -- 9
            elsif byte(7 downto 0) = "00001001" then
               tem_ASCII_in(7 downto 0) <= "00111001";
            -- 10 >>> A
            elsif byte(7 downto 0) = "00001010" then
               tem_ASCII_in(7 downto 0) <= "01001010";
            -- 11 >>> B
            elsif byte(7 downto 0) = "00001011" then
               tem_ASCII_in(7 downto 0) <= "01000010";
            -- 12 >>> C
            elsif byte(7 downto 0) = "00001100" then
               tem_ASCII_in(7 downto 0) <= "01000011";
            -- 13 >>> D
            elsif byte(7 downto 0) = "00001101" then
               tem_ASCII_in(7 downto 0) <= "01000100";
            -- 14 >>> E
            elsif byte(7 downto 0) = "00001110" then
               tem_ASCII_in(7 downto 0) <= "01000101";
            -- 15 >>> F
            elsif byte(7 downto 0) = "00001111" then
               tem_ASCII_in(7 downto 0) <= "01000110";
            end if;
            nextState <= SEND_TX;
         else
            nextState <= BYTE_TO_ASCII;
         end if;
      when SEND_TX =>
         if count_send < 2 then
            if txdone = '1' then
               txnow <= '1';
               txData <= tem_ASCII(7 downto 0);
               count_send <= count_send + 1;
               nextState <= BYTE_TO_ASCII;
            else 
               nextState <= SEND_TX;
            end if;
         elsif count_send = 2 then
            if txdone = '1' then
               txnow <= '1';
               txData <= "00100000";
               count_send <= 0;
               nextState <= BYTE_TO_ASCII;
            else 
               nextState <= SEND_TX;
            end if;
         end if;
   end case;
end process;


seq_state: process(clk, reset)
begin
   if reset = '1' then
      -- TO INNIT once intergrated with other codes
      curState <= TRANSMIT;
   elsif clk'event and clk = '1' then
      curState <= nextState;
   end if;
end process;

end Behavioral;

