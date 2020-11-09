library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity arbiter_regs is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;

      -- To clients
      dst_valid_i   : in  std_logic;
      dst_ready_o   : out std_logic;
      dst_reg_i     : in  std_logic_vector(3 downto 0);
      dst_data_i    : in  std_logic_vector(15 downto 0);

      res_valid_i   : in  std_logic;
      res_ready_o   : out std_logic;
      res_reg_i     : in  std_logic_vector(3 downto 0);
      res_data_i    : in  std_logic_vector(15 downto 0);

      -- To register file
      reg_valid_o   : out std_logic;
      reg_address_o : out std_logic_vector(3 downto 0);
      reg_data_o    : out std_logic_vector(15 downto 0)
   );
end entity arbiter_regs;

architecture synthesis of arbiter_regs is

   signal dbg_reg_counter  : std_logic_vector(15 downto 0);
   signal dbg_wait_counter : std_logic_vector(15 downto 0);

   signal dst_active : std_logic;
   signal res_active : std_logic;

   signal dst_ready  : std_logic;
   signal res_ready  : std_logic;

begin

   p_dbg_reg_counter : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if (dst_active or res_active) = '1' then
            dbg_reg_counter <= dbg_reg_counter + 1;
         end if;
         if rst_i = '1' then
            dbg_reg_counter <= (others => '0');
         end if;
      end if;
   end process p_dbg_reg_counter;

   p_dbg_wait_counter : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if (dst_valid_i and res_valid_i) = '1' then
            dbg_wait_counter <= dbg_wait_counter + 1;
         end if;
         if rst_i = '1' then
            dbg_wait_counter <= (others => '0');
         end if;
      end if;
   end process p_dbg_wait_counter;


   -- Calculate which stage is actively writing to a register.
   -- Note: At most one of the signals below may be asserted, as verified in the assert below.
   dst_active <= dst_valid_i and dst_ready;
   res_active <= res_valid_i and res_ready;

   -- Note: And'ing with "not clk_i" is to avoid trapping on delta cycle transitions.
   assert (dst_active and res_active and not clk_i) = '0'
      report "ERROR: Multiple stages accessing register file";

   -- Calculate which stages are allowed write access.
   -- Priority is given to the later stages.
   res_ready <= '1';
   dst_ready <= not res_active;

   -- Propagate signals from selected stage to the register file.
   reg_address_o <= dst_reg_i when dst_active = '1' else
                    res_reg_i when res_active = '1' else
                    (others => '0');
   reg_data_o    <= dst_data_i when dst_active = '1' else
                    res_data_i when res_active = '1' else
                    (others => '0');
   reg_valid_o   <= dst_valid_i when dst_active = '1' else
                    res_valid_i when res_active = '1' else
                    '0';

   dst_ready_o <= dst_ready;
   res_ready_o <= res_ready;

end architecture synthesis;

