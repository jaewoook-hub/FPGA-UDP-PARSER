library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;

package constants is

    constant ETH_DST_ADDR_BYTES     :   integer := 6;
    constant ETH_SRC_ADDR_BYTES     :   integer := 6;
    constant ETH_PROTOCOL_BYTES     :   integer := 2;
    constant IP_VERSION_BYTES       :   integer := 1;
    constant IP_HEADER_BYTES        :   integer := 1;
    constant IP_TYPE_BYTES          :   integer := 1;
    constant IP_LENGTH_BYTES        :   integer := 2;
    constant IP_ID_BYTES            :   integer := 2;
    constant IP_FLAG_BYTES          :   integer := 2;
    constant IP_TIME_BYTES          :   integer := 1;
    constant IP_PROTOCOL_BYTES      :   integer := 1;
    constant IP_CHECKSUM_BYTES      :   integer := 2;
    constant IP_SRC_ADDR_BYTES      :   integer := 4;
    constant IP_DST_ADDR_BYTES      :   integer := 4;
    constant UDP_DST_ADDR_BYTES     :   integer := 2;
    constant UDP_SRC_ADDR_BYTES     :   integer := 2;
    constant UDP_LENGTH_BYTES       :   integer := 2;
    constant UDP_CHECKSUM_BYTES     :   integer := 2;
    constant IP_PROTOCOL_DEF        :   std_logic_vector((ETH_PROTOCOL_BYTES*8)-1 downto 0) := X"0800";
    constant IP_VERSION_DEF         :   std_logic_vector((IP_VERSION_BYTES*4)-1 downto 0) := X"4";
    constant UDP_PROTOCOL_DEF       :   std_logic_vector((IP_PROTOCOL_BYTES*8)-1 downto 0) := X"11";
	
	component udp_parser is
	port 
	(    
		signal clock        :   in std_logic;
		signal reset        :   in std_logic;
		signal in_dout      :   in  std_logic_vector(7 downto 0); 
		signal in_sof       :   in  std_logic;                    
		signal in_eof       :   in  std_logic;                    
		signal in_empty     :   in  std_logic;                    
		signal in_rd_en     :   out std_logic;                    
		signal out_din      :   out std_logic_vector(7 downto 0);
		signal out_sof      :   out std_logic;                    
		signal out_eof      :   out std_logic;                    
		signal out_full     :   in  std_logic;                   
		signal out_wr_en    :   out std_logic                      
	);
	end component udp_parser;

	component udp_parser_top is
	port
	(
		signal clock        :   in 	std_logic;
		signal reset        :   in 	std_logic;
		signal in_din       :   in  std_logic_vector(7 downto 0); 
		signal in_sof       :   in  std_logic;                   
		signal in_eof       :   in  std_logic;                   
		signal in_full      :   out std_logic;                  
		signal in_wr_en     :   in  std_logic;                   
		signal out_dout     :   out std_logic_vector(7 downto 0); 
		signal out_sof      :   out std_logic;                   
		signal out_eof      :   out std_logic;                   
		signal out_empty    :   out std_logic;                    
		signal out_rd_en    :   in	std_logic                     
	);
	end component udp_parser_top;

    component fifo_ctrl is
    generic
    (
        constant FIFO_DATA_WIDTH : integer := 32;
        constant FIFO_BUFFER_SIZE : integer := 256
    );
    port
    (
        signal reset    : in std_logic;

        signal rd_clk   : in std_logic;
        signal rd_en    : in std_logic;
        signal rd_dout  : out std_logic_vector ((FIFO_DATA_WIDTH - 1) downto 0);
        signal rd_empty : out std_logic;
        signal rd_sof   : out std_logic;
        signal rd_eof   : out std_logic;

        signal wr_clk   : in std_logic;
        signal wr_en    : in std_logic;
        signal wr_din   : in std_logic_vector ((FIFO_DATA_WIDTH - 1) downto 0);
        signal wr_full  : out std_logic;
        signal wr_sof   : in std_logic;
        signal wr_eof   : in std_logic
    );
    end component fifo_ctrl;
	
	component fifo is
	generic
	(
		constant FIFO_DATA_WIDTH : integer := 32;
		constant FIFO_BUFFER_SIZE : integer := 256
	);
	port
	(
		signal rd_clk : in std_logic;
		signal wr_clk : in std_logic;
		signal reset : in std_logic;
		signal rd_en : in std_logic;
		signal wr_en : in std_logic;
		signal din : in std_logic_vector ((FIFO_DATA_WIDTH - 1) downto 0);
		signal dout : out std_logic_vector ((FIFO_DATA_WIDTH - 1) downto 0);
		signal full : out std_logic;
		signal empty : out std_logic
	);
	end component fifo;

end package;