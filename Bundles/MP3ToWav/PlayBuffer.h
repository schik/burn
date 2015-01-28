/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  PlayBuffer.m
 *
 *  Copyright (c) 2005
 *
 *  Author: Andreas Schik <aheppel@web.de>
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

#ifndef PLAYBUFFER_H_INC
#define PLAYBUFFER_H_INC

#include <sys/types.h>
#include <ao/ao.h>
#include <mad.h>

#include <Foundation/Foundation.h>

@interface PlayBuffer : NSObject
{
    int fd;

    /* The buffer of raw mpeg data for libmad to decode */
    void * buf;

    /* length of the current stream, corrected for id3 tags */
    ssize_t length;

    /* have we finished fetching this file? (only in non-mmap()'ed case */
    int done;

    /* total number of frames */
    unsigned long totalFrames;

    /* total duration of the file */
    mad_timer_t duration;

    unsigned long currentFrame;
    
    /*
     * Output related ivars.
     */
    NSString *outputFile;
    ao_device *playDevice;
   
    BOOL stopPlaying;
}

- (id) init;

- (void) stop;

/*
 * Access methods
 */
- (mad_timer_t) duration;

- (BOOL) calcLength: (NSString *)file;
- (NSString *) setInFile: (NSString *)inFile outFile: (NSString *)outFile;
- (double) percentDone;

- (enum mad_flow) readFromMmap: (struct mad_stream *)stream;
- (enum mad_flow) readHeader: (struct mad_header const *) header;
- (enum mad_flow) writeOutput: (struct mad_header const *) header pcmData: (struct mad_pcm *)pcm;

@end

#endif
