----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/09/2019 04:10:23 PM
-- Design Name: 
-- Module Name: SomeFunctions - Behavioral
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Declarations
----------------------------------------------------------------------------------
package SomeFunction is
    
    function pad (I             : in std_logic_vector(31 downto 0);
                  bytes         : in std_logic_vector(2 downto 0)) return std_logic_vector;
    
    function trunc (bdi         : in std_logic_vector(31 downto 0);
                    bdi_eot     : in std_logic;
                    bdi_size    : in std_logic_vector(2 downto 0)) return std_logic_vector;
                    
    function ext (O             : in std_logic_vector(127 downto 0);
                  bytes         : in std_logic_vector(1 downto 0)) return std_logic_vector;
                      
end package SomeFunction;

-- Body
----------------------------------------------------------------------------------
package body SomeFunction is

    -- Padding --------------------------------------------------
    function pad (I : in std_logic_vector(31 downto 0); bytes : in std_logic_vector(2 downto 0)) return std_logic_vector is
    variable temp : std_logic_vector(31 downto 0);
    begin
        case bytes is
            when "000" =>
                temp    := x"80000000";
            when "001" =>
                temp    := I(31 downto 24) & x"800000";
            when "010" =>
                temp    := I(31 downto 16) & x"8000";
            when "011" =>
                temp    := I(31 downto 8)  & x"80";
            when others =>
                temp    := I;
        end case;
    return temp;
    end function;
    
    -- Truncate -----------------------------------------------------------------
    function trunc (bdi : in std_logic_vector(31 downto 0); bdi_eot : in std_logic; bdi_size : in std_logic_vector(2 downto 0)) return std_logic_vector is
    variable temp : std_logic_vector(31 downto 0);
    begin
        if (bdi_eot = '0') then -- No truncation
            temp := bdi;
        else
            case bdi_size is
                when "001" =>
                    temp := bdi(31 downto 24) & x"000000";
                when "010" =>
                    temp := bdi(31 downto 16) & x"0000";
                when "011" =>
                    temp := bdi(31 downto 8) & x"00";
                when others =>
                    temp := bdi;
                end case;
        end if;
    return temp;
    end function;
    
    -- Extract -------------------------------------------------------------------
    function ext (O : in std_logic_vector(127 downto 0); bytes : in std_logic_vector(1 downto 0)) return std_logic_vector is
    begin
    return O((127 - conv_integer(bytes)*32) downto (96 - conv_integer(bytes)*32));
    end function;
    
end package body SomeFunction;