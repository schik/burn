/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  PlayBuffer.m
 *
 *  Copyright (c) 2005
 *
 *  Author: Andreas Schik <aheppel@web.de>
 *
 *  This file contains code from mpg321 by Joe Drew.
 *  Copyright (C) 2001 Joe Drew
 *  
 *  mpg321 is originally based heavily upon:
 *  plaympeg - Sample MPEG player using the SMPEG library
 *  Copyright (C) 1999 Loki Entertainment Software
 *  
 *  Also uses some code from
 *  mad - MPEG audio decoder
 *  Copyright (C) 2000-2001 Robert Leslie
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <mad.h>

#include "PlayBuffer.h"


/* XING parsing is from the MAD winamp input plugin */
struct xing {
  int flags;
  unsigned long frames;
  unsigned long bytes;
  unsigned char toc[100];
  long scale;
};

enum {
  XING_FRAMES = 0x0001,
  XING_BYTES  = 0x0002,
  XING_TOC    = 0x0004,
  XING_SCALE  = 0x0008
};

# define XING_MAGIC     (('X' << 24) | ('i' << 16) | ('n' << 8) | 'g')


/* The following two routines and data structure are from the ever-brilliant
   Rob Leslie.
*/

struct audio_dither {
  mad_fixed_t error[3];
  mad_fixed_t random;
};

/*
* NAME:        prng()
* DESCRIPTION: 32-bit pseudo-random number generator
*/
static inline
unsigned long prng(unsigned long state)
{
  return (state * 0x0019660dL + 0x3c6ef35fL) & 0xffffffffL;
}

/*
* NAME:        audio_linear_dither()
* DESCRIPTION: generic linear sample quantize and dither routine
*/
inline
signed long audio_linear_dither(unsigned int bits, mad_fixed_t sample,
                                struct audio_dither *dither)
{
  unsigned int scalebits;
  mad_fixed_t output, mask, random;

  enum {
    MIN = -MAD_F_ONE,
    MAX =  MAD_F_ONE - 1
  };

  /* noise shape */
  sample += dither->error[0] - dither->error[1] + dither->error[2];

  dither->error[2] = dither->error[1];
  dither->error[1] = dither->error[0] / 2;

  /* bias */
  output = sample + (1L << (MAD_F_FRACBITS + 1 - bits - 1));

  scalebits = MAD_F_FRACBITS + 1 - bits;
  mask = (1L << scalebits) - 1;

  /* dither */
  random  = prng(dither->random);
  output += (random & mask) - (dither->random & mask);

  dither->random = random;

  /* clip */
  if (output > MAX) {
    output = MAX;

    if (sample > MAX)
      sample = MAX;
  }
  else if (output < MIN) {
    output = MIN;

    if (sample < MIN)
      sample = MIN;
  }

  /* quantize */
  output &= ~mask;

  /* error feedback */
  dither->error[0] = sample - output;

  /* scale */
  return output >> scalebits;
}


@interface PlayBuffer (Private)
- (void) openPlayDevice: (struct mad_header const *)header;
- (void) scanFile: (void *) ptr length: (ssize_t) len;
- (int) parseXing: (struct xing *)xing bits: (struct mad_bitptr) ptr bitlen: (unsigned int) bitlen;
@end

@implementation PlayBuffer (Private)

- (void) openPlayDevice: (struct mad_header const *)header
{
    ao_sample_format format;
    int driver_id = ao_driver_id("wav");
    ao_option *ao_options = NULL;

    format.bits = 16;
    format.rate = header->samplerate;
    format.channels = 2;

    /* mad gives us little-endian data; we swap it on big-endian targets, to
       big-endian format, because that's what most drivers expect. */
    format.byte_format = AO_FMT_NATIVE; 
        
    /*
     * Open theoutput file for overwriting.
     */
    if((playDevice = ao_open_file(driver_id, [outputFile cString], 1, &format, ao_options))==NULL) {
	    playDevice = NULL;
    }
}

- (void) scanFile: (void *) ptr length: (ssize_t) len;
{
	struct mad_stream stream;
	struct mad_header header;
	struct xing xing;
    
	unsigned long bitrate = 0;
	int has_xing = 0;
	int is_vbr = 0;

	mad_stream_init(&stream);
	mad_header_init(&header);

	mad_stream_buffer(&stream, ptr, len);

	totalFrames = 0;

    /* There are three ways of calculating the length of an mp3:
      1) Constant bitrate: One frame can provide the information
         needed: # of frames and duration. Just see how long it
         is and do the division.
      2) Variable bitrate: Xing tag. It provides the number of 
         frames. Each frame has the same number of samples, so
         just use that.
      3) All: Count up the frames and duration of each frames
         by decoding each one. We do this if we've no other
         choice, i.e. if it's a VBR file with no Xing tag.
    */

	while (1) {
		if (mad_header_decode(&header, &stream) == -1) {
			if (MAD_RECOVERABLE(stream.error))
				continue;
			else
				break;
		}

		/* Limit xing testing to the first frame header */
		if (!totalFrames++) {
			if([self parseXing: &xing bits: stream.anc_ptr bitlen: stream.anc_bitlen]) {
				is_vbr = 1;
                
				if (xing.flags & XING_FRAMES) {
					/* We use the Xing tag only for frames. If it doesn't have that
					   information, it's useless to us and we have to treat it as a
					   normal VBR file */
					has_xing = 1;
					totalFrames = xing.frames;
					break;
				}
			}
		}                

		/* Test the first n frames to see if this is a VBR file */
		if (!is_vbr && !(totalFrames > 20)) {
			if (bitrate && header.bitrate != bitrate) {
				is_vbr = 1;
			} else {
				bitrate = header.bitrate;
			}
		} else if (!is_vbr) {
			/* We have to assume it's not a VBR file if it hasn't already been
			   marked as one and we've checked n frames for different bitrates */
			break;
		}

		mad_timer_add(&duration, header.duration);
	}

	if (!is_vbr) {
	        double time = (len * 8.0) / (header.bitrate); /* time in seconds */
	        double timefrac = (double)time - ((long)(time));
	        long nsamples = 32 * MAD_NSBSAMPLES(&header); /* samples per frame */
        
	        /* samplerate is a constant */
	        totalFrames = (long) (time * header.samplerate / nsamples);

	        mad_timer_set(&duration, (long)time, (long)(timefrac*100), 100);
	} else if (has_xing) {
        	/* modify header.duration since we don't need it anymore */
	        mad_timer_multiply(&header.duration, totalFrames);
        	duration = header.duration;
	} else {
	        /* the durations have been added up, and the number of frames
        	   counted. We do nothing here. */
	}
    
	mad_header_finish(&header);
	mad_stream_finish(&stream);
}

- (int) parseXing: (struct xing *)xing bits: (struct mad_bitptr) ptr bitlen: (unsigned int) bitlen
{
	if (bitlen < 64 || mad_bit_read(&ptr, 32) != XING_MAGIC)
		goto fail;

	xing->flags = mad_bit_read(&ptr, 32);
	bitlen -= 64;

	if (xing->flags & XING_FRAMES) {
		if (bitlen < 32)
			goto fail;

		xing->frames = mad_bit_read(&ptr, 32);
		bitlen -= 32;
	}

	if (xing->flags & XING_BYTES) {
		if (bitlen < 32)
			goto fail;

		xing->bytes = mad_bit_read(&ptr, 32);
		bitlen -= 32;
	}

	if (xing->flags & XING_TOC) {
		int i;

		if (bitlen < 800)
			goto fail;

		for (i = 0; i < 100; ++i)
			xing->toc[i] = mad_bit_read(&ptr, 8);

		bitlen -= 800;
	}

	if (xing->flags & XING_SCALE) {
		if (bitlen < 32)
			goto fail;

		xing->scale = mad_bit_read(&ptr, 32);
		bitlen -= 32;
	}

	return 1;

fail:
	xing->flags = 0;
	return 0;
}

@end


@implementation PlayBuffer

- (id) init
{
	self = [super init];
	if (self != nil) {
		fd = -1;
		buf = NULL;
		length = 0;
		done = 0;
		totalFrames = 0;
		stopPlaying = NO;
		currentFrame = 0;
		outputFile = nil;
		mad_timer_reset(&duration);
	}
	return self;
}

- (void) dealloc
{
    if (NULL != buf)
        munmap(buf, length);

	if (fd >= 0)
		close (fd);

	RELEASE(outputFile);
	[super dealloc];
}

- (void) stop
{
	stopPlaying = YES;
}


/*
 * Access methods
 */
- (mad_timer_t) duration
{
    return duration;
}


/* The following two functions are adapted from mad_timer, from the 
   libmad distribution */
- (BOOL) calcLength: (NSString *)file
{
	int f;
	struct stat filestat;
	void *fdm;
	char buffer[3];

	f = open([file cString], O_RDONLY);

	if (f < 0) {
		return NO;
	}

	if (fstat(f, &filestat) < 0) {
		close(f);
		return NO;
	}

	if (!S_ISREG(filestat.st_mode)) {
		close(f);
		return NO;
	}

	/* TAG checking is adapted from XMMS */
	length = filestat.st_size;

	if (lseek(f, -128, SEEK_END) < 0) {
		/* File must be very short or empty. Forget it. */
		close(f);
		return NO;
	}    

	if (read(f, buffer, 3) != 3) {
		close(f);
		return NO;
	}
    
	if (!strncmp(buffer, "TAG", 3)) {
		length -= 128; /* Correct for id3 tags */
	}
    
	fdm = mmap(0, length, PROT_READ, MAP_SHARED, f, 0);
	if (fdm == MAP_FAILED) {
		close(f);
		return NO;
	}

	/* Scan the file for a XING header, or calculate the length,
	   or just scan the whole file and add everything up. */
	[self scanFile: fdm length: length];

	if (munmap(fdm, length) == -1) {
		close(f);
		return NO;
	}

	if (close(f) < 0) {
		return NO;
	}

	return YES;
}


- (NSString *) setInFile: (NSString *)inFile outFile: (NSString *)outFile
{
	struct stat stat;
 
	if((fd = open([inFile cString], O_RDONLY)) == -1) {
		return [NSString stringWithFormat: @"%@: %s\n", inFile, strerror(errno)];
	}

	if(fstat(fd, &stat) == -1) {
		return [NSString stringWithFormat: @"%@: %s\n", inFile, strerror(errno)];
	}

	if (!S_ISREG(stat.st_mode)) {
		return [NSString stringWithFormat: @"%@: %s\n", inFile, strerror(errno)];
	}
            
	[self calcLength: inFile];

	if((buf = mmap(0, length, PROT_READ, MAP_SHARED, fd, 0)) == MAP_FAILED) {
		return [NSString stringWithFormat: @"%@: %s\n", inFile, strerror(errno)];
	}
            

	outputFile = [outFile copy];
	return nil;
}

- (double) percentDone
{
	double ret = 0.;
	if (totalFrames != 0)
		ret = ((double)currentFrame * 100.) / (double)totalFrames;
	return ret;
}

- (enum mad_flow) readFromMmap: (struct mad_stream *)stream;
{
	void *mpegdata = NULL;
    
	/* libmad asks us for more data when it runs out. We don't have any more,
	   so we want to quit here. */
	if (done) {
		return MAD_FLOW_STOP;
	}

	mpegdata = buf;

	done = 1;

	mad_stream_buffer(stream, mpegdata, length - (mpegdata - buf));
    
	return MAD_FLOW_CONTINUE;
}

- (enum mad_flow) readHeader: (struct mad_header const *) header
{
	if (stopPlaying) {
		return MAD_FLOW_STOP;
	}

	currentFrame++;

	return MAD_FLOW_CONTINUE;
}

- (enum mad_flow) writeOutput: (struct mad_header const *) header pcmData: (struct mad_pcm *)pcm
{
	register int nsamples = pcm->length;
	mad_fixed_t const *left_ch = pcm->samples[0], *right_ch = pcm->samples[1];
    
	static unsigned char stream[1152*4]; /* 1152 because that's what mad has as a max; *4 because
	there are 4 distinct bytes per sample (in 2 channel case) */
	static unsigned int rate = 0;
	static int channels = 0;
	static struct audio_dither dither;

	register char * ptr = stream;
	register signed int sample;
	register mad_fixed_t tempsample;

	/* We need to know information about the file before we can open the playdevice
	in some cases. So, we do it here. */
	if (!playDevice) {
		channels = MAD_NCHANNELS(header);
		rate = header->samplerate;
		[self openPlayDevice: header];
	}
	if (!playDevice)
		return MAD_FLOW_STOP;

	if (pcm->channels == 2) {
		while (nsamples--) {
			tempsample = (mad_fixed_t)(*left_ch++);
			sample = (signed int) audio_linear_dither(16, tempsample, &dither);

#ifndef WORDS_BIGENDIAN
			*ptr++ = (unsigned char) (sample >> 0);
			*ptr++ = (unsigned char) (sample >> 8);
#else
			*ptr++ = (unsigned char) (sample >> 8);
			*ptr++ = (unsigned char) (sample >> 0);
#endif
            
			tempsample = (mad_fixed_t)(*right_ch++);
			sample = (signed int) audio_linear_dither(16, tempsample, &dither);
#ifndef WORDS_BIGENDIAN
			*ptr++ = (unsigned char) (sample >> 0);
			*ptr++ = (unsigned char) (sample >> 8);
#else
			*ptr++ = (unsigned char) (sample >> 8);
			*ptr++ = (unsigned char) (sample >> 0);
#endif
		}

		ao_play(playDevice, stream, pcm->length * 4);
	} else {
		while (nsamples--) {
			tempsample = (mad_fixed_t)(*left_ch++);
			sample = (signed int) audio_linear_dither(16, tempsample, &dither);
            
			/* Just duplicate the sample across both channels. */
#ifndef WORDS_BIGENDIAN
			*ptr++ = (unsigned char) (sample >> 0);
			*ptr++ = (unsigned char) (sample >> 8);
			*ptr++ = (unsigned char) (sample >> 0);
			*ptr++ = (unsigned char) (sample >> 8);
#else
			*ptr++ = (unsigned char) (sample >> 8);
			*ptr++ = (unsigned char) (sample >> 0);
			*ptr++ = (unsigned char) (sample >> 8);
			*ptr++ = (unsigned char) (sample >> 0);
#endif
		}

		ao_play(playDevice, stream, pcm->length * 4);
	}

	return MAD_FLOW_CONTINUE;        
}

@end
