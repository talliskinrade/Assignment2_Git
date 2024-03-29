
-- Data Processor (DataController.vhd)
-- Asynchronous reset, active high
------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;
USE work.common_pack.all;

entity dataConsume is
port (
  clk:		in std_logic;
  reset:        in std_logic; -- synchronous reset
  start: in std_logic; -- goes high to signal data transfer
  numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
  ctrlIn: in std_logic;
  ctrlOut: out std_logic;
  data: in std_logic_vector(7 downto 0);
  dataReady: out std_logic;
  byte: out std_logic_vector(7 downto 0);
  seqDone: out std_logic;
  maxIndex: out BCD_ARRAY_TYPE(2 downto 0);
  dataResults: out CHAR_ARRAY_TYPE(0 to 6) -- index 3 holds the peak
);
end dataConsume;

-----------------------------------------------------------------

ARCHITECTURE behavioural OF dataConsume IS

-- State Declaration
-- ALL STATE TYPES
	TYPE state_type IS (INIT, DONE, FIRST_THREE_ctrlSet, FIRST_THREE_ctrlWait,
        FIRST_THREE_regOn, FIRST_THREE_decision, MAIN_LOOP_ctrlSet, MAIN_LOOP_ctrlWait,
        MAIN_LOOP_regOn, MAIN_LOOP_decision, LOOP_END_regOn, LOOP_END_decision
      );
 
-- Signal Declaration
	signal ctrlIn_delayed, ctrlIn_detected: std_logic;
	SIGNAL start_reg: std_logic;

	SIGNAL reg6, reg5, reg4, reg3, reg2, reg1, reg0: unsigned(7 DOWNTO 0);
        --SIGNAL data0, data1, data2, data3, data4, data5, data6: UNSIGNED(7 DOWNTO 0);

	SIGNAL numWords_add3: integer range 3 to 1002;
	SIGNAL numWords_int: integer range 0 to 999;
	SIGNAL counter: integer range 0 to 999;
	--SIGNAL maxValue: unsigned(7 DOWNTO 0);
BEGIN

-------------------------------------------------------------------
  combi_out: PROCESS(cur_state)
  BEGIN
	dataReady <= '0';
	byte <= '00000000';
	seqDone <= '0';
	
	IF cur_state = FIRST_THREE_regOn
	OR cur_state = MAIN_LOOP_regOn THEN

	  byte <= data;
	  dataReady <= '1';

	END IF;
	IF cur_state = DONE THEN
	  seqDone = '1';
	END IF;
  END PROCESS;

--- there is a potential issue with this combi_out state stuff. If the max Value is the very final one in the sequence, it may not actually output this. However,
-- I think this is unlikely because the last three digits are always 0. However, it is worth trying this to see.







--fill in list

-------------------------------------------------------------------
--Component Instantiation


--Data Generation Two-Phase Protocol

  delay_CtrlIn: process(clk)     
    begin
      if rising_edge(clk) then
        ctrlIn_delayed <= ctrlIn;
      end if;
    end process;
  
  ctrlIn_detected <= ctrlIn xor ctrlIn_delayed;

-- Registers:

-- use this to get the reg6_in.





  bcd_to_integer: PROCESS(numWords_bcd)
	    -- variable of type integer with constrained range and initial value

  VARIABLE tmp:INTEGER RANGE 0 TO 999:=0;  -- store the sum

  BEGIN
  FOR i IN 0 TO 2 LOOP
    tmp:=tmp+TO_INTEGER(numWords_bcd(i))*(10**(2-i));
  
  END LOOP;

  numWords_int <= tmp;    
  numWords_add3 <= (tmp +3);
  END PROCESS;
	  
--make something that converts the integer back to a thing.


  Integer_to_bcd: Process(maxIndex_int)
	Variable tmp: integer range 0 to 99;
  Begin
	maxIndex(0) <= to_unsigned((maxIndex_int / 100), 4);
-- can I convert this to vector in same line?
--vhdl integers really round down?
	tmp:= maxIndex_int rem 100;
	MaxIndex(1) <= to_unsigned((tmp / 10), 4);
	MaxIndex(2) <= to_unsigned((tmp mod 10), 4);
  End process;














-------------------------------------------------------------------
seq_state:  PROCESS (clk, reset, start)

--setting up sequential state logic and putting the 'start' signal
-- through a register.
 BEGIN
    IF reset = '1' THEN
      curState <= INIT;
    ELSIF rising_edge(clk) THEN
        curState <= nextState;
	start_reg <= start;
      
      
    END IF;
   
  END PROCESS;







 

------------------------------------------------------------------
combi_nextState: PROCESS(curState, start_reg, ctrlIn_detected, numWords_int, numWords_add3)

BEGIN

  CASE curState IS

-----INIT and DONE states:

      WHEN INIT =>
	--reset all registers
	reg6 <= TO_UNSIGNED(0,8);
	reg5 <= TO_UNSIGNED(0,8);
	reg4 <= TO_UNSIGNED(0,8);
	reg3 <= TO_UNSIGNED(0,8);
	reg2 <= TO_UNSIGNED(0,8);
	reg1 <= TO_UNSIGNED(0,8);
	reg0 <= TO_UNSIGNED(0,8);
	--data0 <= TO_UNSIGNED(0,8);
	--data1 <= TO_UNSIGNED(0,8);
	--data2 <= TO_UNSIGNED(0,8);
	--data3 <= TO_UNSIGNED(0,8);
	--data4 <= TO_UNSIGNED(0,8);
	--data5 <= TO_UNSIGNED(0,8);
	--data6 <= TO_UNSIGNED(0,8);
	maxValue <= TO_UNSIGNED(0,8);

	counter = 0;



--all registers to zero, then:
	if start_reg = '1' then
	  nextState <= FIRST_THREE_ctrlSet;
	else
	  nextState <= INIT;
	end if;

      WHEN DONE =>
	nextState => INIT;
	
	  
-------- maybe there's a way to streamline these? like just three, one before the 
-- max test, one with the max test, one with the end loop.
--------------------------------------------------------------------
-------- Register 6 States (NORMAL CONDITIONS)
      WHEN FIRST_THREE_ctrlSet =>
	ctrlOut <= not ctrlOut;
	nextState <= FIRST_THREE_ctrlWait;

      WHEN FIRST_THREE_ctrlWait =>
	if ctrlIn_detected = '1' then 
	  nextState <= FIRST_THREE_regOn;
	else
	  nextState <= FIRST_THREE_ctrlWait;

      WHEN FIRST_THREE_regOn =>
	reg6 <= UNSIGNED(data);
	reg5 <= reg6;
	reg4 <= reg5;
	--??--reg3 <= reg4;
	counter <= counter + 1;
	nextState <= FIRST_THREE_decision;
      
      WHEN FIRST_THREE_decision =>
	if start_reg = '1' then
	  if counter < numWords_int then
	    if counter < 3 then
--or should it be 4?
	      nextState <= FIRST_THREE_ctrlSet;

	    else
	      nextState <= MAIN_LOOP_ctrlSet;
	    end if;
	  else
	    nextState <= LOOP_END_ctrlSet;
	  end if;
	else
	  nextState <= FIRST_THREE_decision;
	end if;

--------------------------------------------------------------------
------ Registers 3 to 0 (Main Loop)

      WHEN MAIN_LOOP_ctrlSet =>
	ctrlOut <= not ctrlOut;
	nextState <= MAIN_LOOP_ctrlWait;

      WHEN MAIN_LOOP_ctrlWait =>
	if ctrlIn_detected = '1' then 
	  nextState <= MAIN_LOOP_regOn;
	else
	  nextState <= MAIN_LOOP_ctrlWait;

      WHEN MAIN_LOOP_regOn =>
	reg6 <= UNSIGNED(data);
	reg5 <= reg6;
	reg4 <= reg5;
	reg3 <= reg4;
	reg2 <= reg3;
	reg1 <= reg2;
	reg0 <= reg1;
	counter <= counter +1;
	if reg4 > dataResults(3) then
	  dataResults(0) <= std_logic_vector(reg1);
	  dataResults(1) <= std_logic_vector(reg2);
	  dataResults(2) <= std_logic_vector(reg3);
	  dataResults(3) <= std_logic_vector(reg4);
	  dataResults(4) <= std_logic_vector(reg5);
	  dataResults(5) <= std_logic_vector(reg6);
	  dataResults(6) <= data;
	  maxIndex <= counter -3;

---- maybe add more things here?

	end if;
	nextState <= MAIN_LOOP_decision;

      WHEN MAIN_LOOP_decision =>
	if start_reg = '1' then
	  if counter < numWords_int then
	    nextState <= MAIN_LOOP_ctrlSet;
----- loop back to the start of MAIN_LOOP_ctrlSet.


	  else
	    nextState <= LOOP_END_ctrlSet;

	  end if;
	else
	  nextState <= MAIN_LOOP_decision;
	end if;	
	  
--------------------------------------------------------------------
-------- Register states AT FINAL THREE bytes:
---Register 6


      WHEN LOOP_END_regOn =>
	reg6 <= TO_UNSIGNED(0,8);
	reg5 <= reg6;
	reg4 <= reg5;
	reg3 <= reg4;
	reg2 <= reg3;
	reg1 <= reg2;
	reg0 <= reg1;
	counter <= counter +1;
	if reg4 > dataResults(3) then
	  dataResults(0) <= std_logic_vector(reg1);
	  dataResults(1) <= std_logic_vector(reg2);
	  dataResults(2) <= std_logic_vector(reg3);
	  dataResults(3) <= std_logic_vector(reg4);
	  dataResults(4) <= std_logic_vector(reg5);
	  dataResults(5) <= std_logic_vector(reg6);
	  dataResults(6) <= "00000000";
	  
	  maxIndex <= counter - 3;
	end if;

	nextState <= LOOP_END_decision;


      WHEN LOOP_END_decision =>
	if counter < numWords_add3 then
	  nextState <= LOOP_END_decision;
	else
	  nextState <= DONE;

END PROCESS;

END behavioural;






































































