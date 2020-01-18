----------------------------------------------------------------------------------
-- ASCON_AEAD(V1)
-- Behnaz Rezvani
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.SomeFunction.all;

-- Entity
----------------------------------------------------------------------------------
entity ASCON128 is
    Port(
        clk             : in std_logic;
        rst             : in std_logic;
        -- Data Input
        key             : in std_logic_vector(31 downto 0); -- SW = 32
        bdi             : in std_logic_vector(31 downto 0); -- W = 32
        -- Key Control
        key_valid       : in std_logic;
        key_ready       : out std_logic;
        key_update      : in std_logic;
        -- BDI Control
        bdi_valid       : in std_logic;
        bdi_ready       : out std_logic;
        bdi_pad_loc     : in std_logic_vector(3 downto 0); -- W/8 = 4
        bdi_valid_bytes : in std_logic_vector(3 downto 0); -- W/8 = 4
        bdi_size        : in std_logic_vector(2 downto 0); -- W/(8+1) = 3
        bdi_eot         : in std_logic;
        bdi_eoi         : in std_logic;
        bdi_type        : in std_logic_vector(3 downto 0);
        hash_in         : in std_logic;
        decrypt_in      : in std_logic;
        -- Data Output
        bdo             : out std_logic_vector(31 downto 0); -- W = 32
        -- BDO Control
        bdo_valid       : out std_logic;
        bdo_ready       : in std_logic;
        bdo_valid_bytes : out std_logic_vector(3 downto 0); -- W/8 = 4
        end_of_block    : out std_logic;
        bdo_type        : out std_logic_vector(3 downto 0);
        -- Tag Verification
        msg_auth        : out std_logic;
        msg_auth_valid  : out std_logic;
        msg_auth_ready  : in std_logic    
    );
end ASCON128;

-- Architecture
----------------------------------------------------------------------------------
architecture Behavioral of ASCON128 is

    -- Constants -----------------------------------------------------------------
    --bdi_type and bdo_type encoding
    constant HDR_AD         : std_logic_vector(3 downto 0) := "0001";
    constant HDR_MSG        : std_logic_vector(3 downto 0) := "0100";
    constant HDR_CT         : std_logic_vector(3 downto 0) := "0101";
    constant HDR_TAG        : std_logic_vector(3 downto 0) := "1000";
    constant HDR_KEY        : std_logic_vector(3 downto 0) := "1100";
    constant HDR_NPUB       : std_logic_vector(3 downto 0) := "1101";
    
    constant zero32          : std_logic_vector(31 downto 0)  := (others => '0');
    constant IV              : std_logic_vector(63 downto 0)  := x"80400c0600000000"; -- k||r||a||b||0*
    
    -- Types ---------------------------------------------------------------------
    type fsm is (idle, load_key, wait_Npub, load_Npub, Initialization, wait_AD, load_AD,
                 process_AD, process_last_AD, wait_data, load_data, process_data,
                 Finalization, output_tag, wait_tag, load_tag, verify_tag);

    -- Signals -------------------------------------------------------------------
    -- Permutation signals
    signal perm_start       : std_logic;
    signal a_rounds         : std_logic;
    signal Sr               : std_logic_vector(63 downto 0);
    signal Sc0, Sc1         : std_logic_vector(127 downto 0);
    signal perm_Sr          : std_logic_vector(63 downto 0); 
    signal perm_Sc0         : std_logic_vector(127 downto 0);
    signal perm_Sc1         : std_logic_vector(127 downto 0);
    signal perm_done        : std_logic;

    -- Data signals
    signal KeyTagReg_rst    : std_logic;
    signal KeyTagReg_en     : std_logic;
    signal KeyTagReg_in     : std_logic_vector(127 downto 0);
    signal key_tag_reg      : std_logic_vector(127 downto 0);
    
    signal bdo_t            : std_logic_vector(31 downto 0); 
    signal partial_tag      : std_logic_vector(31 downto 0);  

    -- Control Signals
    signal bdi_eot_rst      : std_logic;
    signal bdi_eot_en       : std_logic;
    signal bdi_eot_reg      : std_logic;
    
    signal bdi_eoi_rst      : std_logic;
    signal bdi_eoi_en       : std_logic;
    signal bdi_eoi_reg      : std_logic;
    
    signal decrypt_rst      : std_logic;
    signal decrypt_set      : std_logic;
    signal decrypt_reg      : std_logic;

    signal last_AD_reg      : std_logic;
    signal last_AD_rst      : std_logic;
    signal last_AD_set      : std_logic;

    signal no_AD_reg        : std_logic;
    signal no_AD_rst        : std_logic;
    signal no_AD_set        : std_logic;
    
    signal partial_AD_reg   : std_logic;
    signal partial_AD_rst   : std_logic;
    signal partial_AD_set   : std_logic;
    
    signal last_M_reg       : std_logic;
    signal last_M_rst       : std_logic;
    signal last_M_set       : std_logic;
    
    signal no_M_reg         : std_logic;
    signal no_M_rst         : std_logic;
    signal no_M_set         : std_logic;
    
    signal partial_M_reg    : std_logic;
    signal partial_M_rst    : std_logic;
    signal partial_M_set    : std_logic;
    
    signal tag_check_reg    : std_logic;
    signal tag_check_rst    : std_logic;
    signal tag_check_set    : std_logic;

    -- Counter signals
    signal ctr_words_rst    : std_logic;
    signal ctr_words_inc    : std_logic;
    signal ctr_words        : std_logic_vector(1 downto 0);
    
    -- State machine signals
    signal state            : fsm;
    signal next_state       : fsm;

------------------------------------------------------------------------------
begin
    
    P: entity work.Permutation -- The SPN permutation (pc . ps. pl)
        Port map(
            clk         => clk,
            rst         => rst,
            start       => perm_start,
            a_rounds    => a_rounds,
            Sr          => Sr,
            Sc0         => Sc0,
            Sc1         => Sc1,
            pSr         => perm_Sr,
            pSc0        => perm_Sc0,
            pSc1        => perm_Sc1,
            done        => perm_done
        );
    
    KeyReg128: entity work.myReg -- For 128-bit secret key and computed tag
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => KeyTagReg_rst,
        en      => KeyTagReg_en,
        D_in    => KeyTagReg_in,
        D_out   => key_tag_reg
    );

    bdo <= bdo_t; 
    --bdo_type <= bdi_type xor "0001" when (bdi_type = HDR_MSG or bdi_type = HDR_CT) else HDR_TAG; -- HDR_CT = HDR_MSG xor "0001"
    bdo_valid_bytes <= bdi_valid_bytes when (bdi_type = HDR_MSG or bdi_type = HDR_CT) else "1111";
    

    ---------------------------------------------------------------------------------
    Sync: process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                state      <= idle;
            else
                state      <= next_state;
            end if;
            
            if (ctr_words_rst = '1') then
                ctr_words   <= "00";
            elsif (ctr_words_inc = '1') then
                ctr_words   <= ctr_words + 1;
            end if;
            
            if (decrypt_rst = '1') then
                decrypt_reg <= '0';
            elsif (decrypt_set = '1') then
                decrypt_reg <= '1';
            end if;
            
            if (last_AD_rst = '1') then
                last_AD_reg <= '0';
            elsif (last_AD_set = '1') then
                last_AD_reg <= '1';
            end if;

            if (no_AD_rst = '1') then
                no_AD_reg   <= '0';
            elsif (no_AD_set = '1') then
                no_AD_reg   <= '1';
            end if;
            
            if (partial_AD_rst = '1') then
                partial_AD_reg   <= '0';
            elsif (partial_AD_set = '1') then
                partial_AD_reg   <= '1';
            end if;
            
            if (last_M_rst = '1') then
                last_M_reg  <= '0';
            elsif (last_M_set = '1') then
                last_M_reg  <= '1';
            end if;
            
            if (no_M_rst = '1') then
                no_M_reg   <= '0';
            elsif (no_M_set = '1') then
                no_M_reg   <= '1';
            end if;
            
            if (partial_M_rst = '1') then
                partial_M_reg   <= '0';
            elsif (partial_M_set = '1') then
                partial_M_reg   <= '1';
            end if;
            
            if (tag_check_rst = '1') then
                tag_check_reg   <= '0';
            elsif (tag_check_set = '1') then
                tag_check_reg   <= '1';
            end if;

        end if;
    end process;
    
    ----------------------------------------------------------------------------------
    Controller: process(key, key_valid, key_update, bdi, bdi_valid, bdi_eot,
                        bdi_eoi, bdi_type, bdo_ready, msg_auth_ready, state,
                        ctr_words, perm_done, perm_Sr, perm_Sc0, perm_Sc1, partial_tag)
    begin
        -- Default values
        next_state          <= idle;
        perm_start          <= '0';
        a_rounds            <= '1'; -- pa = 12
        key_ready           <= '0';
        bdi_ready           <= '0';
        ctr_words_rst       <= '0';
        ctr_words_inc       <= '0';
        KeyTagReg_rst       <= '0';
        KeyTagReg_en        <= '0';
        decrypt_rst         <= '0';
        decrypt_set         <= '0';
        last_AD_rst         <= '0';
        last_AD_set         <= '0';
        no_AD_rst           <= '0';
        no_AD_set           <= '0';
        partial_AD_rst      <= '0';
        partial_AD_set      <= '0';
        last_M_rst          <= '0';
        last_M_set          <= '0';
        no_M_rst            <= '0';
        no_M_set            <= '0';
        partial_M_rst       <= '0';
        partial_M_set       <= '0';
        tag_check_rst       <= '0';
        tag_check_set       <= '0';
        bdo_valid           <= '0';
        msg_auth            <= '0';
        msg_auth_valid      <= '0';      
        
        case state is
            when idle =>
                ctr_words_rst   <= '1';
                decrypt_rst     <= '1';
                last_AD_rst     <= '1';
                no_AD_rst       <= '1';
                partial_AD_rst  <= '1';
                last_M_rst      <= '1';
                no_M_rst        <= '1';
                partial_M_rst   <= '1';
                tag_check_set   <= '1'; -- It should be always 1, unless the verification fails
                if (key_valid = '1' and key_update = '1') then -- Get a new key
                    KeyTagReg_rst   <= '1'; -- No need to keep the previous key
                    next_state      <= load_key;
                elsif (bdi_valid = '1') then -- In decryption, skip getting the key and get the nonce
                    next_state      <= load_Npub;
                else
                    next_state      <= idle;
                end if;
                
            when load_key =>
                key_ready       <= '1';
                KeyTagReg_en    <= '1';
                ctr_words_inc   <= '1';
                if (ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= wait_Npub;
                else
                    next_state      <= load_key;
                end if;
                
            when wait_Npub =>
                if (bdi_valid = '1' and bdi_type = HDR_NPUB) then
                    next_state  <= load_Npub;
                else
                    next_state  <= wait_Npub;
                end if;
                
            when load_Npub =>
                bdi_ready           <= '1';               
                ctr_words_inc       <= '1'; 
                if (decrypt_in = '1') then -- Decryption
                    decrypt_set     <= '1';
                else                       -- Encryption
                    decrypt_rst     <= '1';
                end if;
                if (bdi_eoi = '1') then -- No AD and no data
                    no_AD_set       <= '1';
                    no_M_set        <= '1';
                else
                    no_AD_rst       <= '1';
                    no_M_rst        <= '1';
                end if;  
                if (ctr_words = 3) then 
                    ctr_words_rst   <= '1';
                    perm_start      <= '1';
                    next_state      <= Initialization;
                else
                    next_state      <= load_Npub;
                end if;
                
            when Initialization =>
                if (perm_done = '1') then                   
                    if (no_AD_reg = '1' and no_M_reg = '1') then  -- No AD and no data 
                        next_state  <= Finalization;
                    elsif (bdi_type = HDR_AD) then -- AD
                        next_state  <= load_AD;
                    elsif (bdi_type = HDR_MSG or bdi_type = HDR_CT) then -- No AD but have data
                        no_AD_set   <= '1';
                        next_state  <= load_data; 
                    else
                        next_state  <= Initialization;
                    end if;
                else
                    next_state      <= Initialization;
                end if;            
                
            when wait_AD =>
                if (bdi_valid = '1') then                    
                    next_state  <= load_AD;
                else
                    next_state  <= wait_AD;
                end if;    
            
            when load_AD =>
                bdi_ready       <= '1';
                ctr_words_inc   <= '1';
                if (bdi_eoi = '1') then -- No data
                    no_M_set    <= '1';
                else
                    no_M_rst    <= '1';
                end if;
                if (bdi_eot = '1') then -- Last block of AD
                    last_AD_set <= '1';
                else
                    last_AD_rst <= '1';
                end if;
                if ((ctr_words /= 1) or (bdi_size /= "100")) then -- Last partial block
                    partial_AD_set  <= '1';
                else
                    partial_AD_rst  <= '1';
                end if;
                if (ctr_words = 1 and bdi_size = "100") then -- Full blocks of AD
                    ctr_words_rst   <= '1';   
                    perm_start      <= '1';                
                    next_state      <= process_AD;
                elsif (bdi_eot = '1') then -- Partial last block of AD
                    ctr_words_rst   <= '1';                   
                    next_state      <= process_last_AD;
                else
                    next_state      <= load_AD;
                end if;                       
            
            when process_AD => -- Except the last block of AD
                a_rounds        <= '0'; -- pb = 6
                if (perm_done = '1') then 
                    if (last_AD_reg = '1') then -- Last full block of AD follows by a 1||0* block 
                        next_state  <= process_last_AD;
                    else                        -- Still loading AD
                        next_state  <= wait_AD;
                    end if;
                else
                    next_state  <= process_AD;
                end if;
                
             when process_last_AD =>
                perm_start  <= '1';
                a_rounds    <= '0'; -- pb = 6
                if (perm_done = '1') then
                    perm_start      <= '0';
                    if (no_M_reg = '1') then -- No data, go to process tag  
                        next_state  <= Finalization;
                    else                     -- Done with AD, start loading data  
                        next_state  <= wait_data;
                    end if;
                else
                    next_state      <= process_last_AD;
                end if;
            
            when wait_data =>
                if (bdi_valid = '1' and (bdi_type = HDR_MSG or bdi_type = HDR_CT)) then               
                    next_state      <= load_data;
                else
                    next_state      <= wait_data;
                end if;
                
            when load_data =>
                bdi_ready       <= '1'; 
                ctr_words_inc   <= '1';
                if (bdi_eot = '1') then -- Last block of data
                    last_M_set  <= '1';
                else
                    last_M_rst  <= '1';
                end if;
                if (((ctr_words /= 1) or (bdi_size /= "100"))) then -- Partial last block 
                    partial_M_set   <= '1';
                else
                    partial_M_rst   <= '1';
                end if;
                if (bdo_ready = '1') then
                    bdo_valid   <= '1'; 
                else
                    bdo_valid   <= '0';              
                end if;                
                if (bdi_eot = '1' or ctr_words = 1) then -- A block of data is received
                    ctr_words_rst       <= '1';
                    if ((ctr_words /= 1) or (bdi_size /= "100")) then -- Partial last block of data does not need a permutation
                        next_state      <= Finalization;
                    else                                              -- Full blocks of data
                        perm_start      <= '1';
                        next_state      <= process_data;
                    end if; 
                else
                    next_state      <= load_data;
                end if;
                
            when process_data =>
                a_rounds            <= '0'; -- pb = 6
                if (perm_done = '1') then
                    if (last_M_reg = '1') then -- Last full block of data
                        next_state  <= Finalization;
                    else                       -- Still loading data
                        next_state  <= wait_data;
                    end if;
                else
                    next_state      <= process_data;
                end if;
            
            when Finalization =>
                perm_start          <= '1';
                if (perm_done = '1') then
                    perm_start      <= '0';
                    if (decrypt_reg = '0') then -- Encryption
                        next_state  <= output_tag;
                    else                        -- Decryption
                        next_state  <= wait_tag;   
                    end if;
                else
                    next_state      <= Finalization;
                end if;
                
            when output_tag =>
                bdo_valid       <= '1';
                ctr_words_inc   <= '1';
                if (ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= idle;
                else
                    next_state      <= output_tag;
                end if; 
                 
            when wait_tag =>
                if (bdi_valid = '1' and bdi_type = HDR_TAG) then
                    KeyTagReg_en    <= '1';
                    next_state      <= load_tag;
                else
                    next_state      <= wait_tag;
                end if;
             
            when load_tag =>
                bdi_ready           <= '1';
                ctr_words_inc       <= '1'; 
                if (bdi /= partial_tag) then
                    tag_check_rst <= '1';  
                end if;               
                if (ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= verify_tag;
                else
                    next_state      <= load_tag;
                end if;  
            
            when verify_tag =>
                bdi_ready           <= '1';
                ctr_words_inc       <= '1'; 
                if (msg_auth_ready = '1' and tag_check_reg = '1' ) then
                    msg_auth_valid  <= '1';
                    msg_auth        <= '1';
                    next_state      <= idle;
                elsif (msg_auth_ready = '1') then
                    msg_auth_valid  <= '1';
                    msg_auth        <= '0';
                    next_state      <= idle;
                else
                    next_state      <= verify_tag;
                end if;
                
            when others => null;
        end case;
    end process;
    
    -- Datapath
    -------------------------------------------------------------------------------- 
    Sr_fsm: process(state, perm_done, perm_Sr, ctr_words, bdi_eot, bdi, bdo_t, partial_AD_reg)
    begin
        Sr <= perm_Sr;  -- Default value      
        case state is   -- Case statement
            when idle =>
                Sr <= IV;              
            when load_AD | load_data =>
                if (ctr_words = 0 and bdi_eot = '1') then -- Partial last block
                    if (decrypt_reg = '1' and bdi_type /= HDR_AD) then -- Decrypt
                        Sr <= (perm_Sr(63 downto 32) xor pad(bdo_t, bdi_size)) & perm_Sr(31 downto 0);
                    else                                               -- Encrypt
                        Sr <= (perm_Sr(63 downto 32) xor pad(bdi, bdi_size)) & perm_Sr(31 downto 0); 
                    end if;
                    if (bdi_size = 4) then
                        Sr(31) <= perm_Sr(31) xor '1'; -------
                    else
                        Sr(31) <= perm_Sr(31);
                    end if;
                elsif (ctr_words = 0 and bdi_eot = '0') then -- Upper 32 bits
                     if (decrypt_reg = '1' and bdi_type /= HDR_AD) then -- Decrypt
                        Sr <= bdi & perm_Sr(31 downto 0);
                    else                                               -- Encrypt
                        Sr <= (perm_Sr(63 downto 32) xor bdi) & perm_Sr(31 downto 0); 
                    end if;
                else                                         -- Lower 32 bits
                    if (decrypt_reg = '1' and bdi_type /= HDR_AD) then -- Decrypt
                        Sr <= perm_Sr(63 downto 32) & (perm_Sr(31 downto 0) xor pad(bdo_t, bdi_size));
                    else                                               -- Encrypt
                        Sr <= perm_Sr(63 downto 32) & (perm_Sr(31 downto 0) xor pad(bdi, bdi_size));
                    end if;
                end if;
            when process_last_AD => 
                if (perm_done = '0' and partial_AD_reg = '0') then -- Last full block of AD follows by a 1||0* block
                    Sr <= (perm_Sr(63) xor '1') & perm_Sr(62 downto 0); -- p(Sr) xor 1||0*
                else
                    Sr <= perm_Sr; -- p(Sr)
                end if;
            when Finalization =>
                if (no_M_reg = '1' or (last_M_reg = '1' and partial_M_reg = '0')) then -- No data or full last block
                    Sr <= (perm_Sr(63) xor '1') & perm_Sr(62 downto 0); -- p(Sr) xor 1||0*
                else 
                    Sr <= perm_Sr; -- p(Sr)
                end if;
            when others => null;
        end case;
    end process Sr_fsm;
    
    --------------------------------------------------------------------------------              
    Sc0_fsm: process(state, perm_done, perm_Sc0)
    begin
        Sc0 <= perm_Sc0; -- Default value    
        case state is    -- Case statement
            when idle =>
                Sc0 <= (others => '0'); 
            when load_npub =>
                Sc0 <= key_tag_reg; -- Key                             
            when Finalization =>
                Sc0 <= perm_Sc0 xor key_tag_reg; -- p(Sc0) xor key
            when others => null;
        end case;
    end process Sc0_fsm;

    --------------------------------------------------------------------------------
    Sc1_fsm: process(state, perm_done, perm_Sc1, bdi, ctr_words, bdi_type)
    begin        
        Sc1 <= perm_Sc1; -- Default value     
        case state is    -- Case statement
            when idle =>
                Sc1 <= (others => '0'); 
            when load_npub =>
                Sc1 <= perm_Sc1(95 downto 0) & bdi; -- Nonce  
            when Initialization =>
                if (perm_done = '1') then -- End of initialization
                    if (no_AD_reg = '1' or bdi_type /= HDR_AD) then -- NO AD
                        Sc1 <= (perm_Sc1(127 downto 1) xor key_tag_reg(127 downto 1)) &
                               (perm_Sc1(0) xor key_tag_reg(0) xor '1'); -- p(Sc1) xor key xor 0*||1
                    else
                        Sc1 <= perm_Sc1 xor key_tag_reg; -- p(Sc1) xor key 
                    end if;
                else
                    Sc1 <= perm_Sc1;
                end if;
            when process_last_AD =>
                if (perm_done = '1') then -- End of AD
                    Sc1 <= perm_Sc1(127 downto 1) & (perm_Sc1(0) xor '1'); -- p(Sc1) xor 0*||1
                else
                    Sc1 <= perm_Sc1;
                end if;                              
            when others => null;
        end case;
    end process Sc1_fsm;
    
    --------------------------------------------------------------------------------              
    key_fsm: process(state, key_tag_reg, key)
    begin
        -- Default values
        KeyTagReg_in <= (others => '0'); 
        case state is -- Case statement
            when load_key =>
                KeyTagReg_in <= key_tag_reg(95 downto 0) & key; -- Secret key
            when wait_tag =>
                KeyTagReg_in <= Sc1 xor key_tag_reg; -- Computed tag
            when others => null;
        end case;
    end process key_fsm;
    
    --------------------------------------------------------------------------------
    bdo_temp_fsm: process(state, Perm_Sr, Sc1, ctr_words, bdi_eot, bdi)
    begin
        bdo_t <= (others => '0'); -- Default value        
        case state is           -- Case statement
            when load_data => 
                if (ctr_words = 0) then -- Upper 32 bits
                    bdo_t <= trunc(Perm_Sr(63 downto 32) xor bdi, bdi_eot, bdi_size); 
                else                    -- Lower 32 bits
                    bdo_t <= trunc(Perm_Sr(31 downto 0) xor bdi, bdi_eot, bdi_size);
                end if;
            when output_tag =>
                bdo_t <= ext(Sc1 xor key_tag_reg, ctr_words);
            when others => null;
        end case;
    end process bdo_temp_fsm;
    
    --------------------------------------------------------------------------------
    partial_tag_fsm: process(state, bdi, ctr_words)
    begin
        partial_tag <= (others => '0'); -- Default value        
        case state is                   -- Case statement
            when load_tag => 
                partial_tag <= key_tag_reg((127 - conv_integer(ctr_words)*32) downto (96 - conv_integer(ctr_words)*32)); 
            when others => null;
        end case;
    end process partial_tag_fsm;
    
     --------------------------------------------------------------------------------
    end_of_block_fsm: process(state, ctr_words)
    begin
        end_of_block <= '0'; -- Default value   
        case state is        -- Case statement
            when load_data =>
                end_of_block <= bdi_eot;
            when output_tag =>
                if (ctr_words = 3) then -- Last word of tag
                    end_of_block <= '1'; 
                else
                    end_of_block <= '0';
                end if;                      
            when others => null;
        end case;
    end process;

end Behavioral;
