/* local include files */
#include  "interfac.h"
#include  "scopedef.h"


int sampling_rate;
int trigger_level;
int trigger_slope;
int trigger_delay;

/* sampling parameter functions */

int  set_sample_rate(long int rate)
{
	sampling_rate = rate;
    return rate * 5;
}

void  set_trigger(int level, int slope)
{
	trigger_level = level;
	trigger_slope = slope;
    return;
}

void  set_delay(long int delay)
{
	trigger_delay = delay;
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
	get_test_sample(sampling_rate, sampling_rate*10, sample);
	return sample;
}

