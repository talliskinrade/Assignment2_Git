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
    SIGNAL rxDataBuffer: std_logic_vector(7 downto 0);
    -- L Printing
	SIGNAL counterL7: integer range 6 downto -1;
	SIGNAL counterL3: integer range 0 to 3;
    SIGNAL dataResultLBuffer: std_logic_vector(0 to 7);
    -- P Printing
	SIGNAL counterP6: integer range 0 to 6;
	SIGNAL outPPrinting: std_logic_vector (0 to 48) := "0000000000000000000000000000000000000000000000000";
    SIGNAL dataResultPBuffer: std_logic_vector(0 to 7);
	-------- A Printing -------
	SIGNAL dataResultsBuffer: CHAR_ARRAY_TYPE (0 to RESULT_BYTE_NUM-1);
	SIGNAL maxIndexBuffer: BCD_ARRAY_TYPE (2 downto 0);
	SIGNAL outByteBuffer: std_logic_vector (0 to 23) := "000000000000000000000000";
	SIGNAL outMaxIndexBuffer: std_logic_vector (0 to 23) := "000000000000000000000000";
	SIGNAL counterA3: integer range 2 downto 0;
    SIGNAL ASCII1, ASCII2 : std_logic_vector(7 downto 0);
    SIGNAL seqDoneBuffer: std_logic;
    SIGNAL dataReadyBuffer: std_logic;
    SIGNAL byteBuffer: std_logic_vector(7 downto 0);
	
BEGIN

    combi_setRXDone_echoing: PROCESS(cur_state, rxNow)
    -- Process tells RX that data has been received.
    BEGIN
        rxDone <= '0';
        IF (cur_state = RECEIVE_DATA OR cur_state = RECEIVE_DATA_A) AND rxNow = '1' THEN
	       rxDone <= '1';
	    END IF;
    END PROCESS;

    combi_sendTX: PROCESS (cur_state, txDone, rxDataBuffer, counterL3, outByteBuffer, counterP6, outPPrinting, ASCII1, ASCII2, dataResultLBuffer, rxDataBuffer, dataReadyBuffer, seqDoneBuffer)
    -- Process sets the txData line and tells the TX that the data in the line is complete
    BEGIN
        txNow <= '0';
        txData <= "00000000";

        IF (cur_state = ECHO_DATA OR cur_state = ECHO_DATA_A) AND txDone = '1' THEN
            -- Sends an echo of the user's input to the TX to show the user what they entered
            txData <= rxDataBuffer;
            txNow <= '1';
        ELSIF cur_state = SEND_TX_L AND counterL3 < 3 THEN
            -- Sends the next in the list of peak bytes from dataResults
            txData <= outByteBuffer(counterL3*8 to counterL3*8 + 7);
            txNow <= '1';
        ELSIF cur_state = SEND_TX_P THEN
            -- Sends the peak byte followed by the index of that byte
            txData <= outPPrinting(counterP6*8 to counterP6*8 + 7);
            txNow <= '1';
        ELSIF cur_state = SEND_TX_1 AND txDone = '1' THEN
            -- Sends the first ASCII code to be output from the first 4 bits of the byte received from the data processor
            txData <= ASCII1;
            txNow <= '1';
        ELSIF cur_state = SEND_TX_2 AND txDone = '1' THEN
            -- Sends the second ASCII code
            txData <= ASCII2;
            txNow <= '1';
        ELSIF cur_state = SEND_SPACE AND txDone = '1' THEN
            -- Sends the ASCII code for a space character
            txData <= "00100000";
            txNow <= '1';
	    END IF;
    END PROCESS;
    
    seq_numWords_bcdSync: PROCESS (clk)
    -- Process sets a latch for the numWords_bcd port signal
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                numWords_bcd(0) <= "0000";
                numWords_bcd(1) <= "0000";
                numWords_bcd(2) <= "0000";
            ELSIF cur_state = BYTE_TO_BCD_A THEN
                -- To convert the incoming decimal ASCII number code to a BCD number, we must only take the last four bits of the code
                numWords_bcd(counterA3) <= rxDataBuffer(3 downto 0);
                -- Repeat for all three bytes received.
            END IF;
        END IF;
    END PROCESS;
    
    seq_BCDToASCII_P: PROCESS (clk)
    -- Process sets a latch for the outMaxIndexBuffer signal to retain the max index ASCII codes that must be sent to TX
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                outMaxIndexBuffer <= "000000000000000000000000";
            ELSIF cur_state = BCD_TO_ASCII_P THEN
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
            END IF;
        END IF;
    END PROCESS;
    
    seq_setOutPPrinting: PROCESS (clk)
    -- Process sets a latch for the outPPrinting signal to retain the ASCII character codes to be output in P printing
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                outPPrinting <= "0000000000000000000000000000000000000000000000000";
            ELSIF cur_state = BCD_TO_ASCII_P THEN
                -- First ASCII code
                outPPrinting(0 to 7) <= outByteBuffer(0 to 7);
                -- Second ASCII code
                outPPrinting(8 to 15) <= outByteBuffer(8 to 15);
                -- SPACE ASCII code
                outPPrinting(16 to 23) <= "00100000";
            ELSIF cur_state = SET_TX_P THEN
                outPPrinting(24 to 47) <= outMaxIndexBuffer;
                -- OutPPrinting now contains the full 48 bits that must be output in P printing
            END IF;
        END IF;
    END PROCESS;
    
    seq_count6_P: PROCESS (clk)
    -- Process counts 6 times for P printing, to send each bit in outPPrinting to the TX
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' OR cur_state = RECEIVE_DATA THEN
                counterP6 <= 0;
            ELSIF cur_state = SEND_TX_P THEN
                counterP6 <= counterP6 + 1;
            END IF;
        END IF;
    END PROCESS;
    
    seq_setRXDataBuffer: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                rxDataBuffer <= "00000000";
            ELSIF rxNow = '1' THEN
                rxDataBuffer <= rxData;
            END IF;
        END IF;
    END PROCESS;
    
    seq_setByteBuffer: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                byteBuffer <= "00000000";
            ELSIF dataReady = '1' THEN
                byteBuffer <= byte;
            END IF;
        END IF;
    END PROCESS;
    
    seq_setDataResultPBuffer: PROCESS (clk)
    -- Process sets a latch for the byte from dataResults that must be output when P printing
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                dataResultPBuffer <= "00000000";
            ELSE
                -- 3 index takes the peak byte from dataResults
                dataResultPBuffer <= dataResultsBuffer(3);
            END IF;
        END IF;
    END PROCESS;
    
    seq_setDataResultLBuffer: PROCESS (clk)
    -- Process sets a latch to store the next byte in the list of dataResults to be sent to TX for L printing
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                dataResultLBuffer <= "00000000";
            ELSIF counterL7 > -1 THEN
                -- Counts through each byte in dataResults
                dataResultLBuffer <= dataResultsBuffer(counterL7);
            END IF;
        END IF;
    END PROCESS;
    
    seq_readDataResults: PROCESS (clk)
    -- Process sets a latch for storing the dataResults signal
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
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
            ELSIF seqDone = '1' THEN
                dataResultsBuffer <= dataResults;
                maxIndexBuffer <= maxIndex;
            END IF;
        END IF;
    END PROCESS;
    
    seq_countL7: PROCESS (clk)
    -- Process counts down from 6 to 0 so that L printing can output each of the 7 bytes in dataResults
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' OR cur_state = RECEIVE_DATA THEN
                counterL7 <= 6;
            ELSIF cur_state = RESET_COUNTER_3 THEN
                counterL7 <= counterL7 - 1;
            END IF;
        END IF;
    END PROCESS;
    
    seq_countL3: PROCESS (clk)
    -- Process counts up to 3 to output each of the three ASCII character codes that must be sent to TX for each byte during L printing
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' OR cur_state = RESET_COUNTER_3 THEN
                counterL3 <= 0;
            ELSIF cur_state = SEND_TX_L THEN
                counterL3 <= counterL3 + 1;
            END IF;
        END IF;
    END PROCESS;

    seq_state: PROCESS (clk, reset)
    -- Sequential process setting the next state for the processor
    BEGIN
        IF reset = '1' THEN
            cur_state <= INIT;
        ELSIF rising_edge(clk) THEN
            cur_state <= next_state;
        END IF;
    END PROCESS;
    
---A Printing Processes----------------------------------------

    seq_countA3: PROCESS (clk)
    -- Process decrements counter each time a number is received from rxData so that the three BCD values for numWords are received
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' OR cur_state = RECEIVE_DATA THEN
                counterA3 <= 2;
            ELSIF cur_state = UPDATE_COUNTER_A THEN
                counterA3 <= counterA3 - 1;
            END IF;
        END IF;
    END PROCESS;
    
    seq_setDataReadyBuffer: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' OR cur_state = SEND_TX_1 THEN
                dataReadyBuffer <= '0';
            ELSIF dataReady = '1' THEN
                dataReadyBuffer <= '1';
            END IF;
        END IF;
    END PROCESS;
    
    combi_driveStart: PROCESS(cur_state, txDone)
    -- Process sets the start port signal when the next byte can be received from the data processor
    BEGIN
        start <= '0';
        IF cur_state = SEND_TO_DP_A OR (cur_state = SEND_SPACE AND txDone = '1') THEN
            start <= '1';
        END IF;
    END PROCESS;
    
    combi_byteToASCII: PROCESS(byteBuffer, dataResultPBuffer, cur_state, dataResultLBuffer)
    -- Process maps each possible hexadecimal 4-bit value to it's appropriate ASCII value.
    BEGIN
        ASCII1 <= "00000000";
        ASCII2 <= "00000000";
        
        IF cur_state = SEND_TX_1 THEN
            CASE byteBuffer(7 downto 4) is
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
            CASE byteBuffer(3 downto 0) is
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
        ELSIF cur_state = BYTE_TO_ASCII_P THEN
            CASE dataResultPBuffer(0 to 3) is
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
            CASE dataResultPBuffer(4 to 7) is
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
        ELSIF cur_state = BYTE_TO_ASCII_L THEN
            CASE dataResultLBuffer(0 to 3) is
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
            CASE dataResultLBuffer(4 to 7) IS
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
        END IF;
    END PROCESS;
    
    seq_setSeqDoneBuffer: PROCESS (clk)
    -- Process sets a latch for the seqDone port signal
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' OR cur_state = RECEIVE_DATA_A THEN
                seqDoneBuffer <= '0';
            ELSIF seqDone = '1' THEN -- Maybe add 'OR cur_state = DATA_READY'?
                seqDoneBuffer <= '1';
            END IF;
        END IF;
    END PROCESS;
    
    seq_setOutByteBuffer: PROCESS (clk)
    -- Process sets the ASCII character codes for the byte to be output during A printing
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset='1' THEN
                outByteBuffer <= "000000000000000000000000";
            ELSIF cur_state = BYTE_TO_ASCII_P OR cur_state = BYTE_TO_ASCII_L THEN
                outByteBuffer(0 to 7) <= ASCII1;
                outByteBuffer(8 to 15) <= ASCII2;
                outByteBuffer(16 to 23) <= "00100000";
            END IF;
        END IF;
    END PROCESS;
  
------------------------------------------------------------------
    combi_nextState: PROCESS(cur_state, rxNow, txDone, rxData, counterL3, counterL7, counterP6, counterA3, dataReady, seqDone, rxDataBuffer, dataReadyBuffer, seqDoneBuffer)
    -- Process sets the next state logic for the program
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
	           ELSIF counterL7 > -1 THEN
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
                   next_state <= CHECK_BYTE_A;
               ELSE
                   next_state <= ECHO_DATA_A;
               END IF;

           WHEN CHECK_BYTE_A =>
               IF rxDataBuffer = "00110000" OR 
                    rxDataBuffer = "00110001" OR 
                    rxDataBuffer = "00110010" OR 
                    rxDataBuffer = "00110011" OR 
                    rxDataBuffer = "00110100" OR 
                    rxDataBuffer = "00110101" OR 
                    rxDataBuffer = "00110110" OR 
                    rxDataBuffer = "00110111" OR 
                    rxDataBuffer = "00111000" OR 
                    rxDataBuffer = "00111001" THEN
                   next_state <= BYTE_TO_BCD_A;
               ELSIF rxDataBuffer = "01000001" OR rxDataBuffer = "01100001" THEN
                   next_state <= RECEIVE_DATA_A;
               ELSE
                   next_state <= RECEIVE_DATA;
               END IF;
               
           WHEN BYTE_TO_BCD_A =>
               next_state <= UPDATE_COUNTER_A;
               
           WHEN UPDATE_COUNTER_A =>
               IF counterA3 > 0 THEN
                  next_state <= RECEIVE_DATA_A;
               ELSIF dataReadyBuffer = '0' THEN
                  next_state <= SEND_TO_DP_A;
               ELSE
                  next_state <= DATA_READY;
               END IF;

           WHEN SEND_TO_DP_A =>
               next_state <= DATA_READY;
               
           WHEN DATA_READY =>
--               IF dataReady = '1' AND seqDoneBuffer = '0' THEN
--                   next_state <= SEND_TX_1;
--               ELSIF seqDoneBuffer = '1' THEN
--                   next_state <= RECEIVE_DATA;
--               ELSE
--                   next_state <= DATA_READY;
--               END IF;
               
               IF dataReadyBuffer = '1' THEN
                   next_state <= SEND_TX_1;
               ELSE
                   next_state <= DATA_READY;
               END IF;
               
           WHEN SEND_TX_1 =>
                IF txDone = '1' THEN
                    next_state <= SEND_TX_2;
                ELSE
                    next_state <= SEND_TX_1;
                END IF;
           
           WHEN SEND_TX_2 =>
               IF txDone = '1' THEN
                   next_state <= SEND_SPACE;
               ELSE
                   next_state <= SEND_TX_2;
               END IF;
               
           WHEN SEND_SPACE =>
               IF txDone = '1' THEN
                   IF seqDoneBuffer = '0' THEN
                       next_state <= DATA_READY;
                   ELSE
                       next_state <= RECEIVE_DATA;
                   END IF;
               ELSE
                   next_state <= SEND_SPACE;
               END IF;
-----------------------------------------------
	       WHEN OTHERS =>
	           next_state <= INIT;
        END CASE;
    END PROCESS;
END behavioural;