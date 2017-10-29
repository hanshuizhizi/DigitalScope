/****************************************************************************/
/*                                                                          */
/*                                 ROT_ENC.H                                */
/*                         Rotary Encoder Definitions                       */
/*                               Include File                               */
/*                       Digital Oscilloscope Project                       */
/*                                 EE/CS 52                                 */
/*                                                                          */
/****************************************************************************/

/*
 * This file contains the masks for the enabling, disabling, and handling
 * of interrupts from user input via the rotary encoders for the Digital
 * Oscilloscope project. These masks are used to clear and set bits in both
 * interruptmask and edgecapture registers of the PIO core.


 * Revision History:
 *  5/14/17  Maitreyi Ashok	 Initial Revision
 *  6/03/17  Maitreyi Ashok	 Changed constants for 6 bit PIO value
*/



#ifndef  __ROT_ENC_H__
    #define  __ROT_ENC_H__

/* library include files */
  /* none */

/* local include files */
  /* none */


/* constants */


#define DISABLE_INT	0xFFC0	/* Mask to disable rotary encoder interrupts */
#define ENABLE_INT	0x003F	/* Mask to enable rotary encoder interrupts and
							   clear the rotary encoder edges in the edge
							   capture register */

#endif

