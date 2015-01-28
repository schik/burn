/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  MP3ToWavController.m
 *
 *  Copyright (c) 2005
 *
 *  Author: Andreas Heppel <aheppel@web.de>
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

#include <sys/types.h>
#include <sys/wait.h>
#include <ao/ao.h>

#include "MP3ToWavController.h"
#include "MadFunctions.h"

#include "Constants.h"
#include "Functions.h"
#include "Track.h"

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]



static MP3ToWavController *singleInstance = nil;

@interface MP3ToWavController (Private)
- (void) sendOutputString: (NSString *) outString;
- (void) setStatus: (ProcessStatus) status;
- (NSString *) makeOutfileNameForTrack: (NSString *)trackName
                               tempDir: (NSString *)tempDir;
@end

//
// private interface
//

@implementation MP3ToWavController (Private)

- (NSString *) makeOutfileNameForTrack: (NSString *)trackName
                               tempDir: (NSString *)tempDir
{
	NSString *outName;
    NSString *baseName = [[trackName lastPathComponent] stringByDeletingPathExtension];

	outName = [tempDir stringByAppendingPathComponent:
                           [NSString stringWithFormat: @"%@.wav", baseName]];

	return outName;
}

- (void) sendOutputString: (NSString *) outString
{
	NSString *outLine;

	outLine = [NSString stringWithFormat: @"%@", outString];

	[[NSDistributedNotificationCenter defaultCenter]
					postNotificationName: ExternalToolOutput
					object: nil
					userInfo: [NSDictionary dictionaryWithObject: outLine forKey: @"Output"]];
}

- (void) setStatus: (ProcessStatus) status
{
	[statusLock lock];
	convStatus.processStatus = status;
	[statusLock unlock];
}

@end

//
// public interface
//

@implementation MP3ToWavController

- (id) init
{
	self = [super init];

	if (self) {
		statusLock = [NSLock new];
        playBuffer = nil;
	}

	return self;
}


- (void) dealloc
{
	singleInstance = nil;
	RELEASE(statusLock);

	[super dealloc];
}

//
// BurnTool methods
//

- (NSString *) name
{
	return @"mp3towav";
}

- (id<PreferencesModule>) preferences;
{
	return nil;
}

- (id<PreferencesModule>) parameters;
{
	return nil;
}

- (void) cleanUp
{
    /*
     * No need to clean anything, as we forget about what
     * we ripped.
     */
}


//
// class methods
//
+ (id) singleInstance
{
	if (! singleInstance) {
		singleInstance = [[MP3ToWavController alloc] init];
	}

	return singleInstance;
}


//
// AudioConverter methods
//
- (NSString *) fileType
{
    return @"mp3";
}

/**
 * <p>We create a temporary file buffer and make it calculate its
 * size. This size is of type @c mad_timer_t which must be converted
 * to audio CD frames using the function @c mad_timer_count.</p>
 */
- (long) duration: (NSString *)fileName
{
    long duration;
    PlayBuffer *pb = [PlayBuffer new];
    [pb calcLength: fileName];
    duration = mad_timer_count([pb duration], MAD_UNITS_75_FPS);
    DESTROY(pb);
    return duration;
}

/*
 * <p>Calculate the size in bytes by converting the number of
 * frames into audio CD size.</p>
 */
- (unsigned) size: (NSString *)fileName
{
    long duration = [self duration: fileName];
    unsigned size = framesToAudioSize(duration);
    return size;
}


- (ToolStatus) getStatus
{
	ToolStatus status;

	[statusLock lock];
	status = convStatus;
	[statusLock unlock];

	return status;

}

- (BOOL) convertTracks: (NSArray *)tracks
	    withParameters: (NSDictionary *) parameters
{
	BOOL ret = YES;
    NSString *fileName;
    Track *track;
    NSDictionary *sesDefaults = [parameters objectForKey: @"SessionParameters"];
    struct mad_decoder decoder;
    int trackIndex;
    int trackCount;

    allTracks = tracks;
    trackCount = [allTracks count];

    convStatus.entireProgress = 0;
    convStatus.trackProgress = 0;

    /*
     * Initialize the audio output library.
     */
    ao_initialize();

    [self setStatus: isConverting];

    for (trackIndex = 0; (trackIndex < trackCount) && (NO != ret); trackIndex++) {
        /*
         * Did the user click abort?
         */
	    if (convStatus.processStatus == isCancelled) {
            break;
        }

        track = [allTracks objectAtIndex: trackIndex];

        [statusLock lock];
        convStatus.trackName = [track description];
        if (nil != track) {
            convStatus.trackProgress = [playBuffer percentDone];
        } else {
            convStatus.trackProgress = 0;
        }
        if (0 == trackCount) {
            convStatus.entireProgress = 0;
        } else {
            convStatus.entireProgress = trackIndex * 100. / trackCount;
        }
        [statusLock unlock];

        fileName = [self makeOutfileNameForTrack: [track source]
                                         tempDir: [sesDefaults objectForKey: @"TempDirectory"]];

        [track setStorage: fileName];

        [self sendOutputString: [NSString stringWithFormat: _(@"Converting track %@ to %@"),
										[track description], fileName]];

        playBuffer = [PlayBuffer new];
        [playBuffer setInFile: [track source] outFile: fileName];
            
        mad_decoder_init(&decoder, playBuffer, read_from_mmap, read_header, /*filter*/0,
                            output, /*error*/0, /* message */ 0);

        mad_decoder_run(&decoder, MAD_DECODER_MODE_SYNC);

        mad_decoder_finish(&decoder);
        DESTROY(playBuffer);
    }

    ao_shutdown();

	if (convStatus.processStatus == isConverting) {
        [self setStatus: isStopped];
	}

    allTracks = nil;
	return ret;
}

- (BOOL) stop: (BOOL)immediately
{
	if (convStatus.processStatus == isConverting) {
		[self sendOutputString: _(@"Terminating process.")];
        [self setStatus: isCancelled];
        [playBuffer stop];
	}
	return YES;
}

@end
