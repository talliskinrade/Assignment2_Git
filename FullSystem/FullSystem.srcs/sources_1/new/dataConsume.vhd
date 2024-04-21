-- Data Processor (DataController.vhd)
-- Asynchronous reset, active high
----------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;
USE work.common_pack.all;

entity dataConsume is
port (
  clk: in std_logic;
  reset: in std_logic; -- synchronous reset
  start: in std_logic; -- goes high to signal data transfer
  numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
--  \numWords_bcd[2]\ : in STD_LOGIC_VECTOR ( 3 downto 0 );
--  \numWords_bcd[1]\ : in STD_LOGIC_VECTOR ( 3 downto 0 );
--  \numWords_bcd[0]\ : in STD_LOGIC_VECTOR ( 3 downto 0 );
  ctrlIn: in std_logic;
  ctrlOut: out std_logic;
  data: in std_logic_vector(7 downto 0);
  dataReady: out std_logic;
  byte: out std_logic_vector(7 downto 0);
  seqDone: out std_logic;
  maxIndex: out BCD_ARRAY_TYPE(2 downto 0);
--  \maxIndex[2]\ : out STD_LOGIC_VECTOR ( 3 downto 0 );
--  \maxIndex[1]\ : out STD_LOGIC_VECTOR ( 3 downto 0 );
--  \maxIndex[0]\ : out STD_LOGIC_VECTOR ( 3 downto 0 );
  dataResults: out CHAR_ARRAY_TYPE(0 to 6) -- index 3 holds the peak
--  \dataResults[0]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
--  \dataResults[1]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
--  \dataResults[2]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
--  \dataResults[3]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
--  \dataResults[4]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
--  \dataResults[5]\ : out STD_LOGIC_VECTOR ( 7 downto 0 );
--  \dataResults[6]\ : out STD_LOGIC_VECTOR ( 7 downto 0 )
);
end dataConsume;

-----------------------------------------------------------------

ARCHITECTURE behavioural OF dataConsume IS

-- State Declaration
-- ALL STATE TYPES
	TYPE state_type IS (INIT, DONE, FIRST_THREE_ctrlSet, FIRST_THREE_ctrlWait,
		FIRST_THREE_regOn, FIRST_THREE_decision, MAIN_LOOP_ctrlSet, MAIN_LOOP_ctrlWait,
		MAIN_LOOP_regOn, MAIN_LOOP_decision, LOOP_END_regOn, LOOP_END_decision, STORE_reg
	);
 
-- Signal Declaration
	SIGNAL cur_state, next_state, prev_state: state_type;
	SIGNAL ctrlIn_delayed, ctrlIn_detected: std_logic;
	SIGNAL start_reg: std_logic;

	SIGNAL reg6, reg5, reg4, reg3, reg2, reg1, reg0: unsigned(7 DOWNTO 0);
        --SIGNAL data0, data1, data2, data3, data4, data5, data6: UNSIGNED(7 DOWNTO 0);

	SIGNAL numWords_add3: integer range 3 to 1002;
	SIGNAL numWords_int: integer range 0 to 999;
	SIGNAL counter: integer range 0 to 999;
	--SIGNAL maxValue: unsigned(7 DOWNTO 0);

	SIGNAL maxIndex_int: integer range 0 to 999;

	SIGNAL ctrlOut_reg: std_logic;
	SIGNAL dataResults_reg: CHAR_ARRAY_TYPE(0 to 6);
	--SIGNAL \dataResults_reg[0]\, \dataResults_reg[1]\, \dataResults_reg[2]\, \dataResults_reg[3]\, \dataResults_reg[4]\, \dataResults_reg[5]\, \dataResults_reg[6]\: STD_LOGIC_VECTOR ( 7 downto 0 );
BEGIN

-------------------------------------------------------------------
  combi_out: PROCESS(cur_state)
  BEGIN
	dataReady <= '0';
--	byte <= "00000000";
	seqDone <= '0';
	
	IF cur_state = FIRST_THREE_regOn OR cur_state = MAIN_LOOP_regOn THEN
--	  byte <= data;
	  dataReady <= '1';
	END IF;

	IF cur_state = DONE THEN
	  seqDone <= '1';
	END IF;
  END PROCESS;

-- there is a potential issue with this combi_out state stuff. If the max Value is the very final one in the sequence, it may not actually output this. However,
-- I think this is unlikely because the last three digits are always 0. However, it is worth trying this to see.

    seq_byteLatch: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                byte <= "00000000";
            ELSE
                byte <= data;
            END IF;
        END IF;
    END PROCESS;





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
  tmp := 0;

  --FOR i IN 0 TO 2 LOOP
    --tmp:=tmp+(TO_INTEGER(unsigned(numWords_bcd(i)))*(10**(i)));
   tmp:=tmp+(TO_INTEGER(unsigned(numWords_bcd(0)))*(10**(0)));
   tmp:=tmp+(TO_INTEGER(unsigned(numWords_bcd(1)))*(10**(1)));
   tmp:=tmp+(TO_INTEGER(unsigned(numWords_bcd(2)))*(10**(2)));
  
  --END LOOP;

  numWords_int <= tmp;    
  numWords_add3 <= (tmp +3);
  END PROCESS;
	  
--make something that converts the integer back to a thing.


  Integer_to_bcd: Process(maxIndex_int)
	Variable tmp: integer range 0 to 99;
  Begin
	maxIndex(2) <= std_logic_vector(to_unsigned((maxIndex_int / 100), 4));
-- can I convert this to vector in same line?
--vhdl integers really round down?
	tmp:= maxIndex_int rem 100;
	maxIndex(1) <= std_logic_vector(to_unsigned((tmp / 10), 4));
	maxIndex(0) <= std_logic_vector(to_unsigned(((tmp mod 10)-1), 4));
  End process;







-------------------------------------------------------------------
seq_state:  PROCESS (clk, reset, start)

--setting up sequential state logic and putting the 'start' signal
-- through a register.
 BEGIN
    IF reset = '1' THEN
      cur_state <= INIT;
    ELSIF rising_edge(clk) THEN
	IF cur_state = FIRST_THREE_regOn OR cur_state = MAIN_LOOP_regOn OR cur_state = LOOP_END_regOn THEN
	  counter <= counter + 1;
	ELSIF cur_state = INIT THEN
	  counter <= 0;
	END IF;
        cur_state <= next_state after 1 ns;
	prev_state <= cur_state;
	start_reg <= start;
        dataResults <= dataResults_reg;
--        \dataResults[0]\ <= dataResults_reg(0);
--        \dataResults[1]\ <= dataResults_reg(1);
--        \dataResults[2]\ <= dataResults_reg(2);
--        \dataResults[3]\ <= dataResults_reg(3);
--        \dataResults[4]\ <= dataResults_reg(4);
--        \dataResults[5]\ <= dataResults_reg(5);
--        \dataResults[6]\ <= dataResults_reg(6);
        
	ctrlOut <= ctrlOut_reg;
    END IF;
   
  END PROCESS;







 

------------------------------------------------------------------
combi_nextState: PROCESS(cur_state, start_reg, ctrlIn_detected, numWords_int, numWords_add3)

BEGIN

  CASE cur_state IS

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
	--maxValue <= TO_UNSIGNED(0,8);
	--counter <= 0;
	ctrlOut_reg <= '0';
	dataResults_reg <= (others => (others => '0'));

--all registers to zero, then:
	if start_reg = '1' then
	  next_state <= FIRST_THREE_ctrlSet;
	else
	  next_state <= INIT;
	end if;


      WHEN DONE =>
	next_state <= INIT;
	
	  
-------- maybe there's a way to streamline these? like just three, one before the 
-- max test, one with the max test, one with the end loop.
--------------------------------------------------------------------
-------- Register 6 States (NORMAL CONDITIONS)
      WHEN FIRST_THREE_ctrlSet =>
	ctrlOut_reg <= not ctrlOut_reg;
	next_state <= FIRST_THREE_ctrlWait;


      WHEN FIRST_THREE_ctrlWait =>
	if ctrlIn_detected = '1' then 
	  next_state <= FIRST_THREE_regOn;
	else
	  next_state <= FIRST_THREE_ctrlWait;
	end if;


      WHEN FIRST_THREE_regOn =>
	reg6 <= UNSIGNED(data) after 2 ns;
	reg5 <= reg6 after 1 ns;
	reg4 <= reg5;
	--??--reg3 <= reg4;
	--counter <= counter + 1;
	next_state <= FIRST_THREE_decision;
      

      WHEN FIRST_THREE_decision =>
	if start_reg = '1' then
	  if counter < numWords_int then
	    if counter < 3 then
--or should it be 4?
	      next_state <= FIRST_THREE_ctrlSet;

	    else
	      next_state <= MAIN_LOOP_ctrlSet;
	    end if;
	  else
	    next_state <= LOOP_END_regOn;
	  end if;
	else
	  next_state <= FIRST_THREE_decision;
	end if;

-------------------------------------------------------------------
------ Registers 3 to 0 (Main Loop)

      WHEN MAIN_LOOP_ctrlSet =>
	ctrlOut_reg <= not ctrlOut_reg;
	next_state <= MAIN_LOOP_ctrlWait;


      WHEN MAIN_LOOP_ctrlWait =>
	if ctrlIn_detected = '1' then 
	  next_state <= MAIN_LOOP_regOn;
	else
	  next_state <= MAIN_LOOP_ctrlWait;
	end if;


      WHEN MAIN_LOOP_regOn =>
	--reg6 <= UNSIGNED(data) after 6 ns;
	--reg5 <= reg6 after 5 ns;
	--reg4 <= reg5 after 4 ns;
	--reg3 <= reg4 after 3 ns;
	--reg2 <= reg3 after 2 ns;
	--reg1 <= reg2 after 1 ns;
	--reg0 <= reg1;
	reg0 <= UNSIGNED(data) after 6 ns;
	reg1 <= reg0 after 5 ns;
	reg2 <= reg1 after 4 ns;
	reg3 <= reg2 after 3 ns;
	reg4 <= reg3 after 2 ns;
	reg5 <= reg4 after 1 ns;
	reg6 <= reg5;

	next_state <= STORE_reg;


      WHEN MAIN_LOOP_decision =>
	if start_reg = '1' then
	  if counter < numWords_int then
	    next_state <= MAIN_LOOP_ctrlSet;
----- loop back to the start of MAIN_LOOP_ctrlSet.
	  else
	    next_state <= LOOP_END_regOn;
	  end if;
	else
	  next_state <= MAIN_LOOP_decision;
	end if;	
	  
--------------------------------------------------------------------
-------- Register states AT FINAL THREE bytes:
---Register 6


      WHEN LOOP_END_regOn =>
	--reg6 <= TO_UNSIGNED(0,8) after 6 ns;
	--reg5 <= reg6 after 5 ns;
	--reg4 <= reg5 after 4 ns;
	--reg3 <= reg4 after 3 ns;
	--reg2 <= reg3 after 2 ns;
	--reg1 <= reg2 after 1 ns;
	--reg0 <= reg1;
	reg0 <= TO_UNSIGNED(0,8) after 6 ns;
	reg1 <= reg0 after 5 ns;
	reg2 <= reg1 after 4 ns;
	reg3 <= reg2 after 3 ns;
	reg4 <= reg3 after 2 ns;
	reg5 <= reg4 after 1 ns;
	reg6 <= reg5;

	next_state <= STORE_reg;


      WHEN LOOP_END_decision =>
	if counter < numWords_int then
	  next_state <= LOOP_END_decision;
	else
	  next_state <= DONE;
	end if;


-----------------------------------------------------------------------------
-- COMPARING REGISTER TO DATARESULT_REG AND STORE VALUES
      WHEN STORE_reg =>
	if reg3 > unsigned(dataResults_reg(3)) then
	  dataResults_reg(0) <= std_logic_vector(reg0);
	  dataResults_reg(1) <= std_logic_vector(reg1);
	  dataResults_reg(2) <= std_logic_vector(reg2);
	  dataResults_reg(3) <= std_logic_vector(reg3);
	  dataResults_reg(4) <= std_logic_vector(reg4);
	  dataResults_reg(5) <= std_logic_vector(reg5);
	  dataResults_reg(6) <= std_logic_vector(reg6);
	  
	  maxIndex_int <= counter - 3;
	end if;
	
	if prev_state = MAIN_LOOP_regOn then
	  next_state <= MAIN_LOOP_decision;
	else
	  next_state <= LOOP_END_decision;
	end if;

    END CASE;
END PROCESS;
END behavioural;