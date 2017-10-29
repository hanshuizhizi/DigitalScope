----------------------------------------------------------------------------
--
--  Rotary Encoder Decoding
--
--  This is an implementation of a decoder for the rotary encoders in the
--	 digital oscilloscope system.  There are two inputs to the system, the
--  Pin A and Pin B of the rotary encoders. Depending on whether Pin A 
--  advances before Pin B, or the other way, the clockwise or counterclockwise
--  rotation is determined. If Pin A advances from 1 to 0 before Pin B does,
--  the encoder is travelling clockwise. If Pin B advances before, then the 
--  encoder is travelling counterclockwise. This is subject to the encoders
--  travelling back to both pins being 0 and both pins being 1, due to
--  the previous sequence maybe being a result of bouncing between pins.
--  The two outputs are a clockwise and counterclockwise signal of which
--  direction the rotary encoder is travelling (if either), which is used
--  to generate edge sensitive interrupts in the CPU.
--
--
--  Revision History:
--     13 May 17  Maitreyi Ashok    Initial revision.
--     19 May 17  Maitreyi Ashok		Changed sequence for full debounce
--
----------------------------------------------------------------------------


-- bring in the necessary packages
library ieee;
use ieee.std_logic_1164.all;

--
--  Rotary Encoder Decoding entity declaration
--

entity rot_decoder is
	port (
			PIN_A		:	in std_logic;		-- pin A of the encoder
			PIN_B		:  in std_logic;		-- pin B of the encoder
			CLK		:  in std_logic;		-- clock
			Reset		:	in std_logic;		-- reset the system
			
			Clockwise			:	out	std_logic;	-- clockwise turn has occurred
			CounterClockwise	:	out	std_logic   -- counterclockwise turn has occurred
	);
end rot_decoder;

--
--  Rotary Encoder Decoding Moore State Machine
--     Simple Architecture
--
--  This architecture uses manual assignment of state bits.
--  This minimizes the need to decode the output of a state
--  as the outputs are the lower state bits themselves.
--

architecture assign_dec_statebits	of rot_decoder is
	subtype states is std_logic_vector(4 downto 0); -- state type
	
	constant	START			: states := "00000";	-- waiting for turn of encoder
	constant	POSS_CW		: states := "00100";	-- pin A started changing before B
	constant	POSS_CC		: states := "01000";	-- pin B started changing before A
	constant	FINISH_CW	: states := "01100";	-- guarantee that travel clockwise
	constant FINISH_CC	: states	:= "10000";	-- guarantee that travel clockwise
	constant HOLD_CW_1	: states := "00110";	-- after finish complete rotation in 
	constant	HOLD_CC_1	: states := "00101";	-- 	either direction, hold the 
	constant HOLD_CW_2	: states := "01010"; -- 	clockwise or counterclockwise
	constant HOLD_CC_2	: states := "01001";	--		signal high for 3 clocks so
	constant HOLD_CW_3	: states := "01110";	--		it is recognized by the CPU
	constant	HOLD_CC_3	: states := "01101";
	
	
	signal	CurrentState	: states;	-- current state
	signal	NextState		: states;	-- next state
	
begin
	
	Clockwise	<= CurrentState(1);		-- clockwise rotation is second lowest bit
	CounterClockwise <= CurrentState(0);-- counterclockwise rotation is lowest bit
	
	-- compute the next state (function of current state and inputs)
	transition:	process (PIN_A, PIN_B, Reset)
	begin
			case CurrentState is			-- do the state transition and output
			
					when	START =>
						if (PIN_A = '1' and PIN_B = '0') then	-- if pin A starts changing
							NextState <= POSS_CW;					-- possibly moving clockwise
						elsif (PIN_A = '0' and PIN_B = '1') then	-- if pin B starts changing
							NextState <= POSS_CC;						-- possibly moving counterclockwise
						else	
							NextState <= START;						-- turn not possible yet
						end if;
					when	POSS_CW =>
						if (PIN_A = '1' and PIN_B = '0') then	-- if pin A continues changing but not
							NextState <= POSS_CW;					-- pin B, still possibly moving clockwise
						elsif (PIN_A = '0' and PIN_B = '0') then	-- if pin A and pin B both changed
							NextState <= FINISH_CW;						-- then definitely moved clockwise
						else												-- otherwise encoder just bounced
							NextState <= START;						-- move back to waiting for a turn
						end if;
					when	POSS_CC =>
						if (PIN_A = '0' and PIN_B = '1') then	-- if pin B continues changing but not 
							NextState <= POSS_CC;					-- pin A, still possibly moving counterclockwise
						elsif (PIN_A = '0' and PIN_B = '0') then	-- if pin A and B both changed then
							NextState <= FINISH_CC;						-- encoder definitely moved counterclockwise
						else												-- otherwise encoder just bounced
							NextState <= START;						-- move back to waiting for a turn
						end if;
					when 	FINISH_CW =>
						if (PIN_A = '0' and PIN_B = '0') then	-- if both pin A and pin B are at middle value
							NextState <= FINISH_CW;					-- wait for them to finish rotation before
																			-- sending clockwise rotation high
						elsif (PIN_A = '1' and PIN_B = '1') then -- if finished complete rotation, hold
							NextState <= HOLD_CW_1;					  -- clockwise signal high
						else												-- if travelling to any intermediate value
							NextState <= FINISH_CW;					-- hold this state until rotation completed
						end if;
					when	FINISH_CC =>
						if (PIN_A = '0' and PIN_B = '0') then	-- if both pin A and B are at middle value
							NextState <= FINISH_CC;					-- wait for end of rotation before sending
																			-- counterclockwise rotation high
						elsif (PIN_A = '1' and PIN_B = '1') then	-- if finished complete rotation
							NextState <= HOLD_CC_1;						-- hold counterclockwise signal high
						else												-- if travelling to any intermediate value
							NextState <= FINISH_CC;					-- hold this state until rotation completed
						end if;
					when HOLD_CW_1 =>	
						NextState <= HOLD_CW_2;						-- hold the clockwise signal for the second clock
					when HOLD_CW_2 =>
						NextState <= HOLD_CW_3;						-- hold the clockwise signal for the third clock
					when HOLD_CW_3 =>									-- after three clocks go back to waiting for a turn
						NextState <= START;							-- of the rotary encoder
					when HOLD_CC_1 =>									-- hold the counterclockwise signal for the
						NextState <= HOLD_CC_2;						-- second clock
					when HOLD_CC_2 =>									-- hold the counterclockwise signal for the
						NextState <= HOLD_CC_3;						-- third clock
					when HOLD_CC_3 =>									-- after three clocks go back to waiting for a turn
						NextState <= START;							-- of the rotary encoder
					when	OTHERS =>
						NextState <= START;							-- if any other state, go to waiting for a turn
						
			end case;
	end process transition;
	
	process (CLK)
	begin
			if Reset = '0' then								-- reset overrides everything
				CurrentState <= START;						-- if reset go to wait for a turn of rotary encoder
			elsif CLK = '1' and rising_edge(CLK) then	-- only change states on rising edges of clock
				CurrentState <= NextState;					-- save the new state information
			end if;
	end process;
	
end assign_dec_statebits;
	
			