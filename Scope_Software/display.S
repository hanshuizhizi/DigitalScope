////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//                                   DISPLAY                                  //
//                            BASIC DISPLAY FUNCTIONS  						  //
//						   Digital Oscilloscope Project                       //
//                                   EE/CS 52                                 //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// This file contains the routines to plot pixels to the display as well as clear
// the display. These functions interface between the high level user interface
// functions and the oscilloscope hardware. This is done by writing bytes directly
// to the VRAM to be output into the LCD as pixels on the display. This allows for
// more complicated images to be shown by plotting one pixel at a time. In addition,
// the display can be reset with the display clearing function, to allow for
// new pixels to be displayed without the old ones still on the LCD.
//
// Table of contents
// get_addr - Local function to perform a software fix for a hardware issue and
//		get address in VRAM corresponding to pixel position on display
// clear_display - Resets display to be all white pixels in all positions
// plot_pixel - Plots a pixel of a certain color in the specific position (based
//		on row and column)
//			
// Revision History:
//   	5/28/17  Maitreyi Ashok	 Initial Revision
//		5/31/17  Maitreyi Ashok	 Fixed clear_display
//	 	6/01/17  Maitreyi Ashok	 Added software fix of display
//
// Contains VRAM PIO definitions
#include "system.h"
// Contains display and VRAM constants
#include "disp.h"
// contains macros to interface with the stack
#include "macros.m"
// contains color and display size definitions
#include "interfac.h"


.section .text

// get_addr
//
// Description:		 This function calculates the address in the VRAM 
//					 corresponding to a row and column of a pixel on the display.
//					 The row and column number are with reference to the top left
//					 corner pixel, which is row 0 and column 0 in the VRAM. The row 
// 					 number increases moving down in the display, and column  
//					 number increases moving right in the display. In addition,
//					 a fix is implemented due to an issue in the VRAM or display
//					 controller to adjust what row/column in the display 
//					 corresponds to what row/column in the VRAM.
//
// Operation:		 This function finds the address in the VRAM for a specified
//					 row and column in the display. Since the first byte of the
//				     VRAM stores the top left pixel of the display, the address
//					 is found by first finding the starting address of the row
//					 to plot the pixel in the VRAM by multiplying the row number
//					 to the number of columns in the display per row. Then, the
//					 column number is added to include the offset from the start
//					 of the row, and this offset from the start of the VRAM is
//					 added to the starting address of the VRAM itself.
//					 The row and column numbers used for this calculation are
//					 adjusted based on a software fix for a hardware issue that
//					 could not be debugged. Due to an indexing issue, pixels in
//					 the first column of the display are actually the first pixel
//					 in the row above of the VRAM that is outside of the display's
//					 range. In addition, all other column indices for pixels are
//					 shifted left, so the second column of the display is stored
//					 in the first column of the display for the same row. This
//					 fix is used, and then the adjusted row and column are used
//					 to find the exact address in the VRAM to write the pixel to.
//
// Arguments:		 x [r4] - Column number of the pixel to plot
//					 y [r5] - Row number of pixel to plot
// Return Value:	 addr [r2] - address in VRAM to write pixel to
//
// Local Variables:	 adjusted_x [r12] - Adjusted column number in VRAM
//					 adjusted_y [r11] - Adjusted row number in VRAM
// Shared Variables: None
// Global Variables: None
//
// Input:			 None
// Output:			 None
//
// Error Handling:	 None
//
// Algorithms:		 addr = VRAM_BASE + NUM_COLS_VRAM * adjusted_y + adjusted_x
// Data Structures:	 None
//
// Registers Changed:r12, r11, r2
// Stack Depth:		 0 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 06/01/17	Maitreyi Ashok	Initial revision
//					 06/29/17	Maitreyi Ashok	Updated comments

.align 4
.type get_addr, @function

get_addr:
GetArgs:
	mov		r11, r5					// Save the values of the row (y) and column
	mov		r12, r4					// (x) number
	bne		r12, zero, MoveLeft		// If not on first column, do not need to 
									// adjust the row
AdjustFirstCol:
	subi	r11, r11, ROW_FIX		// What is seen in the first column is 
	movi	r12, SIZE_X				// stored in the VRAM at end of the previous 
	jmpi	CalcAddr				// row
MoveLeft:
	subi	r12, r12, COL_FIX		// If not in first column, just shift left
									// since each pixel in display is represented
									// by pixel in column before in VRAM
CalcAddr:
	movia	r2, VRAM_BASE			// Calculate address
	muli	r11, r11, NUM_COLS_VRAM	// addr = VRAM_BASE + NUM_ROWS_VRAM * row + col
	add		r2, r2, r11
	add		r2, r2, r12				// Return the address in the VRAM corresponding
	ret								// to pixel in display

// clear_display
//
// Description:		 This function resets the LCD display so that every pixel
//					 in the display is white. White is used as the background
//					 color for the display so that other pixels displayed will 
//					 be more easily readable regardless of the color of the pixel.
//					 This function is used everytime the system is reset or powered
//					 on to replace any garbage in the display/VRAM with a clear
//					 screen.
//
// Operation:		 This function clears the display by writing a white pixel
//					 to every byte of the VRAM. Through the row transfer and serial
//					 output cycles, these white pixels will be displayed on the LCD
//					 for a clear screen. This is done by starting with the first
//					 row in the VRAM and writing a white pixel to every column
//					 of that row. This same process is repeated for every row
//					 of the VRAM. Since nothing is stored in the regions of the 
//					 VRAM that is not displayed, all bytes of the VRAM can be cleared.
//
// Arguments:		 None
// Return Value:	 None
//
// Local Variables:	 row [r5] - row of VRAM clearing pixels in
//					 col [r4] - column of VRAM clearing pixels in
// Shared Variables: None
// Global Variables: None
//
// Input:			 None
// Output:			 Display is completely clear, with all pixels being white
//
// Error Handling:	 None
//
// Algorithms:		 Iterate through every pixel of the VRAM by going
//					 through all the columns in a row for every row.
// Data Structures:	 None
//
// Registers Changed:r4, r5, r6, r10, r11, r12, r2
// Stack Depth:		 1 word
//
// Author:			 Maitreyi Ashok
// Last Modified:	 05/28/17	Maitreyi Ashok	Initial revision
//					 05/31/17   Maitreyi Ashok  Fixed implementation to go through
//												all pixels of display
//					 06/29/17	Maitreyi Ashok	Updated comments

.global clear_display
.align 4
.type clear_display, @function

clear_display:
InitVars:
	mov		r4, zero				// Start at top left corner of display
	mov 	r5, zero
	movia	r6, PIXEL_WHITE			// To clear display, show white pixel at 
									// all positions
	PUSH	ra						// Store return address from this function
									// so it can be restored after calling other
									// functions
CheckRow:
	cmpgei	r10, r5, NUM_ROWS_VRAM	// Once go through all the rows in the VRAM
	bne		r10, zero, EndClear		// done clearing display
CheckCol:
	cmpgei	r10, r4, NUM_COLS_VRAM	// Once go through all columns of a row in
	bne		r10, zero, DoneRow		// VRAM need to move to next row
ClearPixel:						
	call	plot_pixel				// Otherwise, valid row & column number to 
									// clear a pixel at by plotting a white pixel
	addi	r4, r4, 1				// Move to next column and check if it 
	jmpi	CheckCol				// is in valid range of VRAM
DoneRow:
	mov		r5, zero				// When finished a row, move to next row
	addi	r5, r5, 1				// and first column within that row
	jmpi	CheckRow				// Check if next row is within valid range of 
									// VRAM
EndClear:
	POP_VAL	ra						// Restore the return address into caller
	ret								// function
	
	
// plot_pixel
//
// Description:		 This function plots a pixel of a specified color at the
//					 given row and column of the display. The row and column
//					 are specified as an index in the display. Row 0 and column 0
//					 specify the top left corner of the display. Increasing the
//					 row number moves down in the display, and increasing the
//					 column number moves right in the display. The pixel color
//					 is given by an 8 bit value that represents the RGB color
//					 code for the color. The 8 bits of color includes 3 bits of red,
//					 3 bits of green, and 2 bits of blue data. These bits are
//					 the most significant bits of the 8 bits representing each
//					 of the primary colors. The non-controllable bits are always
//					 1s.
//
// Operation:		 This function plots a pixel of the given color in the given
//					 position on the display. This is done by using the get_addr
//					 function to find the address in the VRAM of the given row
//					 and column number of the display. Then, a direct write 
//					 memory is done to write the pixel byte to that location in
//					 the VRAM. This will then be output from the SAM through
//					 the serial output cycle, and displayed on the LCD.
//
// Arguments:		 x [r4] - Column number of the pixel to plot
//					 y [r5] - Row number of pixel to plot
//					 color [r6] - Pixel color to plot
// Return Value:	 None
//
// Local Variables:	 vram_addr [r2] - address in VRAM to write to
// Shared Variables: None
// Global Variables: None
//
// Input:			 None
// Output:			 A pixel is plotted on display at specified position with
//					 the specified color
//
// Error Handling:	 None
//
// Algorithms:		 None
// Data Structures:	 None
//
// Registers Changed:r2, r11, r12
// Stack Depth:		 1 words
//
// Author:			 Maitreyi Ashok
// Last Modified:	 05/28/17	Maitreyi Ashok	Initial revision
//					 06/01/17   Maitreyi Ashok	Changed address calculation to 
//												use get_addr
//					 06/29/17	Maitreyi Ashok	Updated comments

.global	plot_pixel
.align 4
.type plot_pixel, @function

plot_pixel:
GetAddr:
	PUSH	ra						// Save return address before calling other
									// functions
	call	get_addr				// Get address corresponding to (x, y) passed
									// in for position of pixel to plot
	stb		r6, 0(r2)				// Store the pixel color passed in at that
									// address
	POP_VAL	ra						// Restore return address into caller function
	ret
