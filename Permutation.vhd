----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/19/2019 12:00:19 AM
-- Design Name: 
-- Module Name: Permutation - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Entity
---------------------------------------------------------------------------------
entity Permutation is
    Port(
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic;
        a_rounds    : in  std_logic; -- One: 12 rounds, Zero: 6 rounds
        Sr          : in  std_logic_vector(63 downto 0);  -- Rate
        Sc0, Sc1    : in  std_logic_vector(127 downto 0); -- Capacity
        pSr         : out std_logic_vector(63 downto 0);  -- Permuted rate
        pSc0, pSc1  : out std_logic_vector(127 downto 0); -- Permuted capacity
        done        : out std_logic
    );
end Permutation;

-- Architecture
---------------------------------------------------------------------------------
architecture Behavioral of Permutation is

    -- Types ---------------------------------------------------------------------
    type fsm is (s_idle, s_process, s_done);
    
    -- Signals ------------------------------------------------------------------
    signal S0_o, S1_o, S2_o, S3_o, S4_o    : std_logic_vector(63 downto 0); -- Permutation output after being registered
    signal x2_RC                           : std_logic_vector(63 downto 0); -- Third word after round constant addition
    signal x0_s, x1_s, x2_s, x3_s, x4_s    : std_logic_vector(63 downto 0); -- State words after substitution
    signal x0_p, x1_p, x2_p, x3_p, x4_p    : std_logic_vector(63 downto 0); -- State words after permuattion
    signal round, next_round               : std_logic_vector(3 downto 0);  -- Round number
    signal RC_i                            : natural range 0 to 11; -- Round constant index
    signal state, next_state               : fsm; -- State machine signals
    signal S_sel                           : std_logic; -- Selector of mux

    -- Constants ----------------------------------------------------------------
    type RoundConstant is array (0 to 11) of std_logic_vector(7 downto 0); -- Round constants
    constant RC : RoundConstant := (x"f0", x"e1", x"d2", x"c3", x"b4", x"a5",
                                    x"96", x"87", x"78", x"69", x"5a", x"4b");
    constant zero56             : std_logic_vector(55 downto 0) := (others => '0');
                                    
---------------------------------------------------------------------------------
begin
    -- Outputs assignments
    pSr     <= S0_o;
    pSc0    <= S1_o & S2_o;
    pSc1    <= S3_o & S4_o;
        
    -- Addition of constants
    RC_i    <= conv_integer(round) when(a_rounds = '1') else conv_integer(round) + 6;
    x2_RC   <= S2_o xor (zero56 & RC(RC_i));
    
    -- Substitution layer
    ps: entity work.Sub_layer
        port map(
            x0  => S0_o,
            x1  => S1_o,
            x2  => x2_RC,
            x3  => S3_o,
            x4  => S4_o,
            Sx0 => x0_s,
            Sx1 => x1_s,
            Sx2 => x2_s,
            Sx3 => x3_s,
            Sx4 => x4_s            
        );
     
    -- Diffusion layer
    pl: entity work.Diff_layer
        port map(
           x0   => x0_s,
           x1   => x1_s,
           x2   => x2_s,
           x3   => x3_s,
           x4   => x4_s,
           Dx0  => x0_p,
           Dx1  => x1_p,
           Dx2  => x2_p,
           Dx3  => x3_p,
           Dx4  => x4_p 
        );
    
    -- Clock Process
    perm_clk: process(clk)
    begin
        if rising_edge(clk) then -- Registering signals
            if (rst = '1') then
                state   <= s_idle;
            else
                state   <= next_state;     
            end if;           
            round   <= next_round;
            if (S_sel = '1') then
                S0_o    <= x0_p;
                S1_o    <= x1_p;
                S2_o    <= x2_p;
                S3_o    <= x3_p;
                S4_o    <= x4_p;  
            else
                S0_o    <= Sr;
                S1_o    <= Sc0(127 downto 64);
                S2_o    <= Sc0(63 downto 0);
                S3_o    <= Sc1(127 downto 64);
                S4_o    <= Sc1(63 downto 0);
            end if;                    
        end if;
    end process perm_clk;
    
    -- State machine
    perm_fsm: process(state, start, round, a_rounds)
    begin
        -- Default values
        next_state  <= s_idle;
        next_round  <= (others => '0');   
        S_sel       <= '0';    
        done        <= '0';
        
        -- Case statement       
        case state is
            when s_idle => -- Wait for start
                if (start = '1') then
                    next_state  <= s_process;
                else
                    next_state  <= s_idle;
                end if;              
            when s_process => -- permutation
                S_sel       <= '1';
                next_round  <= round + 1;
                if (a_rounds = '1' and round = 11) or (a_rounds = '0' and round = 5) then -- pa = 12, pb = 6
                    next_round  <= (others => '0');
                    next_state  <= s_done;
                else
                    next_state  <= s_process;
                end if;               
            when s_done => -- Done permutation
                done        <= '1';
                if (start = '1') then
                    next_state  <= s_process;
                else
                    next_state  <= s_idle;
                end if;             
            when others => null; -- Other cases
        end case;
    end process perm_fsm;

end Behavioral;
