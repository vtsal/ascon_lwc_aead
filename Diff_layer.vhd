----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/19/2019 02:30:47 PM
-- Design Name: 
-- Module Name: Diff_layer - Behavioral
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
entity Diff_layer is
    Port(
        x0,  x1,  x2,  x3,  x4   : in  std_logic_vector (63 downto 0);
        Dx0, Dx1, Dx2, Dx3, Dx4  : out std_logic_vector (63 downto 0)
    );
end Diff_layer;

-- Architecture
----------------------------------------------------------------------------------
architecture Behavioral of Diff_layer is

----------------------------------------------------------------------------------
begin

    
    
    Dx0 <= x0 xor (x0(18 downto 0) & x0(63 downto 19)) xor (x0(27 downto 0) & x0(63 downto 28));  
    Dx1 <= x1 xor (x1(60 downto 0) & x1(63 downto 61)) xor (x1(38 downto 0) & x1(63 downto 39)); 
    Dx2 <= x2 xor (x2(0)           & x2(63 downto 1))  xor (x2(5 downto 0)  & x2(63 downto 6)); 
    Dx3 <= x3 xor (x3(9 downto 0)  & x3(63 downto 10)) xor (x3(16 downto 0) & x3(63 downto 17)); 
    Dx4 <= x4 xor (x4(6 downto 0)  & x4(63 downto 7))  xor (x4(40 downto 0) & x4(63 downto 41)); 

end Behavioral;
