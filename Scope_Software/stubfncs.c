/****************************************************************************/
/*                                                                          */
/*                                 STUBFNCS                                 */
/*                        Oscilloscope Stub Functions                       */
/*                        Digital Oscilloscope Project                      */
/*                                 EE/CS 52                                 */
/*                                                                          */
/****************************************************************************/

/*
   This file contains stub functions for the hardware interfacing code for the
   Digital Oscilloscope project.  The file is meant to allow linking of the
   main code without necessarily having all of the low-level functions or
   hardware working.  The functions included are:
      key_available   - check if a key is available
      getkey          - get a key
      clear_display   - clear the display
      plot_pixel      - plot a pixel
      set_sample_rate - set the sample rate
      set_trigger     - set the trigger level and slope
      set_delay       - set the trigger delay
      start_sample    - start sampling
      sample_done     - sampling status

   The local functions included are:
      none

   The locally global variable definitions included are:
      none


   Revision History
      3/8/94   Glen George       Initial revision.
      3/13/94  Glen George       Updated comments.
      3/13/94  Glen George       Changed set_sample_rate to return SIZE_X.
      5/9/06   Glen George       Updated start_sample stub to match the new
	                         specification.
*/



/* library include files */
  /* none */

/* local include files */
#include  "interfac.h"
#include  "scopedef.h"

static int trg_level;
static int old_trg_level;

void init_analog()
{
	trg_level = 0;
}
/* sampling parameter functions */

int  set_sample_rate(long int rate)
{
    return  SIZE_X;
}

void  set_trigger(int level, int slope)
{
	trg_level = level;
    return;
}


void  set_delay(long int delay)
{
    return;
}



/* sampling functions */

void  start_sample(int auto_trigger)
{
    return;
}

unsigned char *sample_done()
{
	unsigned char *sample = malloc(SIZE_X*sizeof(unsigned char));
	get_test_sample(SIZE_X, SIZE_X*5, sample);
	return sample;
}
