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
	   ECHO_DATA_START,
	   SET_DATA,
	   TRANSMIT,
	   RESET_COUNT,
	   INCREMENT_COUNT,
	   BYTE_TO_BCD,
	   SEND_TO_DP,
	   BYTE_TO_ASCII,
	   SET_TX,
	   SEND_TX,
	   STORE_RESULTS,
	   BYTE_TO_ASCII_L,
	   RESET_COUNTER_3,
	   SET_TX_L,
	   SEND_TX_L,
	   DONE
	);
 
-- Signal Declaration
    SIGNAL cur_state, next_state: state_type;
	SIGNAL counter7: integer range 0 to 7;
	SIGNAL counter3: integer range 0 to 3;
	
-------------------------------------------------------------------
--Component Instantiation

    COMPONENT terminal_echo
    PORT (
        clk: IN STD_LOGIC;
        reset: IN STD_LOGIC;
        rxNow: IN STD_LOGIC;
        txDone: IN STD_LOGIC;
        rxData: IN STD_LOGIC_VECTOR (7 downto 0);
        txData: OUT STD_LOGIC_VECTOR (7 downto 0);
        txNow: OUT STD_LOGIC;
        rxDone: OUT STD_LOGIC
    );
    END COMPONENT;
    
    FOR behavTerminalEcho: terminal_echo USE ENTITY WORK.terminal_echo(behavTerminalEcho);

--End component instantiation
-------------------------------------------------------------------
	
BEGIN
    combi_out: PROCESS(cur_state)
    BEGIN
--	     txNow <= '0';
	
--	     IF cur_state = SEND_TX_L OR cur_state = SEND_TX_P OR --etc. THEN
--	         txNow <= '1';
--	     ELSIF cur_state = THEN
--	     END IF;
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
    combi_nextState: PROCESS(cur_state, rxData, txDone, counter3, counter7) --[other states necessary]--
    BEGIN
        CASE cur_state IS
	       WHEN INIT =>
	           next_state <= ECHO_DATA_START;
	
	       WHEN ECHO_DATA_START =>
	           next_state <= SET_DATA;
	  
	       WHEN SET_DATA =>
	           next_state <= TRANSMIT;

	       WHEN TRANSMIT =>
	           IF rxData = "01001100" OR rxData = "01101100" THEN
	               next_state <= BYTE_TO_ASCII_L;
	               counter7 <= 0;
--	             ELSIF rxData = --etc.
	           END IF;
	
	       WHEN BYTE_TO_ASCII_L =>
	           next_state <= RESET_COUNTER_3;
	
	       WHEN RESET_COUNTER_3 =>
	           counter7 <= counter7 + 1;
	           counter3 <= 0;
	           next_state <= SET_TX_L;
	
	       WHEN SET_TX_L =>
	           counter3 <= counter3 + 1;
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
	               next_state <= ECHO_DATA_START;
	           END IF;
	  
	
	       WHEN DONE =>
	           next_state <= INIT;
	       WHEN OTHERS =>
	           next_state <= INIT;
        END CASE;
    END PROCESS;
    
    behavTerminalEcho: terminal_echo PORT MAP(clk,reset,rxNow,txDone,rxData,txData,txNow,rxDone);
END behavioural;