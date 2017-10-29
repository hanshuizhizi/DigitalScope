/****************************************************************************/
/*                                                                          */
/*                                INTERFAC.H                                */
/*                           Interface Definitions                          */
/*                               Include File                               */
/*                       Digital Oscilloscope Project                       */
/*                                 EE/CS 52                                 */
/*                                                                          */
/****************************************************************************/

/*
   This file contains the constants for interfacing between the C code and
   the assembly code/hardware for the Digital Oscilloscope project.  This is
   a sample interface file to allow compilation of the .c files.


   Revision History:
      3/8/94   Glen George       Initial revision.
      3/13/94  Glen George       Updated comments.
      3/17/97  Glen George       Added constant MAX_SAMPLE_SIZE and removed
	                         	 KEY_UNUSED.
	  4/17/17  Maitreyi Ashok	 Changed keypad constants to match PIO inputs
*/



#ifndef  __INTERFAC_H__
    #define  __INTERFAC_H__


/* library include files */
  /* none */

/* local include files */
  /* none */




/* constants */

/* keypad constants */
#define  KEY_MENU       4	/* <Menu>      */
#define  KEY_UP         2	/* <Up>        */
#define  KEY_DOWN       1	/* <Down>      */
#define  KEY_LEFT       16	/* <Left>      */
#define  KEY_RIGHT      8	/* <Right>     */
#define	 KEY_EXTRA		32	/* <Extra Key>*/
#define  KEY_ILLEGAL    6	/* illegal key */

/* display constants */
#define  SIZE_X         480	/* size in the x dimension */
#define  SIZE_Y		    272 /* size in the y dimension */
#define  PIXEL_BLUE    0xf0 /* blue pixel RGB code */
#define  PIXEL_BLACK   0x00 /* black (dark blue) pixel RGB code */
#define  PIXEL_WHITE   0xff /* white pixel RGB code */
#define  PIXEL_PINK    0x44 /* pink pixel RGB code */
#define  PIXEL_GREEN   0x03 /* green pixel RGB code */

/* scope parameters */
#define  MIN_DELAY	       0    /* minimum trigger delay */
#define  MAX_DELAY     50000    /* maximum trigger delay */
#define  MIN_LEVEL         0    /* minimum trigger level (in mV) */
#define  MAX_LEVEL      5000    /* maximum trigger level (in mV) */

/* sampling parameters */
#define  MAX_SAMPLE_SIZE   2400 /* maximum size of a sample (in samples) */


#endif
