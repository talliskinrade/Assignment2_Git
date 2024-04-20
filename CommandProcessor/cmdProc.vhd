LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.all;
USE work.common_pack.all;

ENTITY cmdProc IS
    PORT (
        clk: IN std_logic;
        reset: IN std_logic;
        rxNow: IN std_logic; -- Equivalent to RX's dataReady signal
        rxData: IN std_logic_vector (7 downto 0);
        txData: OUT std_logic_vector (7 downto 0);
        rxDone: OUT std_logic;
        ovErr: IN std_logic;
        framErr: IN std_logic;
        txNow: OUT std_logic;
        txDone: IN std_logic;
        start: OUT std_logic;
        numWords_bcd: OUT BCD_ARRAY_TYPE(2 downto 0);
        dataReady: IN std_logic;
        byte: IN std_logic_vector(7 downto 0);
        maxIndex: IN BCD_ARRAY_TYPE(2 downto 0);
        dataResults: IN CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
        seqDone: IN std_logic
    );
END cmdProc;

ARCHITECTURE behavioural OF cmdProc IS
-- State Declaration
-- ALL STATE TYPES
	TYPE state_type IS (
	   INIT,
	   RECEIVE_DATA,
	   ECHO_DATA,
	   CHECK_COMMANDS,
	   RECEIVE_DATA_A,
	   ECHO_DATA_A,
	   CHECK_BYTE_A,
	   BYTE_TO_BCD_A,
	   INCREMENT_COUNT_A,
	   UPDATE_COUNTER_A,
	   BYTE_TO_ASCII_L,
	   RESET_COUNTER_3,
	   SET_TX_L,
	   SEND_TX_L,
	   RESET_COUNTER_6,
	   SET_TX_P,
	   SEND_TX_P,
	   BYTE_TO_ASCII_P,
	   BCD_TO_ASCII_P,
	   BYTE_TO_BCD, 
	   SEND_TO_DP_A,
	   DATA_READY, 
	   SEND_TX_1, 
	   SEND_TX_2, 
	   SEND_SPACE
	);
 
-- Signal Declaration
    SIGNAL cur_state, next_state: state_type;
	SIGNAL counterL7: integer range 0 to 7;
	SIGNAL counterL3: integer range 0 to 3;
	SIGNAL counterP6: integer range 0 to 5;
	SIGNAL counterA3: integer range 2 downto 0;
	SIGNAL sentDataFlag, byteToBCDFlag: std_logic;
	SIGNAL byteBuffer: std_logic_vector (0 to 7) := "00000000";
	SIGNAL dataResultsBuffer: CHAR_ARRAY_TYPE (0 to RESULT_BYTE_NUM-1);
	SIGNAL maxIndexBuffer: BCD_ARRAY_TYPE (2 downto 0);
	SIGNAL dataResultBuffer: std_logic_vector (0 to 7) := "00000000";
	SIGNAL outByteBuffer: std_logic_vector (0 to 23) := "000000000000000000000000";
	SIGNAL outMaxIndexBuffer: std_logic_vector (0 to 23) := "000000000000000000000000";
	SIGNAL outPPrinting: std_logic_vector (0 to 48) := "0000000000000000000000000000000000000000000000000";
	-------- A Printing -------
    SIGNAL ASCII1, ASCII2 : std_logic_vector(7 downto 0);
    SIGNAL regDataReady: std_logic := '0';
-------------------------------------------------------------------
--Component Instantiation

--End component instantiation
-------------------------------------------------------------------
	
BEGIN

    combi_setRXDone_echoing: PROCESS(cur_state, rxNow)
    BEGIN
        rxDone <= '0';
        IF (cur_state = RECEIVE_DATA OR cur_state = RECEIVE_DATA_A) AND rxNow = '1' THEN
	       rxDone <= '1';
	    END IF;
    END PROCESS;

    combi_sendTX: PROCESS (cur_state, txDone)
    BEGIN
        txNow <= '0';
        txData <= "00000000";

        IF (cur_state = ECHO_DATA OR cur_state = ECHO_DATA_A) AND txDone = '1' THEN
            txData <= rxData;
            txNow <= '1';
        ELSIF cur_state = SEND_TX_L THEN
            txData <= outByteBuffer(counterL3*8 to counterL3*8 + 7);
            txNow <= '1';
        ELSIF cur_state = SEND_TX_P THEN
            txData <= outPPrinting(counterP6*8 to counterP6*8 + 7);
            txNow <= '1';
        ELSIF cur_state = SEND_TX_1 AND txDone = '1' THEN
            txData <= ASCII1;
            txNow <= '1';
        ELSIF cur_state = SEND_TX_2 AND txDone = '1' THEN
            txData <= ASCII2;
            txNow <= '1';
        ELSIF cur_state = SEND_SPACE AND txDone = '1' THEN
            txData <= "00100000";
            txNow <= '1';
	    END IF;
    END PROCESS;
    
    combi_byteToBCD_A: PROCESS (cur_state, rxData)
    BEGIN
        IF cur_state = BYTE_TO_BCD_A THEN
            -- Byte in dataBuffer is an ASCII code between 00110000 and 00111001.
            -- Last 4 bits denote the BCD digit, hence we can extract this and store it in the BCD array.
            numWords_bcd(counterA3) <= rxData(3 downto 0);
            -- Repeat for all three bytes received.
        ELSIF cur_state = INIT THEN
            numWords_bcd(0) <= "0000";
            numWords_bcd(1) <= "0000";
            numWords_bcd(2) <= "0000";
        END IF;
    END PROCESS;
    
    combi_BCDToASCII_P: PROCESS (cur_state)
    BEGIN
        IF cur_state = BCD_TO_ASCII_P THEN
            -- Don't need to check if seqDone = 1 as this will have been checked in BYTE_TO_ASCII_P
            -- and will no longer be 1 as it has been a clock cycle.
            -- Every decimal character begins with the ASCII code "0011".
            outMaxIndexBuffer(0 to 3) <= "0011";
            -- First BCD digit in maxIndex
            outMaxIndexBuffer(4 to 7) <= maxIndexBuffer(2);
            outMaxIndexBuffer(8 to 11) <= "0011";
            outMaxIndexBuffer(12 to 15) <= maxIndexBuffer(1);
            outMaxIndexBuffer(16 to 19) <= "0011";
            outMaxIndexBuffer(20 to 23) <= maxIndexBuffer(0);
            -- outMaxIndexBuffer contains all three ASCII codes for the BCD digits that must be output for the max index.
        ELSIF cur_state = BCD_TO_ASCII_P OR cur_state = RESET_COUNTER_6 OR cur_state = SET_TX_P OR cur_state = SEND_TX_P THEN
            outMaxIndexBuffer <= outMaxIndexBuffer;
        ELSE
            outMaxIndexBuffer <= "000000000000000000000000";
        END IF;
    END PROCESS;
    
    combi_setOutPPrinting: PROCESS (cur_state)
    BEGIN
        IF cur_state = SET_TX_P THEN
            outPPrinting(0 to 23) <= outByteBuffer;
            outPPrinting(24 to 47) <= outMaxIndexBuffer;
        ELSIF cur_state = BYTE_TO_ASCII_P OR cur_state = BCD_TO_ASCII_P OR cur_state = SEND_TX_P THEN
            outPPrinting <= outPPrinting;
        ELSE
            outPPrinting <= "0000000000000000000000000000000000000000000000000";
        END IF;
    END PROCESS;
    
    combi_count6_P: PROCESS (cur_state)
    BEGIN
        IF cur_state = SEND_TX_P THEN
            counterP6 <= counterP6 + 1;
        ELSIF cur_state = BYTE_TO_ASCII_P OR cur_state = BCD_TO_ASCII_P OR cur_state = SET_TX_P THEN
            counterP6 <= counterP6;
        ELSE
            counterP6 <= 0;
        END IF;
    END PROCESS;
    
    combi_setDataResultBuffer: PROCESS (cur_state)
    BEGIN
        dataResultBuffer <= "00000000";
        IF cur_state = BYTE_TO_ASCII_L THEN
            dataResultBuffer <= dataResultsBuffer(counterL7);
        ELSIF cur_state = BYTE_TO_ASCII_P THEN
            dataResultBuffer <= dataResultsBuffer(3);
        END IF;
    END PROCESS;
    
    combi_readDataResults: PROCESS (seqDone)
    BEGIN
        IF cur_state = SEND_TX_1 AND seqDone = '1' THEN
            dataResultsBuffer <= dataResults;
            maxIndexBuffer <= maxIndex;
        ELSIF cur_state = INIT THEN
            dataResultsBuffer(0) <= "00000000";
            dataResultsBuffer(1) <= "00000000";
            dataResultsBuffer(2) <= "00000000";
            dataResultsBuffer(3) <= "00000000";
            dataResultsBuffer(4) <= "00000000";
            dataResultsBuffer(5) <= "00000000";
            dataResultsBuffer(6) <= "00000000";
            
            maxIndexBuffer(0) <= "0000";
            maxIndexBuffer(1) <= "0000";
            maxIndexBuffer(2) <= "0000";
        ELSE
            dataResultsBuffer <= dataResultsBuffer;
            maxIndexBuffer <= maxIndexBuffer;
        END IF;
    END PROCESS;
    
    combi_setOutByte_L_P: PROCESS (cur_state, ASCII1, ASCII2)
    BEGIN
        
        IF cur_state = BYTE_TO_ASCII_L OR cur_state = BYTE_TO_ASCII_P THEN
            -- Set first byte of outByteBuffer to the ASCII value for the hex value of the first 4 bits of the incoming byte.
            outByteBuffer(0 to 7) <= ASCII1;
            -- Set second byte of outByteBuffer to the ASCII value for the hex value of the last 4 bits of the incoming byte.
            outByteBuffer(8 to 15) <= ASCII2;
            -- Set third byte of outByteBuffer to the ASCII value for the space character.
            outByteBuffer(16 to 23) <= "00100000"; -- Space ASCII value
        ELSIF cur_state = SET_TX_L OR cur_state = SEND_TX_L OR cur_state = RESET_COUNTER_3 OR cur_state = BCD_TO_ASCII_P OR cur_state = RESET_COUNTER_6 OR cur_state = SET_TX_P OR cur_state = SEND_TX_P THEN
            outByteBuffer <= outByteBuffer;
        ELSE
            outByteBuffer <= "000000000000000000000000";
        END IF;
    END PROCESS;
    
    combi_countL7: PROCESS (cur_state)
    BEGIN
        IF cur_state = RESET_COUNTER_3 THEN
            counterL7 <= counterL7 + 1;
        ELSIF cur_state = BYTE_TO_ASCII_L OR cur_state = SEND_TX_L OR cur_state = SET_TX_L THEN
            counterL7 <= counterL7;
        ELSE
            counterL7 <= 0;
        END IF;
    END PROCESS;
    
    combi_countL3: PROCESS (cur_state)
    BEGIN
        IF cur_state = SEND_TX_L THEN
            counterL3 <= counterL3 + 1;
        ELSIF cur_state = BYTE_TO_ASCII_L OR cur_state = SET_TX_L THEN
            counterL3 <= counterL3;
        ELSE
            counterL3 <= 0;
        END IF;
    END PROCESS;

    seq_setRegDataReady: PROCESS (clk)
    BEGIN
        IF clk'event AND clk='1' THEN
            regDataReady <= dataReady;
        END IF;
    END PROCESS;

    seq_state: PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            cur_state <= INIT;
        ELSIF rising_edge(clk) THEN
            cur_state <= next_state;
        END IF;
    END PROCESS;
    
---A Printing Processes----------------------------------------

-- This PROCESS increment counter when a number is received from rxData and reset otherwise
combi_countA3: PROCESS(cur_state)
BEGIN
    IF cur_state = UPDATE_COUNTER_A THEN
        counterA3 <= counterA3 - 1;
    ELSIF cur_state = RECEIVE_DATA_A OR cur_state = CHECK_BYTE_A OR cur_state = ECHO_DATA_A OR cur_state = BYTE_TO_BCD_A THEN
        counterA3 <= counterA3;
    ELSE
        counterA3 <= 2;
    END IF;
END PROCESS;

combi_driveStart: PROCESS(cur_state, txDone)
BEGIN
    start <= '0';
    IF cur_state = SEND_TO_DP_A OR (cur_state = SEND_SPACE AND txDone = '1') THEN
        start <= '1';
    END IF;
END PROCESS;

combi_byteToASCII: PROCESS(byte, dataResultBuffer)
BEGIN
    IF cur_state = SEND_TX_1 THEN
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
    ELSIF cur_state = SEND_TX_2 THEN
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
    ELSIF cur_state = BYTE_TO_ASCII_L OR cur_state = BYTE_TO_ASCII_P THEN
        CASE dataResultBuffer(0 to 3) is
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
        CASE dataResultBuffer(4 to 7) is
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
    ELSE
        ASCII1 <= "00000000";
        ASCII2 <= "00000000";
    END IF;
END PROCESS;
  
------------------------------------------------------------------
    combi_nextState: PROCESS(cur_state, rxData, txDone, counterL3, counterL7, byte, txdone, dataReady, seqDone, rxNow) --[other states necessary]--
    BEGIN
        CASE cur_state IS
	       WHEN INIT =>
	           next_state <= RECEIVE_DATA;
	
	       WHEN RECEIVE_DATA =>
               IF rxNow = '1' THEN
                   next_state <= ECHO_DATA;
               ELSE
                   next_state <= RECEIVE_DATA;
               END IF;
	  
	       WHEN ECHO_DATA =>
	           IF txDone = '1' THEN
	               next_state <= CHECK_COMMANDS;
	           ELSE
	               next_state <= ECHO_DATA;
	           END IF;

	       WHEN CHECK_COMMANDS =>
               IF rxData = "01001100" OR rxData = "01101100" THEN -- L
	               next_state <= BYTE_TO_ASCII_L;
	           ELSIF rxData = "01000001" OR rxData = "01100001" THEN -- A
	               next_state <= RECEIVE_DATA_A;
	           ELSIF rxData = "01010000" OR rxData = "01110000" THEN -- P
	               next_state <= BYTE_TO_ASCII_P;
	           ELSE
	               next_state <= RECEIVE_DATA;
	           END IF;
	
	--- L printing:
	       WHEN BYTE_TO_ASCII_L =>
    	       next_state <= RESET_COUNTER_3;
	
	       WHEN RESET_COUNTER_3 =>
	           next_state <= SET_TX_L;
	
	       WHEN SET_TX_L =>
	           IF txDone = '1' THEN
	               next_state <= SEND_TX_L;
	           ELSE
	               next_state <= SET_TX_L;
	           END IF;
	
	       WHEN SEND_TX_L =>
	           IF counterL3 < 3 THEN
	               next_state <= SET_TX_L;
	           ELSIF counterL7 < 7 THEN
	               next_state <= BYTE_TO_ASCII_L;
	           ELSE
	               next_state <= RECEIVE_DATA;
	           END IF;
	           
	   ---- P printing:

    	   WHEN BYTE_TO_ASCII_P =>
    	       -- Because in combi_byteToASCII we wait for seqDone to = 1, we do not know if this 
    	       -- will be completed in a single clock cycle. Hence, we must wait for it to finish 
    	       -- before moving to the next state.
               next_state <= BCD_TO_ASCII_P;
    	   
    	   WHEN BCD_TO_ASCII_P =>
    	       next_state <= RESET_COUNTER_6;
    	       
    	   WHEN RESET_COUNTER_6 =>
    	       next_state <= SET_TX_P;
    	       
    	   WHEN SET_TX_P =>
    	       IF txDone = '1' AND counterP6 < 6 THEN
    	           next_state <= SEND_TX_P;
    	       ELSIF txDone = '0' AND counterP6 < 6 THEN
    	           next_state <= SET_TX_P;
    	       ELSE
    	           next_state <= RECEIVE_DATA;
    	       END IF;
    	           
    	   WHEN SEND_TX_P => 
               next_state <= SET_TX_P;
	 
---A Printing States--------------------------------------------

           WHEN RECEIVE_DATA_A =>
               IF rxNow = '1' THEN
                   next_state <= ECHO_DATA_A;
               ELSE
                   next_state <= RECEIVE_DATA_A;
               END IF;
               
           WHEN ECHO_DATA_A =>
	           IF txDone = '1' THEN
--               IF sentDataFlag = '1' THEN
                   next_state <= CHECK_BYTE_A;
               ELSE
                   next_state <= ECHO_DATA_A;
               END IF;

           WHEN CHECK_BYTE_A =>
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
                   next_state <= BYTE_TO_BCD_A;
               ELSIF rxData = "01000001" OR rxData = "01100001" THEN
                   next_state <= RECEIVE_DATA_A;
               ELSE
                   next_state <= RECEIVE_DATA;
               END IF;
               
           WHEN BYTE_TO_BCD_A =>
               next_state <= UPDATE_COUNTER_A;
               
           WHEN UPDATE_COUNTER_A =>
               IF counterA3 > 0 THEN
                  next_state <= RECEIVE_DATA_A;
               ELSE
                  next_state <= SEND_TO_DP_A;
               END IF;

           WHEN SEND_TO_DP_A =>
               next_state <= DATA_READY;
               
           WHEN DATA_READY =>
               IF dataReady = '1' THEN
                   next_state <= SEND_TX_1;
               ELSE
                   next_state <= DATA_READY;
               END IF;
               
           WHEN SEND_TX_1 =>
               IF txDone = '1' AND seqDone = '0' THEN
                   next_state <= SEND_TX_2;
               ELSIF seqDone = '0' THEN
                   next_state <= SEND_TX_1;
               ELSE
                   next_state <= RECEIVE_DATA;
               END IF;
           
           WHEN SEND_TX_2 =>
               IF txDone = '1' THEN
                   next_state <= SEND_SPACE;
               ELSE
                   next_state <= SEND_TX_2;
               END IF;
               
           WHEN SEND_SPACE =>
               IF txDone = '1' THEN
                   next_state <= DATA_READY;
               ELSE
                   next_state <= SEND_SPACE;
               END IF;
-----------------------------------------------
	       WHEN OTHERS =>
	           next_state <= INIT;
        END CASE;
    END PROCESS;
END behavioural;