/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  CDparanoiaController.m
 *
 *  Copyright (c) 2002-2005
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


#include "CDparanoiaController.h"
#include "CDparanoiaSettingsView.h"
#include "CDparanoiaParametersView.h"

#include "Constants.h"
#include "Functions.h"
#include "Track.h"

#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]



static CDparanoiaController *singleInstance = nil;
static NSFileManager *fileMan = nil;

@interface CDparanoiaController (Private)
- (void) initializeFromDefaults;
- (void) waitForTaskExit;
- (void) sendOutputString: (NSString *) outString;
- (void) setStatus: (ProcessStatus) status;
- (NSString *) makeOutfileNameForTrack: (int)index
                                  onCD: (NSString *)cddbId
                               tempDir: (NSString *)tempDir;
@end

//
// private interface
//

@implementation CDparanoiaController (Private)

/**
 * Tries to find the mkisofs executable in case it is not already set
 * in the defaults.
 */
- (void) initializeFromDefaults
{
    NSString *program;
    NSDictionary *params = [[NSUserDefaults standardUserDefaults]
        dictionaryForKey: @"CDparanoiaParameters"];
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
        program = which(@"cdparanoia");
    }

    [mutableParams setObject: program forKey: @"Program"];

    [[NSUserDefaults standardUserDefaults] setObject: mutableParams
                                              forKey: @"CDparanoiaParameters"];
    RELEASE(mutableParams);
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *) makeOutfileNameForTrack: (int)index
                                  onCD: (NSString *)cddbId
                               tempDir: (NSString *)tempDir
{
	NSString *grabFile;

	grabFile = [tempDir stringByAppendingPathComponent:
                                [NSString stringWithFormat: @"%@_track%d.wav", cddbId, index]];

	return grabFile;
}

- (void) waitForTaskExit
{
	trackSize = 0xffffffff;

	while ([cdpTask isRunning]) {
		NSData *inData;
        while ((inData = [[[cdpTask standardError] fileHandleForReading] availableData]) && [inData length]) {
			int i, count;
			unsigned long from = 0, to = 0;
			NSString *aLine;
			NSArray *theOutput;
			NSRange aRange;

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

				aRange = [aLine rangeOfString: @"from sector "];
				if (aRange.location != NSNotFound) {
					[statusLock lock];
					from = [[aLine substringWithRange: NSMakeRange(aRange.location+11,8)] intValue];
					[statusLock unlock];
				}
				aRange = [aLine rangeOfString: @"to sector "];
				if (aRange.location != NSNotFound) {
					to = [[aLine substringWithRange: NSMakeRange(aRange.location+11,8)] intValue];
					trackSize = (to + 1 - from) * 2352;
				}
			}
		}
	}
}

- (void) sendOutputString: (NSString *) outString
{
	NSString *outLine;

	outLine = [NSString stringWithFormat: @"**** %@ ****", outString];

	[[NSDistributedNotificationCenter defaultCenter]
					postNotificationName: ExternalToolOutput
					object: nil
					userInfo: [NSDictionary dictionaryWithObject: outLine forKey: @"Output"]];
}

- (void) setStatus: (ProcessStatus) status
{
	[statusLock lock];
	ripStatus.processStatus = status;
	[statusLock unlock];
}

@end

//
// public interface
//

@implementation CDparanoiaController

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
	return @"cdparanoia";
}

- (id<PreferencesModule>) preferences;
{
	return AUTORELEASE([CDparanoiaSettingsView singleInstance]);
}

- (id<PreferencesModule>) parameters;
{
	return AUTORELEASE([CDparanoiaParametersView singleInstance]);
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
		singleInstance = [[CDparanoiaController alloc] init];
	}

	return singleInstance;
}


//
// AudioConverter methods
//
- (NSString *) fileType
{
    return @"cd";
}


- (ToolStatus) getStatus
{
	ToolStatus status;
    Track *track = [allTracks objectAtIndex: currentTrack];
    int count = [allTracks count];

	[statusLock lock];
    ripStatus.trackName = [track description];
    if (track != nil)
    	ripStatus.trackProgress = [[[fileMan fileAttributesAtPath: [track storage] traverseLink: NO]
	    									objectForKey: NSFileSize] doubleValue] * 100 / trackSize;
    else {
        ripStatus.trackProgress = 0;
    }
    if (count == 0) {
        ripStatus.entireProgress = 0;
    } else {
	    ripStatus.entireProgress = currentTrack * 100 / count;
        ripStatus.entireProgress += ripStatus.trackProgress / count;
    }

	status = ripStatus;
	[statusLock unlock];

	return status;
}

- (BOOL) convertTracks: (NSArray *)tracks
	    withParameters: (NSDictionary *) parameters
{
	BOOL ret = YES;
	int termStatus;
	NSString *cdparanoia;
    NSString *fileName;
	NSMutableArray *cdpArgs;
	NSString *cdpParam;
	NSPipe *stdOut;
    Track *track;
    NSDictionary *cdpDefaults = [parameters objectForKey: @"CDparanoiaParameters"];
    NSDictionary *sesDefaults = [parameters objectForKey: @"SessionParameters"];

	// set up cdparanoia task
	cdparanoia = [cdpDefaults objectForKey: @"Program"];
    if (!checkProgram(cdparanoia))
        return NO;

    allTracks = tracks;

    ripStatus.entireProgress = 0;
    ripStatus.trackProgress = 0;

    for (currentTrack = 0; (currentTrack < [allTracks count]) && (ret != NO); currentTrack++) {
        track = [tracks objectAtIndex: currentTrack];

    	cdpArgs = [NSMutableArray arrayWithObjects: @"-w", nil];

    	// which device to use?
	    [cdpArgs addObject: [NSString stringWithFormat: @"-d"]];
    	[cdpArgs addObject: [NSString stringWithFormat: @"%@", [parameters objectForKey: @"SourceDevice"]]];

	    // any extra parameters?
    	cdpParam = [cdpDefaults objectForKey: @"DisableParanoia"];
	    if (cdpParam) {
		    [cdpArgs addObject: @"-Z"];
    	}
	    cdpParam = [cdpDefaults objectForKey: @"DisableExtraParanoia"];
    	if (cdpParam) {
	    	[cdpArgs addObject: @"-Y"];
    	}
	    cdpParam = [cdpDefaults objectForKey: @"DisableScratchRepair"];
    	if (cdpParam) {
	    	[cdpArgs addObject: @"-W"];
    	}

        // add track number and outfile name to args list
 	    [cdpArgs addObject: [[track source] substringFromIndex: 14]];

        fileName = [self makeOutfileNameForTrack: [[[track source] substringFromIndex: 14] intValue]
                                            onCD: [parameters objectForKey: @"CddbId"]
                                         tempDir: [sesDefaults objectForKey: @"TempDirectory"]];

    	[cdpArgs addObject: fileName];
        [track setStorage: fileName];

	    cdpTask = [[NSTask alloc] init];
    	stdOut = [[NSPipe alloc] init];

	    [cdpTask setLaunchPath: cdparanoia];
	    [cdpTask setArguments: cdpArgs];
    	[cdpTask setStandardError: stdOut];

    	[self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
											cdparanoia, [cdpArgs componentsJoinedByString: @" "]]];

	    [cdpTask launch];

	    ripStatus.processStatus = isConverting;

    	/*
    	 * Now we wait until the cdparanoia task is over and process its output.
    	 */
    	[self waitForTaskExit];

    	/*
    	 * If cdparanoia did not terminate gracefully we stop the whole affair.
    	 * We delete in any case the actual (not finished) file.
    	 */
    	termStatus = [cdpTask terminationStatus];	// FreeBSD needs an lvalue for the WIF* macros
    	if ((WIFEXITED(termStatus) == 0)
    			|| WIFSIGNALED(termStatus)
    			|| (ripStatus.processStatus == isCancelled)) {
    		[self sendOutputString: [NSString stringWithFormat: _(@"Removing temporary file %@."), [track storage]]];
    		if (![fileMan removeFileAtPath: [track storage] handler: nil]) {
    			[self sendOutputString: _(@"Removing file failed.")];
    		}
    		ripStatus.processStatus = isCancelled;
    		ret = NO;
    	}

    	RELEASE(stdOut);
    	RELEASE(cdpTask);
    	cdpTask = nil;
    }

	if (ripStatus.processStatus == isConverting) {
        [self setStatus: isStopped];
	}

    allTracks = nil;
	return ret;
}

- (BOOL) stop: (BOOL)immediately
{
	if (cdpTask && (ripStatus.processStatus == isConverting)) {
		[self sendOutputString: _(@"Terminating process.")];
        [self setStatus: isCancelled];
		[cdpTask terminate];
	}
	return YES;
}

- (long) duration: (NSString *)fileName
{
    return 0;
}

- (unsigned) size: (NSString *)fileName
{
    return 0;
}

@end
