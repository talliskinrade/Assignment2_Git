library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

ENTITY terminal_echo IS
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
END terminal_echo;

ARCHITECTURE behavTerminalEcho of terminal_echo IS

TYPE state_type IS (INIT, RECEIVE_DATA, SEND_DATA);

SIGNAL dataBuffer: STD_LOGIC_VECTOR (7 downto 0);
SIGNAL receivedDataFlag, sentDataFlag: STD_LOGIC := '0';
SIGNAL currentState, nextState: state_type;

BEGIN

    terminalEcho_nextState: PROCESS (currentState, reset, receivedDataFlag, sentDataFlag)
    BEGIN
        CASE currentState IS
            WHEN INIT =>
                nextState <= RECEIVE_DATA;
            WHEN RECEIVE_DATA =>
                IF receivedDataFlag = '1' THEN
                    nextState <= SEND_DATA;
                ELSE
                    nextState <= RECEIVE_DATA;
                END IF;
            WHEN SEND_DATA =>
                IF sentDataFlag = '1' THEN
                    nextState <= RECEIVE_DATA;
                ELSE
                    nextState <= SEND_DATA;
                END IF;
        END CASE;
    END PROCESS;
    
    terminalEcho_seqState: PROCESS (clk)
    BEGIN
        IF reset = '1' THEN
            currentState <= INIT;
        ELSIF rising_edge(clk) THEN
            currentState <= nextState;
        END IF;
    END PROCESS;
    
    terminalEcho_combiOut: PROCESS (currentState, rxNow, txDone)
    BEGIN
        txNow <= '0';
        rxDone <= '0';
        receivedDataFlag <= '0';
        sentDataFlag <= '0';
        
        IF currentState = RECEIVE_DATA AND rxNow = '1' THEN
            dataBuffer <= rxData;
            rxDone <= '1';
            txData <= dataBuffer;
            receivedDataFlag <= '1';
        END IF;
        IF currentState = SEND_DATA AND txDone = '1' THEN
            txNow <= '1';
            sentDataFlag <= '1';
        END IF;
    END PROCESS;

END behavTerminalEcho;
