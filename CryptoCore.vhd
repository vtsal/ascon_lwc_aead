----------------------------------------------------------------------------------
-- Create Date: 10/18/2019 12:18:11 PM
-- Design Name: 
-- Module Name: cryptocore - Behavioral
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
use work.design_pkg.all;

-- Entity
--------------------------------------------------------------------------------
entity CryptoCore is
    Port ( 
            clk             : in   STD_LOGIC;
            rst             : in   STD_LOGIC;
            --PreProcessor===============================================
            ----!key----------------------------------------------------
            key             : in   STD_LOGIC_VECTOR (CCSW      -1 downto 0);
            key_valid       : in   STD_LOGIC;
            key_ready       : out  STD_LOGIC;
            ----!Data----------------------------------------------------
            bdi             : in   STD_LOGIC_VECTOR (CCW       -1 downto 0);
            bdi_valid       : in   STD_LOGIC;
            bdi_ready       : out  STD_LOGIC;
            --bdi_partial     : in   STD_LOGIC;
            bdi_pad_loc     : in   STD_LOGIC_VECTOR (CCWdiv8   -1 downto 0);
            bdi_valid_bytes : in   STD_LOGIC_VECTOR (CCWdiv8   -1 downto 0);
            bdi_size        : in   STD_LOGIC_VECTOR (3       -1 downto 0);
            bdi_eot         : in   STD_LOGIC;
            bdi_eoi         : in   STD_LOGIC;
            bdi_type        : in   STD_LOGIC_VECTOR (4       -1 downto 0);
            decrypt_in      : in   STD_LOGIC;
            hash_in         : in   STD_LOGIC;
            key_update      : in   STD_LOGIC;
            --!Post Processor=========================================
            bdo             : out  STD_LOGIC_VECTOR (CCW       -1 downto 0);
            bdo_valid       : out  STD_LOGIC;
            bdo_ready       : in   STD_LOGIC;
            bdo_type        : out  STD_LOGIC_VECTOR (4       -1 downto 0);
            bdo_valid_bytes : out  STD_LOGIC_VECTOR (CCWdiv8   -1 downto 0);
            end_of_block    : out  STD_LOGIC;
            msg_auth        : out std_logic;
            msg_auth_valid  : out std_logic;
            msg_auth_ready  : in  std_logic
         );
            
end CryptoCore;

-- Architecture
------------------------------------------------------------------------------
architecture Behavorial of CryptoCore is


------------------------------------------------------------------------------
begin

    MainCipher: entity work.ASCON128
    Port map(
        clk             => clk,
        rst             => rst,
        -- Data Input
        key             => key,
        bdi             => bdi,
        -- Key Control
        key_valid       => key_valid,
        key_ready       => key_ready,
        key_update      => key_update,
        -- BDI Control
        bdi_valid       => bdi_valid,
        bdi_ready       => bdi_ready,
        --bdi_partial     => bdi_partial,
        bdi_pad_loc     => bdi_pad_loc,
        bdi_valid_bytes => bdi_valid_bytes,
        bdi_size        => bdi_size,
        bdi_eot         => bdi_eot,
        bdi_eoi         => bdi_eoi,
        bdi_type        => bdi_type,
        hash_in         => hash_in,
        decrypt_in      => decrypt_in,
        -- Data Output
        bdo             => bdo,
        -- BDO Control
        bdo_valid       => bdo_valid,
        bdo_ready       => bdo_ready,
        bdo_valid_bytes => bdo_valid_bytes,
        end_of_block    => end_of_block,
        bdo_type        => bdo_type,
        -- Tag Verification
        msg_auth        => msg_auth,
        msg_auth_valid  => msg_auth_valid,
        msg_auth_ready  => msg_auth_ready 
    );

end Behavorial;