library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use work.constants.all;

entity fifo_ctrl is
generic
(
	constant FIFO_DATA_WIDTH  : integer := 32;
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
end entity fifo_ctrl;

architecture structural of fifo_ctrl is 

	signal full 	: std_logic_vector(1 downto 0);
	signal empty 	: std_logic_vector(1 downto 0);
	signal rd_ctrl : std_logic_vector(1 downto 0);
	signal wr_ctrl : std_logic_vector(1 downto 0);

begin

	fifo_data : component fifo
	generic map
	(
		FIFO_BUFFER_SIZE => FIFO_BUFFER_SIZE,
		FIFO_DATA_WIDTH  => FIFO_DATA_WIDTH
	)
	port map
	(
		rd_clk 	=> rd_clk,
		wr_clk 	=> wr_clk,
		reset 	=> reset,
		rd_en 	=> rd_en,
		wr_en 	=> wr_en,
		din 		=> wr_din,
		dout 		=> rd_dout,
		full 		=> full(0),
		empty 	=> empty(0)
	);

	fifo_control : component fifo
	generic map
	(
		FIFO_BUFFER_SIZE => FIFO_BUFFER_SIZE,
		FIFO_DATA_WIDTH  => 2
	)
	port map
	(
		rd_clk 	=> rd_clk,
		wr_clk 	=> wr_clk,
		reset 	=> reset,
		rd_en 	=> rd_en,
		wr_en 	=> wr_en,
		din 		=> wr_ctrl,
		dout 		=> rd_ctrl,
		full 		=> full(1),
		empty 	=> empty(1)
	);

	rd_sof 		<= rd_ctrl(0);
	rd_eof 		<= rd_ctrl(1);
	rd_empty 	<= empty(0) or empty(1);
	wr_ctrl(0)  <= wr_sof;
	wr_ctrl(1)  <= wr_eof;
	wr_full 		<= full(0) or full(1);

end architecture structural;
