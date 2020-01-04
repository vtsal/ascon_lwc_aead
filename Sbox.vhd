----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/19/2019 01:00:34 PM
-- Design Name: 
-- Module Name: Sbox - Behavioral
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

-- Entity
----------------------------------------------------------------------------------
entity Sbox is
  Port (x   : in std_logic_vector (0 to 4);
        Sx  : out std_logic_vector (0 to 4)
        );
end Sbox;

--Architecture
----------------------------------------------------------------------------------
architecture Behavioral of Sbox is

    -- Signals -------------------------------------------------------------------
    signal x0,x00,x1,x2,x22,x3,x4,x44,t0    :std_logic;
    signal t1   :std_logic_vector(0 to 3);

----------------------------------------------------------------------------------
begin

    x0      <= x(0) xor x(4);
    x4      <= x(4) xor x(3);
    x2      <= x(2) xor x(1);
    
    t0      <= x0 and not(x4); 
    t1(0)   <= x2 and not(x(1));
    
    x00     <= x0 xor t1(0);
    t1(1)   <= x4 and (not x(3));
    
    x22     <= x2 xor t1(1);
    t1(2)   <= x(1) and (not x00);
    
    x44     <= x4 xor t1(2);
    t1(3)   <= x(3) and (not x22);
    
    x1      <= x(1) xor t1(3);
    x3      <= x(3) xor t0;
    
    Sx(1)   <= x1 xor x00;
    Sx(3)   <= x3 xor x22;
    Sx(0)   <= x00 xor x44;
    Sx(2)   <= not x22;
    Sx(4)   <= x44;
    
end Behavioral;
