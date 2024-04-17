LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_CmdProcessor IS END;

architecture Behavioral of tb_CmdProcessor is
    COMPONENT cmdProc
    PORT (
        clk: IN std_logic;
        reset: IN std_logic;
        rxnow: IN std_logic;
        rxData: IN std_logic_vector (7 downto 0);
        txData: OUT std_logic_vector (7 downto 0);
        rxdone: OUT std_logic;
        ovErr: IN std_logic;
        framErr: IN std_logic;
        txNow: OUT std_logic;
        txDone: IN std_logic;
        start: OUT std_logic;
--        numWords_bcd: OUT BCD_ARRAY_TYPE(2 downto 0);
        dataReady: IN std_logic;
        byte: IN std_logic_vector(7 downto 0);
--        maxIndex: IN BCD_ARRAY_TYPE(2 downto 0);
--        dataResults: IN CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
        seqDone: IN std_logic;
        rxValid: IN std_logic);
    END COMPONENT;
    
    FOR behavioural: cmdProc USE ENTITY WORK.cmdProc(behavioural);
    
    SIGNAL reset, clk: STD_LOGIC := '0';
    SIGNAL rxnow, rxdone, ovErr, framErr, txNow, txDone, start: STD_LOGIC;
    SIGNAL dataReady, seqDone, rxValid: STD_LOGIC;
    SIGNAL rxData, txData, byte: STD_LOGIC_VECTOR (7 downto 0);
    CONSTANT clk_period_half: time := 5 ns;
BEGIN
    clk <= NOT clk AFTER clk_period_half WHEN NOW < 3 us ELSE clk;
    reset <= '0' AFTER 5 ns,
        '1' AFTER 10 ns;
        
    behavioural: cmdProc PORT MAP(clk,reset,rxnow,rxData,txData,rxdone,ovErr,framErr,
        txNow,txDone,start,dataReady,byte,seqDone,rxValid);

END Behavioral;