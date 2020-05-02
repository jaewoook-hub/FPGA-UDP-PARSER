library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use work.constants.all;

entity udp_parser_top_tb is
generic
(
    constant FILE_IN_NAME  : string (10 downto 1) := "input.pcap";
    constant FILE_OUT_NAME : string (10 downto 1) := "output.txt";
    constant FILE_CMP_NAME : string (11 downto 1) := "compare.txt";
    constant CLOCK_PERIOD : time := 10 ns
);
end entity udp_parser_top_tb;

architecture behavior of udp_parser_top_tb is 
        
	type raw_file is file of character;
	signal clock            : std_logic := '1';
	signal reset            : std_logic := '0';
	signal in_full          : std_logic := '0';
	signal in_sof           : std_logic := '0';
	signal in_eof           : std_logic := '0';
	signal in_wr_en         : std_logic := '0';
	signal in_din           : std_logic_vector (7 downto 0) := (others => '0');   
	signal out_rd_en        : std_logic := '0';
	signal out_sof          : std_logic := '0';
	signal out_eof          : std_logic := '0';
	signal out_empty        : std_logic := '0';
	signal out_dout         : std_logic_vector (7 downto 0) := (others => '0');
	signal hold_clock       : std_logic := '0';
	signal in_write_done    : std_logic := '0';
	signal out_read_done    : std_logic := '0';
	signal out_errors       : integer   := 0;

begin

    udp_parser_top_inst : component udp_parser_top
    port map
    (
		clock  		=> clock,
		reset      	=> reset,
		in_din    	=> in_din,
		in_sof     	=> in_sof,
		in_eof     	=> in_eof,
		in_wr_en    => in_wr_en,
		in_full     => in_full,
		out_dout    => out_dout,
		out_sof     => out_sof,
		out_eof     => out_eof,
		out_rd_en   => out_rd_en,	
		out_empty   => out_empty       
    );

    clock_process : process
    begin
        clock <= '1';
        wait for  (CLOCK_PERIOD / 2);
        clock <= '0';
        wait for  (CLOCK_PERIOD / 2);
        if ( hold_clock = '1' ) then
            wait;
        end if;
    end process clock_process;

    reset_process : process
    begin
        reset <= '0';
        wait until  (clock = '0');
        wait until  (clock = '1');
        reset <= '1';
        wait until  (clock = '0');
        wait until  (clock = '1');
        reset <= '0';
        wait;
    end process reset_process;

    tb_process : process
        variable errors : integer := 0;
        variable warnings : integer := 0;
        variable start_time : time;
        variable end_time : time;
        variable ln1, ln2, ln3, ln4 : line;
    begin
        wait until  (reset = '1');
        wait until  (reset = '0');
        wait until  (clock = '0');
        wait until  (clock = '1');
        start_time := NOW;
        write( ln1, string'("@ ") );
        write( ln1, start_time );
        write( ln1, string'(": Beginning simulation...") );
        writeline( output, ln1 );
        wait until  (clock = '0');
        wait until  (clock = '1');
        wait until  (out_read_done = '1');
        end_time := NOW;
        write( ln2, string'("@ ") );
        write( ln2, end_time );
        write( ln2, string'(": Simulation completed.") );
        writeline( output, ln2 );
        errors := out_errors;
        write( ln3, string'("Total simulation cycle count: ") );
        write( ln3, (end_time - start_time) / CLOCK_PERIOD );
        writeline( output, ln3 );
        write( ln4, string'("Total error count: ") );
        write( ln4, errors );
        writeline( output, ln4 );
        hold_clock <= '1';
        wait;
    end process tb_process;

    file_read_process : process 
        file in_file : raw_file;
        variable char : character;
        variable ln1 : line;
        variable i : integer := 0;
        variable n_bytes : std_logic_vector(31 downto 0) := (others => '0');
    begin
        wait until  (reset = '1');
        wait until  (reset = '0');
        write( ln1, string'("@ ") );
        write( ln1, NOW );
        write( ln1, string'(": Loading file ") );
        write( ln1, FILE_IN_NAME );
        write( ln1, string'("...") );
        writeline( output, ln1 );
        file_open( in_file, FILE_IN_NAME, read_mode );
		  in_wr_en <= '0';
        in_sof <= '0';
        in_eof <= '0';
        in_din <= (others => '0');		
		  
		while ( not ENDFILE( in_file) and i < 24 ) loop
            read( in_file, char );
            i := i + 1;
        end loop;
        
		while ( not ENDFILE( in_file) ) loop
            i := 0;
            while ( not ENDFILE( in_file) and i < 16 ) loop
                read( in_file, char );                
                if ( i >= 8 AND i < 12 ) then
                    n_bytes := std_logic_vector(to_unsigned(character'pos(char),8)) & n_bytes(31 downto 8);
                end if;
                i := i + 1;
            end loop;
            i := 0;
            while ( not ENDFILE( in_file) and i < to_integer(unsigned(n_bytes)) ) loop
                wait until (clock = '1');
                wait until (clock = '0');
                if ( in_full = '0' ) then
                    read( in_file, char );
                    in_din <= std_logic_vector(to_unsigned(character'pos(char),8));
						  
						  if ( i = 0 ) then 
								in_sof <= '1'; 
						  else
								in_sof <= '0'; 
						  end if; 
						  
						  if (i = to_integer(unsigned(n_bytes))-1) then
								in_eof <= '1'; 
						  else
								in_eof <= '0';
						  end if; 
						  
                    in_wr_en <= '1';
                    i := i + 1;
                else
                    in_wr_en <= '0';
                end if;
            end loop;	
        end loop;

	wait until (clock = '1');
	wait until (clock = '0');
	in_wr_en <= '0';
	in_sof <= '0';
	in_eof <= '0';
	in_din <= (others => '0');		
	file_close( in_file );
	in_write_done <= '1';
	wait;
	end process file_read_process;
  
    file_write_process : process 
        file cmp_file : raw_file;
        file out_file : raw_file;
        variable char : character;
        variable ln1, ln2, ln3 : line;
        variable i : integer := 0;
        variable out_data_read : std_logic_vector (7 downto 0);
        variable out_data_cmp : std_logic_vector (7 downto 0);
    begin
        wait until  (reset = '1');
        wait until  (reset = '0');
        wait until  (clock = '1');
        wait until  (clock = '0');
        write( ln1, string'("@ ") );
        write( ln1, NOW );
        write( ln1, string'(": Comparing file ") );
        write( ln1, FILE_OUT_NAME );
        write( ln1, string'("...") );
        writeline( output, ln1 );
        file_open( out_file, FILE_OUT_NAME, write_mode);
        file_open( cmp_file, FILE_CMP_NAME, read_mode );
		  out_rd_en <= '0';
        i := 0;
		  
		while ( not ENDFILE(cmp_file) ) loop
			wait until ( clock = '1');
			wait until ( clock = '0');
			if ( out_empty = '0' ) then
				out_rd_en <= '1';
				read( cmp_file, char );
				out_data_cmp := std_logic_vector(to_unsigned(character'pos(char),8));
            write(out_file, character'val(to_integer(unsigned(out_dout))));                
				if ( to_01(unsigned(out_dout)) /= to_01(unsigned(out_data_cmp)) ) then
					out_errors <= out_errors + 1;
					write( ln2, string'("@ ") );
					write( ln2, NOW );
					write( ln2, string'(": ") );
					write( ln2, FILE_OUT_NAME );
					write( ln2, string'("(") );
					write( ln2, i + 1 );
					write( ln2, string'("): ERROR: ") );
					hwrite( ln2, out_dout );
					write( ln2, string'(" != ") );
					hwrite( ln2, out_data_cmp );
					write( ln2, string'(" at address 0x") );
					hwrite( ln2, std_logic_vector(to_unsigned(i,32)) );
					write( ln2, string'(".") );
					writeline( output, ln2 );
               exit;
				end if;
            i := i + 1;
			else
				out_rd_en <= '0';
			end if;
     end loop;

		wait until (clock = '1');
		wait until (clock = '0');
		out_rd_en <= '0';
		file_close( cmp_file );
		file_close( out_file );
		out_read_done <= '1';
		wait;
		end process file_write_process;

end architecture behavior;
