library ieee;
use ieee.std_logic_1164.all;

entity arbiter_regs is
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;

      -- To clients
      src_valid_i   : in  std_logic;
      src_ready_o   : out std_logic;
      src_reg_i     : in  std_logic_vector(3 downto 0);
      src_data_i    : in  std_logic_vector(15 downto 0);

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

   signal src_active : std_logic;
   signal dst_active : std_logic;
   signal res_active : std_logic;

   signal src_ready  : std_logic;
   signal dst_ready  : std_logic;
   signal res_ready  : std_logic;

begin

   -- Calculate which stage is actively writing to a register.
   -- Note: At most one of the signals below may be asserted, as verified in the assert below.
   src_active <= src_valid_i and src_ready;
   dst_active <= dst_valid_i and dst_ready;
   res_active <= res_valid_i and res_ready;

   -- Note: And'ing with "not clk_i" is to avoid trapping on delta cycle transitions.
   assert (((src_active and dst_active) or
            (src_active and res_active) or
            (dst_active and res_active)) and not clk_i) = '0'
      report "ERROR: Multiple stages accessing register file";

   -- Calculate which stages are allowed write access.
   -- Priority is given to the later stages.
   res_ready <= '1';
   dst_ready <= not res_active;
   src_ready <= not (res_active or dst_active);

   -- Propage signals from selected stage to the register file.
   reg_address_o <= src_reg_i when src_active = '1' else
                    dst_reg_i when dst_active = '1' else
                    res_reg_i when res_active = '1' else
                    (others => '0');
   reg_data_o    <= src_data_i when src_active = '1' else
                    dst_data_i when dst_active = '1' else
                    res_data_i when res_active = '1' else
                    (others => '0');
   reg_valid_o   <= src_valid_i when src_active = '1' else
                    dst_valid_i when dst_active = '1' else
                    res_valid_i when res_active = '1' else
                    '0';

   src_ready_o <= src_ready;
   dst_ready_o <= dst_ready;
   res_ready_o <= res_ready;

end architecture synthesis;

