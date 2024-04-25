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
      TYPE state_type IS (INIT, DONE, MAIN_LOOP_ctrlSet, MAIN_LOOP_ctrlWait,
            MAIN_LOOP_regOn, MAIN_LOOP_decision, LOOP_END_regOn, LOOP_END_decision, STORE_reg
      );
 
-- Signal Declaration
      SIGNAL cur_state, next_state, prev_state: state_type;
      SIGNAL ctrlIn_delayed, ctrlIn_detected, reg_ctrlIn_detected: std_logic;
      SIGNAL start_reg: std_logic;
      SIGNAL seqDone_reg: std_logic;

      SIGNAL reg6, reg5, reg4, reg3, reg2, reg1, reg0: std_logic_vector(7 DOWNTO 0);
      SIGNAL numWords_int: integer range 0 to 999;
      SIGNAL counter: integer range 0 to 999;

      SIGNAL maxIndex_int: integer range 0 to 999;

      SIGNAL ctrlOut_reg: std_logic;
      SIGNAL dataResults_reg: CHAR_ARRAY_TYPE(0 to 6);
      SIGNAL numWords_bcd_reg: BCD_ARRAY_TYPE(2 downto 0);
BEGIN

-------------------------------------------------------------------
    combi_out: PROCESS(cur_state)
    BEGIN
        seqDone <= '0';

        IF cur_state = DONE THEN
            seqDone <= '1';
        END IF;
    END PROCESS;
    
    combi_setDataReady: PROCESS (cur_state)
    BEGIN
        dataReady <= '0';
        IF cur_state = MAIN_LOOP_regOn THEN
            dataReady <= '1';
        END IF;
    END PROCESS;

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
    
--Data Generation Two-Phase Protocol
    delay_CtrlIn: PROCESS (clk)    
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                ctrlIn_delayed <= '0';
            ELSE
                ctrlIn_delayed <= ctrlIn;
            END IF;
        END IF;
    END PROCESS;
    
    detect_ctrlIn: PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                ctrlIn_detected <= '0';
            ELSE
                ctrlIn_detected <= ctrlIn XOR ctrlIn_delayed;
            END IF;
        END IF;
    END PROCESS;

    bcd_to_integer: PROCESS(clk, numWords_bcd_reg)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                numWords_int <= 0;
            ELSE
                numWords_int <= TO_INTEGER(unsigned(numWords_bcd_reg(0))) + TO_INTEGER(unsigned(numWords_bcd_reg(1)))*10 + TO_INTEGER(unsigned(numWords_bcd_reg(2)))*100;
            END IF;
        END IF;
    END PROCESS;

    Integer_to_bcd: PROCESS(clk, maxIndex_int)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                maxIndex(2) <= "0000";
                maxIndex(1) <= "0000";
                maxIndex(0) <= "0000";
            ELSE
                maxIndex(2) <= std_logic_vector(to_unsigned((maxIndex_int / 100), 4));
                maxIndex(1) <= std_logic_vector(to_unsigned(((maxIndex_int rem 100) / 10), 4));
                maxIndex(0) <= std_logic_vector(to_unsigned((((maxIndex_int rem 100) rem 10)-1), 4));
            END IF;
        END IF;
    END PROCESS;

-------------------------------------------------------------------
    updateCounter:  PROCESS (clk, reset, start)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' OR cur_state = INIT THEN
                counter <= 0;
            ELSIF cur_state = MAIN_LOOP_regOn OR cur_state = LOOP_END_regOn THEN
                counter <= counter + 1;
            END IF;
        END IF;
    END PROCESS;
    
    seq_start_reg: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            start_reg <= start;
        END IF;
    END PROCESS;
    
    seq_numWords_bcd_reg: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            numWords_bcd_reg <= numWords_bcd;
        END IF;
    END PROCESS;
    
    seq_dataResults: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            dataResults <= dataResults_reg;
        END IF;
    END PROCESS;
    
    seq_ctrlOut: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            ctrlOut <= ctrlOut_reg;
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

    transit_reg_0: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF RESET = '1' OR cur_state = INIT OR cur_state = LOOP_END_regOn THEN
                reg0 <= "00000000";
            ELSIF cur_state = MAIN_LOOP_regOn THEN
                reg0 <= data;
            END IF;
        END IF;
    END PROCESS;

    transit_reg_1: PROCESS(clk, reg0)
    BEGIN
        IF rising_edge(clk) THEN
            IF RESET = '1' OR cur_state = INIT THEN
                reg1 <= "00000000";
            ELSIF cur_state = MAIN_LOOP_regOn OR cur_state = LOOP_END_regOn THEN
                reg1 <= reg0; 
            END IF;
        END IF;
    END PROCESS;

    transit_reg_2: PROCESS(clk, reg1)
    BEGIN
        IF rising_edge(clk) THEN
            IF RESET = '1' OR cur_state = INIT THEN
                reg2 <= "00000000";
            ELSIF cur_state = MAIN_LOOP_regOn OR cur_state = LOOP_END_regOn THEN
                reg2 <= reg1;
            END IF;
        END IF;
    END PROCESS;

    transit_reg_3: PROCESS(clk, reg2)
    BEGIN
        IF rising_edge(clk) THEN
            IF RESET = '1' OR cur_state = INIT THEN
                reg3 <= "00000000";
            ELSIF cur_state = MAIN_LOOP_regOn OR cur_state = LOOP_END_regOn THEN
                reg3 <= reg2;
            END IF;
        END IF;
    END PROCESS;

    transit_reg_4: PROCESS(clk, reg3)
    BEGIN
        IF rising_edge(clk) THEN
            IF RESET = '1' OR cur_state = INIT THEN
                reg4 <= "00000000";
            ELSIF cur_state = MAIN_LOOP_regOn OR cur_state = LOOP_END_regOn THEN
                reg4 <= reg3;
            END IF;
        END IF;
    END PROCESS;

    transit_reg_5: PROCESS(clk, reg4)
    BEGIN
        IF rising_edge(clk) THEN
            IF RESET = '1' OR cur_state = INIT THEN
                reg5 <= "00000000";
            ELSIF cur_state = MAIN_LOOP_regOn OR cur_state = LOOP_END_regOn THEN
                reg5 <= reg4;
            END IF;
        END IF;
    END PROCESS;

    transit_reg_6: PROCESS(clk, reg5)
    BEGIN
        IF rising_edge(clk) THEN
            IF RESET = '1' OR cur_state = INIT THEN
                reg6 <= "00000000";
            ELSIF cur_state = MAIN_LOOP_regOn OR cur_state = LOOP_END_regOn THEN
                reg6 <= reg5;
            END IF;
        END IF;
    END PROCESS;

    seq_ctrl_out: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF RESET = '1' or cur_state = INIT THEN
                ctrlOut_reg <= '0';
            ELSIF cur_state = MAIN_LOOP_ctrlSet THEN
                IF start_reg = '1' THEN
                    ctrlOut_reg <= not ctrlOut_reg;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    seq_max_Index: process(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF RESET = '1' or cur_state = INIT THEN
                maxIndex_int <= 0;
            ELSIF cur_state = MAIN_LOOP_regOn or cur_state = LOOP_END_regOn THEN
                IF reg3 > dataResults_reg(3) THEN
                    maxIndex_int <= counter - 3;
                END IF;
            END IF;
        END IF;
    END PROCESS;


    data_reg: process(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF RESET = '1' or cur_state = INIT THEN
                dataResults_reg <= (others => (others => '0'));

            ELSIF cur_state = MAIN_LOOP_regOn or cur_state = LOOP_END_regOn THEN
                IF reg3 > dataResults_reg(3) THEN
                    dataResults_reg(0) <= reg0;
                    dataResults_reg(1) <= reg1;
                    dataResults_reg(2) <= reg2;
                    dataResults_reg(3) <= reg3;
                    dataResults_reg(4) <= reg4;
                    dataResults_reg(5) <= reg5;
                    dataResults_reg(6) <= reg6;
                END IF;
            END IF;
        END IF;
    END PROCESS;

------------------------------------------------------------------
    combi_nextState: PROCESS(cur_state, start_reg, ctrlIn_detected, numWords_int, counter)
    BEGIN

        CASE cur_state IS
-----INIT and DONE states:
            WHEN INIT =>
                next_state <= MAIN_LOOP_ctrlSet;

            WHEN DONE =>
                next_state <= INIT;

            WHEN MAIN_LOOP_ctrlSet =>
                IF start_reg = '1' THEN
                    next_state <= MAIN_LOOP_ctrlWait;
                END IF;

            WHEN MAIN_LOOP_ctrlWait =>
                IF ctrlIn_detected = '1' THEN
                    next_state <= MAIN_LOOP_regOn;
                ELSE
                    next_state <= MAIN_LOOP_ctrlWait;
                END IF;

            WHEN MAIN_LOOP_regOn =>
                next_state <= MAIN_LOOP_decision;


            WHEN MAIN_LOOP_decision =>
                IF counter < numWords_int THEN
                    next_state <= MAIN_LOOP_ctrlSet;
----- loop back to the start of MAIN_LOOP_ctrlSet.
                ELSE
                    next_state <= LOOP_END_regOn;
                END IF;
--------------------------------------------------------------------
-------- Register states AT FINAL THREE bytes:
---Register 6

            WHEN LOOP_END_regOn =>
                next_state <= LOOP_END_decision;

            WHEN LOOP_END_decision =>
                IF counter < numWords_int THEN
                    next_state <= LOOP_END_decision;
                ELSE
                    next_state <= DONE;
                END IF;

            WHEN OTHERS =>
                next_state <= INIT;
        END CASE;
    END PROCESS;
END behavioural;