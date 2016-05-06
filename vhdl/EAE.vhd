----------------------------------------------------------------------------------
-- EAE - Extended Arithmetic Element inspired by the PDP-11
--
-- performs 32-bit signed/unsigned integer multiplication and division and modulo
--
-- meant to be connected to QNICE's data bus, tristate output goes high impedance
-- when en is '0'
-- 
-- done in May 2016 by sy2002
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity EAE is
port (
   clk      : in std_logic;                        -- system clock
   reset    : in std_logic;                        -- system reset
   
   -- EAE registers
   en       : in std_logic;                        -- chip enable
   we       : in std_logic;                        -- write enable
   reg      : in std_logic_vector(2 downto 0);     -- register selector
   data     : inout std_logic_vector(15 downto 0)  -- system's data bus
);
end EAE;

architecture beh of EAE is

-- EAE opcodes
constant eaeMULU  : std_logic_vector(1 downto 0) := "00";       -- unsigned multiply
constant eaeMULS  : std_logic_vector(1 downto 0) := "01";       -- signed multiply
constant eaeDIVU  : std_logic_vector(1 downto 0) := "10";       -- unsigned division
constant eaeDIVS  : std_logic_vector(1 downto 0) := "11";       -- signed division

-- EAE register
constant regOP0   : std_logic_vector(2 downto 0)  := "000";     -- 16-bit input operand 0
constant regOP1   : std_logic_vector(2 downto 0)  := "001";     -- 16-bit input operand 1
constant regRLO   : std_logic_vector(2 downto 0)  := "010";     -- low word of 32-bit result
constant regRHI   : std_logic_vector(2 downto 0)  := "011";     -- high word of 32-bit result
constant regCSR   : std_logic_vector(2 downto 0)  := "100";     -- control and status register

-- internal registers 
signal op0        : std_logic_vector(15 downto 0);    -- operand 0: the real flip-flop
signal op0_s      : signed(15 downto 0);              -- operand 0: signed representation
signal op0_u      : unsigned(15 downto 0);            -- operand 0: unsigned representation
signal op1        : std_logic_vector(15 downto 0);    -- ditto operand 1
signal op1_s      : signed(15 downto 0);
signal op1_u      : unsigned(15 downto 0);
signal res        : std_logic_vector(31 downto 0);    -- result: 32-bit flip-flop
signal res_u      : unsigned(31 downto 0);
signal res_s      : signed(31 downto 0);
signal csr        : std_logic_vector(1 downto 0);     -- control and status register
signal busy       : std_logic;                        -- EAE is currently computing


begin

   write_eae_registers : process(clk, reset)
   begin
      if reset = '1' then
         op0 <= (others => '0');
         op1 <= (others => '0');
         csr <= (others => '0');
      else
         if falling_edge(clk) then
            if en = '1' and we = '1' then
               case reg is
                  when regOP0 => op0 <= data;
                  when regOP1 => op1 <= data;
                  when regCSR => csr <= data(1 downto 0);
                  when others => null;
               end case;
            end if;
         end if;
      end if;
   end process;

   read_eae_registers : process(en, we, reg, op0, op1, res, busy, csr)
   begin
      if en = '1' and we = '0' then
         case reg is
            when regOP0 => data <= op0;
            when regOP1 => data <= op1;
            when regRLO => data <= res(15 downto 0);
            when regRHI => data <= res(31 downto 16);
            when regCSR => data <= busy & "0000000000000" & csr(1 downto 0);
            when others => data <= (others => '0');
         end case;
      else
         data <= (others => 'Z');
      end if;
   end process;
   
   busy <= '0';
   
   res <= std_logic_vector(res_s);
   
   res_s <= op0_s * op1_s;
   
   op0_s <= signed(op0);
   op0_u <= unsigned(op0);
   op1_s <= signed(op1);
   op1_u <= unsigned(op1);
end beh;

