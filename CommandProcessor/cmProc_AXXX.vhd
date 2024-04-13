library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
-- library UNISIM;
--use UNISIM.VCOMPONENTS.ALL;
-- use UNISIM.VPKG.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed OR Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY cmdProc IS
   pORt (
      clk:	IN std_logic;
      reset:	IN std_logic;
      rxnow:	IN std_logic;
      rxData:	IN std_logic_vectOR (7 downto 0);
      txData:	OUT std_logic_vectOR (7 downto 0);
      rxdone:	OUT std_logic;
      ovErr:	IN std_logic;
      framErr:	IN std_logic;
      txnow:	OUT std_logic;
      txdone:	IN std_logic;
      start:    OUT std_logic;
      numWORds_bcd: OUT BCD_ARRAY_TYPE(2 downto 0);
      dataReady: IN std_logic;
      byte:     IN std_logic_vectOR(7 downto 0);
      maxIndex: IN BCD_ARRAY_TYPE(2 downto 0);
      dataResults: IN CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
      seqDone:  IN std_logic
    );
END cmdProc;

ARCHITECTURE BehaviORal OF cmdProc IS
   Type state_type is (INIT, TRANSMIT, BYTE_TO_BCD, RX_DONE_LOW, SEND_TO_DP_A, START_HIGH, DETA_READY, SEND_TX_1, SEND_TX_2, SEND_SPACE);
   SIGNAL cur_state, next_state : state_type;
   SIGNAL count_numbers, count_send : integer := 0;
   SIGNAL tem_BCD, tem_Data_to_BCD : std_logic_vectOR(11 downto 0);
   SIGNAL rxdone_temp : std_logic := '0';
   SIGNAL ASCII1, ASCII2 : std_logic_vectOR(7 downto 0);
   signal prev_seqDone, seqDone_temp : std_logic := '0';
   signal byte_complete, count_reset : std_logic := '0';
BEGIN

-- This PROCESS increment counter when a number is received from rxData and reset otherwise
count_number: PROCESS(rxData, count_reset)
BEGIN
   IF count_reset = '0' THEN
      IF rxData = "00110000" OR 
         rxData = "00110001" OR 
         rxData = "00110010" OR 
         rxData = "00110011" OR 
         rxData = "00110100" OR 
         rxData = "00110101" OR 
         rxData = "00110110" OR 
         rxData = "00110111" OR 
         rxData = "00111000" OR 
         rxData = "00111001" THEN
         count_numbers <= count_numbers + 1;
      ELSE
         count_numbers <= 0;
      END IF;
   ELSE
      count_numbers <= 0;
      count_reset <= '0';
   END IF;

END PROCESS;


-- This register saves the BCD OF numbers to be sent to Data PROCESSOR
numbers_register: PROCESS(clk, tem_Data_to_BCD)
BEGIN
   IF clk'EVENT AND clk = '1' THEN
      tem_BCD <= tem_Data_to_BCD;
   END IF;
END PROCESS;

PROCESS(txdone)
BEGIN
   IF txdone = '0' THEN
      txnow <= '0';
   END IF;
END PROCESS;

--PROCESS(clk)
--BEGIN
--    IF clk'EVENT and CLK = '1' THEN
--        IF rxdone = '1' THEN
--            rxdone <= '0';  -- Set rxdone low after one clock cycle
--        END IF;
--    END IF;
--END PROCESS;


set_rxdone_high_proc: PROCESS(clk, rxdone_temp)
BEGIN 
   IF clk'EVENT AND clk= '1' THEN
      IF rxdone_temp = '1' THEN
         rxdone <= '1';
      ELSE
         rxdone <= '0';
      END IF;
      rxdone_temp <= '0';
   END IF;
END PROCESS;


-- process(seqDone)
-- begin
----    if clk'event and clk = '1' then
--        if seqDone = '1' then
--            seqDone_temp <= '1';  -- Set Start signal to low
--        else
--           seqDone_temp <= seqDone_temp;
--        end if;
----     end if;
--    end process;

byte_to_ASCII: PROCESS(byte)
  BEGIN
      CASE byte(7 downto 4) is
        WHEN "0000" => ASCII1 <= "00110000";  -- '0'
        WHEN "0001" => ASCII1 <= "00110001";  -- '1'
        WHEN "0010" => ASCII1 <= "00110010";  -- '2'
        WHEN "0011" => ASCII1 <= "00110011";  -- '3'
        WHEN "0100" => ASCII1 <= "00110100";  -- '4'
        WHEN "0101" => ASCII1 <= "00110101";  -- '5'
        WHEN "0110" => ASCII1 <= "00110110";  -- '6'
        WHEN "0111" => ASCII1 <= "00110111";  -- '7'
        WHEN "1000" => ASCII1 <= "00111000";  -- '8'
        WHEN "1001" => ASCII1 <= "00111001";  -- '9'
        WHEN "1010" => ASCII1 <= "01000001";  -- 'A'
        WHEN "1011" => ASCII1 <= "01000010";  -- 'B'
        WHEN "1100" => ASCII1 <= "01000011";  -- 'C'
        WHEN "1101" => ASCII1 <= "01000100";  -- 'D'
        WHEN "1110" => ASCII1 <= "01000101";  -- 'E'
        WHEN "1111" => ASCII1 <= "01000110";  -- 'F'
        WHEN others => ASCII1 <= "01000110";  -- '?' (default fOR unknown values)
      END CASE;
            CASE byte(3 downto 0) is
        WHEN "0000" => ASCII2 <= "00110000";  -- '0'
        WHEN "0001" => ASCII2 <= "00110001";  -- '1'
        WHEN "0010" => ASCII2 <= "00110010";  -- '2'
        WHEN "0011" => ASCII2 <= "00110011";  -- '3'
        WHEN "0100" => ASCII2 <= "00110100";  -- '4'
        WHEN "0101" => ASCII2 <= "00110101";  -- '5'
        WHEN "0110" => ASCII2 <= "00110110";  -- '6'
        WHEN "0111" => ASCII2 <= "00110111";  -- '7'
        WHEN "1000" => ASCII2 <= "00111000";  -- '8'
        WHEN "1001" => ASCII2 <= "00111001";  -- '9'
        WHEN "1010" => ASCII2 <= "01000001";  -- 'A'
        WHEN "1011" => ASCII2 <= "01000010";  -- 'B'
        WHEN "1100" => ASCII2 <= "01000011";  -- 'C'
        WHEN "1101" => ASCII2 <= "01000100";  -- 'D'
        WHEN "1110" => ASCII2 <= "01000101";  -- 'E'
        WHEN "1111" => ASCII2 <= "01000110";  -- 'F'
        WHEN others => ASCII2 <= "01000110";  -- '?' (default fOR unknown values)
      END CASE;
  END PROCESS;


next_state_logic: PROCESS(cur_state, rxData, byte, txdone, dataReady, seqDone)
BEGIN
   CASE cur_state IS     
      WHEN INIT =>
         --rxdone <= '1';
         txnow <= '0';
         start <= '0';
         byte_complete <= '0';
         next_state <= TRANSMIT;
      WHEN TRANSMIT =>
         IF rxnow = '1' THEN
            --rxdone <= '1';
            IF rxData = "01000001" OR rxData = "01100001" THEN
               rxdone <= '1';
               next_state <= BYTE_TO_BCD;
               --rxdone <= '1';
            ELSE
              next_state <= BYTE_TO_BCD;
            END IF;
         END IF;
      WHEN BYTE_TO_BCD =>
        IF rxnow = '1' THEN
         rxdone <= '1';
         IF rxData = "00110000" OR 
            rxData = "00110001" OR 
            rxData = "00110010" OR 
            rxData = "00110011" OR 
            rxData = "00110100" OR 
            rxData = "00110101" OR 
            rxData = "00110110" OR 
            rxData = "00110111" OR 
            rxData = "00111000" OR 
            rxData = "00111001" THEN
            IF count_numbers = 1 THEN
               tem_Data_to_BCD(11 downto 8) <= rxData(3 downto 0);
            ELSIF count_numbers = 2 THEN
               tem_Data_to_BCD(7 downto 4) <= rxData(3 downto 0);      
            ELSIF count_numbers = 3 THEN
               tem_Data_to_BCD(3 downto 0) <= rxData(3 downto 0);
            END IF;
            --rxdone <= '1';
            next_state <= RX_DONE_LOW;
         ELSE
            next_state <= INIT;
         END IF;
       END IF;
      WHEN RX_DONE_LOW =>
         rxdone <= '0';
         IF count_numbers = 3 THEN
            next_state <= SEND_TO_DP_A;
            count_reset <= '1';
         ELSE
            next_state <= INIT;
         END IF;
      WHEN SEND_TO_DP_A =>
         numWORds_bcd(2) <= tem_BCD(11 downto 8);
         numWORds_bcd(1) <= tem_BCD(7 downto 4);
         numWORds_bcd(0) <= tem_BCD(3 downto 0);
         tem_Data_to_BCD(11 downto 0) <="000000000000";
         next_state <= START_HIGH;
      WHEN START_HIGH =>
         start <= '1';
         next_state <= DETA_READY;
      WHEN DETA_READY =>
      IF byte_complete = '0' THEN
         IF dataReady = '1' THEN
            next_state <= SEND_TX_1;
         ELSE
            next_state <= DETA_READY;
         END IF;
         IF seqDone = '1' THEN
            start <= '0';
         END IF;
      ELSE
         next_state <= INIT;
      END IF;
      WHEN SEND_TX_1 =>
            IF txdone = '1' THEN
               txnow <= '1';
               txData <= ASCII1;
               next_state <= SEND_TX_2;
               IF seqDone = '1' THEN
                  start <= '0';
               END IF;
            ELSE
               next_state <= SEND_TX_1;
            END IF;
            IF seqDone = '1' THEN
               start <= '0';
               byte_complete <= '1';
            END IF;
      WHEN SEND_TX_2 =>
            IF txdone = '1' THEN
               txnow <= '1';
               txData <= ASCII2;
               count_send <= count_send + 1;
               next_state <= SEND_SPACE;
            ELSE
               next_state <= SEND_TX_2;
            END IF;
            IF seqDone = '1' THEN
               start <= '0';
               byte_complete <= '1';
            END IF;
      WHEN SEND_SPACE =>
            IF txdone = '1' THEN
               txnow <= '1';
               txData <= "00100000";
               IF seqDone = '0' THEN
                  next_state <= DETA_READY;
               ELSIF seqDone = '1' then
                  start <= '0';
                  byte_complete <= '1';
                  next_state <= INIT;
               END IF;
            END IF;
      WHEN others =>
         next_state <= INIT;
   END CASE;
END PROCESS;


seq_state: PROCESS(clk, reset)
BEGIN
   IF reset = '1' THEN
      cur_state <= INIT;
   ELSIF clk'EVENT AND clk = '1' THEN
      cur_state <= next_state;
   END IF;
END PROCESS;

END BehaviORal;
