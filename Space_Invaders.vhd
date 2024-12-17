library IEEE;
use IEEE.STD_LOGIC_1164.ALL;-- voor alle logica, we gaan niet op poortniveau werken
use IEEE.numeric_std.all; -- voor unsigned

entity Space_Invaders is
    Port ( clk : in STD_LOGIC; --100MHz clk
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
           displaysCAT: out std_logic_vector(7 downto 0) 
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
    type CathodeArrayEnScoreLives is array(9 downto 0) of std_logic_vector(7 downto 0);
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
    constant MUUR_RAND : integer := 1;
    
--    clock domeinen
--vga
    signal pixel_clk : STD_LOGIC;
    signal pixel_counter : integer := 0;
--clk voor game proces
    signal clk_60hz : STD_LOGIC;
    signal counter_60hz : integer := 0;
--clk voor sevensegment display
    signal ClkCounter : integer range 0 to 6249 := 0;
    signal SlowClk: std_logic := '0' ;
 --teller voor sevensegm om van 0 tot 7 elke display aan te sturen
    signal SlowCounter : integer range 0 to 7 := 0; 
    
--  player
    signal player_snelheid : integer := 3;
    signal PLAYER_H : integer := 30;
    signal PLAYER_V : integer := 50;
    signal player_L: integer  := 434;
    signal player_R: integer := player_L + player_H;
    signal player_UP: integer := 455;
    signal player_DOWN: integer := player_UP + player_V;

--  enemy
    signal enemy_snelheid : integer := 5;
    signal enemy_H : integer := 50;
    signal enemy_V : integer := 40;
    signal enemy_L: integer  := 434;
    signal enemy_R: integer := enemy_L + enemy_H;
    signal enemy_UP: integer := 50;
    signal enemy_DOWN: integer := enemy_UP + enemy_V;
    
--    ball
    signal shoot : boolean := false;
    signal ball_snelheid : integer := 5;
    signal BALL_Z : integer := 10;
    signal ball_L: integer := 459;
    signal ball_R: integer := BALL_L + BALL_Z;
    signal ball_UP: integer := player_UP - BALL_Z;
    signal ball_DOWN: integer := BALL_UP + BALL_Z;--net boven player

--    voor vsync en hsync
    signal h_count, v_count : integer := 0;
    signal hsync_counter, vsync_counter : integer := 0;
    
--    we mogen display data sturen volgens de vga timings
    signal VideoActive : boolean := false;
   
    
--    power ups
    signal sneller_player : boolean := false;
    signal sneller_ball : boolean := false;
    signal maximum_snelheid : boolean := false;
    signal groter_ball : boolean := false;
    
    
--    lives and restart
    signal lives : integer := 9;
    signal death : boolean := false;
    signal live_lost : boolean := false;
    
    
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
    P_pixel_clk : process (clk)
    begin
        if rising_edge(clk) then
            if pixel_counter = 1 then
                pixel_clk <= not pixel_clk;
                pixel_counter <= 0;                
            else
                pixel_counter <= pixel_counter + 1;
            end if;
        end if;
    end process P_pixel_clk;


    -- Vertical en horizontal Counter
    P_VHcount : process (pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            if h_count = H_RES + H_FRONT_PORCH + H_SYNC_TIME + H_BACK_PORCH - 1 then
                h_count <= 0;
                if v_count = V_RES + V_FRONT_PORCH + V_SYNC_TIME + V_BACK_PORCH - 1 then
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
                end if;
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process P_VHcount;
    
    
    --we maken een trage klok van 60 hz(=60 pixels/s)
    P_clk_60hz : process (clk)
    begin
        if rising_edge(clk) then
            if counter_60hz = 833332 then --60hz
                clk_60hz <= not clk_60hz;
                counter_60hz <= 0; 
            else
                counter_60hz <= counter_60hz + 1;
            end if;
        end if;
    end process P_clk_60hz;
    
    
    P_clkdiv : process(clk)
    begin
        if rising_edge(clk) then
            if ClkCounter = 6249 then
                ClkCounter <= 0;
                SlowClk <= not SlowClk;
             else
                ClkCounter <= ClkCounter + 1;
            end if;
        end if;
    end process P_clkdiv;
    
    
    P_slow : process(SlowClk)
    begin
        if rising_edge(SlowClk) then
            if SlowCounter = 0 then
                SlowCounter <= 7;
            else
                SlowCounter <= SlowCounter - 1;
            end if;
        end if;
    end process P_slow;
    
    
    P_SevenSegmDisplays : process(SlowCounter, death, EH, TT, HT, DT, Lives) 
    begin
        --we gaan onze score (tot 9999), onze levens (10) en de gameover melding displayen op het sevensement display
        if death = true then
            --Game Over Melding 
            displaysAN <= (others => '1'); -- Default alle displays uit
            displaysAN(SlowCounter) <= '0'; -- Activeer huidig display
            displaysCAT <= DisplayGameOverData(SlowCounter);
        else
            --show levens en score
            displaysAN <= (others => '1');
            case SlowCounter is
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
                    displaysAN(SlowCounter) <= '1';
                    displaysCAT <= (others => '1');
                    
            end case;
        end if;   
    end process P_SevenSegmDisplays;
    
    
    P_game : process(clk_60hz)
    begin
        if rising_edge(clk_60hz) then
        --hier maken we een counter dat optelt/aftrekt wanneer we BTN induwen
        --beweging van player links-rechts
            -- de default assignement
            player_R <= player_R;
            player_L <= player_L;
            
            --naar links
            if BTNL = '1' then
                    if player_L > 144 + MUUR_RAND then--collision met linkse kant en wall
                        player_L <= player_L - player_snelheid;
                        player_R <= player_R - player_snelheid;
                    else
                        player_L <= player_L;--maybe verwijder dit om latch te voorkomen?
                    end if;
            --naar rechts
            elsif BTNR = '1' then
                if player_R < 784 - MUUR_RAND then--collision met rechtse kant en wall
                    player_R <= player_R + player_snelheid;
                    player_L <= player_L + player_snelheid;
                else
                    player_R <= player_R;--maybe verwijder dit om latch te voorkomen?
                end if;
            end if;
            
            --shooting bullet
            if BTNC = '1' then
                shoot <= true;
            else 
                if ball_UP > 0 and shoot then
                    ball_UP <= ball_UP - ball_snelheid; 
                    ball_DOWN <= ball_DOWN - ball_snelheid; 
                else
                    shoot <= false;
                    ball_UP   <= player_UP - BALL_Z;
                    ball_DOWN <= BALL_UP + BALL_Z;
                end if;
            end if;
            
            
            --lives lost
            if live_lost then
                lives <= lives - 1;
                live_lost <= false;
            end if;
            
            --death 
            if lives <= 0 then
                death <= true;     
            --restart
            elsif lives <= 0 and BTNU = '1' then
                lives <= 9;
                score <= 0;
                death <= false;
            else
                lives <= lives;
            end if;
            
        end if;
    end process P_game;
    
  
    P_powerup : process(score)
    begin
        sneller_player <= false;
        sneller_ball <= false;
        maximum_snelheid <= false;
 
        if 0 <= score and score <= 500 then
            ball_snelheid <= 2;
        elsif 600 <= score and score <= 1000 then
            ball_snelheid <= 3;
            player_snelheid <= 5;
            sneller_player <= true;
        elsif 1100 <= score and score <= 2000 then
            ball_snelheid <= 5;
            sneller_ball <= true;
            sneller_player <= true;
        else
            ball_snelheid <= 8;
            maximum_snelheid <= true;
            sneller_ball <= true;
            sneller_player <= true;
        end if; 
    end process P_powerup;
    
    P_Display : process(h_count, v_count, death, player_L, player_R, player_UP, player_DOWN, 
                        ball_L, ball_R, ball_UP, ball_DOWN, maximum_snelheid, sneller_player, sneller_ball, shoot)
    begin
        G <= "0000";
        B <= "0000";
        R <= "0000";
        if not death then
            -- wanneer we rgb signalen mogen sturen
            if (H_BACK_PORCH + H_SYNC_TIME) < h_count and h_count < (H_RES + H_SYNC_TIME + H_BACK_PORCH - 1)
             and (V_BACK_PORCH + V_SYNC_TIME) < v_count and v_count < (V_RES + V_SYNC_TIME + V_BACK_PORCH - 1) then
                VideoActive <= true;
    --------------------- paddles en bal generation--------------------
                if player_L < h_count and h_count < player_R 
                and player_UP < v_count and v_count < player_DOWN then
                    --  paddle -> onze player, vernadert van kleur wanneer het sneller wordt
                    if sneller_player then
                        G <= "1111";
                        B <= "0000";
                        R <= "0000";
                    elsif maximum_snelheid then--oranje
                        G <= "1000";
                        B <= "0000";
                        R <= "1111";
                    else
                        G <= "1111";
                        B <= "1111";
                        R <= "1111";
                    end if;
                                      
                elsif ball_L < h_count and h_count < ball_R --bal
                and ball_UP < v_count and v_count < ball_DOWN then
                    --witte vierkanten bal in het midden van player 10x10 px
                    if shoot = true then
                       if sneller_ball then
                            G <= "1111";
                            B <= "0000";
                            R <= "0000";
                        elsif maximum_snelheid then--oranje
                            G <= "1000";
                            B <= "0000";
                            R <= "1111";
                        else
                            G <= "1111";
                            B <= "1111";
                            R <= "1111";
                        end if;
                    else
                        G <= "0000";
                        B <= "0000";
                        R <= "0000";
                    end if;
               --------------------------------------------------------------------
     ---------------------------------------rode box----------------------------------
                elsif (H_BACK_PORCH + H_SYNC_TIME) < h_count and h_count < (H_BACK_PORCH + H_SYNC_TIME) + MUUR_RAND then--links muur
                    G <= "0000";
                    B <= "0000";
                    R <= "1111";

                elsif (H_RES + H_SYNC_TIME + H_BACK_PORCH) - MUUR_RAND < h_count and h_count < (H_RES + H_SYNC_TIME + H_BACK_PORCH - 1) then--rchts muur
                    G <= "0000";
                    B <= "0000";
                    R <= "1111";
                elsif (V_BACK_PORCH + V_SYNC_TIME) < v_count and v_count < (V_BACK_PORCH + V_SYNC_TIME) + MUUR_RAND then -- boven muur
                    G <= "0000";
                    B <= "0000";
                    R <= "1111";
                   
                elsif (V_RES + V_SYNC_TIME + V_BACK_PORCH - 1) - MUUR_RAND < v_count and v_count < (V_RES + V_SYNC_TIME + V_BACK_PORCH - 1) then--onder muur
                    G <= "0000";
                    B <= "0000";
                    R <= "1111";

    ------------------------------------------------------------------------------------
                else
                    --al de rest zwart
                    G <= "0000";
                    B <= "0000";
                    R <= "0000";
                end if;           
            else
                VideoActive <= false;
            end if;
        else --death is true
            G <= "0000";
            B <= "0000";
            R <= "1111";  
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
