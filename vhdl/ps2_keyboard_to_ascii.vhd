--------------------------------------------------------------------------------
--
--   FileName:         ps2_keyboard_to_ascii.vhd
--   Dependencies:     ps2_keyboard.vhd, debounce.vhd
--   Design Software:  Quartus II 32-bit Version 12.1 Build 177 SJ Full Version
--
--   HDL CODE IS PROVIDED "AS IS."  DIGI-KEY EXPRESSLY DISCLAIMS ANY
--   WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--   PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
--   BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
--   DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
--   PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
--   BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
--   ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
--
--   Version History
--   Version 2.0 in January 2016 by sy2002
--     Locales for DE and US/EN and special key handling
--     Known issue: The numeric keypad is intentionally not supported,
--     as it seems that the Nexys4 DDR generates wrong scancodes, e.g.
--     the scancode for cursor left and for keypad 4 are identical.
--   Version 1.0 11/29/2013 Scott Larson
--     Initial Public Release
--    
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE work.kbd_constants.all;

ENTITY ps2_keyboard_to_ascii IS
  PORT(
      clk        : IN  STD_LOGIC;                     --system clock input
      ps2_clk    : IN  STD_LOGIC;                     --clock signal from PS2 keyboard
      ps2_data   : IN  STD_LOGIC;                     --data signal from PS2 keyboard
      ascii_new  : OUT STD_LOGIC;                     --output flag indicating new ASCII value
      ascii_code : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  --ASCII value
      spec_new   : OUT STD_LOGIC;                     -- output flag indicating new special key value
      spec_code  : OUT STD_LOGIC_VECTOR(7 downto 0);  -- special key value
      locale     : IN  STD_LOGIC_VECTOR(2 downto 0);  -- locale will not be latched but eval. in real time
      modifiers  : OUT STD_LOGIC_VECTOR(2 downto 0);  -- modifiers: 0 = shift, 1 = alt, 2 = ctrl
      event_data : OUT STD_LOGIC_VECTOR(15 downto 0);
      event_wr   : OUT STD_LOGIC
      ); 
END ps2_keyboard_to_ascii;

ARCHITECTURE behavior OF ps2_keyboard_to_ascii IS
  TYPE machine IS(ready, new_code, translate, output);              --needed states
  SIGNAL state             : machine;                               --state machine
  SIGNAL ps2_code_new      : STD_LOGIC;                             --new PS2 code flag from ps2_keyboard component
  SIGNAL ps2_code          : STD_LOGIC_VECTOR(7 DOWNTO 0);          --PS2 code input form ps2_keyboard component
  SIGNAL prev_ps2_code_new : STD_LOGIC := '1';                      --value of ps2_code_new flag on previous clock
  SIGNAL break             : STD_LOGIC := '0';                      --'1' for break code, '0' for make code
  SIGNAL e0_code           : STD_LOGIC := '0';                      --'1' for multi-code commands, '0' for single code commands
  SIGNAL caps_lock         : STD_LOGIC := '0';                      --'1' if caps lock is active, '0' if caps lock is inactive
  SIGNAL control_r         : STD_LOGIC := '0';                      --'1' if right control key is held down, else '0'
  SIGNAL control_l         : STD_LOGIC := '0';                      --'1' if left control key is held down, else '0'
  SIGNAL shift_r           : STD_LOGIC := '0';                      --'1' if right shift is held down, else '0'
  SIGNAL shift_l           : STD_LOGIC := '0';                      --'1' if left shift is held down, else '0'
  SIGNAL alt_l             : STD_LOGIC := '0';                      --'1' if left alt is held down, else '0'
  SIGNAL alt_gr            : STD_LOGIC := '0';                      --'1' if right alt (sometimes called Alt Gr) is held down, else '0'
  SIGNAL ascii             : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"FF"; --internal value of ASCII translation
  
  -- extensions by sy2002 to handle 256 ascii codes and special keys
  SIGNAL ascii_ext         : STD_LOGIC := '0';
  SIGNAL spec              : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"00";
  
BEGIN

  --instantiate PS2 keyboard interface logic
  ps2_keyboard_0: entity work.ps2_keyboard
    PORT MAP(clk => clk, ps2_clk => ps2_clk, ps2_data => ps2_data, ps2_code_new => ps2_code_new, ps2_code => ps2_code);
  
  PROCESS(clk)
  BEGIN
    IF(clk'EVENT AND clk = '1') THEN
      prev_ps2_code_new <= ps2_code_new; --keep track of previous ps2_code_new values to determine low-to-high transitions
      ascii_new <= '0';                                       --reset new ASCII code indicator
      spec_new <= '0';
      event_wr <= '0';
      CASE state IS
      
        --ready state: wait for a new PS2 code to be received
        WHEN ready =>
          ascii_ext <= '0';
          spec <= x"00";
          
          IF(prev_ps2_code_new = '0' AND ps2_code_new = '1') THEN --new PS2 code received
            state <= new_code;                                      --proceed to new_code state
          END IF;
          
        --new_code state: determine what to do with the new PS2 code  
        WHEN new_code =>
          ascii_ext <= '0';
          spec <= x"00";
          
          IF(ps2_code = x"F0") THEN    --code indicates that next command is break
            break <= '1';                --set break flag
            state <= ready;              --return to ready state to await next PS2 code
          ELSIF(ps2_code = x"E0") THEN --code indicates multi-key command
            e0_code <= '1';              --set multi-code command flag
            state <= ready;              --return to ready state to await next PS2 code
          ELSE                         --code is the last PS2 code in the make/break code
            ascii(7) <= '1';             --set internal ascii value to unsupported code (for verification)
            state <= translate;          --proceed to translate state
          END IF;

        --translate state: translate PS2 code to ASCII value
        WHEN translate =>
            break <= '0';    --reset break flag
            e0_code <= '0';  --reset multi-code command flag
            ascii_ext <= '0';
            spec <= x"00";

            event_data <= break & "0000000" & ps2_code;
            event_wr   <= '1';
            
            --handle codes for control, shift, and caps lock
            CASE ps2_code IS
              WHEN x"58" =>                   --caps lock code
                IF(break = '0') THEN            --if make command
                  caps_lock <= NOT caps_lock;     --toggle caps lock
                END IF;
              WHEN x"14" =>                   --code for the control keys
                IF(e0_code = '1') THEN          --code for right control
                  control_r <= NOT break;         --update right control flag
                ELSE                            --code for left control
                  control_l <= NOT break;         --update left control flag
                END IF;
              WHEN x"12" =>                   --left shift code
                shift_l <= NOT break;           --update left shift flag
              WHEN x"59" =>                   --right shift code
                shift_r <= NOT break;           --update right shift flag          
              WHEN x"11" =>
                IF (e0_code = '1') THEN       -- E0 11 = Alt GR or Right Alt
                  alt_gr <= NOT break;
                ELSE
                  alt_l <= NOT break;         -- 11 = Left Alt
                END IF;
              WHEN OTHERS => NULL;
            END CASE;
                       
            -- E0 encoded keys
            IF e0_code = '1' THEN
               -- Cursor and cursor control keys
               CASE ps2_code IS
                  WHEN x"75" => spec <= key_cur_up;
                  WHEN x"72" => spec <= key_cur_down;
                  WHEN x"6B" => spec <= key_cur_left;
                  WHEN x"74" => spec <= key_cur_right;
                  WHEN x"70" => spec <= key_ins;
                  WHEN x"71" => spec <= key_del;
                  WHEN x"6C" => spec <= key_pos1;
                  WHEN x"69" => spec <= key_end;
                  WHEN x"7D" => spec <= key_pg_up;
                  WHEN x"7A" => spec <= key_pg_down;
                  
                  WHEN OTHERS => NULL;
               END CASE;
               
            -- standard encoded keys
            ELSE
               CASE ps2_code IS
                  -- @TODO: Known Issue with Nexys4 DDR USB to PS/2 translation:
                  -- numeric keypad and cursor keys are having wrong codes, so we interpret
                  -- the keypad codes also as cursor and cursor modification keys
                  WHEN x"75" => spec <= key_cur_up;
                  WHEN x"72" => spec <= key_cur_down;
                  WHEN x"6B" => spec <= key_cur_left;
                  WHEN x"74" => spec <= key_cur_right;
                  WHEN x"70" => spec <= key_ins;
                  WHEN x"71" => spec <= key_del;
                  WHEN x"6C" => spec <= key_pos1;
                  WHEN x"69" => spec <= key_end;
                  WHEN x"7D" => spec <= key_pg_up;
                  WHEN x"7A" => spec <= key_pg_down;
               
                  -- function keys
                  WHEN x"05" => spec <= key_f1;
                  WHEN x"06" => spec <= key_f2;
                  WHEN x"04" => spec <= key_f3;
                  WHEN x"0C" => spec <= key_f4;
                  WHEN x"03" => spec <= key_f5;
                  WHEN x"0B" => spec <= key_f6;
                  WHEN x"83" => spec <= key_f7;
                  WHEN x"0A" => spec <= key_F8;
                  WHEN x"01" => spec <= key_F9;
                  WHEN x"09" => spec <= key_F10;
                  WHEN x"78" => spec <= key_F11;
                  WHEN x"07" => spec <= key_F12;              
                  
                  WHEN OTHERS => NULL;
               END CASE;
            END IF;
                       
            -- translate "Alt Gr" (equivalent to CTRL +left ALT) control codes for locale DE
            IF locale = loc_DE AND
               (alt_gr = '1' or (control_l = '1' and alt_l = '1' )) THEN
               
               CASE ps2_code IS
                                 
                  WHEN x"15" => ascii <= x"40"; -- Alt Gr + Q => @ (at sign)                                    
                  WHEN x"24" =>                 -- Alt Gr + E => € (Euro sign)
                     ascii_ext <= '1';
                     ascii <= x"A4" and x"7F"; 
                  WHEN x"5B" => ascii <= x"7E"; -- Alt Gr + + => ~
                  WHEN x"1E" =>                 -- Alt Gr + 2 => ² (to the square / second power)
                     ascii_ext <= '1';
                     ascii <= x"B2" and x"7F";
                  WHEN x"26" =>                 -- Alt Gr + 3 => ³ (to the third power)
                     ascii_ext <= '1';
                     ascii <= x"B3" and x"7F";
                  WHEN x"3D" => ascii <= x"7B"; -- Alt Gr + 7 => {
                  WHEN x"3E" => ascii <= x"5B"; -- Alt Gr + 8 => [
                  WHEN x"46" => ascii <= x"5D"; -- Alt Gr + 9 => ]
                  WHEN x"45" => ascii <= x"7D"; -- Alt Gr + 0 => }
                  WHEN x"4E" => ascii <= x"5C"; -- Alt Gr + ß => \
                  WHEN x"61" => ascii <= x"7C"; -- Alt Gr + < => |
                  WHEN x"3A" =>                 -- Alt Gr + m => µ
                     ascii_ext <= '1';
                     ascii <= x"B5" and x"7F";
               
                  WHEN OTHERS => NULL;
               END CASE;            
        
            --translate control codes (these do not depend on shift or caps lock)
            ELSIF(control_l = '1' OR control_r = '1') THEN
              CASE ps2_code IS
                WHEN x"1E" => ascii <= x"00"; --^@  NUL
                WHEN x"1C" => ascii <= x"01"; --^A  SOH
                WHEN x"32" => ascii <= x"02"; --^B  STX
                WHEN x"21" => ascii <= x"03"; --^C  ETX
                WHEN x"23" => ascii <= x"04"; --^D  EOT
                WHEN x"24" => ascii <= x"05"; --^E  ENQ
                WHEN x"2B" => ascii <= x"06"; --^F  ACK
                WHEN x"34" => ascii <= x"07"; --^G  BEL
                WHEN x"33" => ascii <= x"08"; --^H  BS
                WHEN x"43" => ascii <= x"09"; --^I  HT
                WHEN x"3B" => ascii <= x"0A"; --^J  LF
                WHEN x"42" => ascii <= x"0B"; --^K  VT
                WHEN x"4B" => ascii <= x"0C"; --^L  FF
                WHEN x"3A" => ascii <= x"0D"; --^M  CR
                WHEN x"31" => ascii <= x"0E"; --^N  SO
                WHEN x"44" => ascii <= x"0F"; --^O  SI
                WHEN x"4D" => ascii <= x"10"; --^P  DLE
                WHEN x"15" => ascii <= x"11"; --^Q  DC1
                WHEN x"2D" => ascii <= x"12"; --^R  DC2
                WHEN x"1B" => ascii <= x"13"; --^S  DC3
                WHEN x"2C" => ascii <= x"14"; --^T  DC4
                WHEN x"3C" => ascii <= x"15"; --^U  NAK
                WHEN x"2A" => ascii <= x"16"; --^V  SYN
                WHEN x"1D" => ascii <= x"17"; --^W  ETB
                WHEN x"22" => ascii <= x"18"; --^X  CAN
                
                --^Y  scancode: US: ^Y / DE: ^Z
                WHEN x"35" =>
                  if locale = loc_DE then
                     ascii <= x"1A"; --^Z  SUB
                  else
                     ascii <= x"19"; --^Y  EM
                  end if;
                  
                --^Z scancode: US: ^Z / DE: ^Y
                WHEN x"1A" =>
                  if locale = loc_DE then
                     ascii <= x"19"; --^Y  EM
                  else
                     ascii <= x"1A"; --^Z  SUB
                  end if;
                
                -- @TODO: make a DE locale version of these
                WHEN x"54" => ascii <= x"1B"; --^[  ESC
                WHEN x"5D" => ascii <= x"1C"; --^\  FS
                WHEN x"5B" => ascii <= x"1D"; --^]  GS
                WHEN x"36" => ascii <= x"1E"; --^^  RS
                WHEN x"4E" => ascii <= x"1F"; --^_  US
                WHEN x"4A" => ascii <= x"7F"; --^?  DEL
                WHEN OTHERS => NULL;
              END CASE;
            ELSE --if control keys are not pressed  
                        
               --translate characters that do not depend on shift, or caps lock
               CASE ps2_code IS
                  WHEN x"29" => ascii <= x"20"; --space
                  WHEN x"66" => ascii <= x"08"; --backspace (BS control code)
                  WHEN x"0D" => ascii <= x"09"; --tab (HT control code)
                  WHEN x"5A" => ascii <= x"0D"; --enter (CR control code)
                  WHEN x"76" => ascii <= x"1B"; --escape (ESC control code)
                  
                  WHEN OTHERS => NULL;
               END CASE;               
                                          
              --translate letters (these depend on both shift and caps lock)
              IF((shift_r = '0' AND shift_l = '0' AND caps_lock = '0') OR
                ((shift_r = '1' OR shift_l = '1') AND caps_lock = '1')) THEN  --letter is lowercase
                CASE ps2_code IS              
                  WHEN x"1C" => ascii <= x"61"; --a
                  WHEN x"32" => ascii <= x"62"; --b
                  WHEN x"21" => ascii <= x"63"; --c
                  WHEN x"23" => ascii <= x"64"; --d
                  WHEN x"24" => ascii <= x"65"; --e
                  WHEN x"2B" => ascii <= x"66"; --f
                  WHEN x"34" => ascii <= x"67"; --g
                  WHEN x"33" => ascii <= x"68"; --h
                  WHEN x"43" => ascii <= x"69"; --i
                  WHEN x"3B" => ascii <= x"6A"; --j
                  WHEN x"42" => ascii <= x"6B"; --k
                  WHEN x"4B" => ascii <= x"6C"; --l
                  WHEN x"3A" => ascii <= x"6D"; --m
                  WHEN x"31" => ascii <= x"6E"; --n
                  WHEN x"44" => ascii <= x"6F"; --o
                  WHEN x"4D" => ascii <= x"70"; --p
                  WHEN x"15" => ascii <= x"71"; --q
                  WHEN x"2D" => ascii <= x"72"; --r
                  WHEN x"1B" => ascii <= x"73"; --s
                  WHEN x"2C" => ascii <= x"74"; --t
                  WHEN x"3C" => ascii <= x"75"; --u
                  WHEN x"2A" => ascii <= x"76"; --v
                  WHEN x"1D" => ascii <= x"77"; --w
                  WHEN x"22" => ascii <= x"78"; --x
                  
                  -- y scancode: US: y / DE: z
                  WHEN x"35" =>
                     if locale = loc_DE then
                        ascii <= x"7A"; -- z
                     else
                        ascii <= x"79"; -- y
                     end if;
                     
                  -- z scancode: US: z / DE: y
                  WHEN x"1A" =>
                     if locale = loc_DE then
                        ascii <= x"79"; -- y
                     else
                        ascii <= x"7A"; -- z
                     end if;
                  
                  WHEN OTHERS => NULL;
                END CASE;
              ELSE                                     --letter is uppercase
                CASE ps2_code IS            
                  WHEN x"1C" => ascii <= x"41"; --A
                  WHEN x"32" => ascii <= x"42"; --B
                  WHEN x"21" => ascii <= x"43"; --C
                  WHEN x"23" => ascii <= x"44"; --D
                  WHEN x"24" => ascii <= x"45"; --E
                  WHEN x"2B" => ascii <= x"46"; --F
                  WHEN x"34" => ascii <= x"47"; --G
                  WHEN x"33" => ascii <= x"48"; --H
                  WHEN x"43" => ascii <= x"49"; --I
                  WHEN x"3B" => ascii <= x"4A"; --J
                  WHEN x"42" => ascii <= x"4B"; --K
                  WHEN x"4B" => ascii <= x"4C"; --L
                  WHEN x"3A" => ascii <= x"4D"; --M
                  WHEN x"31" => ascii <= x"4E"; --N
                  WHEN x"44" => ascii <= x"4F"; --O
                  WHEN x"4D" => ascii <= x"50"; --P
                  WHEN x"15" => ascii <= x"51"; --Q
                  WHEN x"2D" => ascii <= x"52"; --R
                  WHEN x"1B" => ascii <= x"53"; --S
                  WHEN x"2C" => ascii <= x"54"; --T
                  WHEN x"3C" => ascii <= x"55"; --U
                  WHEN x"2A" => ascii <= x"56"; --V
                  WHEN x"1D" => ascii <= x"57"; --W
                  WHEN x"22" => ascii <= x"58"; --X
                  
                  -- Y scancode: US: Y / DE: Z
                  WHEN x"35" =>
                     if locale = loc_DE then
                        ascii <= x"5A"; -- Z
                     else
                        ascii <= x"59"; -- Y
                     end if;
                     
                  -- Z scancode: US: Z / DE: Y
                  WHEN x"1A" =>
                     if locale = loc_DE then
                        ascii <= x"59"; -- Y
                     else
                        ascii <= x"5A"; -- Z
                     end if;
                                    
                  WHEN OTHERS => NULL;
                END CASE;
              END IF;
              
              --translate numbers and symbols (these depend on shift but not caps lock)
              IF(shift_l = '1' OR shift_r = '1') THEN  --key's secondary character is desired
                
                -- DE LOCALE
                if locale = loc_DE then
                   CASE ps2_code IS              
                     WHEN x"16" => ascii <= x"21"; -- SHIFT+1 => !
                     WHEN x"1E" => ascii <= x"22"; -- SHIFT+2 => "
                     WHEN x"26" =>                 -- SHIFT+3 => §
                        ascii_ext <= '1';
                        ascii <= x"A7" and x"7F";
                     WHEN x"25" => ascii <= x"24"; -- SHIFT+4 => $      
                     WHEN x"2E" => ascii <= x"25"; -- SHIFT+5 => %
                     WHEN x"36" => ascii <= x"26"; -- SHIFT+6 => &
                     WHEN x"3D" => ascii <= x"2F"; -- SHIFT+7 => /
                     WHEN x"3E" => ascii <= x"28"; -- SHIFT+8 => (
                     WHEN x"46" => ascii <= x"29"; -- SHIFT+9 => )
                     WHEN x"45" => ascii <= x"3D"; -- SHIFT+0 => =
                     WHEN x"4E" => ascii <= x"3F"; -- SHIFT+ß => ?                     
                     WHEN x"55" => null;           -- @TODO: Implement complex apostroph handling                     
                     WHEN x"54" =>                 -- SHIFT+ü => Ü
                        ascii_ext <= '1';
                        ascii <= x"DC" and x"7F";
                     WHEN x"5B" => ascii <= x"2A"; -- SHIFT++ => *
                     WHEN x"4C" =>                 -- SHIFT+ö => Ö
                        ascii_ext <= '1';
                        ascii <= x"D6" and x"7F";
                     WHEN x"52" =>                 -- SHIFT+ä => Ä
                        ascii_ext <= '1';
                        ascii <= x"C4" and x"7F";
                     WHEN x"5D" => ascii <= x"27"; -- SHIFT+# => '
                     WHEN x"41" => ascii <= x"3B"; -- SHIFT+, => ;
                     WHEN x"49" => ascii <= x"3A"; -- SHIFT+. => :
                     WHEN x"4A" => ascii <= x"5F"; -- SHIFT+- => _
                     WHEN x"0E" =>                 -- SHIFT+^ => °
                        ascii_ext <= '1';
                        ascii <= x"B0" and x"7F";
                     WHEN x"61" => ascii <= x"3E"; -- SHIFT+< => >
                     WHEN OTHERS => null;                     
                  END CASE;
                
                -- U.S. LOCALE
                else
                   CASE ps2_code IS              
                     WHEN x"16" => ascii <= x"21"; --!
                     WHEN x"52" => ascii <= x"22"; --"
                     WHEN x"26" => ascii <= x"23"; --#                     
                     WHEN x"25" => ascii <= x"24"; --$
                     WHEN x"2E" => ascii <= x"25"; --%
                     WHEN x"3D" => ascii <= x"26"; --&              
                     WHEN x"46" => ascii <= x"28"; --(
                     WHEN x"45" => ascii <= x"29"; --)
                     WHEN x"3E" => ascii <= x"2A"; --*
                     WHEN x"55" => ascii <= x"2B"; --+
                     WHEN x"4C" => ascii <= x"3A"; --:
                     WHEN x"41" => ascii <= x"3C"; --<
                     WHEN x"49" => ascii <= x"3E"; -->
                     WHEN x"4A" => ascii <= x"3F"; --?
                     WHEN x"1E" => ascii <= x"40"; --@
                     WHEN x"36" => ascii <= x"5E"; --^
                     WHEN x"4E" => ascii <= x"5F"; --_
                     WHEN x"54" => ascii <= x"7B"; --{
                     WHEN x"5D" => ascii <= x"7C"; --|
                     WHEN x"5B" => ascii <= x"7D"; --}
                     WHEN x"0E" => ascii <= x"7E"; --~
                     WHEN OTHERS => NULL;
                  END CASE;                
                end if;
              
              ELSE                                     --key's primary character is desired
              
                -- DE LOCALE
                if locale = loc_DE then
                   CASE ps2_code IS              
                     WHEN x"16" => ascii <= x"31"; -- 1
                     WHEN x"1E" => ascii <= x"32"; -- 2
                     WHEN x"26" => ascii <= x"33"; -- 3
                     WHEN x"25" => ascii <= x"34"; -- 4
                     WHEN x"2E" => ascii <= x"35"; -- 5
                     WHEN x"36" => ascii <= x"36"; -- 6
                     WHEN x"3D" => ascii <= x"37"; -- 7
                     WHEN x"3E" => ascii <= x"38"; -- 8
                     WHEN x"46" => ascii <= x"39"; -- 9
                     WHEN x"45" => ascii <= x"30"; -- 0
                     WHEN x"4E" =>                 -- ß
                        ascii_ext <= '1';
                        ascii <= x"DF" and x"7F";
                     WHEN x"55" => null;           -- @TODO: Implement complex apostroph handling                     
                     WHEN x"54" =>                 -- ü
                        ascii_ext <= '1';
                        ascii <= x"FC" and x"7F";
                     WHEN x"5B" => ascii <= x"2B"; -- +
                     WHEN x"4C" =>                 -- ö
                        ascii_ext <= '1';
                        ascii <= x"F6" and x"7F";
                     WHEN x"52" =>                 -- ä
                        ascii_ext <= '1';
                        ascii <= x"E4" and x"7F";
                     WHEN x"5D" => ascii <= x"23"; -- #
                     WHEN x"41" => ascii <= x"2C"; -- ,
                     WHEN x"49" => ascii <= x"2E"; -- .
                     WHEN x"4A" => ascii <= x"2D"; -- -
                     WHEN x"0E" => ascii <= x"5E"; -- ^
                     WHEN x"61" => ascii <= x"3C"; -- <
                     WHEN OTHERS => null;                     
                  END CASE;
                
                -- U.S. LOCALE
                else
                   CASE ps2_code IS  
                     WHEN x"45" => ascii <= x"30"; --0
                     WHEN x"16" => ascii <= x"31"; --1
                     WHEN x"1E" => ascii <= x"32"; --2
                     WHEN x"26" => ascii <= x"33"; --3
                     WHEN x"25" => ascii <= x"34"; --4
                     WHEN x"2E" => ascii <= x"35"; --5
                     WHEN x"36" => ascii <= x"36"; --6
                     WHEN x"3D" => ascii <= x"37"; --7
                     WHEN x"3E" => ascii <= x"38"; --8
                     WHEN x"46" => ascii <= x"39"; --9
                     WHEN x"52" => ascii <= x"27"; --'
                     WHEN x"41" => ascii <= x"2C"; --,
                     WHEN x"4E" => ascii <= x"2D"; ---
                     WHEN x"49" => ascii <= x"2E"; --.
                     WHEN x"4A" => ascii <= x"2F"; --/
                     WHEN x"4C" => ascii <= x"3B"; --;
                     WHEN x"55" => ascii <= x"3D"; --=
                     WHEN x"54" => ascii <= x"5B"; --[                     
                     WHEN x"5D" => ascii <= x"5C"; --\
                     WHEN x"5B" => ascii <= x"5D"; --]
                     WHEN x"0E" => ascii <= x"60"; --`
                     WHEN OTHERS => NULL;
                   END CASE;                
                end if;
                
              END IF;              
            END IF;
          
          IF(break = '0') THEN  --the code is a make
            state <= output;      --proceed to output state
          ELSE                  --code is a break
            state <= ready;       --return to ready state to await next PS2 code
          END IF;
        
        --output state: verify the code is valid and output the ASCII value
        WHEN output =>

          IF (ascii(7) = '0' or ascii_ext='1') THEN              --the PS2 code has an ASCII output
            ascii_new <= '1';                                   --set flag indicating new ASCII output
            ascii_code <= ascii_ext & ascii(6 DOWNTO 0);        --output the ASCII value
          END IF;
          
          IF spec /= x"00" THEN
            spec_new <= '1';
            ascii_code <= x"00";
          END IF;
          spec_code <= spec;
          
          modifiers(mod_ctrl_bit)  <= control_l or control_r;
          modifiers(mod_shift_bit) <= shift_l or shift_r;
          modifiers(mod_alt_bit)   <= alt_l or alt_gr;
          
          state <= ready;                      --return to ready state to await next PS2 code

      END CASE;
    END IF;
  END PROCESS;

END behavior;



