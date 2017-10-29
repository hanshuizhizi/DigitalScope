/****************************************************************************/
/*                                                                          */
/*                                 ANALOG.H                                 */
/*                             Analog Definitions                           */
/*                               Include File                               */
/*                       Digital Oscilloscope Project                       */
/*                                 EE/CS 52                                 */
/*                                                                          */
/****************************************************************************/

/*
   This file contains the constants for interfacing with the analog hardware. It
   contains a mask for the FIFO PIO in the CPU, as well as constants for the
   various parts of analog sampling.

   Revision History:
      06/03/17  Maitreyi Ashok		Initial revision
	  06/29/17	Maitreyi Ashok		Added NUM_SAMPLES constant
	  06/30/17	Maitreyi Ashok		Updated comments
*/

#ifndef  __ANALOG_H__
	#define  __ANALOG_H__


#define		ENABLE_FIFO_INT				0x0001
#define		NUM_SAMPLES					480
#define		BUFF_SIZE					NUM_SAMPLES
#define		SAMPLING_RATE_MULTIPLIER_1	0x2710
#define		SAMPLING_RATE_MULTIPLIER_2	0x03E8

#endif
