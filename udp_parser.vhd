library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use work.constants.all;

entity udp_parser is
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
end entity udp_parser;

architecture behavioral of udp_parser is
  
    type STATE_TYPES is (INIT, WAIT_FOR_SOF_STATE, ETH_DST_ADDR_STATE, ETH_SRC_ADDR_STATE, ETH_PROTOCOL_STATE, IP_VERSION, IP_TYPE_STATE, IP_LENGTH_STATE, IP_ID_STATE, IP_FLAG_STATE, IP_TIME_STATE, IP_PROTOCOL_STATE, IP_OPTIONS, IP_CHECKSUM_STATE, IP_SRC_ADDR_STATE, IP_DST_ADDR_STATE, UDP_SRC_ADDR_STATE, UDP_DST_ADDR_STATE, UDP_LENGTH_STATE, UDP_CHECKSUM_STATE, UDP_DATA_WR,UDP_VALIDATE, UDP_DATA_RD);
    
    signal state, next_state        	: STATE_TYPES;       
    signal num_bytes, num_bytes_c   	: integer := 0;
    signal checksum, checksum_c			: std_logic_vector(31 downto 0);
	 signal check_word, check_word_c 	: std_logic_vector(15 downto 0); 
	 signal sum, sum_c 						: std_logic_vector(31 downto 0);
	
	-- ETHERNET FRAME SIGNALS --
    signal eth_dst_addr, eth_dst_addr_c : std_logic_vector((ETH_SRC_ADDR_BYTES*8)-1 downto 0);
    signal eth_src_addr, eth_src_addr_c : std_logic_vector((ETH_DST_ADDR_BYTES*8)-1 downto 0);
    signal eth_protocol, eth_protocol_c : std_logic_vector((ETH_PROTOCOL_BYTES*8)-1 downto 0);        
    
	-- IP FRAME SIGNALS --
	 signal ip_ver, ip_ver_c              : std_logic_vector((IP_VERSION_BYTES*4)-1 downto 0);        
    signal ip_header, ip_header_c        : std_logic_vector((IP_HEADER_BYTES*4)-1 downto 0);        
    signal ip_id, ip_id_c                : std_logic_vector((IP_ID_BYTES*8)-1 downto 0);
    signal ip_type, ip_type_c            : std_logic_vector((IP_TYPE_BYTES*8)-1 downto 0);
    signal ip_length, ip_length_c        : std_logic_vector((IP_LENGTH_BYTES*8)-1 downto 0);
    signal ip_flag, ip_flag_c            : std_logic_vector((IP_FLAG_BYTES*8)-1 downto 0);
    signal ip_time, ip_time_c            : std_logic_vector((IP_TIME_BYTES*8)-1 downto 0);
    signal ip_protocol, ip_protocol_c    : std_logic_vector((IP_PROTOCOL_BYTES*8)-1 downto 0);
    signal ip_checksum, ip_checksum_c    : std_logic_vector((IP_CHECKSUM_BYTES*8)-1 downto 0);
    signal ip_dst_addr, ip_dst_addr_c    : std_logic_vector((IP_SRC_ADDR_BYTES*8)-1 downto 0);
    signal ip_src_addr, ip_src_addr_c    : std_logic_vector((IP_DST_ADDR_BYTES*8)-1 downto 0);
    
	-- UDP FRAME SIGNALS --
	 signal udp_bytes, udp_bytes_c   	 : integer;    
	 signal udp_dst_addr, udp_dst_addr_c  : std_logic_vector((udp_dst_addr_BYTES*8)-1 downto 0);
    signal udp_src_addr, udp_src_addr_c  : std_logic_vector((udp_src_addr_BYTES*8)-1 downto 0);
    signal udp_length, udp_length_c      : std_logic_vector((UDP_LENGTH_BYTES*8)-1 downto 0);
    signal udp_checksum, udp_checksum_c  : std_logic_vector((UDP_CHECKSUM_BYTES*8)-1 downto 0);

	-- FIFO WRITE SIGNALS -- 
    signal fifo_wr_din              : std_logic_vector(7 downto 0);
    signal fifo_wr_full             : std_logic;
    signal fifo_wr_en               :   std_logic;
    signal fifo_wr_sof              :   std_logic;
    signal fifo_wr_eof              :   std_logic;
	
	-- FIFO READ SIGNALS -- 
    signal fifo_rd_dout             :   std_logic_vector(7 downto 0);
    signal fifo_rd_empty            :   std_logic;
    signal fifo_rd_en               :   std_logic;
    signal fifo_rd_sof              :   std_logic;
    signal fifo_rd_eof              :   std_logic;
	
	-- FIFO RESET/CLEAR --
    signal fifo_reset               :   std_logic;
    signal fifo_clear               :   std_logic;
    signal fifo_clear_c             :   std_logic;       
    
begin

    udp_fifo : fifo_ctrl
    generic map
    (
        FIFO_DATA_WIDTH     => 8,
        FIFO_BUFFER_SIZE    => 2048
    )
    port map
    (
        reset       => fifo_reset,
        rd_clk      => clock,
        rd_en       => fifo_rd_en,
        rd_dout     => fifo_rd_dout,
        rd_sof      => fifo_rd_sof,
        rd_eof      => fifo_rd_eof,
        rd_empty    => fifo_rd_empty,
        wr_clk      => clock,
        wr_en       => fifo_wr_en,
        wr_din      => fifo_wr_din,
        wr_sof      => fifo_wr_sof,
        wr_eof      => fifo_wr_eof,
        wr_full     => fifo_wr_full        
    );
                   
    udp_read_process : process (state, num_bytes, num_bytes_c, checksum, sum, udp_bytes, eth_dst_addr, eth_src_addr, eth_protocol, ip_ver, ip_header, ip_type, ip_length, ip_id, ip_flag, ip_time, ip_protocol, ip_checksum, ip_dst_addr, ip_src_addr, udp_dst_addr, udp_src_addr, udp_length, udp_checksum, in_dout, in_sof, in_eof, in_empty, fifo_wr_full, fifo_rd_empty, fifo_rd_dout, fifo_rd_sof, fifo_rd_eof )  
                    
        variable eth_protocol_t           :   std_logic_vector((ETH_PROTOCOL_BYTES*8)-1 downto 0);        
        variable ip_ver_t                 :   std_logic_vector((IP_VERSION_BYTES*4)-1 downto 0);        
        variable ip_length_t              :   std_logic_vector((IP_LENGTH_BYTES*8)-1 downto 0);
        variable ip_time_t                :   std_logic_vector((IP_TIME_BYTES*8)-1 downto 0);
        variable ip_protocol_t            :   std_logic_vector((IP_PROTOCOL_BYTES*8)-1 downto 0);
        variable ip_dst_addr_t            :   std_logic_vector((IP_DST_ADDR_BYTES*8)-1 downto 0);
        variable ip_src_addr_t            :   std_logic_vector((IP_SRC_ADDR_BYTES*8)-1 downto 0);
        variable udp_dst_addr_t           :   std_logic_vector((UDP_DST_ADDR_BYTES*8)-1 downto 0);
        variable udp_src_addr_t           :   std_logic_vector((UDP_SRC_ADDR_BYTES*8)-1 downto 0);
        variable udp_length_t             :   std_logic_vector((UDP_LENGTH_BYTES*8)-1 downto 0);
        variable udp_checksum_t           :   std_logic_vector((UDP_CHECKSUM_BYTES*8)-1 downto 0);    
		  variable sum_t					  		:   std_logic_vector(31 downto 0) := (others => '0');
		
    begin

        next_state <= state;
        checksum_c <= checksum;
        num_bytes_c <= num_bytes;
		
		-- ETHERNET FRAME --
        eth_dst_addr_c <= eth_dst_addr;
        eth_src_addr_c <= eth_src_addr;
        eth_protocol_c <= eth_protocol;
        eth_protocol_t := (others => '0');
		
		-- IP FRAME --
        ip_ver_c <= ip_ver;
        ip_header_c <= ip_header;
        ip_type_c <= ip_type;
        ip_length_c <= ip_length;
        ip_id_c <= ip_id;
        ip_flag_c <= ip_flag;
        ip_time_c <= ip_time;
        ip_protocol_c <= ip_protocol;
        ip_checksum_c <= ip_checksum;
        ip_dst_addr_c <= ip_dst_addr;
        ip_src_addr_c <= ip_src_addr;
	     ip_ver_t := (others => '0');
        ip_length_t := (others => '0');
        ip_time_t := (others => '0');
        ip_protocol_t := (others => '0');
        ip_dst_addr_t := (others => '0');
        ip_src_addr_t := (others => '0');
		
		-- UDP FRAME -- 
        udp_bytes_c <= udp_bytes;
        udp_dst_addr_c <= udp_dst_addr;
        udp_src_addr_c <= udp_src_addr;
        udp_length_c <= udp_length;
        udp_checksum_c <= udp_checksum;   
		  udp_dst_addr_t := (others => '0');
        udp_src_addr_t := (others => '0');
        udp_length_t := (others => '0');
        udp_checksum_t := (others => '0');  

		-- FIFO -- 
        in_rd_en <= '0';      
        out_wr_en <= '0';
        out_din <= (others => '0');
        out_sof <= '0';
        out_eof <= '0';
        fifo_rd_en <= '0';
        fifo_wr_sof <= '0';
        fifo_wr_eof <= '0';
        fifo_wr_din <= (others => '0');
        fifo_wr_en <= '0';
        fifo_clear_c <= '0';       
                    
        case ( state ) is                                    
                
            when INIT =>
					 checksum_c <= (others => '0');
                num_bytes_c <= 0;
                udp_bytes_c <= 0;
                eth_dst_addr_c <= (others => '0');
                eth_src_addr_c <= (others => '0');
                eth_protocol_c <= (others => '0');
                ip_ver_c <= (others => '0');
                ip_header_c <= (others => '0');
                ip_type_c <= (others => '0');
                ip_length_c <= (others => '0');
                ip_id_c <= (others => '0');
                ip_flag_c <= (others => '0');
                ip_time_c <= (others => '0');
                ip_protocol_c <= (others => '0');
                ip_checksum_c <= (others => '0');
                ip_dst_addr_c <= (others => '0');
                ip_src_addr_c <= (others => '0');
                udp_dst_addr_c <= (others => '0');
                udp_src_addr_c <= (others => '0');
                udp_length_c <= (others => '0');
                udp_checksum_c <= (others => '0');
                next_state <= WAIT_FOR_SOF_STATE;
                
            when WAIT_FOR_SOF_STATE =>
                if ( (in_sof = '1') and (in_empty = '0') ) then
                    next_state <= ETH_DST_ADDR_STATE;
                elsif ( in_empty = '0' ) then
                    in_rd_en <= '1';
                end if;
                
            when ETH_DST_ADDR_STATE =>
					 eth_dst_addr_c <= eth_dst_addr;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    eth_dst_addr_c <= std_logic_vector((unsigned(eth_dst_addr) sll 8) or resize(unsigned(in_dout),ETH_DST_ADDR_BYTES*8));
                    num_bytes_c <= (num_bytes + 1) mod ETH_DST_ADDR_BYTES;                        
                    if ( num_bytes = ETH_DST_ADDR_BYTES-1 ) then
                        next_state <= ETH_SRC_ADDR_STATE;                        
                    end if;
                end if;

            when ETH_SRC_ADDR_STATE =>
					 eth_src_addr_c <= eth_src_addr;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    eth_src_addr_c <= std_logic_vector((unsigned(eth_src_addr) sll 8) or resize(unsigned(in_dout),ETH_SRC_ADDR_BYTES*8));
                    num_bytes_c <= (num_bytes + 1) mod ETH_SRC_ADDR_BYTES;                        
                    if ( num_bytes = ETH_SRC_ADDR_BYTES-1 ) then
                        next_state <= ETH_PROTOCOL_STATE;                        
                    end if;
                end if;
                
            when ETH_PROTOCOL_STATE =>
					 eth_protocol_c <= eth_protocol; 
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    eth_protocol_t := std_logic_vector((unsigned(eth_protocol) sll 8) or resize(unsigned(in_dout),ETH_PROTOCOL_BYTES*8));
                    eth_protocol_c <= eth_protocol_t;
                    num_bytes_c <= (num_bytes + 1) mod ETH_PROTOCOL_BYTES;                        
                    if ( num_bytes = ETH_PROTOCOL_BYTES-1 ) then
                        if ( eth_protocol_t = IP_PROTOCOL_DEF ) then
                            next_state <= IP_VERSION;
                        else
                            next_state <= INIT;
                        end if;
                    end if;
                end if;
                    
            when IP_VERSION =>
					 ip_ver_c <= ip_ver;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    ip_ver_t := in_dout(7 downto 4);
                    ip_ver_c <= ip_ver_t;
                    ip_header_c <= in_dout(3 downto 0);
					 num_bytes_c <= 0;
                    if ( ip_ver_t = IP_VERSION_DEF ) then
                        next_state <= IP_TYPE_STATE;
                    else
                        next_state <= INIT;
                    end if;
                end if;

            when IP_TYPE_STATE =>
					 ip_type_c <= ip_type;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    ip_type_c <= std_logic_vector((unsigned(ip_type) sll 8) or resize(unsigned(in_dout),IP_TYPE_BYTES*8));
                    num_bytes_c <= (num_bytes + 1) mod IP_TYPE_BYTES;                             
                    if ( num_bytes = IP_TYPE_BYTES-1 ) then
                        next_state <= IP_LENGTH_STATE;                        
                    end if;
                end if;
                          
            when IP_LENGTH_STATE =>
					 ip_length_c <= ip_length;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    ip_length_t := std_logic_vector((unsigned(ip_length) sll 8) or resize(unsigned(in_dout),IP_LENGTH_BYTES*8));
                    ip_length_c <= ip_length_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_LENGTH_BYTES;                        
                    if ( num_bytes = IP_LENGTH_BYTES-1 ) then
                        checksum_c <= std_logic_vector(unsigned(checksum) + resize(unsigned(ip_length_t),32) - to_unsigned(20,32));
                        next_state <= IP_ID_STATE;                        
                    end if;
                end if;
                                                          
            when IP_ID_STATE => 
					 ip_id_c <= ip_id;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    ip_id_c <= std_logic_vector((unsigned(ip_id) sll 8) or resize(unsigned(in_dout),IP_ID_BYTES*8));
                    num_bytes_c <= (num_bytes + 1) mod IP_ID_BYTES;                        
                    if ( num_bytes = IP_ID_BYTES-1 ) then
                        next_state <= IP_FLAG_STATE; 
                    end if;
                end if;
                                
            when IP_FLAG_STATE =>
					 ip_flag_c <= ip_flag;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    ip_flag_c <= std_logic_vector((unsigned(ip_flag) sll 8) or resize(unsigned(in_dout),IP_FLAG_BYTES*8));
                    num_bytes_c <= (num_bytes + 1) mod IP_FLAG_BYTES;                        
                    if ( num_bytes = IP_FLAG_BYTES-1 ) then
                        next_state <= IP_TIME_STATE;                        
                    end if;
                end if;
                                
            when IP_TIME_STATE =>
					 ip_time_c <= ip_time; 
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    ip_time_t := std_logic_vector((unsigned(ip_time) sll 8) or resize(unsigned(in_dout),IP_TIME_BYTES*8));
                    ip_time_c <= ip_time_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_TIME_BYTES;                        
                    if ( num_bytes = IP_TIME_BYTES-1 ) then
                        if ( ip_time_t = std_logic_vector(to_unsigned(0,IP_TIME_BYTES*8)) ) then
                            next_state <= INIT;
                        else
                            next_state <= IP_PROTOCOL_STATE;
                        end if;
                    end if;                
                end if;
            
            when IP_PROTOCOL_STATE => 
					 ip_protocol_c <= ip_protocol; 
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    ip_protocol_t := std_logic_vector((unsigned(ip_protocol) sll 8) or resize(unsigned(in_dout),IP_PROTOCOL_BYTES*8));
                    ip_protocol_c <= ip_protocol_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_PROTOCOL_BYTES;                        
                    if ( num_bytes = IP_PROTOCOL_BYTES-1 ) then
                        checksum_c <= std_logic_vector(unsigned(checksum) + resize(unsigned(ip_protocol_t),32));
                        if ( ip_protocol_t = UDP_PROTOCOL_DEF ) then                                
                            next_state <= IP_CHECKSUM_STATE;                        
                        else
                            next_state <= INIT;
                        end if;                            
                    end if;
                end if;

            when IP_CHECKSUM_STATE => 
					 ip_checksum_c <= ip_checksum; 
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    ip_checksum_c <= std_logic_vector((unsigned(ip_checksum) sll 8) or resize(unsigned(in_dout),IP_CHECKSUM_BYTES*8));
                    num_bytes_c <= (num_bytes + 1) mod IP_CHECKSUM_BYTES;                        
                    if ( num_bytes = IP_CHECKSUM_BYTES-1 ) then
                        next_state <= IP_SRC_ADDR_STATE;                        
                    end if;
                end if;

            when IP_SRC_ADDR_STATE => 
					 ip_src_addr_c <= ip_src_addr;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    ip_src_addr_t := std_logic_vector((unsigned(ip_src_addr) sll 8) or resize(unsigned(in_dout),IP_SRC_ADDR_BYTES*8));
                    ip_src_addr_c <= ip_src_addr_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_SRC_ADDR_BYTES;                        
                    if ( num_bytes = IP_SRC_ADDR_BYTES-1 ) then
                        checksum_c <= std_logic_vector(unsigned(checksum) + resize(unsigned(ip_src_addr_t(31 downto 16)),32) + resize(unsigned(ip_src_addr_t(15 downto 0)),32));
                        next_state <= IP_DST_ADDR_STATE;
                    end if;
                end if;

            when IP_DST_ADDR_STATE => 
					 ip_dst_addr_c <= ip_dst_addr;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    ip_dst_addr_t := std_logic_vector((unsigned(ip_dst_addr) sll 8) or resize(unsigned(in_dout),IP_DST_ADDR_BYTES*8));
                    ip_dst_addr_c <= ip_dst_addr_t;
                    num_bytes_c <= (num_bytes + 1) mod IP_DST_ADDR_BYTES;                        
                    if ( num_bytes = IP_DST_ADDR_BYTES-1 ) then
                        checksum_c <= std_logic_vector(unsigned(checksum) + resize(unsigned(ip_dst_addr_t(31 downto 16)),32) + resize(unsigned(ip_dst_addr_t(15 downto 0)),32));
                        if ( unsigned(ip_header) > to_unsigned(5,4) ) then                            
                            next_state <= IP_OPTIONS;
                        else
                            next_state <= UDP_DST_ADDR_STATE;
                        end if;
                    end if;
                end if;
           
            when IP_OPTIONS =>
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    num_bytes_c <= (num_bytes + 1);                        
                    if ( num_bytes = (to_integer(unsigned(ip_header)) - 6) ) then
                        num_bytes_c <= 0;
                        next_state <= UDP_DST_ADDR_STATE;
                    end if;
                end if;
				
            when UDP_DST_ADDR_STATE =>
					 udp_dst_addr_c <= udp_dst_addr;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    udp_dst_addr_t := std_logic_vector((unsigned(udp_dst_addr) sll 8) or resize(unsigned(in_dout),UDP_DST_ADDR_BYTES*8));
                    udp_dst_addr_c <= udp_dst_addr_t;
                    num_bytes_c <= (num_bytes + 1) mod UDP_DST_ADDR_BYTES;                      
                    if ( num_bytes = UDP_DST_ADDR_BYTES-1 ) then
                        checksum_c <= std_logic_vector(unsigned(checksum) + resize(unsigned(udp_dst_addr_t),32));
						next_state <= UDP_SRC_ADDR_STATE;
						  end if;
                end if;

            when UDP_SRC_ADDR_STATE =>
					 udp_src_addr_c <= udp_src_addr;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    udp_src_addr_t := std_logic_vector((unsigned(udp_src_addr) sll 8) or resize(unsigned(in_dout),UDP_SRC_ADDR_BYTES*8));
                    udp_src_addr_c <= udp_src_addr_t;
                    num_bytes_c <= (num_bytes + 1) mod UDP_SRC_ADDR_BYTES;                       
                    if ( num_bytes = UDP_SRC_ADDR_BYTES-1 ) then
                        checksum_c <= std_logic_vector(unsigned(checksum) + resize(unsigned(udp_src_addr_t),32));
								next_state <= UDP_LENGTH_STATE;
                    end if;
                end if;

            when UDP_LENGTH_STATE =>
					 udp_length_c <= udp_length;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    udp_length_t := std_logic_vector((unsigned(udp_length) sll 8) or resize(unsigned(in_dout),UDP_LENGTH_BYTES*8));
                    udp_length_c <= udp_length_t;
                    num_bytes_c <= (num_bytes + 1) mod UDP_LENGTH_BYTES;                        
                    if ( num_bytes = UDP_LENGTH_BYTES-1 ) then
                        checksum_c <= std_logic_vector(unsigned(checksum) + resize(unsigned(udp_length_t),32));
                        next_state <= UDP_CHECKSUM_STATE;                   
                    end if;
                end if;

            when UDP_CHECKSUM_STATE =>
					 udp_checksum_c <= udp_checksum;
                if ( in_empty = '0' ) then
                    in_rd_en <= '1';
                    udp_checksum_t := std_logic_vector((unsigned(udp_checksum) sll 8) or resize(unsigned(in_dout),UDP_CHECKSUM_BYTES*8));
                    udp_checksum_c <= udp_checksum_t;
                    num_bytes_c <= (num_bytes + 1) mod UDP_CHECKSUM_BYTES;                        
                    if ( num_bytes = UDP_CHECKSUM_BYTES-1 ) then
                        udp_bytes_c <= to_integer(resize(unsigned(udp_length),32)) - UDP_CHECKSUM_BYTES - UDP_LENGTH_BYTES - UDP_DST_ADDR_BYTES - UDP_SRC_ADDR_BYTES;
                        next_state <= UDP_DATA_WR;                       
                    end if;
                end if;

            when UDP_DATA_WR =>
                if ( in_empty = '0' AND fifo_wr_full = '0' ) then
                    in_rd_en <= '1';
                    fifo_wr_en <= '1';
                    fifo_wr_din <= in_dout;
						  if ( num_bytes = 0 ) then
								fifo_wr_sof <= '1';
						  else
								fifo_wr_sof <= '0'; 
						  end if;
						  if ( (in_eof = '1') or (num_bytes = udp_bytes-1) ) then
								fifo_wr_eof <= '1';
						  else
								fifo_wr_eof <= '0'; 
						  end if;
                    num_bytes_c <= (num_bytes + 1);
                    if ( (num_bytes mod 2) = 1 ) then
                        checksum_c <= std_logic_vector(unsigned(checksum) + resize(unsigned(in_dout),32));
                    else 
                        checksum_c <= std_logic_vector(unsigned(checksum) + resize((unsigned(in_dout) & X"00"),32));
                    end if;
                    if ( (in_eof = '1') or (num_bytes = udp_bytes-1) ) then  
                        next_state <= UDP_VALIDATE;
                    end if;
                 end if;

            when UDP_VALIDATE =>
                if ( checksum(31 downto 16) /= X"0000" ) then
                    checksum_c <= std_logic_vector(unsigned(X"0000" & checksum(31 downto 16)) + unsigned(X"0000" & checksum(15 downto 0)));
                elsif ( udp_checksum = (not checksum(15 downto 0)) ) then
                    next_state <= UDP_DATA_RD;
                else 
                    fifo_clear_c <= '1';
                    next_state <= INIT;
                end if;  

            when UDP_DATA_RD =>
                if ( fifo_rd_empty = '1' ) then
                    next_state <= INIT;
                elsif ( out_full = '0' ) then
                    fifo_rd_en <= '1';
                    out_wr_en <= '1';
                    out_din <= fifo_rd_dout;
                    out_sof <= fifo_rd_sof;
                    out_eof <= fifo_rd_eof;
                end if;

            when OTHERS => 
                fifo_wr_din <= (others => 'X');
                fifo_wr_en <= 'X';
                fifo_clear_c <= 'X';
                udp_bytes_c <= 0;
                eth_dst_addr_c <= (others => 'X');
                eth_src_addr_c <= (others => 'X');
                eth_protocol_c <= (others => 'X');
                ip_ver_c <= (others => 'X');
                ip_header_c <= (others => 'X');
                ip_type_c <= (others => 'X');
                ip_length_c <= (others => 'X');
                ip_id_c <= (others => 'X');
                ip_flag_c <= (others => 'X');
                ip_time_c <= (others => 'X');
                ip_protocol_c <= (others => 'X');
                ip_checksum_c <= (others => 'X');
                ip_dst_addr_c <= (others => 'X');
                ip_src_addr_c <= (others => 'X');
                udp_dst_addr_c <= (others => 'X');
                udp_src_addr_c <= (others => 'X');
                udp_length_c <= (others => 'X');
                udp_checksum_c <= (others => 'X');
                checksum_c <= (others => 'X');
                eth_protocol_t := (others => 'X');
                ip_ver_t := (others => 'X');
                ip_length_t := (others => 'X');
                ip_time_t := (others => 'X');
                ip_protocol_t := (others => 'X');
                ip_dst_addr_t := (others => 'X');
                ip_src_addr_t := (others => 'X');
                udp_dst_addr_t := (others => 'X');
                udp_src_addr_t := (others => 'X');
                udp_length_t := (others => 'X');
                udp_checksum_t := (others => 'X');
                in_rd_en <= 'X';          
                num_bytes_c <= 0;            
                next_state <= INIT;
            
        end case;
                            
    end process udp_read_process;

    clock_process : process (clock, reset)
    begin
        if ( reset = '1' ) then
            state 		 <= INIT;
            udp_bytes 	 <= 0;
            fifo_clear 	 <= '0';
            checksum 	 <= (others => '0');
            eth_dst_addr <= (others => '0');
            eth_src_addr <= (others => '0');
            eth_protocol <= (others => '0');
            ip_ver 		 <= (others => '0');
            ip_header    <= (others => '0');
            ip_type 	 <= (others => '0');
            ip_length 	 <= (others => '0');
            ip_id 		 <= (others => '0');
            ip_flag 	 <= (others => '0');
            ip_time 	 <= (others => '0');
            ip_protocol  <= (others => '0');
            ip_checksum  <= (others => '0');
            ip_dst_addr  <= (others => '0');
            ip_src_addr  <= (others => '0');
            udp_dst_addr <= (others => '0');
            udp_src_addr <= (others => '0');
            udp_length   <= (others => '0');
            udp_checksum <= (others => '0');  
            num_bytes    <= 0;
        elsif ( rising_edge(clock) ) then
            state 		 <= next_state;
            udp_bytes 	 <= udp_bytes_c;
            fifo_clear 	 <= fifo_clear_c;            
            checksum 	 <= checksum_c;
            eth_dst_addr <= eth_dst_addr_c;
            eth_src_addr <= eth_src_addr_c;
            eth_protocol <= eth_protocol_c;
            ip_ver 	     <= ip_ver_c;
            ip_header 	 <= ip_header_c;
            ip_type 	 <= ip_type_c;
            ip_length 	 <= ip_length_c;
            ip_id 		 <= ip_id_c;
            ip_flag 	 <= ip_flag_c;
            ip_time 	 <= ip_time_c;
            ip_protocol  <= ip_protocol_c;
            ip_checksum  <= ip_checksum_c;
            ip_dst_addr  <= ip_dst_addr_c;
            ip_src_addr  <= ip_src_addr_c;
            udp_dst_addr <= udp_dst_addr_c;
            udp_src_addr <= udp_src_addr_c;
            udp_length 	 <= udp_length_c;
            udp_checksum <= udp_checksum_c;   
            num_bytes 	 <= num_bytes_c;  
        end if;
    end process clock_process;
	 
	 fifo_reset <= reset or fifo_clear;
    
end architecture behavioral;
