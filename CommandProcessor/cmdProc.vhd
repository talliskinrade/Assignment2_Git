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
	   RESET_COUNT,
	   INCREMENT_COUNT,
	   BYTE_TO_BCD_A,
	   SEND_TO_DP,
	   BYTE_TO_ASCII,
	   SET_TX,
	   SEND_TX,
	   STORE_RESULTS,
	   BYTE_TO_ASCII_L,
	   RESET_COUNTER_3,
	   SET_TX_L,
	   SEND_TX_L,
	   BYTE_AND_BCD_TO_ASCII,
	   RESET_COUNTER_6,
	   SET_TX_P,
	   SEND_TX_P,
	   BYTE_TO_ASCII_P,
	   BCD_TO_ASCII_P,
	   DONE
	);
 
-- Signal Declaration
    SIGNAL cur_state, next_state: state_type;
	SIGNAL counter7: integer range 0 to 7;
	SIGNAL counter3: integer range 0 to 3;
	SIGNAL counterA3: integer range 0 to 3;
	SIGNAL receivedDataFlag, sentDataFlag, byteToBCDFlag: std_logic;
	SIGNAL dataBuffer: std_logic_vector (7 downto 0) := "11111111";
	SIGNAL numWordsBuffer: std_logic_vector (11 downto 0) := "000000000000";
	SIGNAL byteBuffer: std_logic_vector (0 to 7) := "00000000";
	SIGNAL dataResultBuffer: std_logic_vector (0 to 7) := "00000000";
	SIGNAL outByteBuffer: std_logic_vector (0 to 23) := "000000000000000000000000";
	SIGNAL hexASCIIMapping: std_logic_vector (0 to 127) := "00110000001100010011001000110011001101000011010100110110001101110011100000111001010000010100001001000011010001000100010101000110";
	-- Have faith in the mega array!!!!!
	SIGNAL receivedByteFlag: std_logic := '0';
	SIGNAL outMaxIndexBuffer: std_logic_vector (0 to 23) := "000000000000000000000000";
	SIGNAL outPPrinting: std_logic_vector (0 to 48) := "00000000000000000000000000000000000000000000000000000000";
	
-------------------------------------------------------------------
--Component Instantiation

--End component instantiation
-------------------------------------------------------------------
	
BEGIN

    combi_terminalEcho: PROCESS(cur_state, rxNow, txDone)
    BEGIN
        txNow <= '0';
        rxDone <= '0';
        receivedDataFlag <= '0';
        sentDataFlag <= '0';
	     
        IF cur_state = RECEIVE_DATA AND rxNow = '1' THEN
	       dataBuffer <= rxData;
	       rxDone <= '1';
	       txData <= dataBuffer;
	       receivedDataFlag <= '1';
	    END IF;
	   IF cur_state = ECHO_DATA AND txDone = '1' THEN
	       txNow <= '1';
	       sentDataFlag <= '1';
	   END IF;
    END PROCESS;

    combi_out: PROCESS (cur_state)
    BEGIN
        txNow <= '0';
	    IF cur_state = SEND_TX_L OR cur_state = SEND_TX_P THEN
	       txNow <= '1';
	    ELSIF cur_state = SET_TX_L THEN
	       txData <= byteBuffer(counter3*8 to counter3*8 + 7);
	    END IF;
    END PROCESS;
    
    combi_byteToBCD: PROCESS (cur_state, dataBuffer)
    BEGIN
        IF cur_state = BYTE_TO_BCD_A AND counterA3 < 3 THEN
            -- Byte in dataBuffer is an ASCII code between 00110000 and 00111001.
            -- Last 4 bits denote the BCD digit, hence we can extract this and store it in the BCD array.
            numWordsBuffer(counterA3*4 to counterA3*4 + 3) <= dataBuffer(3 to 7);
            numWords_bcd(counterA3) <= numWordsBuffer(counterA3*4 to counterA3*4 + 3);
            -- Repeat for all three bytes received.
            counterA3 <= counterA3 + 1;
        END IF;
    END PROCESS;
    
    combi_BCDToByte: PROCESS (cur_state)
    BEGIN
        IF cur_state = BCD_TO_ASCII_P THEN
            -- Don't need to check if seqDone = 1 as this will have been checked in BYTE_TO_ASCII_P
            -- and will no longer be 1 as it has been a clock cycle.
            -- Every decimal character begins with the ASCII code "0011".
            outMaxIndexBuffer(0 to 3) <= "0011";
            -- First BCD digit in maxIndex
            outMaxIndexBuffer(4 to 7) <= maxIndex(0);
            outMaxIndexBuffer(8 to 11) <= "0011";
            outMaxIndexBuffer(12 to 15) <= maxIndex(1);
            outMaxIndexBuffer(16 to 19) <= "0011";
            outMaxIndexBuffer(20 to 23) <= maxIndex(2);
            -- outMaxIndexBuffer contains all three ASCII codes for the BCD digits that must be output for the max index.
            
            outPPrinting(24 to 47) <= outMaxIndexBuffer;
            -- outPPrinting now contains all 6 bytes that must be printed in turn to complete P printing.
        END IF;
    END PROCESS;
    
    combi_byteToASCII: PROCESS (cur_state)
    BEGIN
        receivedByteFlag <= '0';
        IF seqDone = '1' AND (cur_state = BYTE_TO_ASCII_L OR cur_state = BYTE_TO_ASCII_P) THEN
            IF cur_state = BYTE_TO_ASCII_L THEN
                -- If L printing, output each result individually.
                dataResultBuffer <= dataResults(counter7);
            ELSIF cur_state = BYTE_TO_ASCII_P THEN
                -- If P printing, only output the 4th (middle) result as this is the peak byte.
                dataResultBuffer <= dataResults(3);
            END IF;
            
            -- Set first byte of outByteBuffer to the ASCII value for the hex value of the first 4 bits of the incoming byte.
            outByteBuffer(0 to 7) <= hexASCIIMapping(TO_INTEGER(UNSIGNED(dataResultBuffer(0 to 3)))*8 to TO_INTEGER(UNSIGNED(dataResultBuffer(0 to 3)))*8 + 7);
            -- Set second byte of outByteBuffer to the ASCII value for the hex value of the last 4 bits of the incoming byte.
            outByteBuffer(8 to 15) <= hexASCIIMapping(TO_INTEGER(UNSIGNED(dataResultBuffer(4 to 7)))*8 to TO_INTEGER(UNSIGNED(dataResultBuffer(4 to 7)))*8 + 7);
            -- Set third byte of outByteBuffer to the ASCII value for the space character.
            outByteBuffer(16 to 23) <= "00100000"; -- Space ASCII value
            IF cur_state = BYTE_TO_ASCII_P THEN
                outPPrinting(0 to 23) <= outByteBuffer;
            END IF;
            receivedByteFlag <= '1';
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
  
------------------------------------------------------------------
    combi_nextState: PROCESS(cur_state, receivedDataFLag, sentDataFlag, rxData, txDone, counter3, counter7) --[other states necessary]--
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
	           ELSE
	               next_state <= ECHO_DATA;
	           END IF;

	       WHEN CHECK_COMMANDS =>
	           IF dataBuffer = "01001100" OR dataBuffer = "01101100" THEN -- L
	               next_state <= BYTE_TO_ASCII_L;
	               counter7 <= 0;
	           ELSIF dataBuffer = "01000001" OR dataBuffer = "01100001" THEN -- A
	               next_state <= RESET_COUNT;
	           ELSIF dataBuffer = "01010000" OR dataBuffer = "01110000" THEN -- P
	               next_state <= BYTE_TO_ASCII_P;
	           ELSE
	               next_state <= RECEIVE_DATA;
	           END IF;
	
	       WHEN BYTE_TO_ASCII_L =>
	           IF receivedByteFlag = '1' THEN
    	           next_state <= RESET_COUNTER_3;
    	       ELSE
    	           next_state <= BYTE_TO_ASCII_L;
    	       END IF;
	
	       WHEN RESET_COUNTER_3 =>
	           counter7 <= counter7 + 1;
	           counter3 <= 0;
	           next_state <= SET_TX_L;
	
	       WHEN SET_TX_L =>
	           IF txDone = '1' THEN
	               next_state <= SEND_TX_L;
	               counter3 <= counter3 + 1;
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
	 
	       WHEN DONE =>
	           next_state <= INIT;
	       WHEN OTHERS =>
	           next_state <= INIT;
        END CASE;
    END PROCESS;
    
END behavioural;