/* vim: set ft=objc ts=4 et sw=4 nowrap: */
/*
 *  CdrdaoController.m
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
#include <stdlib.h>

#include "CdrdaoController.h"

#include "CdrdaoSettingsView.h"

#include "Constants.h"
#include "Functions.h"


#ifdef _
#undef _
#endif

#define _(X) \
	[[NSBundle bundleForClass: [self class]] localizedStringForKey:(X) value:@"" table:nil]


static CdrdaoController *singleInstance = nil;

@implementation CdrdaoController

- (id) init
{
	self = [super init];

	if (self) {
		if (!fileMan) {
			fileMan = [NSFileManager defaultManager];
		}
		statusLock = [NSLock new];

        [self initializeFromDefaults];
		[self checkForDrives];
	}

	return self;
}


- (void) dealloc
{
	singleInstance = nil;
    RELEASE(drives);
	RELEASE(statusLock);

	[super dealloc];
}


//
// BurnTool methods
//

- (NSString *) name
{
	return @"cdrdao";
}

- (id<PreferencesModule>) preferences;
{
    return AUTORELEASE([CdrdaoSettingsView singleInstance]);
}

- (id<PreferencesModule>) parameters;
{
	return nil;
}

- (void) cleanUp
{
	int i, count;

	if (tempFiles) {
		NSString *file;
		count = [tempFiles count];
		for (i = 0; i < count; i++) {
			file = [tempFiles objectAtIndex: i];
			[self sendOutputString: [NSString stringWithFormat: _(@"Removing temporary file %@."), file] raw: NO];
			[fileMan removeFileAtPath: file handler: nil];
		}

		RELEASE(tempFiles);
		tempFiles = nil;
	}
}

+ (id) singleInstance
{
	if (! singleInstance) {
		singleInstance = [[CdrdaoController alloc] init];
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

- (NSDictionary *) mediaInformationForDevice: (NSString *) device
                                  parameters: (NSDictionary *) parameters
{
	int i, count;
	NSString *cdrdao;
	NSMutableArray *cdrArgs;
	NSPipe *stdOut;
	NSArray *cdrOutput;
	NSString *outLine;

	// preset the dictionary with some defaults
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									_(@"NONE"), @"type",
									@"n/a", @"vendor",
									@"n/a", @"speed",
									@"n/a", @"capacity",
									@"n/a", @"empty",
									@"n/a", @"remCapacity",
									@"n/a", @"sessions",
									@"n/a", @"appendable", nil];

	cdrdao = [[parameters objectForKey: @"CdrdaoParameters"]
					objectForKey: @"Program"];

    if (!checkProgram(cdrdao))
        return nil;

    cdrArgs = [NSMutableArray arrayWithObjects: @"disk-info", nil];
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

	// set up cdrdao task
	cdrTask = [[NSTask alloc] init];
	stdOut = [[NSPipe alloc] init];

	[cdrTask setLaunchPath: cdrdao];
	[cdrTask setArguments: cdrArgs];
	[cdrTask setStandardOutput: stdOut];
	[cdrTask setStandardError: stdOut];

	[self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
										cdrdao, [cdrArgs componentsJoinedByString: @" "]] raw: NO];
	[cdrTask launch];

	[cdrTask waitUntilExit];

	/*
	 * If cdrdao did not terminate gracefully we stop the whole affair.
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
		range = [outLine rangeOfString: @"CD-RW"];
		if (range.location != NSNotFound) {
			if ([[outLine substringFromIndex: 23] isEqual: @"yes"])
				[info setObject: @"CD-RW" forKey: @"type"];
			else
				[info setObject: @"CD-R" forKey: @"type"];
			continue;
		}
		range = [outLine rangeOfString: @"CD-R medium"];
		if (range.location != NSNotFound) {
			[info setObject: [outLine substringFromIndex: 23] forKey: @"vendor"];
			continue;
		}
		range = [outLine rangeOfString: @"CD-R empty"];
		if (range.location != NSNotFound) {
			if ([[outLine substringFromIndex: 23] isEqual: @"yes"])
				[info setObject: @"yes" forKey: @"empty"];
			else
				[info setObject: @"no" forKey: @"empty"];
			continue;
		}
		range = [outLine rangeOfString: @"Recording Speed"];
		if (range.location != NSNotFound) {
			[info setObject: [outLine substringFromIndex: 23] forKey: @"speed"];
			continue;
		}
		range = [outLine rangeOfString: @"Total Capacity"];
		if (range.location != NSNotFound) {
			if ([outLine length] > 30) {
				NSString *str = [NSString stringWithFormat: @"%@ - %@",
									[outLine substringWithRange: NSMakeRange(23,8)],
									[outLine substringFromIndex: 32]];
				[info setObject: str forKey: @"capacity"];
			} else
				[info setObject: [outLine substringFromIndex: 23] forKey: @"capacity"];
			continue;
		}
		range = [outLine rangeOfString: @"Remaining Capacity"];
		if (range.location != NSNotFound) {
			if ([outLine length] > 30) {
				NSString *str = [NSString stringWithFormat: @"%@ - %@",
									[outLine substringWithRange: NSMakeRange(23,8)],
									[outLine substringFromIndex: 32]];
				[info setObject: str forKey: @"remCapacity"];
			} else
				[info setObject: [outLine substringFromIndex: 23] forKey: @"remCapacity"];
			continue;
		}
		range = [outLine rangeOfString: @"Sessions"];
		if (range.location != NSNotFound) {
			[info setObject: [outLine substringFromIndex: 23] forKey: @"sessions"];
			continue;
		}
		range = [outLine rangeOfString: @"Appendable"];
		if (range.location != NSNotFound) {
			if ([[outLine substringFromIndex: 23] isEqual: @"yes"])
				[info setObject: @"yes" forKey: @"appendable"];
			else
				[info setObject: @"no" forKey: @"appendable"];
			continue;
		}
	}

	RELEASE(stdOut);
	RELEASE(cdrTask);

	return info;
}

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
	NSString *cdrdao;
	NSMutableArray *cdrArgs;
	NSPipe *stdOut;

	cdrdao = [[parameters objectForKey: @"CdrdaoParameters"]
					objectForKey: @"Program"];

    if (!checkProgram(cdrdao))
        return NO;

    cdrArgs = [NSMutableArray arrayWithObjects: @"blank", nil];
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

    [cdrArgs addObject: @"--eject"];
    [cdrArgs addObject: @"--blank-mode"];
    [cdrArgs addObject: mode==fullBlank?@"full":@"minimal"];

	// set up cdrdao task
	cdrTask = [[NSTask alloc] init];
	stdOut = [[NSPipe alloc] init];

	[cdrTask setLaunchPath: cdrdao];

	[cdrTask setArguments: cdrArgs];
	[cdrTask setStandardOutput: stdOut];
	[cdrTask setStandardError: stdOut];

	[self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
										cdrdao, [cdrArgs componentsJoinedByString: @" "]] raw: NO];

	[cdrTask launch];

	// read cdrdao's output and send it to the display
	while ([cdrTask isRunning]) {
		NSData *inData;
        while ((inData = [[[cdrTask standardError] fileHandleForReading] availableData]) &&
				 [inData length]) {
			int i, count;
			NSString *aLine;
			NSString *temp;
			NSArray *theOutput;

			temp = [[NSString alloc] initWithData: inData
									encoding: NSISOLatin1StringEncoding];

			theOutput = [temp componentsSeparatedByString: @"\n"];

			count = [theOutput count];

			for (i = 0; i < count; i++) {
				aLine = [theOutput objectAtIndex: i];
				if (aLine && [aLine length]) {
					// post the oputput to the progress panel
					[[NSDistributedNotificationCenter defaultCenter]
								postNotificationName: ExternalToolOutput
										object: nil
										userInfo: [NSDictionary dictionaryWithObject: aLine forKey: @"Output"]];
				}
			}	// for (i = 0; i < count; i++)
		}	//  while ((inData = 
	}	// while ([cdrTask isRunning])

	/*
	 * If cdrdao did not terminate gracefully we stop the whole affair.
	 * We delete in any case the actual (not finished) file.
	 */
    {
    	int termStatus = [cdrTask terminationStatus];	// FreeBSD needs an lvalue for the WIF* macros
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
	NSString *cdrdao;
	NSMutableArray *cdrArgs;
	NSPipe *stdOut;
	NSString *tocFile;

	if (!image && (!trackArray || ![trackArray count])) {
		[self sendOutputString: _(@"No tracks to burn on CD.") raw: NO];
		return NO;
	}

	burnStatus.trackNumber = 0;
	burnStatus.trackProgress = 0;
	burnStatus.entireProgress = 0;
	burnStatus.bufferLevel = 0;
	burnStatus.processStatus = isPreparing;

	cdrdao = [[parameters objectForKey: @"CdrdaoParameters"]
					objectForKey: @"Program"];

    if (!checkProgram(cdrdao)) {
	    burnStatus.processStatus = isCancelled;
        return NO;
    }

	tempDir = [[parameters objectForKey: @"SessionParameters"]
                    objectForKey: @"TempDirectory"];

	// set image file as first entry, if there is one
	burnTracks = [[NSMutableArray alloc] init];
	if (image)
		[burnTracks addObject: image];

	[burnTracks addObjectsFromArray: trackArray];

	// create the TOC file
	tocFile = [self createTOC: image ? YES : NO];
    RETAIN(tocFile);

	// createTOC: converts .au files to .wav files
	// if this was cancelled by the user we stop here
	if (burnStatus.processStatus == isCancelled) {
		[fileMan removeFileAtPath: tocFile handler: nil];
		RELEASE(burnTracks);
		return NO;
	}

	// creta ethe arguments array
	NS_DURING
		cdrArgs = [self makeParamsForTask: TaskBurn
                           withParameters: parameters
                                  tocFile: tocFile];
	NS_HANDLER
		[self sendOutputString: [NSString stringWithFormat: @"Error: %@ -> %@",
												[localException name],
												[localException reason]] raw: NO];
		NS_VALRETURN(NO);
	NS_ENDHANDLER

	burnStatus.trackNumber = 0;
	burnStatus.trackProgress = 0;
	burnStatus.entireProgress = 0;
	burnStatus.bufferLevel = 0;
	burnStatus.processStatus = isWaiting;

	// set up cdrdao task
	cdrTask = [[NSTask alloc] init];
	stdOut = [[NSPipe alloc] init];

	[cdrTask setLaunchPath: cdrdao];

	[cdrTask setArguments: cdrArgs];
	[cdrTask setStandardError: stdOut];

	[self sendOutputString: [NSString stringWithFormat: _(@"Launching %@ %@"),
										cdrdao, [cdrArgs componentsJoinedByString: @" "]] raw: NO];

	[cdrTask launch];

	[self waitForEndOfBurning];

	/*
	 * If cdrdao did not terminate gracefully we stop the whole affair.
	 * We delete in any case the actual (not finished) file.
	 */
       {
   		int termStatus = [cdrTask terminationStatus];	// FreeBSD needs an lvalue for the WIF* macros
   		if ((WIFEXITED(termStatus) == 0)
   				|| WIFSIGNALED(termStatus)
   				|| (burnStatus.processStatus == isCancelled)) {
   			burnStatus.processStatus = isCancelled;
   			ret = NO;
   		}
       } 
	RELEASE(stdOut);
	RELEASE(cdrTask);

	if (burnStatus.processStatus != isCancelled) {
		[statusLock lock];
		burnStatus.processStatus = isStopped;
		[statusLock unlock];
	}

	[fileMan removeFileAtPath: tocFile handler: nil];
    RELEASE(tocFile);
	
	RELEASE(burnTracks);

	return ret;
}

- (NSArray *) drivers
{
	return [NSArray arrayWithObjects:
					@"Default", @"cdd2600", @"plextor",
					@"plextor-scan", @"generic-mmc", @"generic-mmc-raw",
					@"ricoh-mp6200", @"yamaha-cdr10x", @"teac-cdr55",
					@"sony-cdu920", @"sony-cdu948", @"taiyo-yuden",
					@"toshiba", nil];
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
	} else if (burnStatus.processStatus == isPreparing) {
		if (cdrTask)
			[cdrTask terminate];
		[self sendOutputString: _(@"Terminating process.") raw: NO];
		burnStatus.processStatus = isCancelled;
	}
	return YES;
}

- (ToolStatus) getStatus
{
	ToolStatus status;

	[statusLock lock];
	status = burnStatus;
	[statusLock unlock];
	return status;
}


@end
