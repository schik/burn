/* vim: set ft=objc et sw=4 ts=4 expandtab nowrap: */
/*
 *  CDrecordController.m
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
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <sys/types.h>
#include <sys/wait.h>


#include "CDrecordController.h"

#include "CDrecordSettingsView.h"
#include "CDrecordParametersView.h"

#include "Constants.h"
#include "Functions.h"

#ifdef _
#undef _
#endif

#define _(X) \
    [[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]



static CDrecordController *singleInstance = nil;




@implementation CDrecordController

- (id) init
{
    self = [super init];

    if (self) {
        statusLock = [NSLock new];
        drivers = [NSMutableArray new];
        drives = [NSMutableDictionary new];
        [self checkForDrives];
        [self getCDrecordDrivers];
    }

    return self;
}


- (void) dealloc
{
    singleInstance = nil;
    RELEASE(drives);
    RELEASE(drivers);
    RELEASE(statusLock);

    [super dealloc];
}


//
// BurnTool methods
//

- (NSString *) name
{
    return @"cdrecord";
}

- (id<PreferencesModule>) preferences;
{
    return [[CDrecordSettingsView singleInstance] autorelease];
}

- (id<PreferencesModule>) parameters;
{
    return [[CDrecordParametersView singleInstance] autorelease];
}

- (void) cleanUp
{
    /*
     * Nothing to do here
     */
}


+ (id) singleInstance
{
    if (! singleInstance) {
        singleInstance = [[CDrecordController alloc] init];
    }

    return singleInstance;
}

//
// Burner methods
//

- (NSArray *) availableDrives
{
    return [drives allKeys];
}

- (NSDictionary *) mediaInformation: (NSDictionary *) parameters
{
    NSEnumerator *e = [drives keyEnumerator];
    id o;

    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    while (nil != (o = [e nextObject])) {
        NSDictionary *info = [self mediaInformationForDevice: o
                                                  parameters: parameters];
        [result setObject: info forKey: o];
    }
    return result;
}

#ifdef WODIM

- (NSDictionary *) mediaInformationForDevice: (NSString *) device
                                  parameters: (NSDictionary *) parameters
{
	int i, count;
	NSString *cdrecord;
	NSMutableArray *cdrArgs;
	NSPipe *stdOut;
	NSArray *cdrOutput;
	NSString *outLine;

	// cdrecord does not deliver useful information about
	// the media on my drive, thus I don't know the output
	// preset the dictionary with some defaults
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									_(@"Unknown"), @"type",
									@"n/a", @"vendor",
									@"n/a", @"speed",
									@"n/a", @"capacity",
									@"n/a", @"empty",
									@"n/a", @"remCapacity",
									@"n/a", @"sessions",
									@"n/a", @"appendable", nil];


	cdrecord = [[parameters objectForKey: @"CDrecordParameters"]
                    objectForKey: @"Program"];

    if (!checkProgram(cdrecord))
        return info;

    cdrArgs = [NSMutableArray arrayWithObjects: @"-v", nil];
	NS_DURING
        [self addDevice: device
          andParameters: parameters
            toArguments: cdrArgs];
	NS_HANDLER
		[self sendOutputString: [NSString stringWithFormat: @"Error: %@ -> %@",
												[localException name],
												[localException reason]] raw: NO];
		NS_VALRETURN(nil);
	NS_ENDHANDLER

    [cdrArgs addObject: @"-atip"];

	// set up cdrecord task
	cdrTask = [[NSTask alloc] init];
	stdOut = [[NSPipe alloc] init];

	[cdrTask setLaunchPath: cdrecord];

	[cdrTask setArguments: cdrArgs];
	[cdrTask setStandardOutput: stdOut];
	[cdrTask setStandardError: stdOut];

	[self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
										cdrecord, [cdrArgs componentsJoinedByString: @" "]] raw: NO];
	[cdrTask launch];

	[cdrTask waitUntilExit];

	/*
	 * If cdrecord did not terminate gracefully we stop the whole affair.
	 * We delete in any case the actual (not finished) file.
	 */
	{
        int termStatus = [cdrTask terminationStatus];	// FreeBSD needs an lvalue for the WIF* macros
    	if ((WIFEXITED(termStatus) == 0)
	    		|| WIFSIGNALED(termStatus)) {
		    [info setObject: _(@"Unknown") forKey: @"type"];
    		return info;
        }
	}

	cdrOutput = [[[NSString alloc] initWithData: [[stdOut fileHandleForReading] availableData]
									encoding: NSISOLatin1StringEncoding]
					componentsSeparatedByString: @"\n"];

	count = [cdrOutput count];

	/*
	 * Skip the first line in output. It contains only header data.
	 */
	for (i = 1; i < count; i++) {
		NSRange range;
		outLine = [cdrOutput objectAtIndex: i];

        // wodim is rather stupid as it can only read ATIP info, which
        // itself does not contain info about whether the disk is empty
        // or not. If we get ATIP info, we assume that the disk is empty.
		range = [outLine rangeOfString: @"ATIP info from disk"];
		if (range.location != NSNotFound) {
			[info setObject: @"yes" forKey: @"empty"];
			continue;
		}

		// check for not erasable first, then for erasable
		// if none applies don#t change the dictionary
		range = [outLine rangeOfString: @"Is not erasable"];
		if (range.location != NSNotFound) {
			[info setObject: @"CD-R" forKey: @"type"];
			continue;
		} else {
			range = [outLine rangeOfString: @"Is erasable"];
			if (range.location != NSNotFound) {
				[info setObject: @"CD-RW" forKey: @"type"];
				continue;
			}
		}

		// search manufacturer/vendor
		range = [outLine rangeOfString: @"Manufacturer"];
		if (range.location != NSNotFound) {
			if ([outLine length] > range.location+13)
				[info setObject: [outLine substringFromIndex: 14] forKey: @"vendor"];
			continue;
		}

		range = [outLine rangeOfString: @"  speed low"];
		if (range.location != NSNotFound) {
			NSRange range1 = [outLine rangeOfString: @"speed high"];
			if ([outLine length] > range1.location+11)
				[info setObject: [NSString stringWithFormat: @"%dX - %dX",
									[[outLine substringFromIndex: 13] intValue],
									[[outLine substringFromIndex: range1.location+12] intValue]]
						forKey: @"speed"];
			continue;
		}
		range = [outLine rangeOfString: @"ATIP start of lead out"];
		if (range.location != NSNotFound) {
			if ([outLine length] > 41) {
				int frames = [[outLine substringFromIndex: 26] intValue];
				NSString *str = [NSString stringWithFormat: @"%@ - %d blocks, %d/%d MB",
									[outLine substringWithRange: NSMakeRange(34,8)],
									frames,
									frames * 2048 / (1024*1024),
									frames * 2352 / (1024*1024)];
				[info setObject: str forKey: @"capacity"];
			} else
				[info setObject: [outLine substringFromIndex: 26] forKey: @"capacity"];

			continue;
		}
	}

	RELEASE(stdOut);
	RELEASE(cdrTask);

	return info;
}
#else
- (NSDictionary *) mediaInformationForDevice: (NSString *) device
                                  parameters: (NSDictionary *) parameters
{
    int i, count;
    NSString *cdrecord;
    NSMutableArray *cdrArgs;
    NSPipe *stdOut;
    NSArray *cdrOutput;
    NSString *outLine;

    // cdrecord does not deliver useful information about
    // the media on my drive, thus I don't know the output
    // preset the dictionary with some defaults
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    _(@"Unknown"), @"type",
                                    @"n/a", @"vendor",
                                    @"n/a", @"speed",
                                    @"n/a", @"capacity",
                                    @"n/a", @"empty",
                                    @"n/a", @"remCapacity",
                                    @"n/a", @"sessions",
                                    @"n/a", @"appendable", nil];


    cdrecord = [[parameters objectForKey: @"CDrecordParameters"]
                    objectForKey: @"Program"];

    if (!checkProgram(cdrecord))
        return info;

    cdrArgs = [NSMutableArray arrayWithObjects: @"-v", nil];
    NS_DURING
        [self addDevice: device
          andParameters: parameters
            toArguments: cdrArgs];
    NS_HANDLER
        [self sendOutputString: [NSString stringWithFormat: @"Error: %@ -> %@",
                                                [localException name],
                                                [localException reason]] raw: NO];
        NS_VALRETURN(nil);
    NS_ENDHANDLER

    [cdrArgs addObject: @"-minfo"];

    // set up cdrecord task
    cdrTask = [[NSTask alloc] init];
    stdOut = [[NSPipe alloc] init];

    [cdrTask setLaunchPath: cdrecord];

    [cdrTask setArguments: cdrArgs];
    [cdrTask setStandardOutput: stdOut];
    [cdrTask setStandardError: stdOut];

    [self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
                                        cdrecord, [cdrArgs componentsJoinedByString: @" "]] raw: NO];
    [cdrTask launch];

    [cdrTask waitUntilExit];

    /*
     * If cdrecord did not terminate gracefully we stop the whole affair.
     * We delete in any case the actual (not finished) file.
     */
    {
        int termStatus = [cdrTask terminationStatus];   // FreeBSD needs an lvalue for the WIF* macros
        if ((WIFEXITED(termStatus) == 0)
                || WIFSIGNALED(termStatus)) {
            [info setObject: _(@"Unknown") forKey: @"type"];
            return info;
        }
    }

    cdrOutput = [[[NSString alloc] initWithData: [[stdOut fileHandleForReading] availableData]
                                    encoding: NSISOLatin1StringEncoding]
                    componentsSeparatedByString: @"\n"];

    count = [cdrOutput count];

    /*
     * Skip the first line in output. It contains only header data.
     */
    for (i = 1; i < count; i++) {
        NSRange range;
        outLine = [cdrOutput objectAtIndex: i];

        // check for not erasable first, then for erasable
        // if none applies don#t change the dictionary
        if ([outLine hasPrefix: @"Mounted media type:"]) {
            [info setObject: [[outLine substringFromIndex: 19] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]]
                     forKey: @"type"];
            continue;
        }

        if ([outLine hasPrefix: @"disk status:"]) {
            NSString *tmp = [[outLine substringFromIndex: 12] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            if ([tmp isEqualToString: @"empty"]) {
                [info setObject: @"yes" forKey: @"empty"];
            } else {
                [info setObject: @"no" forKey: @"empty"];
                if ([tmp isEqualToString: @"complete"]) {
                    [info setObject: @"no" forKey: @"appendable"];
                } else {
                    [info setObject: @"yes" forKey: @"appendable"];
                }
            }
            continue;
        }
        // search manufacturer/vendor
        if ([outLine hasPrefix: @"Manufacturer:"]) {
            NSString *tmp = [[outLine substringFromIndex: 13] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            [info setObject: tmp forKey: @"vendor"];
            continue;
        }

        if ([outLine hasPrefix: @"number of sessions:"]) {
            NSString *tmp = [[outLine substringFromIndex: 19] stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
            [info setObject: tmp forKey: @"sessions"];
            continue;
        }

        range = [outLine rangeOfString: @"ATIP start of lead out:"];
        if (range.location != NSNotFound) {
            if ([outLine length] > 41) {
                int frames = [[outLine substringFromIndex: 26] intValue];
                NSString *str = [NSString stringWithFormat: @"%@ - %d blocks, %d/%d MB",
                                    [outLine substringWithRange: NSMakeRange(34,8)],
                                    frames,
                                    frames * 2048 / (1024*1024),
                                    frames * 2352 / (1024*1024)];
                [info setObject: str forKey: @"capacity"];
            } else
                [info setObject: [outLine substringFromIndex: 26] forKey: @"capacity"];

            continue;
        }
    }

    RELEASE(stdOut);
    RELEASE(cdrTask);

    return info;
}
#endif // WODIM

- (BOOL) isWritableMediumInDevice: (NSString *) device
                       parameters: (NSDictionary *)parameters
{
    BOOL inserted = NO;
    NSDictionary *info = [self mediaInformationForDevice: device
                                              parameters: parameters];
    if (nil != info) {
        NSString *empty = [info objectForKey: @"empty"];
        inserted =[empty isEqualToString: @"yes"];
    }
    return inserted;
}

- (BOOL) blankCDRW: (EBlankingMode) mode
          inDevice: (NSString *) device
    withParameters: (NSDictionary *) parameters
{
    NSString *cdrecord;
    NSMutableArray *cdrArgs;
    NSPipe *stdOut;

    cdrecord = [[parameters objectForKey: @"CDrecordParameters"]
                    objectForKey: @"Program"];

    if (!checkProgram(cdrecord))
        return NO;

    cdrArgs = [NSMutableArray arrayWithObjects: @"-v", nil];
    NS_DURING
        [self addDevice: device
          andParameters: parameters
            toArguments: cdrArgs];
    NS_HANDLER
        [self sendOutputString: [NSString stringWithFormat: @"Error: %@ -> %@",
                                                [localException name],
                                                [localException reason]] raw: NO];
        NS_VALRETURN(NO);
    NS_ENDHANDLER

    [cdrArgs addObject: @"-eject"];
    [cdrArgs addObject: [NSString stringWithFormat: @"blank=%@",mode==fullBlank?@"all":@"fast"]];

    // set up cdrecord task
    cdrTask = [[NSTask alloc] init];
    stdOut = [[NSPipe alloc] init];

    [cdrTask setLaunchPath: cdrecord];

    [cdrTask setArguments: cdrArgs];
    [cdrTask setStandardOutput: stdOut];
    [cdrTask setStandardError: stdOut];

    [self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
                                        cdrecord, [cdrArgs componentsJoinedByString: @" "]] raw: NO];

    [cdrTask launch];

    while ([cdrTask isRunning]) {
        NSData *inData;
        while ((inData = [[[cdrTask standardError] fileHandleForReading] availableData]) &&
                [inData length]) {
            int i, count;
            NSString *aLine;
            NSArray *theOutput;

            theOutput = [[[NSString alloc] initWithData: inData
                                    encoding: NSISOLatin1StringEncoding]
                                    componentsSeparatedByString: @"\n"];

            count = [theOutput count];

            for (i = 0; i < count; i++) {
                aLine = [theOutput objectAtIndex: i];
                if (aLine && [aLine length])
                    [self sendOutputString: aLine raw: YES];
            }   // for (i = 0; i < count; i++)
        }   // while ((inData = 
    }   // while ([cdrTask isRunning])

    /*
     * If cdrecord did not terminate gracefully we stop the whole affair.
     * We delete in any case the actual (not finished) file.
     */
    {
        int termStatus = [cdrTask terminationStatus];   // FreeBSD needs an lvalue for the WIF* macros
        if ((WIFEXITED(termStatus) == 0)
                || WIFSIGNALED(termStatus)) {
            return NO;
        }
    }

    RELEASE(stdOut);
    RELEASE(cdrTask);

    return YES;
}

- (BOOL) burnCDFromImage: (id) image
          andAudioTracks: (NSArray *) trackArray
          withParameters: (NSDictionary *) parameters
{
    BOOL ret = YES;
    NSString *cdrecord;
    NSMutableArray *cdrArgs;
    NSPipe *stdOut;

    if (!image && (!trackArray || ![trackArray count])) {
        [self sendOutputString: _(@"No tracks to burn on CD.") raw: NO];
        return NO;
    }

    burnStatus.processStatus = isWaiting;

    cdrecord = [[parameters objectForKey: @"CDrecordParameters"]
                    objectForKey: @"Program"];

    if (!checkProgram(cdrecord)) {
        burnStatus.processStatus = isCancelled;
        return NO;
    }

    // set image file as first entry, if there is one
    burnTracks = [[NSMutableArray alloc] init];
    if (image)
        [burnTracks addObject: image];

    [burnTracks addObjectsFromArray: trackArray];

    /* The array is autoreleased! Don't release it here!!! */
    NS_DURING
        cdrArgs = [self makeParamsForTask: TaskBurn withParameters: parameters];
    NS_HANDLER
        [self sendOutputString: [NSString stringWithFormat: @"Error: %@ -> %@",
                                                [localException name],
                                                [localException reason]] raw: NO];
        NS_VALRETURN(NO);
    NS_ENDHANDLER

    [self appendTrackArgs: cdrArgs forCDROM: image ? YES : NO];

    burnStatus.trackNumber = 0;
    burnStatus.trackProgress = 0;
    burnStatus.entireProgress = 0;
    burnStatus.bufferLevel = 0;

    // set up cdrecord task
    cdrTask = [[NSTask alloc] init];
    stdOut = [[NSPipe alloc] init];

    [cdrTask setLaunchPath: cdrecord];

    [cdrTask setArguments: cdrArgs];
    [cdrTask setStandardOutput: stdOut];
    [cdrTask setStandardError: stdOut];

    [self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
                                        cdrecord, [cdrArgs componentsJoinedByString: @" "]] raw: NO];

    [cdrTask launch];

    [self waitForEndOfBurning];

    /*
     * If cdrecord did not terminate gracefully we stop the whole affair.
     * We delete in any case the actual (not finished) file.
     */
    {
        int termStatus = [cdrTask terminationStatus];   // FreeBSD needs an lvalue for the WIF* macros
        if ((WIFEXITED(termStatus) == 0)
                || WIFSIGNALED(termStatus)
                || (burnStatus.processStatus == isCancelled)) {
            burnStatus.processStatus = isCancelled;
            ret = NO;
        }
    }

    RELEASE(stdOut);
    RELEASE(cdrTask);

    RELEASE(burnTracks);

    if (burnStatus.processStatus != isCancelled) {
        [statusLock lock];
        burnStatus.processStatus = isStopped;
        [statusLock unlock];
    }

    return ret;
}

- (NSArray *) drivers
{
    return drivers;
}
 
- (ToolStatus) getStatus
{
    ToolStatus status;

    [statusLock lock];
    status = burnStatus;
    [statusLock unlock];
    return status;
}

- (BOOL) stop: (BOOL)immediately
{
    if (cdrTask && (burnStatus.processStatus == isBurning)) {
        [cdrTask terminate];
        [self sendOutputString: _(@"Terminating process.") raw: NO];
        burnStatus.processStatus = isCancelled;
    } else if (cdrTask && (burnStatus.processStatus == isWaiting)) {
        [cdrTask terminate];
        [self sendOutputString: _(@"Terminating process.") raw: NO];
        burnStatus.processStatus = isCancelled;
    }
    return YES;
}

@end
