--hier gaan we de score van 4 cijfers slicen in de eenheden, tientallen, hoderdtallen en duizendtallen (EH, TT, HT, DT)
--dit gaan we dan laten zien op de linkse vier displays van de sevensegment display.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;-- voor alle logica, we gaan niet op poortniveau werken
use IEEE.numeric_std.all; -- voor unsigned

entity scoreToSevensegm is
    Port ( Score : in integer;
           EH : out integer;
           TT : out integer;
           HT : out integer;
           DT : out integer
         );
end scoreToSevensegm;

architecture Behavioral of scoreToSevensegm is

signal vanGetalNaarHT: integer ;
signal vanGetalNaarTT: integer ;
signal ScoreSignal: integer;
signal EHSignal: integer;
signal TTSignal: integer;
signal HTSignal: integer; 
signal DTSignal: integer;

begin            
   process(Score, DTSignal)
   begin      
         Case Score is
             when 0 to 999         => DTSignal <= 0;
             when 1000 to 1999     => DTSignal <= 1;
             when 2000 to 2999     => DTSignal <= 2;
             when 3000 to 3999     => DTSignal <= 3;
             when 4000 to 4999     => DTSignal <= 4;
             when 5000 to 5999     => DTSignal <= 5;
             when 6000 to 6999     => DTSignal <= 6;
             when 7000 to 7999     => DTSignal <= 7;
             when 8000 to 8999     => DTSignal <= 8;
             when others           => DTSignal <= 9;  -- Voor alle andere waarden buiten 0-9999, gaat het 9 blijven. Dus max is 9999
         end case;
         
         DT <= DTSignal;
     end process;

    vanGetalNaarHT <= ScoreSignal - (DTSignal * 1000);
    
    process(vanGetalNaarHT, HTSignal)
       begin
         Case vanGetalNaarHT is
             when 0 to 99      =>   HTSignal   <= 0;
             when 100 to 199   =>   HTSignal   <= 1;
             when 200 to 299   =>   HTSignal   <= 2;
             when 300 to 399   =>   HTSignal   <= 3;
             when 400 to 499   =>   HTSignal   <= 4;
             when 500 to 599   =>   HTSignal   <= 5;
             when 600 to 699   =>   HTSignal   <= 6;
             when 700 to 799   =>   HTSignal   <= 7;
             when 800 to 899   =>   HTSignal   <= 8;
             when others       =>   HTSignal   <= 9;  
        end case;
        
        HT <= HTSignal;
     end process;
     
     vanGetalNaarTT <= (vanGetalNaarHT - (HTSignal * 100));
     
     process(vanGetalNaarTT, TTSignal)
       begin
        Case vanGetalNaarTT is
             when 0 to 9     =>  TTSignal  <= 0;
             when 10 to 19   =>  TTSignal  <= 1;
             when 20 to 29   =>  TTSignal  <= 2;
             when 30 to 39   =>  TTSignal  <= 3;
             when 40 to 49   =>  TTSignal  <= 4;
             when 50 to 59   =>  TTSignal  <= 5;
             when 60 to 69   =>  TTSignal  <= 6;
             when 70 to 79   =>  TTSignal  <= 7;
             when 80 to 89   =>  TTSignal  <= 8;
             when others     =>  TTSignal  <= 9;
        end case;        
        TT <= TTSignal; 
        EH <= vanGetalNaarTT - (TTSignal * 10); --ineens assignen
     end process;

end Behavioral;
