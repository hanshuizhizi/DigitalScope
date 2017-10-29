////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//                                     ANALOG                                 //
//                                 Analog Sampling  	 					  //
//						   Digital Oscilloscope Project                       //
//                                   EE/CS 52                                 //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////


// This file contains the routines to retrieve analog data converted to 8 bit
// digital data through the analog to digital converter. This is done by reading
// the FIFO in the analog hardware, and returning a buffer of data to the main
// loop when the sample is done. The sampling parameters can also be set using
// routines in this file. These parameters are sampling rate, trigger level, delay,
// and slope. None of the functions in these file have been tested.
//
// Table of contents
// init_fifo_full - Initializes event handler for when FIFO is full
// handle_fifo_full - Copies data from analog input into buffer when FIFO
//		is full
// set_sample_rate - Set sampling rate to given value
// set_trigger - Sets trigger level and slope to given values
// set_delay - Sets trigger delay to given value
// start_sample - Start sampling data whenever there is a trigger event (or auto
//		trigger times out)
// sample_done - Checks if sample is collected and returns a pointer to the
//		sampled data
//
// Revision History:
//    06/03/17  Maitreyi Ashok		Initial revision
//    06/29/17	Maitreyi Ashok		Fixed set_sampling_rate to return a constant
//    06/30/17	Maitreyi Ashok		Updated comments



// contains analog PIO definitions
#include "system.h"
// contains constants for analog sampling parameters
#include "analog.h"
// contains definitions for working with stack
#include "macros.m"
// contains general definitions
#include "scopedef.h"

.section .text

// init_fifo_full
//
// Description:		 This function initializes interrupts from the FIFO_FULL
//					 PIO as well as install the handler for it. This interrupt
//					 occurs when NUM_SAMPLES bytes have been written to the FIFO,
//					 as that many samples have been taken of the analog signal
//					 by the analog to digital converter. When the FIFO is full,
//					 the data must be saved before it is overwritten so it is
//					 important to pause the system so this can be done.
//
// Operation:		 Installs the handler using the IRQ constants of the
//					 FIFO_FULL PIO in the alt_ic_isr_register function which
//					 enables hardware interrupts so that the software can use an
//					 interrupt service routine. Then, the interrupts for the used
//					 bits of this PIO are enabled and the bits used in the edge
//					 capture register for this PIO are cleared so that any pending
//					 interrupts will be turned off.
//
// Arguments:		 None
// Return Value:	 None
//
// Local Variables:	 FIFO_PIO [r9] - contains address of the FIFO_FULL
//							PIO register
// Shared Variables: None
// Global Variables: None
//
// Input:			 None
// Output:			 None
//
// Error Handling:	 The function does not return until the installing of the
//					 handler using alt_ic_isr_register succeeds
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r4, r5, r6, r7, r2, r8, r9
// Stack Depth:		 2 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 06/03/17   Maitreyi Ashok		Initial revision
//    				 06/30/17	Maitreyi Ashok		Updated comments

.global init_fifo_full
.align 4
.type init_fifo_full, @function

init_fifo_full:
SetUpFIFOHandler:
	movui	r4, FIFO_FULL_IRQ_INTERRUPT_CONTROLLER_ID
	movui	r5, FIFO_FULL_IRQ				// move the FIFO full interrupt id and
											// IRQ into registers as arguments to
											// the installer function
	movia	r6, handle_fifo_full			// function pointer to event handler is
											// another argument
	mov		r7, zero						// pass a null pointer as isr_context
											// argument since it is unused
	PUSH	ra								// store return address on stack before
											// calling another function
	PUSH	zero							// store a null pointer for the flags
											// argument since it is also unnecessary
CallFifoHandlerSetup:
	call	alt_ic_isr_register				// install event handler for the FIFO
											// full set up
											// If installing failed, try again
	bne		r2, zero, Call_fifo_handler_setup
ReenableInterrupts:
	POP										// Remove argument from stack
	POP_VAL	ra								// Restore the return address
	movia	r9, FIFO_FULL_BASE				// Get FIFO full PIO register address
	ldwio	r8, 8(r9)						// and the value in the interrupt mask
											// register
	ori		r8, r8, ENABLE_FIFO_INT			// Enable interrupts and store the 
	stwio	r8, 8(r9)						// enabled value to the register
	
	ldwio	r8, 12(r9)						// Get value in edgecapture register
	ori		r8, r8, ENABLE_FIFO_INT			// Clear any pending interrupts and
	stwio	r8, 12(r9)						// store cleared value into edge 
											// capture register
	ret
	
// handle_fifo_full
//
// Description:		 This function handles interrupts due to the FIFO filling
//					 up. Hardware interrupts due to this event will be
//					 registered in the FIFO_FULL PIO, causing this handler
//					 function to be called. TThis function reads every byte of
//					 data from the FIFO and moves it to a buffer stored in SRAM.
//					 This is done by sending a software created clock to the FIFO
//					 to read a byte of data on rising edges of the clock. When
//					 this is done, the Done flag is asserted to indicate that
//					 a full sample of analog data has been completed.
//
// Operation:		 This function first disables interrupts during the handling
//					 of the event to avoid any extra events happening. Then, it
//					 disables the trigger so that no new trigger events will occur
//					 and overwrite data that has not been saved anywhere. After this,
//					 the Data_Read signal is made to go high from the PIO. When
//					 this signal goes high, the FIFO outputs the next byte of data
//					 (in first in - first out order). This data is stored in
//					 the analog buffer and buffer pointer incremented to the next
//					 memory address to store data at. Then, the data read signal
//					 is pulsed low again so that the next rising edge can have
//					 data be output from the FIFO. If the entire FIFO has not
//					 been read, the process is repeated. If the FIFO has been read
//					 completely, the Done flag is asserted since a sampling cycle
//					 has finished. Afterwards the FIFO_FULL interrupts are enabled  
//					 again to allow for future hardware interrupts to be registered.
//
// Arguments:		 None
// Return Value:	 None
//
// Local Variables:	 bufferPtr [r10] - Points to next address to write analog data
//							to
//					 FIFO_Data [r13] - PIO address to read FIFO data from
//					 Data_Read_Addr [r16] - Address of PIO for data read clock
// Shared Variables: AnalogBuffer - Stores data read from FIFO of bytes of analog
//							data captured
//					 
// Global Variables: None
//
// Input:			 FIFO storing analog signal data is full. Data is read from
//					 FIFO
// Output:			 None
//
// Error Handling:	 None
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r8, r9, r10, r13, r14, r15, r16, r17, r18
// Stack Depth:		 0 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 06/03/17   Maitreyi Ashok		Initial revision
//    				 06/30/17	Maitreyi Ashok		Updated comments
	
.global handle_fifo_full
.align 4
.type handle_fifo_full, @function

handle_fifo_full:
GetVarAddr:
	movia	r9, FIFO_FULL_BASE		// Store address of FIFO full PIO
	stw		zero, 8(r9)				// Disable further interrupts while handler 
									// executes
	movia	r13, FIFO_DATA_BASE		// Store addresses of FIFO data and Data
	movia	r16, DATA_READ_BASE		// Read PIOs
	movi	r17, TRUE				// Store TRUE and FALSE constants in registers
	movi	r18, FALSE				// to be used in register-only instructions
	
	movia	r10, AnalogBuffer		// Store address of Analog Buffer as a
									// buffer pointer
DisableTrigger:
	movia	r15, TRIGGER_ENABLE_BASE	// Get address of trigger enable PIO
	stb		r18, 0(r15)					// and disable new trigger events
CopyBuffer:
	stb		r17, 0(r16)				// Make data read signal go high
	ldbio	r14, 0(r13)				// Load a byte of data from the FIFO
	stb		r14, 0(r10)				// and store the data in the SRAM buffer
	addi	r10, r10, 1				// Increment the buffer pointer
	stb		r18, 0(r16)				// Send data read signal low
	cmpgei	r14, r10, BUFF_SIZE		// If have not reached end of buffer
	beq		r14, zero, CopyBuffer	// then repeat process for next byte
MarkAsDone:							
	movia	r10, Done				// If have reached end of buffer
	stb		r17, 0(r10)				// assert that sampling is done
	movi	r17, ENABLE_FIFO_INT
	stw		r17, 8(r9)				// Re-enable interrupts for the FIFO_FULL
	ret								// PIO
	
// set_sample_rate
//
// Description:		 This function sets the sampling rate for the analog signal
//					 sampling to the given value. The value is given as samples
//					 per second, and this is converted into a sampling time in
//					 100s of nanoseconds. This is scale is used since the minimum
//					 sampling time is 100 nanoseconds, and other sampling times
//					 supported by the oscilloscope are multiples of 100. This
//					 sampling time is stored in the output PIO for sampling 
//					 rate and used in the hardware logic to make a sampling
//					 clock. The number of samples to be taken is returned, and
//					 is a fixed value (same as the size of the FIFO)
//
// Operation:		 This function first converts the sampling rate passed in
//					 to a sampling time. This is done by getting the reciprocal
//					 of the sampling frequency for a time period. This is then
//					 multiplied by a constant to convert from seconds to 100s of
//					 nanoseconds. This is done in 2 steps due to the size of the
//					 multiplier being larger than a maximum 32 bit value.
//					 This value is stored at the address for the PIO in the CPU
//					 so that it can be output to be used to create a sampling
//					 clock to use for any counters in the sampling hardware.
//					 In addition, the function returns a set value as the number
//					 of samples that will be captured, NUM_SAMPLES. This does not
//					 depend on the sampling frequency, and instead the time for
//					 a complete sample of the signal will vary based on the
//					 sampling frequency.
//
// Arguments:		 sampling_rate [r4] - Number of samples per second to be taken
// Return Value:	 num_samples [r2] - Number of samples that will be taken at
//							the set frequency
//
// Local Variables:	 sample_time [r4] - Time for each sample in 100s of nanoseconds
// Shared Variables: None
//					 
// Global Variables: None
//
// Input:			 None
// Output:			 Sampling time (25 bits) set in hardware PIO configured for
//							output
//
// Error Handling:	 None
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r2, r4, r9
// Stack Depth:		 0 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 06/03/17   Maitreyi Ashok		Initial revision
//				     06/29/17   Maitreyi Ashok		Fixed return value to constant
//    				 06/30/17	Maitreyi Ashok		Updated comments

.global set_sample_rate
.align 4
.type set_sample_rate, @function

set_sample_rate:
	movia	r9, SAMPLING_RATE_MULTIPLIER_1	// Retrieve the sampling rate
									// multiplier to convert from seconds/sample
									// to 100s of nanoseconds/sample
	div		r4, r9, r4				// Convert number of samples/second to 
	muli	r4, r4, SAMPLING_RATE_MULTIPLIER_2						
									// 100s of nanoseconds/sample by
									// 1/sample_rate * SAMPLING_RATE_MULITPLIER (1*2)
	movia	r9, SAMPLING_RATE_BASE	// Store this value in the PIO for the
	stw		r4, 0(r9)				// sampling rate
	movi	r2, NUM_SAMPLES			// Always take a fixed number of samples at
									// any frequency
	ret

// set_trigger
//
// Description:		 This function sets the trigger level and trigger slope to
//					 the given values. This is done by writing to the data register
//					 of the PIO for each value. The trigger level is a value between
//					 0 and 127 (all possible 7 bit unsigned values) that represents
//					 a voltage between MIN_LEVEL and MAX_LEVEL (defined in interfac.h).
//				     The trigger slope is 1 for a negative trigger slope
//					 (meaning a trigger event will happen if the trigger level
//					 is passed when the signal is sloping downwards). Conversely, 
//					 the trigger slope is 0 for a positive trigger slope (trigger 
//					 event occurs if the trigger level is passed with the signal
//					 increasing).
//
// Operation:		 This function sets the trigger level and slope. This is done
//					 by taking each of the arguments to the function, as well as
//					 the base address of each PIO. Then, the argument is written
//					 to the data register (offset 0) of the PIO, which is set
//					 for output from the CPU. These values are then used in the
//					 analog controller to generate trigger events manually.
//
// Arguments:		 trig_level [r4] - Trigger level to set for sampling (between
//							0 and 127)
//					 trig_slope [r5] - Trigger slope to set for sampling (1 for
//							negative slope, 0 for positive slope)
// Return Value:	 None
//
// Local Variables:	 None
// Shared Variables: None
//					 
// Global Variables: None
//
// Input:			 None
// Output:			 Trigger level (7 bits) and trigger slope (1 bit) set in hardware 
//							PIOs configured for output
// Error Handling:	 None
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r9
// Stack Depth:		 0 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 06/03/17   Maitreyi Ashok		Initial revision
//    				 06/30/17	Maitreyi Ashok		Updated comments

.global set_trigger
.align 4
.type set_trigger, @function

set_trigger:
	movia	r9, TRIGGER_LEVEL_BASE	// Store the given trigger level in the
	sth		r4, 0(r9)				// appropriate output PIO
	movia	r9, TRIGGER_SLOPE_BASE	// Store the given trigger slope in the
	sth		r5, 0(r9)				// appropriate output PIO
	ret

// set_delay
//
// Description:		 This function sets the trigger delay to the given value.
//					 This is done by writing to the data register of the PIO 
//					 TRIGGER_DELAY. The trigger delay is a value between
//					 0 and 50000 that represents the number of samples to wait
//					 between a trigger event and saving the signal data to the FIFO.
//				     Once either a manual trigger event occurs due to the trigger
//					 level being passed with the correct slope or from an auto
//					 trigger timeout,a counter using a clock at the sampling 
//					 frequency will count up to this trigger delay before latching
//					 the write request signal to the FIFO.
//
// Operation:		 This function sets the trigger delay. This is done
//					 by taking the argument to the function, as well as
//					 the base address of the PIO. Then, the argument is written
//					 to the data register (offset 0) of the PIO, which is set
//					 for output from the CPU. These values are then used in the
//					 analog controller to generate a write request signal.
//
// Arguments:		 trig_delay [r4] - Trigger delay in units of samples
// Return Value:	 None
//
// Local Variables:	 None
// Shared Variables: None
//					 
// Global Variables: None
//
// Input:			 None
// Output:			 Trigger delay (16 bits) set in hardware PIO set up for output
//
// Error Handling:	 None
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r9
// Stack Depth:		 0 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 06/03/17   Maitreyi Ashok		Initial revision
//    				 06/30/17	Maitreyi Ashok		Updated comments

.global set_delay
.align 4
.type set_delay, @function

set_delay:
	movia	r9, TRIGGER_DELAY_BASE	// Store the given trigger delay in the
	stw		r4, 0(r9)				// appropriate output PIO
	ret

// start_sample
//
// Description:		 This function immediately starts sampling data using the analog
//					 controller. This is done by either manual triggering or auto 
//					 trigger timeout, depending on the setting chosen by the caller
//					 function. If the caller passes in TRUE, then auto trigger 
//					 timeout can be used to start saving data to the FIFO. If the
//					 caller passes in FALSE, then only manual trigger events allow
//					 for data to start being saved to the FIFO. In addition, to 
//					 start waiting for a trigger, the trigger enable signal is
//					 made active.
//
// Operation:		 This function starts sampling in the hardware by both setting
//					 how a trigger event can be generated and enabling trigger
//					 events in general. The address of the manual/auto trigger
//					 option is saved, and the choice of the caller function is
//					 written to the data register. Since the argument is TRUE if 
//					 auto trigger can be used, but the PIO uses TRUE if only manual 
//					 trigger can be used, the value of the argument is inverted 
//					 before being saved. Inverting is equivalent to XORing with 
//					 TRUE, since if the argument is TRUE, the result will be FALSE. 
//					 If the argument is FALSE, then the result will be TRUE since 
//					 there will be an odd amount of TRUEs being XORed.
//
// Arguments:		 auto_trigger [r4] - Whether auto trigger timeout can be used
//	 				 to start sampling (TRUE) or a trigger event must occur (FALSE)
// Return Value:	 None
//
// Local Variables:	 None
// Shared Variables: None
//					 
// Global Variables: None
//
// Input:			 None
// Output:			 Manual or auto trigger setting is set in a hardware PIO. Trigger
//					 events are also enabled in an output hardware PIO. The analog
//					 controller will start waiting for a trigger event due to
//					 manual trigger or auto trigger timeout (if enabled)
//
// Error Handling:	 None
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r4, r9, r15, r18
// Stack Depth:		 0 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 06/03/17   Maitreyi Ashok		Initial revision
//    				 06/30/17	Maitreyi Ashok		Updated comments

.global start_sample
.align 4
.type start_sample, @function

start_sample:
AutoTriggerPIO:
	movia	r9, MANUAL_AUTO_TRIGGER_BASE // Store the manual vs. auto trigger
	xori	r4, r4, TRUE				// Invert manual vs auto trigger value
	sth		r4, 0(r9)				 	// option in the appropriate output PIO
	movi	r18, TRUE					
	movia	r15, TRIGGER_ENABLE_BASE	// Enable triggering so that a new sample
	stb		r18, 0(r15)					// can be collected and stored in the FIFO

	ret

// sample_done
//
// Description:		 This function returns the sampled data once the sampling of
//					 the analog signal is finished. If the sampling is complete, 
//					 then the pointer to the sampled data is returned. If the
//					 sampling is not complete, then a NULL pointer is returned.
//					 If the sampling is complete (Done flag set at end of FIFO
//					 full event handler), then the pointer can be set to the return
//					 value. In addition, the Done flag is reset so that the 
//					 function returns a non-NULL pointer once for each call to
//				     the start_sample function.
//
// Operation:		 This function first retrieves the value of the Done flag from
//					 memory. If the value of the flag is not TRUE, or is FALSE
//					 then the sampling is not complete and a NULL pointer is
//					 returned. If the value of the flag is TRUE, sampling is complete
//					 so the done flag is reset so this function will only return
//					 a pointer to the buffer once for each time the sampling is
//					 started. In addition, the return value is set to the address
//					 of the AnalogBuffer stored in the data section. The size of
//					 the AnalogBuffer is the number of bytes returned by the
//					 sample_rate setting function.
//
// Arguments:		 None
// Return Value:	 bufferAddr [r2] - Pointer to buffer storing FIFO data, NULL
//					  		if sampling is not complete
//
// Local Variables:	 Done_Addr [r9] - address of Done flag stored in memory
// Shared Variables: Done - flag storing whether sampling is complete (TRUE) or 
//							not (FALSE)
//					 AnalogBuffer - buffer of data stored from the FIFO of
//							analog data
//					 
// Global Variables: None
//
// Input:			 None
// Output:			 None
//
// Error Handling:	 None
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r2, r9, r10, r11
// Stack Depth:		 0 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 06/03/17   Maitreyi Ashok		Initial revision
//    				 06/30/17	Maitreyi Ashok		Updated comments

.global sample_done
.align 4
.type sample_done, @function

sample_done:
	movia	r9, Done				// Find the value of the Done flag
	ldb		r11, 0(r9)
	cmpeqi	r10, r11, TRUE			// If the Done flag is not TRUE, then
	beq		r10, zero, NotDone		// a sample is not done completely
DoneSample:		
	movi	r10, FALSE				// If the sample is done completely, then 
	stb		r10, 0(r9)				// the done flag is reset so a sample is only
									// read once from the buffer
	movia	r2, AnalogBuffer		// Return the address of the AnalogBuffer
									// so the data can be read and displayed
	jmpi	EndDoneSample
NotDone:
	mov		r2, zero				// No sample complete, so a NULL pointer is
									// returned
EndDoneSample:		
	ret
	

.section .data
.align 4
Done:	   		.byte FALSE				// Stores whether a sample has been
				.skip 1					// completed with the data stored in the
										// AnalogBuffer so it cannot be overwritten
										// in the FIFO
AnalogBuffer:	.byte 0					// Stores a copy of data from the FIFO
				.skip NUM_SAMPLES		// collected from the analog to digital
										// converter after a trigger event has
										// occurred or auto trigger timeout

							
