library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; -- For unsigned/signed types if needed, and for 2**N operation

-- Entity declaration for the synchronous FIFO
-- This FIFO uses a single clock for both read and write operations.
entity synchronous_fifo is
    Generic (
        DATA_WIDTH      : POSITIVE := 8;  -- Width of the data bus
        FIFO_DEPTH_BITS : POSITIVE := 3   -- Number of bits for FIFO depth (e.g., 3 means 2^3 = 8 locations)
    );
    Port (
        -- Clock and Reset
        clk      : in  STD_LOGIC; -- System clock
        rst      : in  STD_LOGIC; -- Asynchronous reset (active high)

        -- Write Port
        wr_en    : in  STD_LOGIC; -- Write enable
        data_in  : in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0); -- Data to write into FIFO

        -- Read Port
        rd_en    : in  STD_LOGIC; -- Read enable
        data_out : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0); -- Data read from FIFO

        -- Status Flags
        full     : out STD_LOGIC; -- FIFO full flag
        empty    : out STD_LOGIC  -- FIFO empty flag
    );
end entity synchronous_fifo;

-- RTL architecture for the synchronous FIFO
architecture rtl of synchronous_fifo is

    -- Calculate FIFO Depth based on FIFO_DEPTH_BITS generic
    -- For example, if FIFO_DEPTH_BITS is 3, FIFO_DEPTH will be 2^3 = 8.
    constant FIFO_DEPTH : INTEGER := 2**FIFO_DEPTH_BITS;

    -- RAM declaration for storing FIFO data
    -- This defines a memory array of FIFO_DEPTH locations, each DATA_WIDTH wide.
    type RAM_TYPE is array (0 to FIFO_DEPTH-1) of STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
    signal ram : RAM_TYPE;
    -- Synthesis attribute to suggest using Block RAM for the FIFO memory if available.
    -- This can improve performance and resource utilization.
    attribute ram_style : string;
    attribute ram_style of ram : signal is "block";

    -- Pointers and item count
    -- wr_ptr: Points to the next location to be written in the RAM.
    signal wr_ptr       : INTEGER range 0 to FIFO_DEPTH-1 := 0;
    -- rd_ptr: Points to the current location to be read from the RAM.
    signal rd_ptr       : INTEGER range 0 to FIFO_DEPTH-1 := 0;
    -- item_count: Tracks the number of items currently stored in the FIFO.
    signal item_count   : INTEGER range 0 to FIFO_DEPTH   := 0;

    -- Internal full/empty signals used for logic before assigning to output ports
    signal internal_full  : STD_LOGIC;
    signal internal_empty : STD_LOGIC := '1'; -- FIFO is initially empty

begin

    -- Full and Empty status logic
    -- internal_full is asserted when item_count equals FIFO_DEPTH.
    internal_full  <= '1' when item_count = FIFO_DEPTH else '0';
    -- internal_empty is asserted when item_count is zero.
    internal_empty <= '1' when item_count = 0       else '0';

    -- Assign internal status signals to output ports
    full  <= internal_full;
    empty <= internal_empty;

    -- Main synchronous process for handling reset, read, and write operations
    -- This process is sensitive to the clock (clk) and reset (rst).
    process(clk, rst)
    begin
        -- Asynchronous reset logic: Initializes pointers, item count, and data_out.
        if rst = '1' then
            wr_ptr     <= 0;
            rd_ptr     <= 0;
            item_count <= 0;
            data_out   <= (others => '0'); -- Clear output data on reset
        -- Synchronous logic: Operations occur on the rising edge of the clock.
        elsif rising_edge(clk) then
            -- Case 1: Simultaneous Write and Read Operation
            -- Occurs if wr_en and rd_en are active, FIFO is not full, and FIFO is not empty.
            if wr_en = '1' and internal_full = '0' and rd_en = '1' and internal_empty = '0' then
                ram(wr_ptr) <= data_in;  -- Write new data to current write pointer location
                data_out    <= ram(rd_ptr); -- Read data from current read pointer location

                -- Increment write pointer with wrap-around
                if wr_ptr = FIFO_DEPTH - 1 then
                    wr_ptr <= 0;
                else
                    wr_ptr <= wr_ptr + 1;
                end if;

                -- Increment read pointer with wrap-around
                if rd_ptr = FIFO_DEPTH - 1 then
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1;
                end if;
                -- item_count remains the same because one item is written and one is read.
            
            -- Case 2: Write Operation Only
            -- Occurs if wr_en is active, FIFO is not full, and it's not a simultaneous read.
            elsif wr_en = '1' and internal_full = '0' then
                ram(wr_ptr) <= data_in; -- Write data to current write pointer location
                -- Increment write pointer with wrap-around
                if wr_ptr = FIFO_DEPTH - 1 then
                    wr_ptr <= 0;
                else
                    wr_ptr <= wr_ptr + 1;
                end if;
                item_count <= item_count + 1; -- Increment item count
            
            -- Case 3: Read Operation Only
            -- Occurs if rd_en is active, FIFO is not empty, and it's not a simultaneous write.
            elsif rd_en = '1' and internal_empty = '0' then
                data_out <= ram(rd_ptr); -- Read data from current read pointer location
                -- Increment read pointer with wrap-around
                if rd_ptr = FIFO_DEPTH - 1 then
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1;
                end if;
                item_count <= item_count - 1; -- Decrement item count
            end if;
        end if;
    end process;

end architecture rtl;
