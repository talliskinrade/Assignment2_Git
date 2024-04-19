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
	SIGNAL counter7: integer range 0 to 7;
	SIGNAL counter3: integer range 0 to 3;
	SIGNAL counter6: integer range 0 to 5;
	SIGNAL counterA3: integer range 0 to 3;
	SIGNAL receivedDataFlag, sentDataFlag, byteToBCDFlag: std_logic;
	SIGNAL dataBuffer: std_logic_vector (7 downto 0) := "11111111";
	SIGNAL byteBuffer: std_logic_vector (0 to 7) := "00000000";
	SIGNAL dataResultsBuffer: CHAR_ARRAY_TYPE (0 to RESULT_BYTE_NUM-1);
	SIGNAL maxIndexBuffer: BCD_ARRAY_TYPE (2 downto 0);
	SIGNAL dataResultBuffer: std_logic_vector (0 to 7) := "00000000";
	SIGNAL outByteBuffer: std_logic_vector (0 to 23) := "000000000000000000000000";
	SIGNAL hexASCIIMapping: std_logic_vector (0 to 127) := "00110000001100010011001000110011001101000011010100110110001101110011100000111001010000010100001001000011010001000100010101000110";
	-- Have faith in the mega array!!!!!
	SIGNAL receivedByteFlag: std_logic := '0';
	SIGNAL outMaxIndexBuffer: std_logic_vector (0 to 23) := "000000000000000000000000";
	SIGNAL outPPrinting: std_logic_vector (0 to 48) := "0000000000000000000000000000000000000000000000000";
	-------- A Printing -------
    SIGNAL count_numbers, count_send : integer := 0;
    SIGNAL tem_BCD : std_logic_vector(11 downto 0);
    SIGNAL tem_Data_to_BCD : std_logic_vector(11 downto 0) := "000000000000";
    SIGNAL rxdone_temp : std_logic := '0';
    SIGNAL ASCII1, ASCII2 : std_logic_vector(7 downto 0);
    signal prev_seqDone, seqDone_temp : std_logic := '0';
    signal byte_complete, count_reset : std_logic := '0';
    SIGNAL regDataReady: std_logic := '0';
-------------------------------------------------------------------
--Component Instantiation

--End component instantiation
-------------------------------------------------------------------
	
BEGIN

    combi_terminalEcho: PROCESS(cur_state, rxNow, txDone)
    BEGIN
        rxDone <= '0';
        receivedDataFlag <= '0';
	   
        IF (cur_state = RECEIVE_DATA OR cur_state = RECEIVE_DATA_A) AND rxNow = '1' THEN
	       dataBuffer <= rxData;
	       rxDone <= '1';
	       receivedDataFlag <= '1';
	    END IF;
    END PROCESS;

    combi_out: PROCESS (cur_state, txDone)
    BEGIN
        txNow <= '0';
        sentDataFlag <= '0';
        txData <= "00000000";
        
	    IF (cur_state = ECHO_DATA OR cur_state = ECHO_DATA_A) AND txDone = '1' THEN
	       txData <= dataBuffer;
	       txNow <= '1';
	       sentDataFlag <= '1';
	    ELSIF cur_state = SEND_TX_L THEN
           txData <= outByteBuffer(counter3*8 to counter3*8 + 7);
           txNow <= '1';
        ELSIF cur_state = SEND_TX_P AND txDone = '1' THEN
           txData <= outPPrinting(counter6*8 to counter6*8 + 7);
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
    
    combi_byteToBCD_A: PROCESS (cur_state, dataBuffer)
    BEGIN
        IF cur_state = BYTE_TO_BCD_A AND counterA3 < 3 THEN
            -- Byte in dataBuffer is an ASCII code between 00110000 and 00111001.
            -- Last 4 bits denote the BCD digit, hence we can extract this and store it in the BCD array.
            numWords_bcd(2-counterA3) <= dataBuffer(3 downto 0);
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
            outMaxIndexBuffer(4 to 7) <= maxIndexBuffer(0);
            outMaxIndexBuffer(8 to 11) <= "0011";
            outMaxIndexBuffer(12 to 15) <= maxIndexBuffer(1);
            outMaxIndexBuffer(16 to 19) <= "0011";
            outMaxIndexBuffer(20 to 23) <= maxIndexBuffer(2);
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
    
    combi_count6: PROCESS (cur_state)
    BEGIN
        IF cur_state = SEND_TX_P THEN
            counter6 <= counter6 + 1;
        ELSIF cur_state = BYTE_TO_ASCII_P OR cur_state = BCD_TO_ASCII_P OR cur_state = SET_TX_P THEN
            counter6 <= counter6;
        ELSE
            counter6 <= 0;
        END IF;
    END PROCESS;
    
    combi_setDataResultBuffer: PROCESS (cur_state)
    BEGIN
        dataResultBuffer <= "00000000";
        IF cur_state = BYTE_TO_ASCII_L THEN
            dataResultBuffer <= dataResultsBuffer(counter7);
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
    
    combi_setOutByte: PROCESS (dataResultBuffer)
    BEGIN
        receivedByteFlag <= '0';
        
        IF cur_state = BYTE_TO_ASCII_L OR cur_state = BYTE_TO_ASCII_P THEN
            -- Set first byte of outByteBuffer to the ASCII value for the hex value of the first 4 bits of the incoming byte.
            outByteBuffer(0 to 7) <= hexASCIIMapping(TO_INTEGER(UNSIGNED(dataResultBuffer(0 to 3)))*8 to TO_INTEGER(UNSIGNED(dataResultBuffer(0 to 3)))*8 + 7);
            -- Set second byte of outByteBuffer to the ASCII value for the hex value of the last 4 bits of the incoming byte.
            outByteBuffer(8 to 15) <= hexASCIIMapping(TO_INTEGER(UNSIGNED(dataResultBuffer(4 to 7)))*8 to TO_INTEGER(UNSIGNED(dataResultBuffer(4 to 7)))*8 + 7);
            -- Set third byte of outByteBuffer to the ASCII value for the space character.
            outByteBuffer(16 to 23) <= "00100000"; -- Space ASCII value
            receivedByteFlag <= '1';
        ELSIF cur_state = SET_TX_L OR cur_state = SEND_TX_L OR cur_state = RESET_COUNTER_3 THEN
            outByteBuffer <= outByteBuffer;
        ELSE
            outByteBuffer <= "000000000000000000000000";
        END IF;
    END PROCESS;
    
    combi_count7: PROCESS (cur_state)
    BEGIN
        IF cur_state = RESET_COUNTER_3 THEN
            counter7 <= counter7 + 1;
        ELSIF cur_state = BYTE_TO_ASCII_L OR cur_state = SEND_TX_L OR cur_state = SET_TX_L THEN
            counter7 <= counter7;
        ELSE
            counter7 <= 0;
        END IF;
    END PROCESS;
    
    combi_count3: PROCESS (cur_state)
    BEGIN
        IF cur_state = SEND_TX_L THEN
            counter3 <= counter3 + 1;
        ELSIF cur_state = BYTE_TO_ASCII_L OR cur_state = SET_TX_L THEN
            counter3 <= counter3;
        ELSE
            counter3 <= 0;
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
        counterA3 <= counterA3 + 1;
    ELSIF cur_state = RECEIVE_DATA_A OR cur_state = CHECK_BYTE_A OR cur_state = ECHO_DATA_A OR cur_state = BYTE_TO_BCD_A THEN
        counterA3 <= counterA3;
    ELSE
        counterA3 <= 0;
    END IF;
END PROCESS;

combi_driveStart: PROCESS(cur_state, txDone)
BEGIN
    start <= '0';
    IF cur_state = SEND_TO_DP_A OR (cur_state = SEND_SPACE AND txDone = '1') THEN
        start <= '1';
    END IF;
END PROCESS;

byte_to_ASCII_proc: PROCESS(byte)
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
  
------------------------------------------------------------------
    combi_nextState: PROCESS(cur_state, receivedDataFlag, sentDataFlag, rxData, txDone, counter3, counter7, byte, txdone, dataReady, seqDone) --[other states necessary]--
    BEGIN
        CASE cur_state IS
	       WHEN INIT =>
	           next_state <= RECEIVE_DATA;
	
	       WHEN RECEIVE_DATA =>
	           IF receivedDataFlag = '1' THEN
	               next_state <= ECHO_DATA;
	           ELSE
	               next_state <= RECEIVE_DATA;
	           END IF;
	  
	       WHEN ECHO_DATA =>
	           IF sentDataFlag = '1' THEN
	               next_state <= CHECK_COMMANDS;
--	           ELSIF sentDataFlag = '1' THEN
--	               next_state <= CHECK_BYTE_A;
	           ELSE
	               next_state <= ECHO_DATA;
	           END IF;

	       WHEN CHECK_COMMANDS =>
	           IF dataBuffer = "01001100" OR dataBuffer = "01101100" THEN -- L
	               next_state <= BYTE_TO_ASCII_L;
	           ELSIF dataBuffer = "01000001" OR dataBuffer = "01100001" THEN -- A
	               next_state <= RECEIVE_DATA_A;
	           ELSIF dataBuffer = "01010000" OR dataBuffer = "01110000" THEN -- P
	               next_state <= BYTE_TO_ASCII_P;
	           ELSE
	               next_state <= RECEIVE_DATA;
	           END IF;
	
	--- L printing:
	       WHEN BYTE_TO_ASCII_L =>
	           IF receivedByteFlag = '1' THEN
    	           next_state <= RESET_COUNTER_3;
    	       ELSE
    	           next_state <= BYTE_TO_ASCII_L;
    	       END IF;
	
	       WHEN RESET_COUNTER_3 =>
	           next_state <= SET_TX_L;
	
	       WHEN SET_TX_L =>
	           IF txDone = '1' THEN
	               next_state <= SEND_TX_L;
	           ELSE
	               next_state <= SET_TX_L;
	           END IF;
	
	       WHEN SEND_TX_L =>
	           IF counter3 < 3 THEN
	               next_state <= SET_TX_L;
	           ELSIF counter7 < 7 THEN
	               next_state <= BYTE_TO_ASCII_L;
	           ELSE
	               next_state <= RECEIVE_DATA;
	           END IF;
	           
	   ---- P printing:

    	   WHEN BYTE_TO_ASCII_P =>
    	       -- Because in combi_byteToASCII we wait for seqDone to = 1, we do not know if this 
    	       -- will be completed in a single clock cycle. Hence, we must wait for it to finish 
    	       -- before moving to the next state.
    	       IF receivedByteFlag = '1' THEN
    	           next_state <= BCD_TO_ASCII_P;
    	       ELSE
    	           next_state <= BYTE_TO_ASCII_P;
    	       END IF;
    	   
    	   WHEN BCD_TO_ASCII_P =>
    	       next_state <= RESET_COUNTER_6;
    	       
    	   WHEN RESET_COUNTER_6 =>
    	       next_state <= SET_TX_P;
    	       
    	   WHEN SET_TX_P =>
    	       IF txDone = '1' AND counter6 < 6 THEN
    	           next_state <= SEND_TX_P;
    	       ELSIF txDone = '0' AND counter6 < 6 THEN
    	           next_state <= SET_TX_P;
    	       ELSE
    	           next_state <= RECEIVE_DATA;
    	       END IF;
    	           
    	   WHEN SEND_TX_P => 
               next_state <= SET_TX_P;
	 
---A Printing States--------------------------------------------

           WHEN RECEIVE_DATA_A =>
               IF receivedDataFlag = '1' THEN
                   next_state <= ECHO_DATA_A;
               ELSE
                   next_state <= RECEIVE_DATA_A;
               END IF;
               
           WHEN ECHO_DATA_A =>
               IF sentDataFlag = '1' THEN
                   next_state <= CHECK_BYTE_A;
               ELSE
                   next_state <= ECHO_DATA_A;
               END IF;

           WHEN CHECK_BYTE_A =>
               IF dataBuffer = "00110000" OR 
                    dataBuffer = "00110001" OR 
                    dataBuffer = "00110010" OR 
                    dataBuffer = "00110011" OR 
                    dataBuffer = "00110100" OR 
                    dataBuffer = "00110101" OR 
                    dataBuffer = "00110110" OR 
                    dataBuffer = "00110111" OR 
                    dataBuffer = "00111000" OR 
                    dataBuffer = "00111001" THEN
                   next_state <= BYTE_TO_BCD_A;
               ELSIF dataBuffer = "01000001" OR dataBuffer = "01100001" THEN
                   next_state <= RECEIVE_DATA_A;
               ELSE
                   next_state <= RECEIVE_DATA;
               END IF;
               
           WHEN BYTE_TO_BCD_A =>
               next_state <= UPDATE_COUNTER_A;
--               IF counterA3 < 3 THEN
--                   next_state <= RECEIVE_DATA_A;
--               ELSE
--                   next_state <= SEND_TO_DP_A;
--               END IF;
               
           WHEN UPDATE_COUNTER_A =>
               IF counterA3 < 2 THEN
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