////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//                                    ROT_ENC                                 //
//                            Rotary Encoder Handling  						  //
//						   Digital Oscilloscope Project                       //
//                                   EE/CS 52                                 //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////


// This file contains the routines to initialize rotary encoder driven interrupts
// as well as to handle these events. In addition, this provides an interface
// with the user interface code with a function that checks whether an event
// has occurred and key retrieved as well as returns the key press in a form
// usable by the front end software.
//
// Table of contents
// Init_Rot - Initializes edge sensitive interrupts from the bits of the
// 	rotary encoder PIO
// Rot_Handler - Handles interrupts from any of the bits of the PIO by
// 	matching up the correct key to the event
// key_available - Checks whether there is a valid key available from the
// 	rotary encoders
// get_key - If there is a valid key returns the key code to the front end
// 	does not exit until there is a valid key
//
// Revision History:
//    05/14/17  Maitreyi Ashok      initial revision
//	  05/15/17	Maitreyi Ashok		cleaned up code
//	  05/17/17  Maitreyi Ashok		debugged inconsistent rotary encoders
//    05/20/17	Maitreyi Ashok		updated comments


// contains key code definitions
#include "interfac.h"
// contains general constant definitions
#include "scopedef.h"
// contains rotary encoder PIO definitions
#include "system.h"
// contains masks to interface with PIO core register
#include "Rot_Enc.h"
// contains macros to interface with the stack
#include "macros.m"


.section .text


// Init_Rot
//
// Description:		 This function initializes interrupts from the ROTARY_ENCODER
//					 PIO as well as install the handler for it. This interrupt
//					 contains the push button of one of the rotary encoders as
//					 well as the clockwise and counterclockwise turns of both
//					 rotary encoders. All possibilities of events are handled
//					 by the same interrupt handler and are part of the same PIO.
//
// Operation:		 Installs the handler using the IRQ constants of the
//					 ROTARY_ENCODER PIO in the alt_ic_isr_register function which
//					 enables hardware interrupts so that the software can use an
//					 interrupt service routine. Then, the interrupts for the used
//					 bits of this PIO are enabled and the bits used in the edge
//					 capture register for this PIO are cleared so that any pending
//					 interrupts will be turned off.
//
// Arguments:		 None
// Return Value:	 None
//
// Local Variables:	 Rot_Enc_PIO [r9] - contains address of the Rotary Encoder
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
// Registers Changed:r2, r4, r5, r6, r7, r8, r9
// Stack Depth:		 2 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 05/14/17	Maitreyi Ashok	Initial revision
//					 05/17/17	Maitreyi Ashok	Changed ldw/stw to ldwio/stwio
//					 05/20/17	Maitreyi Ashok	Updated comments

.global Init_Rot
.align 4
.type Init_Rot, @function

Init_Rot:
Set_up_handler:
	movui	r4, ROTARY_ENCODER_IRQ_INTERRUPT_CONTROLLER_ID
	movui	r5, ROTARY_ENCODER_IRQ		// move the rotary encoder interrupt
										// id and IRQ into registers as arguments
										// to the installer function
	movia	r6, Rot_Handler				// function pointer to event handler is
										// another argument
	mov		r7, zero					// pass a null pointer as isr_context
										// argument since it is unused
	PUSH	ra							// store return address on stack before
										// calling another function
	PUSH	zero						// store a null pointer for the flags
										// argument since it is also unnecessary
Call_handler_setup:
	call	alt_ic_isr_register			// install the event handler for the rotary
										// encoder interrupt
	bne		r2, zero, Call_handler_setup	// if installing failed, try again
Renable_interrupts:
	POP									// remove the argument from the stack
	POP_VAL	ra							// restore the return address
	movia	r9, ROTARY_ENCODER_BASE		// get the rotary encoder PIO register address
	ldwio	r8, 8(r9)					// and the value in the interruptmask register
	ori		r8, r8, ENABLE_INT			// enable interrupts and store the enabled
	stwio	r8, 8(r9)					// value to the interruptmask register

	ldwio	r8, 12(r9)					// get the value in the edgecapture register
	ori		r8, r8, ENABLE_INT			// clear any pending interrupts and store
	stwio	r8, 12(r9)					// the cleared value into the edgecapture 
										// register
	ret

// Rot_Handler
//
// Description:		 This function handles interrupts due to the rotary encoders.
//					 Hardware interrupts by turning either of the rotary encoders
//					 clockwise or counterclockwise or pushing one of them will
//					 be registered in the ROTARY_ENCODER PIO, causing this handler
//					 function to be called. This function determines the key
//					 code that the hardware event corresponds to and stores this
//					 code to be used by the main loop software. If an illegal key
//					 is received, no value is stored.
//
// Operation:		 This function first disables interrupts during the handling
//					 of the event to avoid any extra events happening. Then,
//					 the edge captured for the event is stored in a register to
//					 determine what the event signified. If there is still an old
//					 key code stored (a valid one), then ignores this current event
//					 to allow the old key code to be retrieved. In addition, if
//					 the edge captured is somehow illegal, the edge is ignored and
//					 no key code is stored. Otherwise, the key code is stored to be
//					 later retrieved by the main loop. The key code options are
//					 MENU (push button), UP (rotary encoder 1 counter clockwise),
//					 DOWN (rotary encoder 1 clockwise), LEFT (rotary encoder 2
//					 counter clockwise), and RIGHT (otary encoder 2 clockwise).
//					 After storing the key code interrupts are enabled again and
//					 the edge capture register is cleared to allow for future
//					 hardware interrupts to be registered.
//
// Arguments:		 None
// Return Value:	 None
//
// Local Variables:	 Rot_Enc_PIO [r9] - contains address of the Rotary Encoder
//							PIO register
//					 edge_captured [r8] - contains the value stored in the edge
//							capture register that caused the interrupt
// Shared Variables: keyCodeStored - stores value of keycode corresponding to user
//							input. Either Left, Right, Up, Down, Menu, or Illegal.
// Global Variables: None
//
// Input:			 Rotary encoders are turned clockwise or counterclockwise
//					 or the pushbutton in one of the encoders is pushed
// Output:			 None
//
// Error Handling:	 If the interrupt is due to an invalid turn or push (either
//					 nothing is registered or a combination of turns is registered)
//					 then ignore the value retrieved
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r8, r9, r10, r12, r14, r15
// Stack Depth:		 0 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 05/14/17	Maitreyi Ashok	Initial revision
//					 05/17/17	Maitreyi Ashok	Changed ldb/stb to ldbio/stbio
//					 05/20/17	Maitreyi Ashok	Updated comments

.global Rot_Handler
.align 4
.type Rot_Handler, @function

Rot_Handler:
	movia	r9, ROTARY_ENCODER_BASE		// Get the address of the PIO register
	ldbuio	r8, 8(r9)					// Retrieve the current value of the
	andi	r8, r8, DISABLE_INT			// interruptmask register and disable 
	stbio	r8, 8(r9)					// interrupts during the handling routine

	ldbuio	r8, 12(r9)					// Get the value stored in the edge capture
										// register as the interrupt that is registered
	movia	r10, keyCodeStored			// Get the address of the key code variable
	movi	r14, TRUE

Check_Validity:
	ldb		r15, 0(r10)					// Load the old key code
	cmpeqi	r15, r15, KEY_ILLEGAL		// If it is not KEY_ILLEGAL, then the old
	bne		r15, r14, Error				// value has not been retrieved so ignore
										// the current one
	movi	r12, KEY_LEFT				// If the current event is a combination of
	ori		r12, r12, KEY_RIGHT			// both left and right turns, then it is
	cmpeq	r12, r8, r12				// an illegal turn and should not be stored
	beq		r12, r14, Error
	movi	r12, KEY_DOWN				// If the current event is a combination of
	ori		r12, r12, KEY_UP			// both up and down turns, then it is an
	cmpeq	r12, r8, r12				// illegal turn and should not be stored
	beq		r12, r14, Error
	beq		r8, zero, Error				// If the current event has no value, it
										// is not stored
Store_Value:
	stb		r8, 0(r10)					// If there is no error in the value
	jmpi	Done_Handler				// store it in the shared variable key code
Error:
Done_Handler:
	ldbuio	r8, 8(r9)					// Get the current value of the interrupt
	ori		r8, r8, ENABLE_INT			// mask register and enable interrupts
	stbio	r8, 8(r9)					// due to the rotary encoder PIO
	movi	r8, ENABLE_INT				// Clear the edge capture register for all
	stwio	r8, 12(r9)					// interrupts in this PIO for any pending
										// interrupts
	ret

// key_available
//
// Description:		 This function checks if a key event is available. This would
// 					 be a result of an edge being captured in the peripheral I/O,
//					 causing the event handler to record the key event in the
//					 keyCodeStored variable. This function checks if the variable
// 					 has a valid key value, and if so returns true. Otherwise,
//					 the function returns that no key is avaiable for retrieval.
//
// Operation:		 The function checks if a key is available by checking the 
//					 value of the shared variable for the key code. This key code
//					 is then compared to the key code for an illegal key. If the
//					 key codes match, the function returns false since a valid key
//					 is not available. This happens when either an illegal key
//					 combination is recorded, or if no key event has been recorded
//					 at all. If the key code does not match that for an illegal key
//					 then the function returns true since a key is available to be
//					 retrieved from the shared variable.
//
// Arguments:		 None
// Return Value:	 available [r2] - returns whether a valid key code is stored
//							due to a hardware interrupt (TRUE) or not (FALSE)
//
// Local Variables:	 None
// Shared Variables: keyCodeStored - stores value of keycode corresponding to user
//							input. Either Left, Right, Up, Down, Menu, or Illegal.
// Global Variables: None
//
// Input:			 Rotary encoders are turned clockwise or counterclockwise
//					 or the pushbutton in one of the encoders is pushed
// Output:			 None
//
// Error Handling:	 None
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r8, r9, r2
// Stack Depth:		 0 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 05/14/17	Maitreyi Ashok	Initial revision
//					 05/20/17	Maitreyi Ashok	Updated comments

.global key_available
.align 4
.type key_available, @function

key_available:
	movia	r8, keyCodeStored		// Retrieves the address of the store key code
	ldbu	r9, 0(r8)				// and the value
	cmpeqi	r9, r9, KEY_ILLEGAL		// Check if the key code is key illegal
	bne		r9, zero, illegal_key	// If it is return that key not available
legal_key:
	movi	r2, TRUE				// If key code is not illegal, return
	jmpi	end_key_available		// that key is available
illegal_key:
	movi	r2, FALSE				// If key code is illegal return that key
									// is not available
end_key_available:
	ret

// get_key
//
// Description:		 This function returns the key code of the key event that has
//					 taken place. The function blocks if no valid key event is 
// 					 available, and it will only return when a valid key is 
//				     present. It also resets the value of the key code shared
//     				 variable to hold an illegal key value. This ensures that
// 					 that each user input key event is only recorded and handled
//					 once. Then, the next time the main loop checks if a key is
//					 available, there will not be a valid key until the user 
//					 interacts with the system again.
//
// Operation:		 This function checks if there a valid key available using the
//					 key_available function. If there is, the actual value of the
//					 key code is retrieved from the shared variable. If not, the
//					 function repeatedly checks for an available key until there
//					 eventually is one. Thus, the function blocks if called before
//					 checking if there is a key event. Once the key code is read,
//					 it is stored as the return value. The shared variable key 
//					 code is reset to an illegal key code value. This is to ensure
//					 that the specific key event will only be handled once.
//
// Arguments:		 None
// Return Value:	 keyCode [r2] - returns the key code if its valid. Does not
//							return until has valid key code
//
// Local Variables:	 None
// Shared Variables: keyCodeStored - stores value of keycode corresponding to user
//							input. Either Left, Right, Up, Down, Menu, or Illegal.
// Global Variables: None
//
// Input:			 Rotary encoders are turned clockwise or counterclockwise
//					 or the pushbutton in one of the encoders is pushed
// Output:			 None
//
// Error Handling:	 None
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r8, r9, r2
// Stack Depth:		 1 word
//
// Author:			 Maitreyi Ashok
// Last Modified:	 05/14/17	Maitreyi Ashok	Initial revision
//					 05/19/17	Maitreyi Ashok	Set key code back to illegal after
//												reading it
//					 05/20/17	Maitreyi Ashok	Updated comments

.global	get_key
.align	4
.type	get_key, @function

get_key:
	PUSH	ra						// store the return address before calling
									// key available
	call	key_available			// Check if there is a key available
	movi	r8, FALSE				// If there is a key available
	bne		r2, r8, valid_key		// then return that key
	jmpi	get_key					// Otherwise keep trying until there is a key
valid_key:
	movia	r8, keyCodeStored		// Get the key code actually stored in the
	ldbu	r2, 0(r8)				// shared variable
	stw		r0, 0(r8)				// Reset the shared variable to an illegal
	movui	r9, KEY_ILLEGAL			// key code byte after clearing out the entire
	stb		r9, 0(r8)				// word

	POP_VAL	ra						// restore the return address
	ret

	
.section .data
.align 4
keyCodeStored: .byte 6			// Contains the key code of the user input event
			   .skip 1			// Can be KEY_MENU, KEY_LEFT, KEY_RIGHT, KEY_UP,
								// KEY_DOWN, or KEY_ILLEGAL
