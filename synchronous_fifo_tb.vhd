library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Testbench entity (empty)
entity synchronous_fifo_tb is
end entity synchronous_fifo_tb;

-- Behavioral architecture for the testbench
architecture behavioral of synchronous_fifo_tb is

    -- 1. Component Declaration for the DUT (Device Under Test)
    component synchronous_fifo is
        Generic (
            DATA_WIDTH      : POSITIVE := 8;
            FIFO_DEPTH_BITS : POSITIVE := 3
        );
        Port (
            clk      : in  STD_LOGIC;
            rst      : in  STD_LOGIC;
            wr_en    : in  STD_LOGIC;
            rd_en    : in  STD_LOGIC;
            data_in  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            data_out : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
            full     : out STD_LOGIC;
            empty    : out STD_LOGIC
        );
    end component synchronous_fifo;

    -- 3. Constants
    constant TB_DATA_WIDTH      : POSITIVE := 8;
    constant TB_FIFO_DEPTH_BITS : POSITIVE := 3;
    constant TB_FIFO_DEPTH      : POSITIVE := 2**TB_FIFO_DEPTH_BITS;
    constant CLK_PERIOD         : TIME     := 10 ns;

    -- 2. Signal Declarations
    -- Clock and Reset
    signal tb_clk      : STD_LOGIC := '0';
    signal tb_rst      : STD_LOGIC := '0';

    -- Write Port
    signal tb_wr_en    : STD_LOGIC := '0';
    signal tb_data_in  : STD_LOGIC_VECTOR(TB_DATA_WIDTH-1 downto 0) := (others => '0');

    -- Read Port
    signal tb_rd_en    : STD_LOGIC := '0';
    signal tb_data_out : STD_LOGIC_VECTOR(TB_DATA_WIDTH-1 downto 0);

    -- Status Flags
    signal tb_full     : STD_LOGIC;
    signal tb_empty    : STD_LOGIC;

begin

    -- 4. DUT Instantiation
    UUT: component synchronous_fifo
        Generic map (
            DATA_WIDTH      => TB_DATA_WIDTH,
            FIFO_DEPTH_BITS => TB_FIFO_DEPTH_BITS
        )
        Port map (
            clk      => tb_clk,
            rst      => tb_rst,
            wr_en    => tb_wr_en,
            data_in  => tb_data_in,
            rd_en    => tb_rd_en,
            data_out => tb_data_out,
            full     => tb_full,
            empty    => tb_empty
        );

    -- 5. Clock Generation Process
    clk_gen_proc : process
    begin
        tb_clk <= '0';
        wait for CLK_PERIOD / 2;
        tb_clk <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_gen_proc;

    -- 6. Stimulus Process
    stim_proc : process
    begin
        report "Starting Testbench...";

        -- Initial reset
        tb_rst <= '1';
        tb_wr_en <= '0';
        tb_rd_en <= '0';
        tb_data_in <= (others => '0');
        wait for CLK_PERIOD * 2;
        tb_rst <= '0';
        wait for CLK_PERIOD;

        report "Testbench: Initial Reset complete.";

        -- Variables for data generation and checking
        variable data_val          : integer := 0;
        variable expected_rd_value : integer := 0;
        variable temp_data         : std_logic_vector(TB_DATA_WIDTH-1 downto 0);

        -- 1. Initial State Check
        report "Testbench: 1. Initial State Check";
        assert tb_empty = '1' report "TS1: FIFO should be empty after reset. tb_empty=" & to_string(tb_empty) severity error;
        assert tb_full = '0'  report "TS1: FIFO should not be full after reset. tb_full=" & to_string(tb_full) severity error;
        wait for CLK_PERIOD;

        -- 2. Write to Fill
        report "Testbench: 2. Write to Fill";
        data_val := 0; -- Reset data generator
        expected_rd_value := 0; -- Expected data to be read will start from 0
        for i in 0 to TB_FIFO_DEPTH - 1 loop
            tb_wr_en <= '1';
            tb_rd_en <= '0';
            tb_data_in <= std_logic_vector(to_unsigned(data_val, TB_DATA_WIDTH));
            report "TS2: Writing " & integer'image(data_val) & " (" & to_hstring(tb_data_in) & ")";
            data_val := data_val + 1;
            wait for CLK_PERIOD;
        end loop;
        tb_wr_en <= '0'; -- Stop writing

        wait for CLK_PERIOD; -- Allow signals to propagate
        assert tb_full = '1'  report "TS2: FIFO should be full. tb_full=" & to_string(tb_full) severity error;
        assert tb_empty = '0' report "TS2: FIFO should not be empty. tb_empty=" & to_string(tb_empty) severity error;
        
        report "Testbench: TS2. Attempting one more write to a full FIFO.";
        tb_data_in <= std_logic_vector(to_unsigned(data_val, TB_DATA_WIDTH)); -- Attempt to write 'data_val' (which is TB_FIFO_DEPTH)
        tb_wr_en <= '1';
        wait for CLK_PERIOD;
        tb_wr_en <= '0';
        assert tb_full = '1' report "TS2: FIFO should still be full after attempted overwrite. tb_full=" & to_string(tb_full) severity error;
        -- Add a read here to check if the last value was overwritten or not?
        -- For now, we assume the FIFO design prevents overwrite correctly if full is asserted.
        wait for CLK_PERIOD;

        -- 3. Read to Empty
        report "Testbench: 3. Read to Empty";
        for i in 0 to TB_FIFO_DEPTH - 1 loop
            tb_rd_en <= '1';
            tb_wr_en <= '0';
            wait for CLK_PERIOD; -- Data is available on tb_data_out after this clock edge
            temp_data := std_logic_vector(to_unsigned(expected_rd_value, TB_DATA_WIDTH));
            assert tb_data_out = temp_data report "TS3: Data mismatch. Expected " & to_hstring(temp_data) & " (" & integer'image(expected_rd_value) & "), Got " & to_hstring(tb_data_out) severity error;
            report "TS3: Reading " & integer'image(expected_rd_value) & " (" & to_hstring(tb_data_out) & ")";
            expected_rd_value := expected_rd_value + 1;
        end loop;
        tb_rd_en <= '0'; -- Stop reading

        wait for CLK_PERIOD; -- Allow signals to propagate
        assert tb_empty = '1' report "TS3: FIFO should be empty. tb_empty=" & to_string(tb_empty) severity error;
        assert tb_full = '0'  report "TS3: FIFO should not be full. tb_full=" & to_string(tb_full) severity error;

        report "Testbench: TS3. Attempting one more read from an empty FIFO.";
        tb_rd_en <= '1';
        wait for CLK_PERIOD;
        tb_rd_en <= '0';
        assert tb_empty = '1' report "TS3: FIFO should still be empty after attempted overread. tb_empty=" & to_string(tb_empty) severity error;
        -- The value of tb_data_out is not specified to change on an empty read, typically holds last value or 'X'
        wait for CLK_PERIOD;

        -- 4. Alternating Read/Write
        report "Testbench: 4. Alternating Read/Write";
        data_val := 100; -- Start with a new data sequence
        expected_rd_value := 100;

        -- Write 3 items
        report "TS4: Writing 3 items.";
        for i in 0 to 2 loop
            tb_wr_en <= '1';
            tb_data_in <= std_logic_vector(to_unsigned(data_val, TB_DATA_WIDTH));
            report "TS4: Writing " & integer'image(data_val);
            data_val := data_val + 1;
            wait for CLK_PERIOD;
        end loop;
        tb_wr_en <= '0';

        -- Read 2 items
        report "TS4: Reading 2 items.";
        for i in 0 to 1 loop
            tb_rd_en <= '1';
            wait for CLK_PERIOD;
            temp_data := std_logic_vector(to_unsigned(expected_rd_value, TB_DATA_WIDTH));
            assert tb_data_out = temp_data report "TS4: Data mismatch (Read 1). Expected " & to_hstring(temp_data) & ", Got " & to_hstring(tb_data_out) severity error;
            report "TS4: Reading " & integer'image(expected_rd_value);
            expected_rd_value := expected_rd_value + 1;
        end loop;
        tb_rd_en <= '0';
        
        -- Write TB_FIFO_DEPTH - 1 items (FIFO capacity is TB_FIFO_DEPTH, 1 item is in there, so TB_FIFO_DEPTH-1 will fill it)
        report "TS4: Writing " & integer'image(TB_FIFO_DEPTH -1) & " more items to fill.";
        for i in 0 to TB_FIFO_DEPTH - 2 loop -- -2 because one item is already in, and loop is 0 to N-1
            tb_wr_en <= '1';
            tb_data_in <= std_logic_vector(to_unsigned(data_val, TB_DATA_WIDTH));
            report "TS4: Writing " & integer'image(data_val);
            data_val := data_val + 1;
            wait for CLK_PERIOD;
            if tb_full = '1' then 
                 report "TS4: FIFO reported full during fill sequence, item " & integer'image(i) & " data " & integer'image(data_val-1);
            end if;
        end loop;
        tb_wr_en <= '0';
        wait for CLK_PERIOD;
        assert tb_full = '1' report "TS4: FIFO should be full after writing " & integer'image(TB_FIFO_DEPTH-1) & " more items. tb_full=" & to_string(tb_full) severity note; -- Note, as some writes might be to already full FIFO

        -- Read until empty
        report "TS4: Reading remaining items until empty.";
        integer items_read_in_alt_section :=0;
        while tb_empty = '0' loop
            tb_rd_en <= '1';
            wait for CLK_PERIOD;
            temp_data := std_logic_vector(to_unsigned(expected_rd_value, TB_DATA_WIDTH));
            assert tb_data_out = temp_data report "TS4: Data mismatch (Read 2). Expected " & to_hstring(temp_data) & ", Got " & to_hstring(tb_data_out) severity error;
            report "TS4: Reading " & integer'image(expected_rd_value);
            expected_rd_value := expected_rd_value + 1;
            items_read_in_alt_section := items_read_in_alt_section + 1;
            if items_read_in_alt_section > TB_FIFO_DEPTH + 5 then -- Safety break
                assert false report "TS4: Stuck in read loop, too many items read." severity failure;
                break;
            end if;
        end loop;
        tb_rd_en <= '0';
        wait for CLK_PERIOD;
        assert tb_empty = '1' report "TS4: FIFO should be empty after reading all items. tb_empty=" & to_string(tb_empty) severity error;

        -- 5. Simultaneous Read and Write
        report "Testbench: 5. Simultaneous Read and Write";
        data_val := 200; -- New data sequence
        expected_rd_value := 200;

        -- Fill half the FIFO
        report "TS5: Filling half the FIFO.";
        for i in 0 to (TB_FIFO_DEPTH / 2) - 1 loop
            tb_wr_en <= '1';
            tb_data_in <= std_logic_vector(to_unsigned(data_val, TB_DATA_WIDTH));
            report "TS5: Writing " & integer'image(data_val);
            data_val := data_val + 1;
            wait for CLK_PERIOD;
        end loop;
        tb_wr_en <= '0';

        report "TS5: Performing 3 simultaneous read/write operations.";
        for i in 0 to 2 loop
            tb_wr_en <= '1';
            tb_rd_en <= '1';
            tb_data_in <= std_logic_vector(to_unsigned(data_val, TB_DATA_WIDTH));
            report "TS5: Sim-Write " & integer'image(data_val) & ", Expecting to read " & integer'image(expected_rd_value);
            
            wait for CLK_PERIOD;
            
            temp_data := std_logic_vector(to_unsigned(expected_rd_value, TB_DATA_WIDTH));
            assert tb_data_out = temp_data report "TS5: Data mismatch. Expected " & to_hstring(temp_data) & ", Got " & to_hstring(tb_data_out) severity error;
            report "TS5: Sim-Read " & integer'image(expected_rd_value) & " (" & to_hstring(tb_data_out) & ")";
            
            data_val := data_val + 1;
            expected_rd_value := expected_rd_value + 1;
            
            -- Check that full/empty status does not change if FIFO was not full or empty
            -- This assumes FIFO was not full before this operation (half full + 1 write - 1 read = half full)
            -- and not empty (half full - 1 read + 1 write = half full)
            assert tb_full = '0' report "TS5: FIFO should not be full during sim R/W. tb_full=" & to_string(tb_full) severity warning;
            assert tb_empty = '0' report "TS5: FIFO should not be empty during sim R/W. tb_empty=" & to_string(tb_empty) severity warning;
        end loop;
        tb_wr_en <= '0';
        tb_rd_en <= '0';
        wait for CLK_PERIOD;

        -- Read out remaining items from simultaneous R/W test
        report "TS5: Reading out remaining items after simultaneous R/W.";
        while tb_empty = '0' loop
            tb_rd_en <= '1';
            wait for CLK_PERIOD;
            temp_data := std_logic_vector(to_unsigned(expected_rd_value, TB_DATA_WIDTH));
            assert tb_data_out = temp_data report "TS5: Data mismatch (Read after Sim). Expected " & to_hstring(temp_data) & ", Got " & to_hstring(tb_data_out) severity error;
            report "TS5: Reading " & integer'image(expected_rd_value);
            expected_rd_value := expected_rd_value + 1;
        end loop;
        tb_rd_en <= '0';
        wait for CLK_PERIOD;
        assert tb_empty = '1' report "TS5: FIFO should be empty. tb_empty=" & to_string(tb_empty) severity error;


        -- 6. Fill, Empty, then Write/Read again
        report "Testbench: 6. Fill, Empty, then Write/Read again";
        data_val := 0; -- Reset data
        expected_rd_value := 0;

        report "TS6: Quickly filling the FIFO.";
        for i in 0 to TB_FIFO_DEPTH - 1 loop
            tb_wr_en <= '1';
            tb_data_in <= std_logic_vector(to_unsigned(data_val, TB_DATA_WIDTH));
            data_val := data_val + 1;
            wait for CLK_PERIOD;
        end loop;
        tb_wr_en <= '0';
        wait for CLK_PERIOD;
        assert tb_full = '1' report "TS6: FIFO should be full. tb_full=" & to_string(tb_full) severity error;

        report "TS6: Quickly emptying the FIFO.";
        for i in 0 to TB_FIFO_DEPTH - 1 loop
            tb_rd_en <= '1';
            wait for CLK_PERIOD;
            -- No data check here, just emptying. Data check was done in TS3.
            expected_rd_value := expected_rd_value + 1; -- Keep counter in sync
        end loop;
        tb_rd_en <= '0';
        wait for CLK_PERIOD;
        assert tb_empty = '1' report "TS6: FIFO should be empty. tb_empty=" & to_string(tb_empty) severity error;

        report "TS6: Write one item.";
        data_val := 77; -- Arbitrary new value
        expected_rd_value := 77;
        tb_wr_en <= '1';
        tb_data_in <= std_logic_vector(to_unsigned(data_val, TB_DATA_WIDTH));
        report "TS6: Writing " & integer'image(data_val);
        wait for CLK_PERIOD;
        tb_wr_en <= '0';
        wait for CLK_PERIOD;
        assert tb_full = '0' report "TS6: FIFO should not be full. tb_full=" & to_string(tb_full) severity note;
        assert tb_empty = '0' report "TS6: FIFO should not be empty. tb_empty=" & to_string(tb_empty) severity note;


        report "TS6: Read one item.";
        tb_rd_en <= '1';
        wait for CLK_PERIOD;
        temp_data := std_logic_vector(to_unsigned(expected_rd_value, TB_DATA_WIDTH));
        assert tb_data_out = temp_data report "TS6: Data mismatch. Expected " & to_hstring(temp_data) & ", Got " & to_hstring(tb_data_out) severity error;
        report "TS6: Reading " & integer'image(expected_rd_value);
        tb_rd_en <= '0';
        wait for CLK_PERIOD;
        assert tb_empty = '1' report "TS6: FIFO should be empty. tb_empty=" & to_string(tb_empty) severity error;


        report "Testbench finished successfully.";
        wait; -- End of simulation
    end process stim_proc;

end architecture behavioral;
