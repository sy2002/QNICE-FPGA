library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity arbiter_mem is
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;

      -- To clients
      inst_valid_i   : in  std_logic;
      inst_ready_o   : out std_logic;
      inst_address_i : in  std_logic_vector(15 downto 0);
      inst_data_o    : out std_logic_vector(15 downto 0);

      src_valid_i    : in  std_logic;
      src_ready_o    : out std_logic;
      src_address_i  : in  std_logic_vector(15 downto 0);
      src_data_o     : out std_logic_vector(15 downto 0);
      src_valid_o    : out std_logic;

      dst_valid_i    : in  std_logic;
      dst_ready_o    : out std_logic;
      dst_address_i  : in  std_logic_vector(15 downto 0);
      dst_data_o     : out std_logic_vector(15 downto 0);
      dst_valid_o    : out std_logic;

      res_valid_i    : in  std_logic;
      res_ready_o    : out std_logic;
      res_address_i  : in  std_logic_vector(15 downto 0);
      res_data_i     : in  std_logic_vector(15 downto 0);

      -- To memory
      mem_address_o  : out std_logic_vector(15 downto 0);
      mem_wr_data_o  : out std_logic_vector(15 downto 0);
      mem_write_o    : out std_logic;
      mem_rd_data_i  : in  std_logic_vector(15 downto 0);
      mem_read_o     : out std_logic
   );
end entity arbiter_mem;

architecture synthesis of arbiter_mem is

   signal dbg_mem_counter  : std_logic_vector(15 downto 0);
   signal dbg_wait_counter : std_logic_vector(15 downto 0);

   signal inst_active : std_logic;
   signal src_active  : std_logic;
   signal dst_active  : std_logic;
   signal res_active  : std_logic;

   signal inst_ready  : std_logic;
   signal src_ready   : std_logic;
   signal dst_ready   : std_logic;
   signal res_ready   : std_logic;

begin

   p_dbg_mem_counter : process (clk_i)
      function to_hstring(slv : std_logic_vector) return string is
         variable l : line;
      begin
         hwrite(l, slv);
         return l.all;
      end function to_hstring;
   begin
      if rising_edge(clk_i) then
         if (inst_active or src_active or dst_active or res_active) = '1' then
            if inst_active = '1' then
               report "MEM: read instruction from 0x" & to_hstring(inst_address_i);
            elsif src_active = '1' then
               report "MEM: read src operand from 0x" & to_hstring(src_address_i);
            elsif dst_active = '1' then
               report "MEM: read dst operand from 0x" & to_hstring(dst_address_i);
            else
               report "MEM: write result to 0x" & to_hstring(res_address_i);
            end if;
            dbg_mem_counter <= dbg_mem_counter + 1;
         end if;
         if rst_i = '1' then
            dbg_mem_counter <= (others => '0');
         end if;
      end if;
   end process p_dbg_mem_counter;

   p_dbg_wait_counter : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if ((inst_valid_i and src_valid_i) or
             (inst_valid_i and dst_valid_i) or
             (inst_valid_i and res_valid_i) or
             (src_valid_i  and dst_valid_i) or
             (src_valid_i  and res_valid_i) or
             (dst_valid_i  and res_valid_i)) = '1' then
            dbg_wait_counter <= dbg_wait_counter + 1;
         end if;
         if rst_i = '1' then
            dbg_wait_counter <= (others => '0');
         end if;
      end if;
   end process p_dbg_wait_counter;

   -- Calculate which stage is actively accessing the memory.
   -- Note: At most one of the signals below may be asserted, as verified in the assert below.
   inst_active <= inst_valid_i and inst_ready;
   src_active  <= src_valid_i  and src_ready;
   dst_active  <= dst_valid_i  and dst_ready;
   res_active  <= res_valid_i  and res_ready;

   p_valid : process (clk_i)
   begin
      if rising_edge(clk_i) then
         src_valid_o <= src_active;
         dst_valid_o <= dst_active;
      end if;
   end process p_valid;

   -- Note: And'ing with "not clk_i" is to avoid trapping on delta cycle transitions.
   assert (((inst_active and src_active) or
            (inst_active and dst_active) or
            (inst_active and res_active) or
            (src_active  and dst_active) or
            (src_active  and res_active) or
            (dst_active  and res_active)) and not clk_i) = '0'
      report "ERROR: Multiple stages accessing memory";

   -- Calculate which stages are allowed memory access.
   -- Priority is given to the later stages.
   res_ready   <= '1';
   dst_ready   <= not (res_active);
   src_ready   <= not (res_active or dst_active);
   inst_ready  <= not (res_active or dst_active or src_active);

   -- Propagate signals from selected stage to the memory.
   mem_address_o <= res_address_i  when res_active  = '1' else
                    dst_address_i  when dst_active  = '1' else
                    src_address_i  when src_active  = '1' else
                    inst_address_i when inst_active = '1' else
                    (others => '0');
   mem_wr_data_o <= res_data_i;
   mem_write_o   <= res_active;
   mem_read_o    <= inst_active or src_active or dst_active;

   inst_data_o   <= mem_rd_data_i;
   src_data_o    <= mem_rd_data_i;
   dst_data_o    <= mem_rd_data_i;

   inst_ready_o  <= inst_ready;
   src_ready_o   <= src_ready;
   dst_ready_o   <= dst_ready;
   res_ready_o   <= res_ready;

end architecture synthesis;

