library IEEE;
use IEEE.STD_LOGIC_1164.ALL;-- voor alle logica, we gaan niet op poortniveau werken
use IEEE.numeric_std.all; -- voor unsigned

entity Space_Invaders is
    Port ( clk100MHz : in STD_LOGIC; --100MHz clk
           BTNL : in STD_LOGIC;-- links bewegen
           BTNR : in STD_LOGIC; -- naar rechts bewegen
           BTNC : in STD_LOGIC; --voor schieten
           BTNU : in STD_LOGIC; --voor restart 
           R : out std_logic_vector(3 downto 0);
           G : out std_logic_vector(3 downto 0);
           B : out std_logic_vector(3 downto 0);
           hsync : out STD_LOGIC;
           vsync : out STD_LOGIC;
           displaysAN: out std_logic_vector(7 downto 0); 
           displaysCAT: out std_logic_vector(7 downto 0);
           LED : out std_logic_vector(15 downto 0)
           );
end Space_Invaders;

architecture Behavioral of Space_Invaders is

-- Look-up tables voor sevensegment display
    type CathodeArrayGameOver is array(7 downto 0) of std_logic_vector(7 downto 0);
    constant DisplayGameOverData : CathodeArrayGameOver := (
        "10100001", -- G
        "10001000", -- A
        "10001001", -- M
        "10110000", -- E
        "10000001", -- O
        "11000001", -- V
        "10110000", -- E
        "00001000"  -- R
    ); 
    type CathodeArrayEnScoreLives is array(0 to 9) of std_logic_vector(7 downto 0);
    constant DisplayLivesEnScoreData : CathodeArrayEnScoreLives := (
        
        "10000001", -- 0
        "11001111", -- 1
        "10010010", -- 2
        "10000110", -- 3
        "11001100", -- 4
        "10100100", -- 5
        "10100000", -- 6
        "10001111", -- 7       
        "10000000", -- 8
        "10000100"  -- 9
     );
     
     --alle timing constanten
    constant H_RES : integer := 640;  -- Horizontale resolutie
    constant V_RES : integer := 480;  -- Verticale resolutie
    constant H_FRONT_PORCH : integer := 16;
    constant H_SYNC_TIME : integer := 96;
    constant H_BACK_PORCH : integer := 48;
    constant V_FRONT_PORCH : integer := 10;
    constant V_SYNC_TIME : integer := 2;
    constant V_BACK_PORCH : integer := 33;
    
    --    clock domeinen
--vga
    signal clk25MHz : STD_LOGIC;
    signal Counter25MHz : integer := 0;
--clk voor game loop
    signal clk60Hz : STD_LOGIC;
    signal Counter60Hz : integer := 0;
    
--clk voor looplicht
    signal LooplichtClkCounter : integer range 0 to 49999999 := 0;
    signal LooplichtClk: std_logic := '0';
  --teller voor looplicht om van 0 tot 15 elke led aan te sturen
    signal LooplichtCounter : integer range 0 to 15 := 0;
    signal looplicht_reset : boolean := false;
    
--clk voor sevensegment display
    signal SevensegmClkCounter : integer range 0 to 6249 := 0;
    signal SevensegmClk: std_logic := '0' ;
 --teller voor sevensegm om van 0 tot 7 elke display aan te sturen
    signal SevensegmCounter : integer range 0 to 7 := 0; 
    
    --    voor vsync en hsync
    signal h_count, v_count : integer := 0;
    signal hsync_counter, vsync_counter : integer := 0;
    
    --    we mogen display data sturen volgens de vga timings
    signal VideoActive : boolean := false;
    
    
    --alle andere constanten
    constant MUUR_DIKTE : integer := 1;
    constant PLAYER_H : integer := 20;
    constant PLAYER_V : integer := 30;
    constant PLAYER_SNELHEID: integer := 5;
    constant ENEMY_H :  integer := 30;
    constant ENEMY_V :  integer := 20;
    constant ENEMY_SNELHEID:  integer := 1;
    constant ENEMY_JUMP: integer := 20;
    constant BULLET_H : integer := 5;
    constant BULLET_V : integer := 10;
    constant BULLET_SNELHEID: integer := 10;

    --player signalen
    signal player_L:    integer := 464;
    signal player_R:    integer := 464 + PLAYER_H;
    signal player_UP:   integer := 470;
    signal player_DOWN: integer := 470 + PLAYER_V;
    
    --player signalen
    signal bullet_L:      integer;
    signal bullet_R:      integer;
    signal bullet_UP:     integer := 470;
    signal bullet_DOWN:   integer := 470 + BULLET_V;
    signal bullet_travel: boolean := false;
    signal shot:          boolean := false;
    
    --enemy signalen
    signal enemy_L:    integer := 147;
    signal enemy_R:    integer := 147 + ENEMY_H;
    signal enemy_UP:   integer := 50;
    signal enemy_DOWN: integer := 50 + ENEMY_V;
    signal enemy_versnelling:    integer := 1;
    signal enemy_h_direction:    integer := 1;
    signal enemy_naar_beneden:   boolean := false;
    signal enemy_position_reset: boolean := false;
    signal enemy_versnelling_reset: boolean := false;
    
     --    lives and restart
    signal lives : integer := 9;
    signal death : boolean := false;
    signal restart : boolean := false;
    signal enemy_death: boolean := false;
    signal enemy_geraakt: boolean := false;
 
     
     --    score en scoredisplay
    signal score_up : boolean := false;
    signal score : integer := 0;
    signal EH: integer;
    signal TT: integer;
    signal HT: integer; 
    signal DT: integer;
     
    component scoreToSevensegm is Port 
         ( Score : in integer;
           EH : out integer;
           TT : out integer;
           HT : out integer;
           DT : out integer
         );                                       
    end component; 
    
begin
    using : scoreToSevensegm port map(
            Score => Score,
            EH => EH,
            TT => TT,
            HT => HT,
            DT => DT
        );
        
 -- Pixel Clock Generation(25 MHz)
    P_clk25MHz : process (clk100MHz)
    begin
        if rising_edge(clk100MHz) then
            if Counter25MHz = 1 then
                clk25MHz <= not clk25MHz;
                Counter25MHz <= 0;                
            else
                Counter25MHz <= Counter25MHz + 1;
            end if;
        end if;
    end process P_clk25MHz;


    -- Vertical en horizontal Counter
    P_VHcount : process (clk25MHz)
    begin
        if rising_edge(clk25MHz) then
            if h_count = H_RES + H_FRONT_PORCH + H_SYNC_TIME + H_BACK_PORCH then
                h_count <= 0;
                if v_count = V_RES + V_FRONT_PORCH + V_SYNC_TIME + V_BACK_PORCH then
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
                end if;
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process P_VHcount;
    
    
    --we maken een trage klok van 60 hz
    P_clk60Hz : process (clk100MHz)
    begin
        if rising_edge(clk100MHz) then
            if Counter60Hz = 833332 then --60hz
                clk60Hz <= not clk60Hz;
                Counter60Hz <= 0; 
            else
                Counter60Hz <= Counter60Hz + 1;
            end if;
        end if;
    end process P_clk60Hz;
    
    --we maken een clk van 4Hz voor de looplicht
    P_LooplichtClk : process(clk100MHz)
    begin
        if rising_edge(clk100MHz) then
            if LooplichtClkCounter = 24999999 then
                LooplichtClkCounter <= 0;
                LooplichtClk <= not LooplichtClk;
             else
                LooplichtClkCounter <= LooplichtClkCounter + 1;
            end if;
        end if;
    end process P_LooplichtClk;
    
    
    P_LooplichtCounter : process(LooplichtClk)
    begin
    --we doen '-' om van sevensegm(0) te beginnen
        if rising_edge(LooplichtClk) then
            if death then enemy_versnelling <= 1;
            end if;
            if LooplichtCounter = 15 then
                LooplichtCounter <= 0;
                looplicht_reset <= not looplicht_reset;
                if not death then
                    enemy_versnelling <= enemy_versnelling + 1;
                end if;
            else
                LooplichtCounter <= LooplichtCounter + 1;
            end if;
        end if;
    end process P_LooplichtCounter;
    
    
    P_LooplichtDisplay : process(LooplichtCounter, death, looplicht_reset)
    begin
        if not death then
            if looplicht_reset then
                LED <= (others => '0');
                LED(LooplichtCounter) <= '1';
            else
                LED <= (others => '0');
                LED(15 - LooplichtCounter) <= '1';
            end if;
        else
            LED <= (others => '0');
        end if;
    end process P_LooplichtDisplay;
    
    
    P_SevensegmClk : process(clk100MHz)
    begin
        if rising_edge(clk100MHz) then
            if SevensegmClkCounter = 6249 then
                SevensegmClkCounter <= 0;
                SevensegmClk <= not SevensegmClk;
             else
                SevensegmClkCounter <= SevensegmClkCounter + 1;
            end if;
        end if;
    end process P_SevensegmClk;
    
    
    P_SevensegmCounter : process(SevensegmClk)
    begin
    --we doen '-' om van sevensegm(0) te beginnen, we hadden dat bij opgave 5 ook zo gedaan
        if rising_edge(SevensegmClk) then
            if SevensegmCounter = 0 then
                SevensegmCounter <= 7;
            else
                SevensegmCounter <= SevensegmCounter - 1;
            end if;
        end if;
    end process P_SevensegmCounter;
    
    
    P_SevenSegmDisplays : process(SevensegmCounter, death, EH, TT, HT, DT, Lives) 
    begin
        --we gaan onze score (tot 9999), onze levens (9) en de gameover melding displayen op het sevensement display
        if death then
            --Game Over Melding 
            displaysAN <= (others => '1'); -- Default alle displays uit
            displaysAN(SevensegmCounter) <= '0'; -- Activeer huidig display
            displaysCAT <= DisplayGameOverData(SevensegmCounter);
        else
            --show levens en score
            displaysAN <= (others => '1');
            case SevensegmCounter is
                --Levens Display
                when 0 =>  
                    displaysAN(0) <= '0';
                    displaysCAT <= DisplayLivesEnScoreData(Lives);
                --score display
                when 4 => 
                    displaysAN(4) <= '0';
                    displaysCAT <= DisplayLivesEnScoreData(EH);
                when 5 => 
                    displaysAN(5) <= '0';
                    displaysCAT <= DisplayLivesEnScoreData(TT);
                when 6 => 
                    displaysAN(6) <= '0';
                    displaysCAT <= DisplayLivesEnScoreData(HT);
                when 7 => 
                    displaysAN(7) <= '0';
                    displaysCAT <= DisplayLivesEnScoreData(DT);
                    
                when others => 
                    displaysAN(SevensegmCounter) <= '1';
                    displaysCAT <= (others => '1');
                    
            end case;
        end if;   
    end process P_SevenSegmDisplays;


   P_death : process(lives)
    begin 
        if lives = 0 then
            death <= true;
        else
            death <= false;
        end if;
    end process P_death;
    
    
    P_restart : process(clk60Hz)
    begin
        if rising_edge(clk60Hz) then
            if BTNU = '1' and death then
                restart <= true;
            else restart <= false;
            end if;
        end if;
    end process P_restart;


    P_player : process(clk60Hz)
    begin
         if rising_edge(clk60Hz) then
            --naar links
            if BTNL = '1' and not death then
                    if player_L > 144 + MUUR_DIKTE then--collision met linkse kant en wall
                        player_L <= player_L - PLAYER_SNELHEID;
                        player_R <= player_R - PLAYER_SNELHEID;
                    else
                        player_L <= player_L;--maybe verwijder dit om latch te voorkomen?
                    end if;
            --naar rechts
            elsif BTNR = '1' and not death then
                if player_R < 784 - MUUR_DIKTE then--collision met rechtse kant en wall
                    player_R <= player_R + PLAYER_SNELHEID;
                    player_L <= player_L + PLAYER_SNELHEID;
                else
                    player_R <= player_R;--maybe verwijder dit om latch te voorkomen?
                end if;
            else
                player_R <= player_R;
                player_L <= player_L;
            end if;
        end if;
    end process P_player;
    
    
    P_enemy : process(clk60Hz)
    begin
        if rising_edge(clk60Hz) then
            if not enemy_position_reset and not death then
                enemy_L <= enemy_L + ((enemy_versnelling + ENEMY_SNELHEID) * enemy_h_direction);
                enemy_R <= enemy_R + ((enemy_versnelling + ENEMY_SNELHEID) * enemy_h_direction);
            else
                enemy_position_reset <= false;
                enemy_death <= false;
                enemy_L <= 147;          
                enemy_R <= 147 + ENEMY_H;
                enemy_UP   <= 50;          
                enemy_DOWN <= 50 + ENEMY_V;
            end if;
            
            if (enemy_R >= 144 + H_RES - MUUR_DIKTE) and not death then--collision met rechtse wall
                enemy_h_direction <= -1;
                enemy_naar_beneden <= true;
            elsif (enemy_L <= 144 + MUUR_DIKTE) and not death then
                enemy_h_direction <= 1;
                enemy_naar_beneden <= true;
            end if;
            
            if enemy_naar_beneden and not (enemy_DOWN >= player_UP) and not death then
                --naar beneden gaan
                enemy_UP <= enemy_UP + ENEMY_JUMP;
                enemy_DOWN <= enemy_DOWN + ENEMY_JUMP;
                enemy_naar_beneden <= not enemy_naar_beneden;
                
            elsif enemy_naar_beneden and (enemy_DOWN >= player_UP) and not death then
                enemy_naar_beneden <= not enemy_naar_beneden;
                enemy_position_reset <= true;
                lives <= lives - 1;
            elsif restart then
                lives <= 9;
                enemy_position_reset <= true;
                score <= 0;

            elsif enemy_geraakt then
                --and score up!
                score <= score + 100;
                enemy_death <= true;
                enemy_position_reset <= true;
            end if;        
        end if;   
    end process P_enemy;


    P_bullet : process(clk60Hz)
    begin
        if rising_edge(clk60Hz) then
            if BTNC = '1' and not bullet_travel then
                shot <= true;
                bullet_travel <= true;
            end if;
            
            if shot then
                bullet_L <= (player_R - (PLAYER_H/2) - (BULLET_H / 2));
                bullet_R <= (player_R - (PLAYER_H/2) + (BULLET_H / 2));
                shot <= false;
            end if;
            
            if bullet_travel and not death then
                bullet_UP <= bullet_UP - BULLET_SNELHEID;
                bullet_DOWN <= bullet_DOWN - BULLET_SNELHEID;
            else 
                bullet_UP <= 470;
                bullet_DOWN <= 470 + BULLET_V;
            end if;
 
            if (bullet_UP < 35) then
                bullet_travel <= false;
            end if;
            if ((bullet_UP < enemy_DOWN) and (bullet_L < enemy_R)) or ((bullet_UP < enemy_DOWN) and (bullet_R > enemy_L)) then
                bullet_travel <= false;
                enemy_geraakt <= true;
            end if;
            
            if enemy_death then enemy_geraakt <= false;end if;
            
        end if;
    end process P_bullet;


    P_Display : process(h_count, v_count, death, VideoActive, bullet_travel,
                        player_L, player_R, player_UP, player_DOWN,
                        enemy_L, enemy_R, enemy_UP, enemy_DOWN,
                        bullet_L, bullet_R, bullet_UP, bullet_DOWN)
    begin
        -- wanneer we rgb signalen mogen sturen
        if (H_BACK_PORCH + H_SYNC_TIME) < h_count and h_count < (H_RES + H_SYNC_TIME + H_BACK_PORCH)
         and (V_BACK_PORCH + V_SYNC_TIME) < v_count and v_count < (V_RES + V_SYNC_TIME + V_BACK_PORCH) then
            VideoActive <= true;
        else
            VideoActive <= false;
        end if;
     
---------------------------------------rode box----------------------------------

        if 144 < h_count and h_count < 145 + MUUR_DIKTE and VideoActive and not death then--links muur
            R <= "1111";
            G <= "0000";
            B <= "0000";

        elsif 143 + H_RES - MUUR_DIKTE < h_count and h_count < 144 + H_RES and VideoActive and not death then--rechts muur
            R <= "1111";
            G <= "0000";
            B <= "0000";

        elsif 35 < v_count and v_count < 36 + MUUR_DIKTE and VideoActive and not death then -- boven muur
            R <= "1111";
            G <= "0000";
            B <= "0000";

        elsif 34 + V_RES - MUUR_DIKTE < v_count and v_count < 35 + V_RES and VideoActive and not death then--onder muur
            R <= "1111";
            G <= "0000";
            B <= "0000";
            
---------------------------------player----------------------------------

        elsif player_L < h_count and h_count < player_R 
        and player_UP < v_count and v_count < player_DOWN and VideoActive and not death then
            R <= "1111";
            G <= "1111";
            B <= "1111";

---------------------------------enemy----------------------------------
        
        elsif enemy_L < h_count and h_count < enemy_R 
        and enemy_UP < v_count and v_count < enemy_DOWN and VideoActive and not death then
            R <= "1111";
            G <= "1111";
            B <= "1111";
            
---------------------------------bullet----------------------------------

        elsif bullet_L < h_count and h_count < bullet_R and bullet_travel
        and bullet_UP < v_count and v_count < bullet_DOWN and VideoActive and not death then
            R <= "1111";
            G <= "1111";
            B <= "1111";
        
        elsif VideoActive and death then
            R <= "1111";
            G <= "0000";
            B <= "0000";

        else
            --al de rest zwart
            R <= "0000";
            G <= "0000";
            B <= "0000";
        end if;
    end process P_Display; 
    
    P_sync : process(h_count, v_count)
    begin
        -- assign HSync 
        if h_count < H_SYNC_TIME then
            hsync <= '0';
        else
            hsync <= '1';
        end if;
        
        --assign vsync
        if v_count < V_SYNC_TIME then
            vsync <= '0';
        else 
            vsync <= '1';
        end if;
    end process P_sync;
    
end Behavioral;