library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.cpu_constants.all;

entity write_result is
   port (
      clk_i            : in  std_logic;
      rst_i            : in  std_logic;

      -- From previous stage
      valid_i          : in  std_logic;
      ready_o          : out std_logic;
      pc_inst_i        : in  std_logic_vector(15 downto 0);
      instruction_i    : in  std_logic_vector(15 downto 0);
      src_operand_i    : in  std_logic_vector(15 downto 0);
      dst_operand_i    : in  std_logic_vector(15 downto 0);
      dst_address_i    : in  std_logic_vector(15 downto 0);

      -- To register file (combinatorial)
      pc_i             : in  std_logic_vector(15 downto 0);
      sr_i             : in  std_logic_vector(15 downto 0);
      sr_o             : out std_logic_vector(15 downto 0);

      -- To memory subsystem (combinatorial)
      mem_valid_o      : out std_logic;
      mem_ready_i      : in  std_logic;
      mem_address_o    : out std_logic_vector(15 downto 0);
      mem_data_o       : out std_logic_vector(15 downto 0);

      -- To register file (combinatorial)
      reg_res_wr_reg_o : out std_logic_vector(3 downto 0);
      reg_res_wr_o     : out std_logic;
      reg_res_ready_i  : in  std_logic;
      reg_res_data_o   : out std_logic_vector(15 downto 0)
   );
end entity write_result;

architecture synthesis of write_result is

   signal res_data       : std_logic_vector(15 downto 0);

   signal mem_request    : std_logic;
   signal mem_ready      : std_logic;
   signal reg_request    : std_logic;
   signal reg_ready      : std_logic;
   signal ready          : std_logic;

   signal branch_execute : std_logic;
   signal branch_dest    : std_logic_vector(15 downto 0);

begin

   -- Do we want to write to memory?
   mem_request <= '0' when valid_i = '0' else
                  '0' when instruction_i(R_OPCODE) = C_OP_BRA else
                  '0' when instruction_i(R_OPCODE) = C_OP_CTRL else
                  '0' when instruction_i(R_OPCODE) = C_OP_CMP else
                  '0' when instruction_i(R_DEST_MODE) = C_MODE_REG else
                  '1';


   -- Are we executing and jumping on a branch?
   branch_execute <= '0' when valid_i = '0' else
                     '0' when conv_integer(instruction_i(R_OPCODE)) /= C_OP_BRA else
                     '0' when sr_i(conv_integer(instruction_i(R_BRA_COND))) /= not instruction_i(R_BRA_NEGATE) else
                     '1';


   -- Do we want register write access?
   reg_request <= '0' when valid_i = '0' else
                  '1' when branch_execute = '1' else
                  '0' when instruction_i(R_OPCODE) = C_OP_BRA else
                  '0' when instruction_i(R_OPCODE) = C_OP_CTRL else
                  '0' when instruction_i(R_OPCODE) = C_OP_CMP else
                  '0' when instruction_i(R_DEST_MODE) /= C_MODE_REG else
                  '1';


   -- Are we waiting for memory read access?
   mem_ready <= not (mem_request and not mem_ready_i);

   -- Are we waiting for register write access?
   reg_ready <= not (reg_request and not reg_res_ready_i);

   -- Are we ready to complete this stage?
   ready <= mem_ready and reg_ready;

   -- To previous stage (combinatorial)
   ready_o <= ready;


   i_alu : entity work.alu
      port map (
         clk_i      => clk_i,
         rst_i      => rst_i,
         valid_i    => valid_i,
         src_data_i => src_operand_i,
         dst_data_i => dst_operand_i,
         sr_i       => sr_i,
         opcode_i   => instruction_i(R_OPCODE),
         res_data_o => res_data,
         sr_o       => sr_o
      ); -- i_alu


   -- Where are we jumping to?
   branch_dest <= pc_i + res_data when instruction_i(R_BRA_MODE) = C_BRA_RBRA else
                  pc_i + res_data when instruction_i(R_BRA_MODE) = C_BRA_RSUB else
                  res_data;

   -- To register write subsystem (combinatorial)
   reg_res_wr_o     <= reg_request and ready;
   reg_res_wr_reg_o <= std_logic_vector(to_unsigned(C_REG_PC, 4)) when branch_execute = '1' else
                       instruction_i(R_DEST_REG);
   reg_res_data_o   <= branch_dest when branch_execute = '1' else
                       res_data;


   -- To memory subsystem (combinatorial)
   mem_valid_o   <= mem_request and ready;
   mem_address_o <= dst_address_i;
   mem_data_o    <= res_data;


   -- synthesis translate_off
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if valid_i = '1' and ready = '1' then
            disassemble(pc_inst_i, instruction_i, res_data);
         end if;
      end if;
   end process;
   -- synthesis translate_on

end architecture synthesis;

