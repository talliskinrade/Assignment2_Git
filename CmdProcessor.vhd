component cmdProc is
    port (
      clk:		in std_logic;
      reset:		in std_logic;
      rxnow:		in std_logic;
      rxData:			in std_logic_vector (7 downto 0);
      txData:			out std_logic_vector (7 downto 0);
      rxdone:		out std_logic;
      ovErr:		in std_logic;
      framErr:	in std_logic;
      txNow:		out std_logic;
      txDone:		in std_logic;
      start: out std_logic;
      numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
      dataReady: in std_logic;
      byte: in std_logic_vector(7 downto 0);
      maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
      dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
      seqDone: in std_logic
    );
  end component;

ARCHITECTURE behavioural OF cmdProc IS

-- State Declaration
-- ALL STATE TYPES
	TYPE state_type IS (
	);
 
-- Signal Declaration

	SIGNAL counter7: integer range 0 to 7;
	SIGNAL counter3: integer range 0 to 3;
BEGIN

-------------------------------------------------------------------
  combi_out: PROCESS(cur_state)
  BEGIN
	txNow <= '0';
	
	IF cur_state = SEND_TX_L OR cur_state = SEND_TX_P OR --etc. THEN
	  txNow <= '1';
	  


	

	ELSIF cur_state = THEN
	  
	END IF;
  END PROCESS;

-------------------------------------------------------------------
--Component/Function Instantiation










-------------------------------------------------------------------
seq_state:  PROCESS (clk, reset, start)


 BEGIN
    IF reset = '1' THEN
      cur_state <= 
    ELSIF rising_edge(clk) THEN
        IF cur_state = 
	END IF;
	
    
    END IF;
   
  END PROCESS;







 

------------------------------------------------------------------
combi_nextState: PROCESS(cur_state, rxData, txDone, counter3, counter7, --[other states necessary]--)

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
	  ELSIF rxData = --etc.

	  END IF:
	
	WHEN BYTE_TO_ASCII_L =>
	  
	  next_state <= RESET_COUNTER_3;
	
	WHEN RESET_COUNTER_3 =>
	  counter7 = counter7 + 1;
	  counter3 <= 0;
	  next_state <= SET_TX_L;
	
	WHEN SET_TX_L =>
	  counter3 = counter3 +1;
	  IF txDone = '1' THEN
	    next_state <= SEND_TX_L;
	  ELSE
	    next_state <= SET_TX_L;
	
	WHEN SEND_TX_L =>
	  IF counter3 < 3 THEN
	    next_state <= SET_TX_L;
	  ELSE
	    IF counter7 < 7 THEN
	      next_state <= BYTE_TO_ASCII_L;
	    ELSE
	      next_state <= ECHO_DATA_START;
	    END IF;
	  END IF;
	


	WHEN DONE =>
	  next_state <= INIT;
	WHEN OTHERS =>
	  next_state <= INIT;

    END CASE;
END PROCESS;

END behavioural;





































