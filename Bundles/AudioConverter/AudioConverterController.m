/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  AudioConverterController.m
 *
 *  Copyright (c) 2016
 *
 *  Author: Andreas Schik <andreas@schik.de>
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

#include "AudioConverterController.h"
#include "AudioConverterSettingsView.h"

#include "Constants.h"
#include "Functions.h"
#include "Track.h"

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]



static AudioConverterController *singleInstance = nil;
static NSFileManager *fileMan = nil;

@interface AudioConverterController (Private)
- (void) initializeFromDefaults;
- (void) waitForTaskExit;
- (void) sendOutputString: (NSString *) outString;
- (void) setStatus: (ProcessStatus) status;
- (NSString *) makeOutfileNameForTrack: (NSString *)trackName
                               tempDir: (NSString *)tempDir;
@end

//
// private interface
//

@implementation AudioConverterController (Private)

/**
 * Tries to find the ffmpeg/avconv executable in case it is not already set
 * in the defaults.
 */
- (void) initializeFromDefaults
{
    NSString *program;
    NSDictionary *params = [[NSUserDefaults standardUserDefaults]
        dictionaryForKey: @"AudioConverterParameters"];
    NSMutableDictionary *mutableParams = nil;

    // We need a mutable dict, otherwise we cannot save our prefs.
    if (nil == params) {
        // The mutable dict must be retained to make life easier for us.
        mutableParams = [NSMutableDictionary new];
    } else {
        mutableParams = [params mutableCopy];
    }

    program = [mutableParams objectForKey: @"Program"];
    if ((nil != program) && ![program isEqualToString: NOT_FOUND]) {
        if (!checkProgram(program)) {
            program = NOT_FOUND;
        }
    } else {
        program = which(@"ffmpeg");
        if ([program isEqualToString: NOT_FOUND]) {
            program = which(@"avconv");
        }
    }

    [mutableParams setObject: program forKey: @"Program"];

    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"AudioConverterParameters"];
    RELEASE(mutableParams);
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *) makeOutfileNameForTrack: (NSString *)trackName
                               tempDir: (NSString *)tempDir
{
	NSString *outName;
    NSString *baseName = [[trackName lastPathComponent] stringByDeletingPathExtension];

	outName = [tempDir stringByAppendingPathComponent:
                           [NSString stringWithFormat: @"%@.wav", baseName]];

	return outName;
}

- (void) waitForTaskExit
{
	while ([avconvTask isRunning]) {
		NSData *inData;
        while ((inData = [[[avconvTask standardError] fileHandleForReading] availableData]) && [inData length]) {
			int i, count;
			NSString *aLine;
			NSArray *theOutput;

			theOutput = [[[NSString alloc] initWithData: inData
									encoding: NSISOLatin1StringEncoding]
									componentsSeparatedByString: @"\n"];

			count = [theOutput count];

			for (i = 0; i < count; i++) {
				aLine = [theOutput objectAtIndex: i];

				[[NSDistributedNotificationCenter defaultCenter]
					postNotificationName: ExternalToolOutput
					object: nil
					userInfo: [NSDictionary dictionaryWithObject: aLine forKey: @"Output"]];
			}
		}
	}
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

@implementation AudioConverterController

- (id) init
{
	self = [super init];

	if (self) {
		if (!fileMan) {
			fileMan = [NSFileManager defaultManager];
		}
		statusLock = [NSLock new];
        [self initializeFromDefaults];
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
	return @"audioconverter";
}

- (id<PreferencesModule>) preferences;
{
	return AUTORELEASE([AudioConverterSettingsView singleInstance]);
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
		singleInstance = [[AudioConverterController alloc] init];
	}

	return singleInstance;
}


//
// AudioConverter methods
//
- (BOOL) isCDGrabber
{
    return NO;
}

- (long) duration: (NSString *)fileName
{
	int i, count;
    long duration = 0;
	NSString *avconv;
	NSMutableArray *args;
	NSPipe *stdOut;
	NSArray *output;
	NSString *outLine;
    NSDictionary *acDefaults = [[NSUserDefaults standardUserDefaults] objectForKey: @"AudioConverterParameters"];

	// set up avconv task
	avconv = [acDefaults objectForKey: @"Program"];
    if (!checkProgram(avconv))
        return duration;

    args = [NSMutableArray arrayWithObjects: @"-i", fileName, nil];

    avconvTask = [[NSTask alloc] init];
    stdOut = [[NSPipe alloc] init];

    [avconvTask setLaunchPath: avconv];
    [avconvTask setArguments: args];
   	[avconvTask setStandardOutput: stdOut];
   	[avconvTask setStandardError: stdOut];

   	[self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
										avconv, [args componentsJoinedByString: @" "]]];

    [avconvTask launch];

   	/*
   	 * Now we wait until the avconv task is over and process its output.
   	 */
   	[avconvTask waitUntilExit];

	output = [[[NSString alloc] initWithData: [[stdOut fileHandleForReading] availableData]
									encoding: NSISOLatin1StringEncoding]
					componentsSeparatedByString: @"\n"];

	count = [output count];

	/*
	 * Skip the first line in output. It contains only header data.
	 */
	for (i = 1; i < count; i++) {
		NSRange range;
		outLine = [output objectAtIndex: i];

		range = [outLine rangeOfString: @"Duration:"];
		if (range.location != NSNotFound) {
			if ([outLine length] > range.location+9) {
				NSString *time = [outLine substringWithRange: NSMakeRange(range.location+10, 11)];
                NSArray *parts = [time componentsSeparatedByString: @":"];
                duration = [[parts objectAtIndex: 0] intValue] * 3600;
                duration += [[parts objectAtIndex: 1] intValue] * 60;
                duration += [[parts objectAtIndex: 2] intValue];
                duration *= 75;
            } else {
    			continue;
            }
		}
	}

	RELEASE(stdOut);
	RELEASE(avconvTask);
    return duration;
}

- (unsigned) size: (NSString *)fileName
{
    long duration = [self duration: fileName];
    unsigned size = framesToAudioSize(duration);
    return size;
}


- (ToolStatus) getStatus
{
	ToolStatus status;
    Track *track = [allTracks objectAtIndex: currentTrack];
    int count = [allTracks count];

    [statusLock lock];
    convStatus.trackName = [track description];
    convStatus.trackProgress = 0;
    if (0 == count) {
        convStatus.entireProgress = 0;
    } else {
        convStatus.entireProgress = currentTrack * 100. / count;
    }
	status = convStatus;
	[statusLock unlock];

	return status;

}

- (BOOL) convertTracks: (NSArray *)tracks
	    withParameters: (NSDictionary *) parameters
{
	BOOL ret = YES;
	int termStatus;
	NSString *avconv;
	NSMutableArray *args;
    NSString *fileName;
	NSPipe *stdOut;
    Track *track;
    NSDictionary *acDefaults = [parameters objectForKey: @"AudioConverterParameters"];
    NSDictionary *sesDefaults = [parameters objectForKey: @"SessionParameters"];

	// set up avconv task
	avconv = [acDefaults objectForKey: @"Program"];
    if (!checkProgram(avconv))
        return NO;

    allTracks = tracks;

    convStatus.entireProgress = 0;
    convStatus.trackProgress = 0;

    [self setStatus: isConverting];

    for (currentTrack = 0; (currentTrack < [allTracks count]) && (NO != ret); currentTrack++) {
        /*
         * Did the user click abort?
         */
	    if (convStatus.processStatus == isCancelled) {
            break;
        }

        track = [allTracks objectAtIndex: currentTrack];

    	args = [NSMutableArray arrayWithObjects: @"-y", @"-i", [track source], @"-vn", @"-ar", @"44100", nil];

        fileName = [self makeOutfileNameForTrack: [track source]
                                         tempDir: [sesDefaults objectForKey: @"TempDirectory"]];

    	[args addObject: fileName];
        [track setStorage: fileName];

	    avconvTask = [[NSTask alloc] init];
    	stdOut = [[NSPipe alloc] init];

	    [avconvTask setLaunchPath: avconv];
	    [avconvTask setArguments: args];
   	    [avconvTask setStandardOutput: stdOut];
    	[avconvTask setStandardError: stdOut];

    	[self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
											avconv, [args componentsJoinedByString: @" "]]];

        [avconvTask launch];

    	/*
    	 * Now we wait until the avconv task is over and process its output.
    	 */
    	[self waitForTaskExit];

    	/*
    	 * If avconv did not terminate gracefully we stop the whole affair.
    	 * We delete in any case the actual (not finished) file.
    	 */
    	termStatus = [avconvTask terminationStatus];	// FreeBSD needs an lvalue for the WIF* macros
    	if ((WIFEXITED(termStatus) == 0)
    			|| WIFSIGNALED(termStatus)
    			|| (convStatus.processStatus == isCancelled)) {
    		[self sendOutputString: [NSString stringWithFormat: _(@"Removing temporary file %@."), [track storage]]];
    		if (![fileMan removeFileAtPath: [track storage] handler: nil]) {
    			[self sendOutputString: _(@"Removing file failed.")];
    		}
    		convStatus.processStatus = isCancelled;
    		ret = NO;
    	}

    	RELEASE(stdOut);
    	RELEASE(avconvTask);
    	avconvTask = nil;
    }

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
		[avconvTask terminate];
	}
	return YES;
}

@end
