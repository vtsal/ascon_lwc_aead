----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/09/2019 02:37:27 PM
-- Design Name: 
-- Module Name: myReg - Behavioral
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
------------------------------------------------------------
entity myReg is
    generic (b : integer);
    Port(
        clk     : in std_logic;
        rst     : in std_logic;
        en      : in std_logic;
        D_in    : in std_logic_vector(b-1 downto 0);
        D_out   : out std_logic_vector(b-1 downto 0)
    );
end myReg;

-- Architecture
------------------------------------------------------------
architecture Behavioral of myReg is

------------------------------------------------------------
begin
    
    Store: process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                D_out <= (others => '0');
            elsif (en = '1') then
                D_out <= D_in;
            end if;
        end if;
    end process;

end Behavioral;
