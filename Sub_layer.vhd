----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/19/2019 07:53:42 PM
-- Design Name: 
-- Module Name: Sub_layer - Behavioral
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


entity Sub_layer is
    Port(
        x0,  x1,  x2,  x3,  x4   : in  std_logic_vector(63 downto 0);
        Sx0, Sx1, Sx2, Sx3, Sx4  : out std_logic_vector(63 downto 0)
    );
end Sub_layer;

-- Architecture
----------------------------------------------------------------
architecture Behavioral of Sub_layer is
    
    -- Signals -------------------------------------------------
    signal temp_in, temp_out    : std_logic_vector(319 downto 0); -- Every column of current and updated state
    
----------------------------------------------------------------
begin

    Sl: for i in 63 downto 0 generate
        temp_in(5*i + 4 downto 5*i + 0) <= x0(i) & x1(i) & x2(i) & x3(i) & x4(i); -- Sbox input: x0,x1,x2,x3,x4
        Sb: entity work.Sbox
            Port map(
                x  => temp_in(5*i + 4 downto 5*i + 0),
                Sx => temp_out(5*i + 4 downto 5*i + 0)
            );
        Sx0(i) <= temp_out(5*i + 4);
        Sx1(i) <= temp_out(5*i + 3);
        Sx2(i) <= temp_out(5*i + 2);
        Sx3(i) <= temp_out(5*i + 1);
        Sx4(i) <= temp_out(5*i);
    end generate Sl;
    
end Behavioral;
