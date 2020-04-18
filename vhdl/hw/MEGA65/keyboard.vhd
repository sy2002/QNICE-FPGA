-- QNICE-MEGA65 keyboard controller
-- done by sy2002 in April 2020
--
-- Wraps the MEGA65 specifics and outputs ASCII and special key signals
-- just as QNICE expects it. The component is meant to be connected
-- with the QNICE CPU as data I/O controled through MMIO. Tristate outputs
-- go high impedance when not enabled.
--
-- IMPORTANT: kbd_constants.vhd contains locales, special characters, modifiers
--            The subfolder "kbd" contains the original MEGA65 keyboard driver
--
-- Registers:
--
-- Register $FF13: State register
--    Bit  0 (read only):      New ASCII character avaiable for reading
--                             (bits 7 downto 0 of Read register)
--    Bit  1 (read only):      New special key available for reading
--                             (bits 15 downto 8 of Read register)
--    Bits 2..4 (read/write):  Locales: 000 = US English keyboard layout,
--                             001 = German layout, others: reserved for more locales
--    Bits 5..7 (read only):   Modifiers: 5 = shift, 6 = alt, 7 = ctrl
--                             Only valid, when bits 0 and/or 1 are '1'
-- Register $FF14: Read register
--    Contains the ASCII character in bits 7 downto 0  or the special key code
--    in 15 downto 0. The "or" is meant exclusive, i.e. it cannot happen that
--    one transmission contains an ASCII character PLUS a special character.


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity keyboard is
generic (
   clk_freq      : integer                     -- system clock frequency
);
port (
   clk           : in std_logic;               -- system clock
   reset         : in std_logic;               -- system reset
   
   -- MEGA65 smart keyboard controller
   kb_io0 : out std_logic;                     -- clock to keyboard
   kb_io1 : out std_logic;                     -- data output to keyboard
   kb_io2 : in std_logic;                      -- data input from keyboard   
   
   -- connect to CPU's data bus (data high impedance when all reg_* are 0)
   kbd_en        : in std_logic;
   kbd_we        : in std_logic;
   kbd_reg       : in std_logic_vector(1 downto 0);   
   cpu_data      : inout std_logic_vector(15 downto 0)
);
end keyboard;

architecture beh of keyboard is

-- MEGA65 hardware keyboard controller
component mega65kbd_to_matrix is
  port (
    ioclock : in std_logic;

    flopmotor : in std_logic;
    flopled : in std_logic;
    powerled : in std_logic;    
    
    kio8 : out std_logic; -- clock to keyboard
    kio9 : out std_logic; -- data output to keyboard
    kio10 : in std_logic; -- data input from keyboard

    matrix_col : out std_logic_vector(7 downto 0) := (others => '1');
    matrix_col_idx : in integer range 0 to 8;

    delete_out : out std_logic;
    return_out : out std_logic;
    fastkey_out : out std_logic;
    
    -- RESTORE and capslock are active low
    restore : out std_logic := '1';
    capslock_out : out std_logic := '1';

    -- LEFT and UP cursor keys are active HIGH
    leftkey : out std_logic := '0';
    upkey : out std_logic := '0'
    
    );
end component;

-- MEGA65 keyboard matrix to ASCII converter
component matrix_to_ascii is
  generic (scan_frequency : integer := 1000;
           clock_frequency : integer);
  port (Clk : in std_logic;
        reset_in : in std_logic;

        matrix_col : in std_logic_vector(7 downto 0);
        matrix_col_idx : in integer range 0 to 15;
        
        suppress_key_glitches : in std_logic;
        suppress_key_retrigger : in std_logic;

        key_up : in std_logic;
        key_left : in std_logic;
        key_caps : in std_logic;
        
        -- UART key stream
        ascii_key : out unsigned(7 downto 0) := (others => '0');
        -- Bucky key list:
        -- 0 = left shift
        -- 1 = right shift
        -- 2 = control
        -- 3 = C=
        -- 4 = ALT
        -- 5 = NO SCROLL
        -- 6 = ASC/DIN/CAPS LOCK (XXX - Has a separate line. Not currently monitored)
        bucky_key : out std_logic_vector(6 downto 0) := (others  => '0');
        ascii_key_valid : out std_logic := '0'
        );
end component;   

signal spec_new            : std_logic := '0';
signal spec_code           : std_logic_vector(7 downto 0) := x"00";

-- connectivity for the MEGA65 hardware keyboard controller
signal matrix_col          : std_logic_vector(7 downto 0);
signal matrix_col_idx      : integer range 0 to 8 := 0;
signal key_delete          : std_logic;
signal key_return          : std_logic;
signal key_fast            : std_logic;
signal key_restore_n       : std_logic;
signal key_capslock_n      : std_logic;
signal key_left            : std_logic;
signal key_up              : std_logic;

-- connectivity for MEGA65 keyboard matrix to ASCII converter
signal ascii_key           : unsigned(7 downto 0);
signal bucky_key           : std_logic_vector(6 downto 0);
signal ascii_key_valid     : std_logic;

-- signals that together form the status register
signal ff_ascii_new        : std_logic;
signal reset_ff_ascii_new  : std_logic;
signal ff_spec_new         : std_logic;
signal reset_ff_spec_new   : std_logic;
signal ff_locale           : std_logic_vector(2 downto 0);
signal modifiers           : std_logic_vector(2 downto 0);

begin

   mega65kbd_ctrl : mega65kbd_to_matrix
   port map (
      ioclock        => clk,
      
      flopmotor      => '0',
      flopled        => '0',
      powerled       => '1',
      
      kio8           => kb_io0,
      kio9           => kb_io1,
      kio10          => kb_io2,
      
      matrix_col     => matrix_col,
      matrix_col_idx => matrix_col_idx,
      
      delete_out     => key_delete,
      return_out     => key_return,
      fastkey_out    => key_fast,
      restore        => key_restore_n,
      capslock_out   => key_capslock_n,
      leftkey        => key_left,
      upkey          => key_up
   );
   
   mega65_matrix_to_ascii : matrix_to_ascii
   generic map (
      scan_frequency => 1000,
      clock_frequency => 50000000
   )
   port map (
      clk => clk,
      reset_in => '0',
      
      matrix_col => matrix_col,
      matrix_col_idx => matrix_col_idx,
      
      suppress_key_glitches => '1',
      suppress_key_retrigger => '0',
      
      key_up => key_up,
      key_left => key_left,
      key_caps => key_capslock_n,
      
      ascii_key => ascii_key,
      bucky_key => bucky_key,
      ascii_key_valid => ascii_key_valid      
   );

   matrix_col_idx_handler : process(clk)
   begin
      if rising_edge(clk) then
         if matrix_col_idx < 8 then
           matrix_col_idx <= matrix_col_idx + 1;
         else
           matrix_col_idx <= 0;
         end if;      
      end if;
   end process;
      
   ff_ascii_new_handler : process(ascii_key_valid, reset, reset_ff_ascii_new)
   begin
      if reset = '1' or reset_ff_ascii_new = '1' then
         ff_ascii_new <= '0';
      else
         if rising_edge(ascii_key_valid) then
            ff_ascii_new <= '1';
         end if;
      end if;
   end process;
   
   ff_spec_new_handler : process(spec_new, reset, reset_ff_spec_new)
   begin
      if reset = '1' or reset_ff_spec_new = '1' then
         ff_spec_new <= '0';
      else
         if rising_edge(spec_new) then
            ff_spec_new <= '1';
         end if;
      end if;
   end process;
   
   write_ff_locale: process(clk, kbd_en, kbd_we, kbd_reg, reset)
   begin
      if reset = '1' then
         ff_locale <= (others => '0');
      else
         if rising_edge(clk) then
            if kbd_en = '1' and kbd_we = '1' and kbd_reg = "00" then
               ff_locale <= cpu_data(4 downto 2);
            end if;
         end if;
      end if;
   end process;
      
   read_registers : process(kbd_en, kbd_we, kbd_reg, ff_locale, ff_spec_new, ff_ascii_new, ascii_key, spec_code, modifiers)
   begin
      reset_ff_ascii_new <= '0';
      reset_ff_spec_new <= '0';
      
      if kbd_en = '1' and kbd_we = '0' then
         case kbd_reg is
         
            -- read status register
            when "00" =>
               cpu_data <= "00000000" &
                           modifiers &    -- bits 7 .. 5: ctrl/alt/shift
                           ff_locale &    -- bits 4 .. 2: 000 = US, 001 = DE
                           ff_spec_new &  -- bit 1: new special key
                           ff_ascii_new;  -- bit 0: new ascii key
               
            -- read data register
            when "01" =>
               cpu_data <= spec_code & std_logic_vector(ascii_key);
               reset_ff_ascii_new <= '1';
               reset_ff_spec_new <= '1';
               
            when others =>
               cpu_data <= (others => '0');
         
         end case;
      else
         cpu_data <= (others => 'Z');
      end if;   
   end process;

end beh;
 