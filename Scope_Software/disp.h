/****************************************************************************/
/*                                                                          */
/*                                  DISP.H                                  */
/*                            Display Definitions                           */
/*                               Include File                               */
/*                       Digital Oscilloscope Project                       */
/*                                 EE/CS 52                                 */
/*                                                                          */
/****************************************************************************/

/*
 * This file contains the constants for the plotting pixels and clearing the
 * the display. These are used to iterate through all the pixels of the VRAM
 * as well as fix a hardware issue with the VRAM and display controller through
 * software.
 *
 * Revision History:
 *  5/28/17  Maitreyi Ashok	 Initial Revision
 *  6/01/17  Maitreyi Ashok	 Added constants for software fix of display
 *  6/29/17  Maitreyi Ashok  Updated comments
*/

#ifndef DISP_H_
#define DISP_H_


#define	NUM_ROWS_VRAM	512;		// Number of rows in VRAM
#define	NUM_COLS_VRAM	512;		// Number of columns in VRAM
#define COL_FIX 		1;			// Shift all columns to left by this
									// amount when displaying
#define ROW_FIX 		1;			// Shift row for first column up by this 
									// amount when displaying
#endif /* DISP_H_ */
