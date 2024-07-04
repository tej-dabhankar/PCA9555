-- Copyright (c) 2006 Frank Buss (fb@frank-buss.de)
-- See license.txt for license
--
-- Test-bench for the I2C slave, with I2C testdevice

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity slave_testbench is
end entity slave_testbench;

architecture test of slave_testbench is

	signal clock_50mhz: std_logic := '0';
	signal reset: std_logic := '0';
	signal scl: std_logic;
	signal sda: std_logic;
	signal port0: unsigned(7 downto 0);
	signal port1: unsigned(7 downto 0);
	signal test1: std_logic;
	signal test2: std_logic;

	constant t4: time := 625 ns;
	constant t2: time := 2*t4;
	constant t: time := 4*t4;
	constant address: unsigned(6 downto 0) := b"1101101";
	constant port0test: unsigned(7 downto 0) := x"01";
	constant port1test: unsigned(7 downto 0) := x"12";

begin
	
	pca9555_inst: entity work.pca9555
		generic map(
			clock_frequency => 50e6,
			address => b"1101101")
		port map(
			clock => clock_50mhz,
			reset => reset,
			scl => scl,
			sda => sda,
			port0 => port0,
			port1 => port1);

	test_loop: process

	procedure write_byte(byte: unsigned(7 downto 0)) is
		variable tmp: unsigned(7 downto 0);
	begin
		tmp := byte;
		for j in 1 to 8 loop
			scl <= '0';
			wait for 10 ns;
			sda <= 'Z';
			if tmp(7) = '0' then
				sda <= '0';
			end if;
			wait for t2;
			scl <= '1';
			wait for t2;
			tmp := shift_left(tmp, 1);
		end loop;
	end;
	
	procedure test_acknowledge is
	begin
		scl <= '0';
		wait for 10 ns;
		sda <= 'Z';
		wait for t2;
		scl <= '1';
		wait for t2;
		assert sda = '0' report "no acknowledge received" severity failure;
		scl <= '0';
		sda <= '0';
		wait for t2;
	end;

	procedure read_test(b: std_logic) is
		variable tmp: unsigned(15 downto 0);
	begin
		port0(0) <= b;
		
		-- start bit
		sda <= '0';
		wait for t4;
		
		-- write address with read flag = 0
		write_byte(address & b"0");
		test_acknowledge;

		-- write input port command
		write_byte(x"00");
		test_acknowledge;
		
		-- repeated start bit
		sda <= 'Z';
		wait for t4;
		scl <= '1';
		wait for t4;
		sda <= '0';
		wait for t4;
		scl <= '0';
		sda <= 'Z';
		
		-- write address with read flag = 1
		write_byte(address & b"1");
		test_acknowledge;

		-- read byte from I2C
		tmp := x"0000";
		sda <= 'Z';
		for j in 1 to 8 loop
			scl <= '0';
			wait for 10 ns;
			wait for t2;
			scl <= '1';
			wait for t2;
			tmp := shift_left(tmp, 1);
			if sda /= '0' then
				tmp(0) := '1';
			end if;
		end loop;
		
		-- send acknowledge
		scl <= '0';
		wait for t2;
		sda <= '0';
		wait for t2;
		scl <= '1';
		wait for t2;
		
		-- read next byte from I2C
		tmp := x"0000";
		sda <= 'Z';
		for j in 1 to 8 loop
			scl <= '0';
			wait for 10 ns;
			wait for t2;
			scl <= '1';
			wait for t2;
			tmp := shift_left(tmp, 1);
			if sda /= '0' then
				tmp(0) := '1';
			end if;
		end loop;
		
		-- test expected result
		assert tmp = port0test(7 downto 1) & b & port1test report "read test failed" severity failure; 

		-- send stop bit
		scl <= '0';
		wait for t4;
		sda <= '0';
		scl <= '1';
		wait for t4;
		sda <= 'Z';

		-- wait a bit
		wait for t;

	end;
	
	begin
		-- init bus
		scl <= '1';
		sda <= 'Z';
		
		-- wait for sample buffer filling
		wait for 2 us;


		-- set configuration registers: port0, bit 0 = input; rest = output
		
		-- start bit
		sda <= '0';
		wait for t4;
		
		-- write address with read flag = 0
		write_byte(address & b"0");
		test_acknowledge;

		-- write configuration port command
		write_byte(x"06");
		test_acknowledge;
		
		-- write data for configuration port 0
		write_byte(x"01");
		test_acknowledge;
		
		-- write data for configuration port 1
		write_byte(x"00");
		test_acknowledge;
		
		-- send stop bit
		sda <= '0';
		scl <= '1';
		wait for t4;
		sda <= 'Z';
		
		-- wait a bit
		wait for t;


		-- send new data for port0 and port1

		-- start bit
		sda <= '0';
		wait for t4;

		-- write address with read flag = 0
		write_byte(address & b"0");
		test_acknowledge;

		-- write output port command
		write_byte(x"02");
		test_acknowledge;
		
		-- write data for port 0
		write_byte(port0test);
		test_acknowledge;
		
		-- write data for port 1
		write_byte(port1test);
		test_acknowledge;
		
		-- send stop bit
		sda <= '0';
		scl <= '1';
		wait for t4;
		sda <= 'Z';
		
		-- wait a bit
		wait for t;

		-- assert port states
		assert port0(7 downto 1) = port0test(7 downto 1) report "port0 write error" severity failure; 
		assert port0(0) = 'Z';
		assert port1 = port1test report "port1 write error" severity failure; 


		-- test input port
		read_test('0');
		read_test('1');
		

		-- stop simulation
		assert false report "No failure, simulation was successful." severity failure; 

	end process;
	
	update_clock: process
	begin
		while true loop 
			clock_50mhz <= not clock_50mhz;
			wait for 10 ns;
		end loop;
	end process;

end architecture test;
