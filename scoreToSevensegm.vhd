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

begin
    process(Score)
       begin
         Case Score is
             when 0 to 999         => DT <= 0;
             when 1000 to 1999     => DT <= 1;
             when 2000 to 2999     => DT <= 2;
             when 3000 to 3999     => DT <= 3;
             when 4000 to 4999     => DT <= 4;
             when 5000 to 5999     => DT <= 5;
             when 6000 to 6999     => DT <= 6;
             when 7000 to 7999     => DT <= 7;
             when 8000 to 8999     => DT <= 8;
             when others           => DT <= 9;  -- Voor alle andere waarden buiten 0-9999
         end case;
     end process;



end Behavioral;
