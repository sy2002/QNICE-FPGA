library ieee;
use ieee.std_logic_1164.all;

entity arbiter is
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

      dst_valid_i    : in  std_logic;
      dst_ready_o    : out std_logic;
      dst_address_i  : in  std_logic_vector(15 downto 0);
      dst_data_o     : out std_logic_vector(15 downto 0);

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
end entity arbiter;

architecture synthesis of arbiter is

   signal inst_ready : std_logic;
   signal src_ready  : std_logic;
   signal dst_ready  : std_logic;
   signal res_ready  : std_logic;

begin

   res_ready   <= '1';
   dst_ready   <= not (res_valid_i and res_ready);
   src_ready   <= not ((res_valid_i and res_ready) or (dst_valid_i and dst_ready));
   inst_ready  <= not ((res_valid_i and res_ready) or (dst_valid_i and dst_ready) or (src_valid_i and src_ready));

   mem_address_o <= res_address_i  when (res_valid_i  and res_ready)  = '1' else
                    dst_address_i  when (dst_valid_i  and dst_ready)  = '1' else
                    src_address_i  when (src_valid_i  and src_ready)  = '1' else
                    inst_address_i when (inst_valid_i and inst_ready) = '1' else
                    (others => '0');
   mem_wr_data_o <= res_data_i;
   mem_write_o   <= res_valid_i and res_ready;
   mem_read_o    <= (dst_valid_i and dst_ready) or (src_valid_i and src_ready) or (inst_valid_i and inst_ready);

   inst_data_o   <= mem_rd_data_i;
   src_data_o    <= mem_rd_data_i;
   dst_data_o    <= mem_rd_data_i;

   inst_ready_o <= inst_ready;
   src_ready_o  <= src_ready;
   dst_ready_o  <= dst_ready;
   res_ready_o  <= res_ready;

end architecture synthesis;

